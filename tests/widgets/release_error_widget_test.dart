import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations_fr.dart';
import 'package:stroom/widgets/release_error_widget.dart';

final _strings = AppLocalizationsFr();
final _title = _strings.renderErrorTitle;
final _message = _strings.renderErrorRestartMessage;

void main() {
  testWidgets('release error remains readable in constrained layouts',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(160, 100);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fr', 'FR'),
        builder: (context, child) => MediaQuery(
          data:
              MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: ReleaseErrorWidget(title: _title, message: _message),
        ),
      ),
    );

    expect(find.text(_title), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.text(_message));
    await tester.pumpAndSettle();
    expect(find.text(_message), findsOneWidget);
    expect(tester.getTopLeft(find.text(_message)).dy, lessThan(100));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fr', 'FR'),
        home: SingleChildScrollView(
          child: Column(
            children: [ReleaseErrorWidget(title: _title, message: _message)],
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
