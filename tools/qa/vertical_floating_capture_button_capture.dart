import 'package:flutter/material.dart';
import 'package:stroom/catcatch/widgets/draggable_floating_panel.dart';

void main() {
  final textScale =
      double.tryParse(Uri.base.queryParameters['scale'] ?? '1') ?? 1;
  runApp(_CaptureFixture(textScale: textScale));
}

class _CaptureFixture extends StatelessWidget {
  const _CaptureFixture({required this.textScale});

  final double textScale;

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('zh', 'CN'),
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        ),
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
            ),
            child: Scaffold(
              body: Stack(
                children: [
                  Positioned(
                    left: 8,
                    top: 8,
                    child: DraggableFloatingPanel(
                      detectedUrls: const [
                        'https://example.test/demo-video.mp4',
                      ],
                      onConfirmCapture: (_) {},
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
