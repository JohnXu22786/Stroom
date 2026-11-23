import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/widgets/background_service_control_buttons.dart';
import 'package:stroom/widgets/constrained_text.dart';

Widget _buildApp({required bool isRunning, required bool isOperating}) {
  return MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child!,
    ),
    home: Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: BackgroundServiceControlButtons(
                isServiceRunning: isRunning,
                isOperating: isOperating,
                startLabel: 'Démarrer le service',
                stopLabel: 'Arrêter le service',
                restartLabel: 'Redémarrer le service',
                redetectLabel: 'Vérifier de nouveau',
                onStart: () {},
                onStop: () {},
                onRestart: () {},
                onRedetect: () {},
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

void main() {
  testWidgets(
    'vertical_background_service_buttons keeps labels constrained in each service state',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildApp(isRunning: false, isOperating: false));
      await tester.pumpAndSettle();

      var labels = tester.widgetList<ConstrainedText>(
        find.byType(ConstrainedText),
      );
      expect(
          labels.map((label) => label.data), contains('Démarrer le service'));
      expect(labels.every((label) => label.maxLines == 1), isTrue);
      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNotNull);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(_buildApp(isRunning: true, isOperating: false));
      await tester.pumpAndSettle();

      labels = tester.widgetList<ConstrainedText>(find.byType(ConstrainedText));
      expect(labels.map((label) => label.data), contains('Arrêter le service'));
      expect(
        labels.map((label) => label.data),
        contains('Redémarrer le service'),
      );
      expect(labels.every((label) => label.maxLines == 1), isTrue);
      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNotNull);
      expect(
        tester
            .widgetList<OutlinedButton>(find.byType(OutlinedButton))
            .every((button) => button.onPressed != null),
        isTrue,
      );
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(_buildApp(isRunning: true, isOperating: true));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNWidgets(2));
      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull);
      expect(
        tester
            .widgetList<OutlinedButton>(find.byType(OutlinedButton))
            .every((button) => button.onPressed == null),
        isTrue,
      );
      expect(find.byIcon(Icons.refresh), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
