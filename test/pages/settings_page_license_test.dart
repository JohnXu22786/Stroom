import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/settings_page.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/providers/theme_provider.dart';
import 'package:stroom/providers/update_provider.dart';

/// Builds the test app with all required provider overrides.
Widget _buildTestApp() {
  return ProviderScope(
    overrides: [
      themeProvider.overrideWith((ref) => ThemeNotifier()),
      providerEntriesProvider.overrideWith((ref) {
        final notifier = ProviderEntriesNotifier();
        notifier.load();
        return notifier;
      }),
      updateProvider.overrideWith((ref) => UpdateNotifier()),
    ],
    child: const MaterialApp(home: SettingsPage()),
  );
}

void main() {
  group('SettingsPage - License Display', () {
    testWidgets('shows AGPLv3 open source license subtitle', (tester) async {
      // Set a large screen so all items are visible without scrolling
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      // Scroll down to the "关于" section
      await tester.scrollUntilVisible(
        find.text('开源协议'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pump();

      // Verify the license subtitle shows AGPLv3
      expect(
        find.text('GNU Affero General Public License v3.0'),
        findsOneWidget,
      );

      // Verify the old GPLv3 text is NOT present
      expect(
        find.text('GNU General Public License v3.0'),
        findsNothing,
      );
    });
  });

  group('LICENSE file', () {
    test('contains AGPLv3 header', () {
      final licenseFile = File('LICENSE');
      expect(licenseFile.existsSync(), isTrue);

      final content = licenseFile.readAsStringSync();
      expect(content, contains('GNU AFFERO GENERAL PUBLIC LICENSE'));
      expect(content, contains('Version 3, 19 November 2007'));
    });
  });
}
