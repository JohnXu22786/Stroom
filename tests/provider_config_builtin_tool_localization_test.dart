import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/models/tool_call.dart';
import 'package:stroom/pages/provider_config_tool_dialogs.dart';
import 'package:stroom/services/todo_tool_service.dart';
import 'package:stroom/services/web_search_service.dart';

void main() {
  dynamic schemaContract(dynamic value) {
    if (value is Map) {
      return <String, dynamic>{
        for (final entry in value.entries)
          if (entry.key != 'description')
            entry.key as String: schemaContract(entry.value),
      };
    }
    if (value is List) return value.map(schemaContract).toList();
    return value;
  }

  testWidgets('built-in tool details are localized without changing schemas', (
    tester,
  ) async {
    Future<void> showTool(Locale locale, ToolDefinition definition) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) =>
                      BuiltinToolDetailsDialog(definition: definition),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
    }

    for (final locale in AppLocalizations.supportedLocales) {
      for (final definition in [
        TodoToolService.toolDefinitions.single,
        WebSearchService.toolDefinitions.single,
      ]) {
        final schemaBefore = jsonEncode(definition.parameters);
        await showTool(locale, definition);

        final description = tester
            .widgetList<Text>(find.byType(Text))
            .map((widget) => widget.data ?? '')
            .join('\n');
        final renderedParameters = tester
            .widget<SelectableText>(find.byType(SelectableText))
            .data!;
        final parameters =
            jsonDecode(renderedParameters) as Map<String, dynamic>;

        expect(parameters['type'], 'object');
        final properties = parameters['properties'] as Map<String, dynamic>;
        expect(
          properties,
          contains(definition.name == 'todowrite' ? 'todos' : 'query'),
        );
        if (locale.languageCode == 'en') {
          expect(description, isNot(contains('通过网络搜索')));
          expect(description, isNot(contains('创建、读取并管理')));
          expect(
            description,
            contains(
              definition.name == 'todowrite'
                  ? 'Create, read, and manage a to-do list.'
                  : 'Search the web for current information.',
            ),
          );
          expect(
            renderedParameters,
            contains(
              definition.name == 'todowrite'
                  ? 'Complete replacement of the to-do list'
                  : 'Search terms',
            ),
          );
        } else {
          expect(
            description,
            contains(
              definition.name == 'todowrite'
                  ? '创建、读取并管理待办事项列表。'
                  : '通过网络搜索获取实时信息。',
            ),
          );
          expect(
            renderedParameters,
            contains(definition.name == 'todowrite' ? '待办事项列表（全量替换）' : '搜索关键词'),
          );
        }

        expect(jsonEncode(definition.parameters), schemaBefore);
        expect(
          schemaContract(parameters),
          schemaContract(definition.parameters),
        );
        await tester.pumpWidget(const SizedBox.shrink());
      }
    }
  });
}
