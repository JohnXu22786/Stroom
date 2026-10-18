import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/llm_account.dart';
import 'llm_connector_service.dart';

/// Queries the account-level signals the pinned upstream exposes directly.
/// Other connectors return unknown unless their native request response itself
/// carried an explicit usage or quota event.
class LlmConnectorQuotaService {
  final LlmAccountConnectorService accountService;
  final Dio _dio;
  final DateTime Function() _clock;

  LlmConnectorQuotaService({
    required this.accountService,
    Dio? dio,
    DateTime Function()? clock,
  })  : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 30),
              ),
            ),
        _clock = clock ?? DateTime.now;

  Future<LlmConnectorObservation> observeAccountQuota(
    LlmAccount account,
  ) async {
    final stored = await accountService.getAccount(account.id);
    if (stored == null ||
        LlmConnectorRegistry.canonicalId(stored.connectorType) !=
            LlmConnectorRegistry.canonicalId(account.connectorType)) {
      throw const LlmConnectorQuotaException();
    }
    switch (stored.connectorType) {
      case 'antigravity':
        return _observeAntigravity(stored);
      case 'devin':
        return _observeDevin(stored);
      default:
        return LlmConnectorObservation();
    }
  }

  Future<LlmConnectorObservation> _observeAntigravity(
    LlmAccount account, {
    bool didRefresh = false,
  }) async {
    final token = _credentialToken(
      account,
      await accountService.readCredential(account.id),
      const ['access_token', 'accessToken'],
    );
    final base = _httpsBase(account, 'https://cloudcode-pa.googleapis.com');
    final uri = base.replace(
      path: _joinPath(base.path, '/v1internal:loadCodeAssist'),
      query: null,
      fragment: null,
    );
    final configuredAgent = account.endpointConfig['userAgent'];
    final userAgent =
        configuredAgent is String && configuredAgent.trim().isNotEmpty
            ? configuredAgent.trim()
            : kLlmAntigravityRequestUserAgent;
    Object? body;
    try {
      body = await _post(
        uri,
        data: const {
          'metadata': {'ideType': 'ANTIGRAVITY'},
        },
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': '*/*',
          'Content-Type': 'application/json',
          'User-Agent': userAgent,
        },
        binary: false,
      );
    } on LlmConnectorQuotaException catch (error) {
      if (didRefresh || error.statusCode != 401) rethrow;
      try {
        if (await accountService.refreshCredential(account)) {
          return _observeAntigravity(account, didRefresh: true);
        }
      } catch (_) {
        throw const LlmConnectorQuotaException();
      }
      rethrow;
    }
    if (body is! Map) return LlmConnectorObservation();
    final paidTier = body['paidTier'];
    if (paidTier is! Map || paidTier['availableCredits'] is! List) {
      return LlmConnectorObservation();
    }
    final availableCredits = paidTier['availableCredits'] as List;
    for (final raw in availableCredits) {
      if (raw is! Map || raw['creditType'] != 'GOOGLE_ONE_AI') continue;
      final amount = _number(raw['creditAmount']);
      final minimum = _number(raw['minimumCreditAmountForUsage']);
      if (amount == null) continue;
      final observedAt = _clock().toUtc();
      return LlmConnectorObservation(
        remainingQuota: LlmMetricObservation.reported(
          amount,
          unit: 'credits',
          source: 'antigravity.GOOGLE_ONE_AI',
          observedAt: observedAt,
        ),
        quotaSignals: {
          if (minimum != null)
            'minimumCreditsForUsage': LlmMetricObservation.reported(
              minimum,
              unit: 'credits',
              source: 'antigravity.GOOGLE_ONE_AI',
              observedAt: observedAt,
            ),
        },
      );
    }
    return LlmConnectorObservation();
  }

  Future<LlmConnectorObservation> _observeDevin(LlmAccount account) async {
    final token = _credentialToken(
      account,
      await accountService.readCredential(account.id),
      const ['session_token', 'sessionToken', 'access_token', 'accessToken'],
    );
    final base = _httpsBase(account, 'https://server.codeium.com');
    final uri = base.replace(
      path: _joinPath(
        base.path,
        '/exa.seat_management_pb.SeatManagementService/GetUserStatus',
      ),
      query: null,
      fragment: null,
    );
    final body = await _post(
      uri,
      data: _buildDevinUserStatusRequest(token, account.id),
      headers: {
        'Authorization': 'Basic $token-$token',
        'Connect-Protocol-Version': '1',
        'Content-Type': 'application/proto',
        'Accept': '*/*',
        'User-Agent': '',
      },
      binary: true,
    );
    if (body is! Uint8List) return LlmConnectorObservation();
    final status = _parseDevinQuotaResponse(body);
    final observedAt = _clock().toUtc();
    return LlmConnectorObservation(
      quotaSignals: {
        if (status.dailyRemainingPercent != null)
          'dailyRemainingPercent': LlmMetricObservation.reported(
            status.dailyRemainingPercent!,
            unit: 'percent',
            source: 'devin.daily',
            observedAt: observedAt,
            resetAt: status.dailyResetAt,
          ),
        if (status.weeklyRemainingPercent != null)
          'weeklyRemainingPercent': LlmMetricObservation.reported(
            status.weeklyRemainingPercent!,
            unit: 'percent',
            source: 'devin.weekly',
            observedAt: observedAt,
            resetAt: status.weeklyResetAt,
          ),
      },
    );
  }

  Future<Object?> _post(
    Uri uri, {
    required Object? data,
    required Map<String, String> headers,
    required bool binary,
  }) async {
    try {
      final response = await _dio.postUri<Object?>(
        uri,
        data: data,
        options: Options(
          headers: headers,
          responseType: ResponseType.bytes,
          validateStatus: (status) => status != null,
        ),
      );
      final status = response.statusCode ?? 0;
      if (status < 200 || status >= 300) {
        throw LlmConnectorQuotaException(statusCode: status);
      }
      if (binary) {
        if (response.data is Uint8List) return response.data;
        if (response.data is List<int>) {
          return Uint8List.fromList(response.data as List<int>);
        }
        return null;
      }
      return _decodeJson(response.data);
    } on LlmConnectorQuotaException {
      rethrow;
    } catch (_) {
      throw const LlmConnectorQuotaException();
    }
  }

  static Object? _decodeJson(Object? data) {
    try {
      if (data is Map) return data;
      if (data is Uint8List) return jsonDecode(utf8.decode(data));
      if (data is List<int>) {
        return jsonDecode(utf8.decode(Uint8List.fromList(data)));
      }
      if (data is String) return jsonDecode(data);
      if (data is List) return data;
    } catch (_) {
      return null;
    }
    return null;
  }

  static String _credentialToken(
    LlmAccount account,
    String? credential,
    List<String> bundleKeys,
  ) {
    if (credential == null || credential.trim().isEmpty) {
      throw const LlmConnectorQuotaException();
    }
    Object? decoded;
    var isJson = false;
    try {
      decoded = jsonDecode(credential);
      isJson = true;
    } catch (_) {
      // Session tokens may be stored as an opaque string.
    }
    if (isJson) {
      if (decoded is! Map) throw const LlmConnectorQuotaException();
      final acceptedKeys = switch (account.authType) {
        'oauth' => const {'access_token', 'accessToken'},
        'session_token' => const {
            'session_token',
            'sessionToken',
            'access_token',
            'accessToken',
          },
        _ => const <String>{},
      };
      for (final key in bundleKeys) {
        if (!acceptedKeys.contains(key)) continue;
        final value = decoded[key];
        if (value is String && value.trim().isNotEmpty) return value.trim();
      }
      throw const LlmConnectorQuotaException();
    }
    if (account.authType == 'oauth' || account.authType == 'session_token') {
      return credential.trim();
    }
    throw const LlmConnectorQuotaException();
  }

  static Uri _httpsBase(LlmAccount account, String fallback) {
    final configured = account.endpointConfig['baseUrl'];
    final value = configured is String && configured.trim().isNotEmpty
        ? configured.trim()
        : fallback;
    final base = Uri.tryParse(value);
    if (base == null ||
        base.scheme != 'https' ||
        base.host.isEmpty ||
        base.userInfo.isNotEmpty ||
        base.host != Uri.parse(fallback).host) {
      throw const LlmConnectorQuotaException();
    }
    return base;
  }

  static String _joinPath(String base, String suffix) {
    if (base.isEmpty || base == '/') return suffix;
    return '${base.replaceFirst(RegExp(r'/+$'), '')}$suffix';
  }

  static num? _number(Object? value) {
    if (value is num) return value;
    if (value is String) return num.tryParse(value.trim());
    return null;
  }
}

class LlmConnectorQuotaException implements Exception {
  final int? statusCode;

  const LlmConnectorQuotaException({this.statusCode});

  @override
  String toString() => statusCode == null
      ? 'LLM connector quota could not be read.'
      : 'LLM connector quota request failed with status $statusCode.';
}

Uint8List _buildDevinUserStatusRequest(String sessionToken, String seed) {
  final metadata = <int>[];
  _appendBytesField(metadata, 1, utf8.encode('chisel'));
  _appendBytesField(metadata, 2, utf8.encode('3000.10.21'));
  _appendBytesField(metadata, 3, utf8.encode(sessionToken));
  _appendBytesField(metadata, 4, utf8.encode('en'));
  _appendBytesField(metadata, 5, utf8.encode(_goosName(defaultTargetPlatform)));
  _appendBytesField(metadata, 7, utf8.encode('3000.10.21'));
  _appendBytesField(metadata, 12, utf8.encode('chisel'));
  _appendBytesField(metadata, 31, utf8.encode(_devinFingerprint(seed)));
  final request = <int>[];
  _appendBytesField(request, 1, metadata);
  return Uint8List.fromList(request);
}

String _goosName(TargetPlatform platform) => switch (platform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.linux => 'linux',
      TargetPlatform.macOS => 'darwin',
      TargetPlatform.windows => 'windows',
      TargetPlatform.fuchsia => 'fuchsia',
    };

String _devinFingerprint(String seed) {
  final value = StringBuffer();
  var counter = 0;
  while (value.length < 732) {
    value.write(
      crypto.sha256.convert(utf8.encode('$seed-$counter')).toString(),
    );
    counter++;
  }
  return value.toString().substring(0, 732);
}

void _appendBytesField(List<int> output, int fieldNumber, List<int> value) {
  _appendVarint(output, (fieldNumber << 3) | 2);
  _appendVarint(output, value.length);
  output.addAll(value);
}

void _appendVarint(List<int> output, int value) {
  while (value >= 0x80) {
    output.add((value & 0x7f) | 0x80);
    value >>= 7;
  }
  output.add(value);
}

_DevinQuotaStatus _parseDevinQuotaResponse(Uint8List response) {
  final outer = _protoFields(response);
  final userStatusBytes = outer
      .where((field) => field.number == 1 && field.bytes != null)
      .map((field) => field.bytes!)
      .firstOrNull;
  if (userStatusBytes == null) return const _DevinQuotaStatus();
  final statusFields = _protoFields(userStatusBytes);
  final planStatus = statusFields
      .where((field) => field.number == 13 && field.bytes != null)
      .map((field) => field.bytes!)
      .firstOrNull;
  if (planStatus == null) return const _DevinQuotaStatus();
  final fields = _protoFields(planStatus);
  final daily = _protoScalar(fields, 14);
  final weekly = _protoScalar(fields, 15);
  final dailyReset = _protoScalar(fields, 17);
  final weeklyReset = _protoScalar(fields, 18);
  return _DevinQuotaStatus(
    dailyRemainingPercent:
        daily != null && daily >= 0 && daily <= 100 ? daily : null,
    weeklyRemainingPercent:
        weekly != null && weekly >= 0 && weekly <= 100 ? weekly : null,
    dailyResetAt: _dateFromEpoch(dailyReset),
    weeklyResetAt: _dateFromEpoch(weeklyReset),
  );
}

List<_ProtoField> _protoFields(Uint8List bytes) {
  final fields = <_ProtoField>[];
  var offset = 0;
  while (offset < bytes.length) {
    final tag = _readVarint(bytes, offset);
    offset = tag.nextOffset;
    final number = tag.value >> 3;
    final wireType = tag.value & 7;
    if (number == 0) throw const LlmConnectorQuotaException();
    switch (wireType) {
      case 0:
        final scalar = _readVarint(bytes, offset);
        offset = scalar.nextOffset;
        fields.add(_ProtoField(number, scalar: scalar.value));
      case 1:
        offset += 8;
        if (offset > bytes.length) throw const LlmConnectorQuotaException();
        fields.add(_ProtoField(number));
      case 2:
        final size = _readVarint(bytes, offset);
        offset = size.nextOffset;
        final end = offset + size.value;
        if (size.value < 0 || end > bytes.length) {
          throw const LlmConnectorQuotaException();
        }
        fields.add(_ProtoField(number, bytes: bytes.sublist(offset, end)));
        offset = end;
      case 5:
        offset += 4;
        if (offset > bytes.length) throw const LlmConnectorQuotaException();
        fields.add(_ProtoField(number));
      default:
        throw const LlmConnectorQuotaException();
    }
  }
  return fields;
}

_ProtoVarint _readVarint(Uint8List bytes, int offset) {
  var value = 0;
  var shift = 0;
  while (offset < bytes.length && shift < 64) {
    final byte = bytes[offset++];
    value |= (byte & 0x7f) << shift;
    if (byte & 0x80 == 0) return _ProtoVarint(value, offset);
    shift += 7;
  }
  throw const LlmConnectorQuotaException();
}

int? _protoScalar(List<_ProtoField> fields, int number) => fields
    .where((field) => field.number == number && field.scalar != null)
    .map((field) => field.scalar!)
    .firstOrNull;

DateTime? _dateFromEpoch(int? seconds) => seconds == null || seconds <= 0
    ? null
    : DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);

class _ProtoField {
  final int number;
  final int? scalar;
  final Uint8List? bytes;

  const _ProtoField(this.number, {this.scalar, this.bytes});
}

class _ProtoVarint {
  final int value;
  final int nextOffset;

  const _ProtoVarint(this.value, this.nextOffset);
}

class _DevinQuotaStatus {
  final int? dailyRemainingPercent;
  final int? weeklyRemainingPercent;
  final DateTime? dailyResetAt;
  final DateTime? weeklyResetAt;

  const _DevinQuotaStatus({
    this.dailyRemainingPercent,
    this.weeklyRemainingPercent,
    this.dailyResetAt,
    this.weeklyResetAt,
  });
}
