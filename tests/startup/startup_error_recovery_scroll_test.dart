import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/startup/startup_app.dart';

void main() {
  testWidgets('long startup diagnostics scroll while keeping retry reachable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final diagnostic = 'diagnostic line\n' * 100;
    await tester.pumpWidget(
      StartupErrorBoundary(
        locale: const Locale('en', 'US'),
        child: _ThrowStartupDiagnostic(diagnostic),
      ),
    );
    await tester.pump();

    final retry = find.text(
      lookupAppLocalizations(const Locale('en', 'US')).startupRecoveryRetry,
    );
    expect(find.text('Bad state: $diagnostic'), findsOneWidget);
    expect(tester.getRect(retry).bottom, greaterThan(640));
    expect(tester.takeException(), isA<StateError>());

    await tester.ensureVisible(retry);
    await tester.pumpAndSettle();

    expect(
      tester.getRect(retry).overlaps(const Rect.fromLTWH(0, 0, 320, 640)),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });
}

class _ThrowStartupDiagnostic extends StatelessWidget {
  const _ThrowStartupDiagnostic(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => throw StateError(message);
}
