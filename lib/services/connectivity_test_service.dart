import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb, visibleForTesting;
import 'package:flutter/widgets.dart' show Locale;
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../models/mcp.dart';
import '../models/tts_models.dart';
import 'http_tool_service.dart';
import 'mcp_client.dart';
import 'todo_tool_service.dart';
import 'web_search_service.dart';

class ConnectivityTestResult {
  final bool succeeded;
  final String summary;
  final String details;
  final Duration elapsed;

  const ConnectivityTestResult({
    required this.succeeded,
    required this.summary,
    required this.details,
    required this.elapsed,
  });
}

/// Runs safe, user-configurable connectivity probes for the MCP tools page.
class ConnectivityTestService {
  static const _builtinPreferencePrefix = 'mcp_connectivity_test_';

  static final _jsonEncoder = const JsonEncoder.withIndent('  ');

  static String defaultMcpTestContent() => _jsonEncoder.convert({
        'method': 'tools/list',
        'params': <String, dynamic>{},
      });

  static String defaultSearchTestContent() =>
      _jsonEncoder.convert({'query': 'Stroom 连通性测试', 'count': 1});

  static String defaultBuiltinTestContent(String toolName) {
    if (toolName == 'todowrite') return '{}';
    return _jsonEncoder.convert({
      'query': 'Stroom 连通性测试',
      'source': 'google',
      'count': 1,
    });
  }

  static String configuredTestContent(
    ProviderConfigItem config, {
    required bool isHttpTool,
  }) {
    final typeConfig = config.models.isNotEmpty
        ? config.models[0].typeConfig
        : config.typeConfig;
    final raw = typeConfig['connectivityTest'];
    if (raw is Map) {
      return _jsonEncoder.convert(Map<String, dynamic>.from(raw));
    }
    return isHttpTool ? defaultSearchTestContent() : defaultMcpTestContent();
  }

  static Future<String> loadBuiltinTestContent(String toolName) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_builtinPreferencePrefix$toolName') ??
        defaultBuiltinTestContent(toolName);
  }

  static Future<void> saveBuiltinTestContent(
    String toolName,
    Map<String, dynamic> content,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setString(
      '$_builtinPreferencePrefix$toolName',
      _jsonEncoder.convert(content),
    );
    if (!saved) {
      throw StateError('无法保存内置工具的连通性测试内容。');
    }
  }

  static Map<String, dynamic> decodeTestContent(String rawContent) {
    final decoded = jsonDecode(rawContent);
    if (decoded is! Map) {
      throw const FormatException('测试内容顶层必须是 JSON 对象');
    }
    return Map<String, dynamic>.from(decoded);
  }

  static Future<ConnectivityTestResult> runProviderTest({
    required ProviderConfigItem config,
    required String testContent,
    required AppLocalizations localizations,
    required Locale locale,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final content = decodeTestContent(testContent);
      final typeConfig = config.models.isNotEmpty
          ? config.models[0].typeConfig
          : config.typeConfig;

      if (typeConfig['isHttpTool'] == true) {
        final toolName = config.models.isNotEmpty
            ? config.models[0].name
            : config.providerName;
        final result = await HttpToolService.runConnectivityTest(
          providerName: toolName,
          arguments: content,
          apiKey: HttpToolService.extractHttpToolApiKey(toolName, typeConfig),
          url: typeConfig['url'] as String? ?? config.host,
          locale: locale,
        );
        final succeeded = !isErrorResult(result, localizations);
        return _finish(
          stopwatch,
          succeeded,
          succeeded
              ? localizations.connectivityTestHttpSuccess
              : localizations.connectivityTestHttpFailure,
          result,
          localizations,
        );
      }

      final serverConfig = McpServerConfig.fromProviderConfig(
        providerName: config.providerName,
        typeConfig: typeConfig,
      );
      if (serverConfig == null) {
        return _finish(
          stopwatch,
          false,
          localizations.connectivityTestInvalidMcpConfig,
          localizations.connectivityTestMissingTransport,
          localizations,
        );
      }
      final isMobile = defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS;
      if (serverConfig.transportType == McpTransportType.stdio &&
          (kIsWeb || isMobile)) {
        return _finish(
          stopwatch,
          false,
          localizations.connectivityTestStdioUnsupported,
          localizations.connectivityTestStdioDesktopOnly,
          localizations,
        );
      }

      final rawMethod = content['method'];
      if (rawMethod != null && rawMethod is! String) {
        return _finish(
          stopwatch,
          false,
          localizations.connectivityTestInvalidContent,
          localizations.connectivityTestMethodMustBeString,
          localizations,
        );
      }
      final method = rawMethod as String? ?? 'tools/list';
      if (method != 'tools/list') {
        return _finish(
          stopwatch,
          false,
          localizations.connectivityTestUnsupportedMethod,
          localizations.connectivityTestReadOnlyMethodOnly,
          localizations,
        );
      }
      final rawParams = content['params'];
      if (rawParams != null && rawParams is! Map) {
        return _finish(
          stopwatch,
          false,
          localizations.connectivityTestInvalidContent,
          localizations.connectivityTestParamsMustBeObject,
          localizations,
        );
      }

      final client = McpClient(config: serverConfig);
      try {
        final connected = await client.connect().timeout(
              const Duration(seconds: 60),
            );
        if (!connected) {
          return _finish(
            stopwatch,
            false,
            localizations.connectivityTestMcpConnectionFailed,
            localizations.connectivityTestCheckConnectionSettings,
            localizations,
          );
        }
        final tools = await client
            .discoverTools(
              params: rawParams == null
                  ? const <String, dynamic>{}
                  : Map<String, dynamic>.from(rawParams as Map),
            )
            .timeout(const Duration(seconds: 35));
        final names = tools.map((tool) => tool.name).take(12).join(', ');
        final suffix = tools.length > 12
            ? localizations.connectivityTestRemainingToolsOmitted
            : '';
        return _finish(
          stopwatch,
          true,
          localizations.connectivityTestMcpSuccess,
          localizations.connectivityTestMcpSuccessDetails(
            tools.length,
            names.isEmpty ? '' : localizations.connectivityTestToolNames(names),
            suffix,
          ),
          localizations,
        );
      } finally {
        client.dispose();
      }
    } catch (error) {
      return _finish(
        stopwatch,
        false,
        localizations.connectivityTestFailedSummary,
        _readableError(error, localizations),
        localizations,
      );
    }
  }

  static Future<ConnectivityTestResult> runBuiltinTest({
    required String toolName,
    required String testContent,
    required AppLocalizations localizations,
    required Locale locale,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final arguments = decodeTestContent(testContent);
      late final String result;
      switch (toolName) {
        case 'todowrite':
          if (arguments['todos'] != null) {
            return _finish(
              stopwatch,
              false,
              localizations.connectivityTestTodoMutationBlocked,
              localizations.connectivityTestTodoReadOnly,
              localizations,
            );
          }
          result = await TodoToolService.handleTodo(arguments, locale: locale);
          break;
        case 'web_search':
          result = await WebSearchService.handleWebSearch(
            arguments,
            locale: locale,
          );
          break;
        default:
          return _finish(
            stopwatch,
            false,
            localizations.connectivityTestUnknownBuiltin,
            localizations.connectivityTestBuiltinExecutorMissing(toolName),
            localizations,
          );
      }

      final succeeded = !isErrorResult(result, localizations);
      return _finish(
        stopwatch,
        succeeded,
        succeeded
            ? localizations.connectivityTestBuiltinSuccess
            : localizations.connectivityTestBuiltinFailure,
        result,
        localizations,
      );
    } catch (error) {
      return _finish(
        stopwatch,
        false,
        localizations.connectivityTestBuiltinFailure,
        _readableError(error, localizations),
        localizations,
      );
    }
  }

  static ConnectivityTestResult _finish(
    Stopwatch stopwatch,
    bool succeeded,
    String summary,
    String details,
    AppLocalizations localizations,
  ) {
    stopwatch.stop();
    const maxDetailsLength = 4000;
    final visibleDetails = details.length <= maxDetailsLength
        ? details
        : '${details.substring(0, maxDetailsLength)}\n${localizations.connectivityTestResultTruncated}';
    return ConnectivityTestResult(
      succeeded: succeeded,
      summary: summary,
      details: visibleDetails,
      elapsed: stopwatch.elapsed,
    );
  }

  static String _readableError(Object error, AppLocalizations localizations) {
    if (error is FormatException) {
      if (error.message == '测试内容顶层必须是 JSON 对象') {
        return localizations.connectivityTestTopLevelObjectRequired;
      }
      return error.message;
    }
    if (error is TimeoutException) {
      const mcpTimeoutPrefix = 'MCP request timed out: ';
      final message = error.message;
      if (message != null && message.startsWith(mcpTimeoutPrefix)) {
        return localizations.connectivityTestMcpRequestTimeout(
          message.substring(mcpTimeoutPrefix.length),
        );
      }
      return localizations.connectivityTestRequestTimeout;
    }
    return error.toString();
  }

  @visibleForTesting
  static bool isErrorResult(String result, AppLocalizations localizations) {
    if (result.startsWith('错误:') ||
        result.startsWith('错误：') ||
        result.startsWith('Error:')) {
      return true;
    }
    const placeholder = '\u0000';
    final incompleteMessage = localizations.toolResultWebSearchIncomplete(
      placeholder,
      placeholder,
    );
    final placeholderIndex = incompleteMessage.indexOf(placeholder);
    return placeholderIndex >= 0 &&
        result.startsWith(incompleteMessage.substring(0, placeholderIndex));
  }
}
