import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/audio_source_header.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildPage({
    required bool hasSource,
    required VoidCallback onUpload,
    String title = 'Source text',
    String emptyMessage = '(No source text)',
    String uploadLabel = 'Upload source text',
    String editLabel = 'Edit source text',
    TextScaler textScaler = TextScaler.noScaling,
  }) {
    return MaterialApp(
      locale: const Locale('en', 'US'),
      theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
      home: MediaQuery(
        data: MediaQueryData(textScaler: textScaler),
        child: Scaffold(
          appBar: AppBar(title: const Text('sample.wav')),
          body: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 216),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AudioSourceHeader(
                      title: title,
                      hasSource: hasSource,
                      emptyMessage: emptyMessage,
                      uploadLabel: uploadLabel,
                      editLabel: editLabel,
                      fontSize: 14,
                      onUpload: onUpload,
                      onDecreaseFontSize: () {},
                      onIncreaseFontSize: () {},
                      canDecreaseFontSize: true,
                      canIncreaseFontSize: true,
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: hasSource
                          ? const TextField(
                              readOnly: true,
                              maxLines: null,
                              expands: true,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.all(12),
                              ),
                            )
                          : const Center(
                              child: Text('Companion text is unavailable'),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void setPhoneViewport(WidgetTester tester) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
  }

  testWidgets('empty source card fits at 320x640 and keeps upload action', (
    tester,
  ) async {
    setPhoneViewport(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildPage(hasSource: false, onUpload: () {}));
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
    expect(find.text('(No source text)'), findsOneWidget);
    expect(find.text('Upload source text'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('populated source card fits at 320x640 with native text field', (
    tester,
  ) async {
    setPhoneViewport(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildPage(hasSource: true, onUpload: () {}));
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
    expect(find.text('Edit source text'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byIcon(Icons.text_decrease), findsOneWidget);
    expect(find.byIcon(Icons.text_increase), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('wide header wraps long localized labels at large text scale', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(600, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      buildPage(
        hasSource: false,
        onUpload: () {},
        title: 'ソーステキスト',
        emptyMessage: '(原文なし)',
        uploadLabel: 'ソーステキストをアップロードする',
        textScaler: const TextScaler.linear(2.5),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
    expect(find.text('ソーステキストをアップロードする'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
