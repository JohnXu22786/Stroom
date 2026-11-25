import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'provider_config.dart';

// ============================================================================
// OCR 通用识别指令
// ============================================================================

/// A user instruction sent together with the images for OCR.
///
/// Instructions are generic — configured once on the OCR page and applied
/// to every OCR model — rather than per-model.
class OcrInstruction {
  /// Optional display name; when empty the content snippet is shown.
  final String name;
  final String content;

  const OcrInstruction({this.name = '', required this.content});

  Map<String, dynamic> toMap() => {'name': name, 'content': content};

  @override
  bool operator ==(Object other) =>
      other is OcrInstruction && other.name == name && other.content == content;

  @override
  int get hashCode => Object.hash(name, content);

  /// Parses a stored {name, content} map, trimming both fields.
  /// Blank-content entries (nothing to send) normalize to an empty list by
  /// the caller dropping them via [content.isNotEmpty].
  static OcrInstruction fromMap(Map<String, dynamic> map) {
    return OcrInstruction(
      name: (map['name']?.toString() ?? '').trim(),
      content: (map['content']?.toString() ?? '').trim(),
    );
  }
}

/// One-time legacy migration: seed the generic instruction list from the
/// first OCR model that still carries per-model instructions
/// (`typeConfig['userInstructions']` or the legacy single-string
/// `typeConfig['userInstruction']`).
///
/// The old keys stay in the stored model configs untouched; this only fills
/// the new generic store so configured instructions are not lost. Idempotent
/// by construction — the migration only runs when the generic store is empty
/// (never written yet).
@visibleForTesting
List<OcrInstruction> migrateLegacyOcrInstructions(List<ProviderEntry> entries) {
  for (final entry in entries) {
    if (entry.type != 'ocr') continue;
    for (final config in entry.configs) {
      for (final model in config.models) {
        final raw = model.typeConfig['userInstructions'];
        if (raw is List) {
          final list = raw
              .whereType<Map>()
              .map((e) => OcrInstruction.fromMap(Map<String, dynamic>.from(e)))
              .where((i) => i.content.isNotEmpty)
              .toList();
          if (list.isNotEmpty) return list;
        }
        final legacy = model.typeConfig['userInstruction'];
        if (legacy is String && legacy.trim().isNotEmpty) {
          return [OcrInstruction(content: legacy.trim())];
        }
      }
    }
  }
  return [];
}

// ============================================================================
// 识别指令全局状态（持久化）
// ============================================================================

/// 通用识别指令列表提供器（持久化）。
///
/// 指令在 OCR 页面统一设置，对所有 OCR 模型生效。
final ocrInstructionsProvider =
    StateNotifierProvider<OcrInstructionsNotifier, List<OcrInstruction>>((ref) {
      final notifier = OcrInstructionsNotifier(ref);
      notifier.load();
      return notifier;
    });

class OcrInstructionsNotifier extends StateNotifier<List<OcrInstruction>> {
  OcrInstructionsNotifier(this._ref) : super([]);

  final Ref _ref;

  static const _storageKey = 'ocr_instructions';

  /// In-flight load future. The provider factory fires [load] unawaited and
  /// tests/UI may call it again explicitly — memoizing makes them share one
  /// load instead of racing.
  Future<void>? _loadFuture;

  /// Tracks edits made while the initial preferences/provider load is pending.
  int _userMutationVersion = 0;

  /// Malformed stored data is left in place during load and backed up before
  /// the first explicit user edit replaces it.
  String? _corruptStoredJson;

  /// Loads persisted instructions once.
  Future<void> load() => _loadFuture ??= _doLoad();

  Future<void> _doLoad() async {
    final loadMutationVersion = _userMutationVersion;
    // Capture the notifier and its load future before any async gap; reading
    // through [Ref] later may fail if this provider has been disposed.
    final providerEntriesNotifier = _ref.read(providerEntriesProvider.notifier);
    final providerEntriesReady = providerEntriesNotifier.ready;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      final json = prefs.getString(_storageKey);
      if (json != null) {
        if (json.isEmpty) {
          if (_userMutationVersion == loadMutationVersion) state = [];
          return;
        }
        List<OcrInstruction> list;
        try {
          list = _decodeStoredInstructions(json);
        } catch (e) {
          _corruptStoredJson = json;
          debugPrint('Failed to load OCR instructions: $e');
          return;
        }
        final preserveUserMutations =
            _userMutationVersion != loadMutationVersion;
        state = preserveUserMutations
            ? [
                ...list,
                ...state.where((instruction) => !list.contains(instruction)),
              ]
            : list;
        if (preserveUserMutations) await _persist();
        return;
      }
    } catch (e) {
      debugPrint('Failed to load OCR instructions: $e');
    }
    await providerEntriesReady;
    if (!mounted || !providerEntriesNotifier.mounted) return;
    // 旧版本按模型配置的指令一次性迁移进通用列表（仅当新存储从未写入时）。
    final legacy = migrateLegacyOcrInstructions(
      providerEntriesNotifier.state.entries,
    );
    if (legacy.isNotEmpty) {
      final preserveUserMutations = _userMutationVersion != loadMutationVersion;
      state = preserveUserMutations
          ? [
              ...legacy,
              ...state.where((instruction) => !legacy.contains(instruction)),
            ]
          : legacy;
      await _persist();
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedJson = prefs.getString(_storageKey);
      final corruptJson =
          _corruptStoredJson ??
          (storedJson != null &&
                  storedJson.isNotEmpty &&
                  !_isValidStoredJson(storedJson)
              ? storedJson
              : null);
      if (corruptJson != null) {
        _corruptStoredJson = corruptJson;
        if (!await _backupCorruptStoredJson(prefs, corruptJson)) return;
        _corruptStoredJson = null;
      }
      final json = jsonEncode(state.map((e) => e.toMap()).toList());
      await prefs.setString(_storageKey, json);
    } catch (e) {
      debugPrint('Failed to persist OCR instructions: $e');
    }
  }

  static List<OcrInstruction> _decodeStoredInstructions(String json) {
    final decoded = jsonDecode(json);
    if (decoded is! List) {
      throw const FormatException('OCR instructions must be a JSON list');
    }
    if (decoded.any((entry) => entry is! Map)) {
      throw const FormatException('OCR instructions must contain JSON objects');
    }
    return decoded
        .whereType<Map>()
        .map((e) => OcrInstruction.fromMap(Map<String, dynamic>.from(e)))
        .where((i) => i.content.isNotEmpty)
        .toList();
  }

  static bool _isValidStoredJson(String json) {
    try {
      _decodeStoredInstructions(json);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _backupCorruptStoredJson(
    SharedPreferences prefs,
    String corruptJson,
  ) async {
    try {
      final hasBackup = prefs.getKeys().any(
        (key) =>
            key.startsWith('ocr_instructions_corrupt_') &&
            prefs.getString(key) == corruptJson,
      );
      if (hasBackup) return true;
      final backupKey =
          'ocr_instructions_corrupt_${DateTime.now().microsecondsSinceEpoch}';
      final saved = await prefs.setString(backupKey, corruptJson);
      if (!saved) return false;
      debugPrint('Backed up corrupt OCR instructions to $backupKey');
      return true;
    } catch (e) {
      debugPrint('Failed to back up corrupt OCR instructions: $e');
      return false;
    }
  }

  /// 添加一条指令（name 可选，content 必填）。
  Future<void> add(String name, String content) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return;
    _userMutationVersion++;
    state = [...state, OcrInstruction(name: name.trim(), content: trimmed)];
    await _persist();
  }

  /// 更新 [index] 处的指令。
  Future<void> update(int index, String name, String content) async {
    final trimmed = content.trim();
    if (index < 0 || index >= state.length || trimmed.isEmpty) return;
    final next = [...state];
    next[index] = OcrInstruction(name: name.trim(), content: trimmed);
    _userMutationVersion++;
    state = next;
    await _persist();
  }

  /// 删除 [index] 处的指令。
  Future<void> remove(int index) async {
    if (index < 0 || index >= state.length) return;
    final next = [...state]..removeAt(index);
    _userMutationVersion++;
    state = next;
    await _persist();
  }
}
