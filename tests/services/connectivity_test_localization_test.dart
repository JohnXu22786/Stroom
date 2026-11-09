import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/l10n/app_localizations_en.dart';
import 'package:stroom/l10n/app_localizations_zh.dart';
import 'package:stroom/models/tts_models.dart';
import 'package:stroom/services/connectivity_test_service.dart';
import 'package:stroom/services/todo_tool_service.dart';

void main() {
  test('connectivity test results follow the selected locale', () async {
    final locales = <({
      AppLocalizations strings,
      Locale locale,
      String invalidSummary,
      String invalidDetails,
      String methodSummary,
      String methodDetails,
      String nonObjectDetails,
      String missingKeyDetails,
      String emptyQueryDetails,
      String todoMutationSummary,
      String todoMutationDetails,
    })>[
      (
        strings: AppLocalizationsEnUs(),
        locale: const Locale('en', 'US'),
        invalidSummary: 'Invalid MCP configuration',
        invalidDetails: 'A valid transport type configuration is missing.',
        methodSummary: 'Unsupported test method',
        methodDetails:
            'To avoid writing remote business data, MCP connectivity tests only allow the read-only tools/list method.',
        nonObjectDetails: 'Test content must be a top-level JSON object.',
        missingKeyDetails:
            'Error: Brave Search API key is not configured. Configure it in settings.',
        emptyQueryDetails: 'Error: The search query cannot be empty.',
        todoMutationSummary: 'Test parameters would modify todo data',
        todoMutationDetails:
            'To protect the current session todo list, omit todos or set it to null in connectivity tests.',
      ),
      (
        strings: AppLocalizationsZhCn(),
        locale: const Locale('zh', 'CN'),
        invalidSummary: 'MCP 配置无效',
        invalidDetails: '缺少有效的传输类型配置。',
        methodSummary: '不支持的测试方法',
        methodDetails: '为避免测试写入远程业务数据，MCP 连通性测试只允许只读的 tools/list 方法。',
        nonObjectDetails: '测试内容顶层必须是 JSON 对象。',
        missingKeyDetails: '错误：Brave Search API Key 未配置，请在设置页面配置。',
        emptyQueryDetails: '错误：搜索关键词不能为空。',
        todoMutationSummary: '测试参数会修改待办数据',
        todoMutationDetails: '为保护当前会话待办列表，连通性测试只允许省略 todos 或设置为 null。',
      ),
    ];

    for (final expected in locales) {
      final strings = expected.strings;
      final invalidConfig = await ConnectivityTestService.runProviderTest(
        config: ProviderConfigItem(),
        testContent: '{}',
        localizations: strings,
        locale: expected.locale,
      );
      expect(invalidConfig.summary, expected.invalidSummary);
      expect(invalidConfig.details, expected.invalidDetails);

      final unsupportedMethod = await ConnectivityTestService.runProviderTest(
        config: ProviderConfigItem(typeConfig: {'transport': 'sse'}),
        testContent: '{"method":"tools/call"}',
        localizations: strings,
        locale: expected.locale,
      );
      expect(unsupportedMethod.summary, expected.methodSummary);
      expect(unsupportedMethod.details, expected.methodDetails);

      final nonObjectContent = await ConnectivityTestService.runProviderTest(
        config: ProviderConfigItem(typeConfig: {'transport': 'sse'}),
        testContent: '[]',
        localizations: strings,
        locale: expected.locale,
      );
      expect(nonObjectContent.summary, strings.connectivityTestFailedSummary);
      expect(nonObjectContent.details, expected.nonObjectDetails);

      final missingKey = await ConnectivityTestService.runProviderTest(
        config: ProviderConfigItem(
          models: [
            ModelConfig(
              name: 'Brave Search',
              modelId: 'http',
              typeConfig: {'isHttpTool': true},
            ),
          ],
        ),
        testContent: '{"query":"Stroom"}',
        localizations: strings,
        locale: expected.locale,
      );
      expect(missingKey.succeeded, isFalse);
      expect(missingKey.details, expected.missingKeyDetails);

      final emptyQuery = await ConnectivityTestService.runBuiltinTest(
        toolName: 'web_search',
        testContent: '{"query":" "}',
        localizations: strings,
        locale: expected.locale,
      );
      expect(emptyQuery.succeeded, isFalse);
      expect(emptyQuery.details, expected.emptyQueryDetails);

      final todoMutation = await ConnectivityTestService.runBuiltinTest(
        toolName: 'todowrite',
        testContent: '{"todos":[]}',
        localizations: strings,
        locale: expected.locale,
      );
      expect(todoMutation.succeeded, isFalse);
      expect(todoMutation.summary, expected.todoMutationSummary);
      expect(todoMutation.details, expected.todoMutationDetails);

      await TodoToolService.handleTodo({
        'todos': List.generate(
          30,
          (index) => {'content': 'item-$index ${List.filled(300, 'x').join()}'},
        ),
      }, locale: expected.locale);
      final truncated = await ConnectivityTestService.runBuiltinTest(
        toolName: 'todowrite',
        testContent: '{}',
        localizations: strings,
        locale: expected.locale,
      );
      expect(
        truncated.details,
        endsWith(strings.connectivityTestResultTruncated),
      );
      // ignore: invalid_use_of_visible_for_testing_member
      TodoToolService.reset();

      expect(
        strings.connectivityTestMcpRequestTimeout('tools/list'),
        strings.localeName == 'en_US'
            ? 'MCP request timed out: tools/list'
            : 'MCP 请求超时：tools/list',
      );
      expect(
        // ignore: invalid_use_of_visible_for_testing_member
        ConnectivityTestService.isErrorResult(
          strings.toolResultWebSearchIncomplete('Google', 'Bing: timeout'),
          strings,
        ),
        isTrue,
      );
      expect(
        // ignore: invalid_use_of_visible_for_testing_member
        ConnectivityTestService.isErrorResult(
          strings.toolResultWebSearchNotFoundFrom('Google, Bing'),
          strings,
        ),
        isFalse,
      );
    }
  });
}
