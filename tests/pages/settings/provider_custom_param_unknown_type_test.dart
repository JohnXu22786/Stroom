import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/models/tts_models.dart';
import 'package:stroom/pages/provider_settings_panel.dart';
import 'package:stroom/pages/simple_model_config_page.dart';
import 'package:stroom/providers/provider_config.dart';

const _unknownType = 'future-param-type';

List<DropdownButton<String>> _paramTypeDropdowns(WidgetTester tester) {
  return tester
      .widgetList<DropdownButton<String>>(find.byType(DropdownButton<String>))
      .where(
        (dropdown) =>
            dropdown.items?.map((item) => item.value).toList().join(',') ==
            'string,number,boolean,json',
      )
      .toList();
}

void main() {
  testWidgets(
    'model custom-param editor displays a valid fallback and preserves unknown type',
    (tester) async {
      ModelConfig? saved;
      final model = ModelConfig(
        name: 'Model',
        modelId: 'model-id',
        customParams: [
          CustomParam(
            paramName: 'response_mode',
            defaultValue: 'compact',
            type: _unknownType,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh', 'CN'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  saved = await Navigator.push<ModelConfig>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SimpleModelConfigPage(model: model),
                    ),
                  );
                },
                child: const Text('Open model'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open model'));
      await tester.pumpAndSettle();

      final dropdowns = _paramTypeDropdowns(tester);
      expect(dropdowns, hasLength(1));
      expect(dropdowns.single.value, ParamType.string.value);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(saved?.customParams.single.type, _unknownType);
    },
  );

  testWidgets(
    'provider custom-param editor displays a valid fallback and preserves unknown type',
    (tester) async {
      ProviderConfigItem? saved;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh', 'CN'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  saved = await showProviderSettingsPanel(
                    context: context,
                    providerType: 'llm',
                    config: ProviderConfigItem(
                      providerName: 'Provider',
                      host: 'https://example.test',
                      key: 'sk-test',
                      customParams: [
                        CustomParam(
                          paramName: 'response_mode',
                          defaultValue: 'compact',
                          type: _unknownType,
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('Open provider'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open provider'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('参数设置'));
      await tester.pumpAndSettle();

      final dropdowns = _paramTypeDropdowns(tester);
      expect(dropdowns, hasLength(1));
      expect(dropdowns.single.value, ParamType.string.value);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(saved?.customParams.single.type, _unknownType);
    },
  );
}
