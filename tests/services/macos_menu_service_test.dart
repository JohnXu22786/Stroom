import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/services/macos_menu_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('macOS Preferences is retained during app startup', (
    tester,
  ) async {
    MacOSMenuService.installPlatformHandler();

    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          MacOSMenuService.channelName,
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('openSettings'),
          ),
          null,
        );

    final navigatorKey = GlobalKey<NavigatorState>();
    final service = MacOSMenuService(navigatorKey);
    addTearDown(service.dispose);
    addTearDown(MacOSMenuService.resetForTesting);

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: Text('Home')),
        routes: {
          '/settings': (_) =>
              const Scaffold(body: Text('Settings destination')),
        },
      ),
    );
    service.attach();
    await tester.pumpAndSettle();

    expect(find.text('Settings destination'), findsOneWidget);
  });
}
