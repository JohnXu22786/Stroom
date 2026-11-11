import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/provider_settings_panel.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/services/asr_service.dart';

void main() {
  testWidgets('ASR setting labels and dropdowns fit narrow and wide dialogs', (
    tester,
  ) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    for (final width in [360.0, 800.0, 1100.0]) {
      tester.view.physicalSize = Size(width, 2400);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: ThemeData(
            dialogTheme: const DialogThemeData(
              constraints: BoxConstraints(maxWidth: 1200),
            ),
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => showProviderSettingsPanel(
                    context: context,
                    config: ProviderConfigItem(
                      providerName: 'ASR provider',
                      host: 'https://api.example.com',
                      key: 'test-key',
                    ),
                    providerType: 'asr',
                  ),
                  child: const Text('Open provider settings'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open provider settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Parameter settings'));
      await tester.pumpAndSettle();

      expect(find.text('Fallback method'), findsOneWidget);
      expect(find.text('Preprocessing method'), findsOneWidget);
      expect(find.text('Compression method'), findsOneWidget);
      expect(find.byType(DropdownButton<String>), findsNWidgets(4));
      final dialogRect = tester.getRect(find.byType(Dialog));
      final customParamsHeader = tester.getRect(find.text('Custom parameters'));
      final addCustomParamButton = tester.getRect(
        find.ancestor(
          of: find.text('Add parameter'),
          matching: find.byType(TextButton),
        ),
      );
      for (final controlRect in [customParamsHeader, addCustomParamButton]) {
        expect(controlRect.left, greaterThanOrEqualTo(dialogRect.left));
        expect(controlRect.right, lessThanOrEqualTo(dialogRect.right));
      }
      if (width < 800) {
        expect(
          addCustomParamButton.top,
          greaterThanOrEqualTo(customParamsHeader.bottom),
        );
      } else {
        expect(
          (addCustomParamButton.center.dy - customParamsHeader.center.dy).abs(),
          lessThan(20),
        );
      }
      final localizations = AppLocalizations.of(
        tester.element(find.byType(Dialog)),
      )!;
      for (final tabLabel in [
        localizations.providerBasicInfoTab,
        localizations.providerParameterSettingsTab,
      ]) {
        final tabRect = tester.getRect(find.text(tabLabel));
        expect(tabRect.left, greaterThanOrEqualTo(0));
        expect(tabRect.right, lessThanOrEqualTo(width));
      }
      final uploadLabel = tester.getRect(find.text('Upload method'));
      final uploadControl = tester.getRect(
        find.byType(DropdownButton<AudioUploadMethod>),
      );
      final maxSizeLabel = tester.getRect(find.text('Maximum upload size'));
      final maxSizeControl = tester.getRect(find.byType(TextField).first);
      if (width < 800) {
        expect(uploadControl.top, greaterThanOrEqualTo(uploadLabel.bottom));
        expect(maxSizeControl.top, greaterThanOrEqualTo(maxSizeLabel.bottom));
      } else {
        for (var i = 0; i < 4; i++) {
          final dropdownRect = tester.getRect(
            find.byType(DropdownButton<String>).at(i),
          );
          expect(
            dropdownRect.right,
            lessThanOrEqualTo(dialogRect.right - 16),
            reason: 'ASR dropdown $i should fit within the dialog content',
          );
        }
        expect(
          (uploadControl.center.dy - uploadLabel.center.dy).abs(),
          lessThan(20),
        );
        expect(
          (maxSizeControl.center.dy - maxSizeLabel.center.dy).abs(),
          lessThan(20),
        );
      }
      expect(tester.takeException(), isNull, reason: 'Dialog width: $width');

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    }
  });
}
