import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/assistant/assistant_schema_info_dialog.dart';

void main() {
  testWidgets('documents exact schema names, ranges, and available tools', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showAssistantSchemaInfoDialog(
                context,
                supportedToolNames: {'web_search', 'todowrite'},
              ),
              child: const Text('show schema'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('show schema'));
    await tester.pumpAndSettle();

    expect(find.text('Remote assistant schema'), findsOneWidget);
    expect(find.text('Catalog manifest fields'), findsOneWidget);
    final list = find.byType(ListView);
    await _scrollUntilBuilt(
      tester,
      list,
      find.text('temperature / enableTemperature'),
    );
    expect(find.textContaining('0–2 / bool'), findsOneWidget);
    await _scrollUntilBuilt(
      tester,
      list,
      find.text('maxTokens / enableMaxTokens'),
    );
    expect(find.text('maxTokens / enableMaxTokens'), findsOneWidget);
    await _scrollUntilBuilt(tester, list, find.text('defaultToolNames'));
    expect(find.textContaining('todowrite, web_search'), findsOneWidget);
  });

  testWidgets('localizes schema field values in English and Chinese', (
    tester,
  ) async {
    Future<void> show(Locale locale) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showAssistantSchemaInfoDialog(context),
                child: const Text('show schema'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('show schema'));
      await tester.pumpAndSettle();
    }

    await show(const Locale('en', 'US'));
    expect(find.textContaining('Non-empty string'), findsOneWidget);
    expect(find.textContaining('ISO 8601 string, optional'), findsOneWidget);
    final list = find.byType(ListView);
    await _scrollUntilBuilt(tester, list, find.text('description'));
    expect(
      find.textContaining(
          'Optional string · Short description shown in the market.'),
      findsOneWidget,
    );
    await _scrollUntilBuilt(
      tester,
      list,
      find.text('maxToolOutputChars / enableMaxToolOutputChars'),
    );
    expect(find.textContaining('100–100000 characters / bool'), findsOneWidget);
    await _scrollUntilBuilt(
      tester,
      list,
      find.text('defaultModelId / defaultProviderName'),
    );
    expect(
      find.textContaining('String · Should identify a model'),
      findsOneWidget,
    );
    await _scrollUntilBuilt(
      tester,
      list,
      find.textContaining('Model configured on this device'),
    );
    expect(
        find.textContaining('Model configured on this device'), findsOneWidget);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await show(const Locale('zh', 'CN'));
    expect(find.textContaining('非空字符串'), findsOneWidget);
    expect(find.textContaining('ISO 8601 字符串，可省略'), findsOneWidget);
    final chineseList = find.byType(ListView);
    await _scrollUntilBuilt(tester, chineseList, find.text('description'));
    expect(
      find.textContaining('字符串，可省略 · 列表中的说明文字。'),
      findsOneWidget,
    );
    await _scrollUntilBuilt(
      tester,
      chineseList,
      find.text('maxToolOutputChars / enableMaxToolOutputChars'),
    );
    expect(find.textContaining('100–100000 字符 / bool'), findsOneWidget);
    await _scrollUntilBuilt(
      tester,
      chineseList,
      find.text('defaultModelId / defaultProviderName'),
    );
    expect(
      find.textContaining('字符串 · 模型 ID 与供应商名应对应本机配置'),
      findsOneWidget,
    );
    await _scrollUntilBuilt(
      tester,
      chineseList,
      find.textContaining('当前设备已配置的模型'),
    );
    expect(find.textContaining('当前设备已配置的模型'), findsOneWidget);
  });
}

Future<void> _scrollUntilBuilt(
  WidgetTester tester,
  Finder list,
  Finder target,
) async {
  for (var i = 0; i < 24; i++) {
    if (target.evaluate().isNotEmpty) return;
    await tester.drag(list, const Offset(0, -260));
    await tester.pumpAndSettle();
  }
}
