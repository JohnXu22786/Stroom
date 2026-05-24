import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:stroom/models/chat_message.dart';
import 'package:stroom/pages/chat_page.dart';

Widget _buildApp({
  void Function(String, List<Attachment>)? onSend,
  ComposerHeightNotifier? notifier,
}) {
  Widget composer = SizedBox(
    width: 400,
    height: 400,
    child: Stack(
      children: [
        ChatComposerWidget(
          onSend: onSend ?? (_, __) {},
          onStop: () {},
        ),
      ],
    ),
  );

  if (notifier != null) {
    composer = ListenableProvider<ComposerHeightNotifier>.value(
      value: notifier,
      child: composer,
    );
  }

  return ProviderScope(
    child: MaterialApp(
      home: Scaffold(body: composer),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('ChatComposerWidget reports height to ComposerHeightNotifier',
      (tester) async {
    double? capturedHeight;
    final heightNotifier = ComposerHeightNotifier();
    heightNotifier.addListener(() {
      capturedHeight = heightNotifier.height;
    });

    await tester.pumpWidget(_buildApp(notifier: heightNotifier));
    await tester.pumpAndSettle();

    expect(capturedHeight, greaterThan(0));
  });

  testWidgets('ChatComposerWidget renders text field and buttons',
      (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.byIcon(Icons.send_rounded), findsOneWidget);
    expect(find.byIcon(Icons.attach_file_outlined), findsOneWidget);
  });

  testWidgets('ChatComposerWidget hint text shows correctly',
      (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.decoration?.hintText, '输入消息...');
    expect(textField.textInputAction, TextInputAction.send);
  });

  testWidgets('ChatComposerWidget hides stop button when not streaming',
      (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.stop_circle_outlined), findsNothing);
  });

  testWidgets('ChatComposerWidget calls onSend when text submitted',
      (tester) async {
    String? sentText;

    await tester.pumpWidget(
      _buildApp(onSend: (text, _) => sentText = text),
    );
    await tester.pumpAndSettle();

    final textField = find.byType(TextField);
    await tester.enterText(textField, 'hello world');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    expect(sentText, 'hello world');
  });
}
