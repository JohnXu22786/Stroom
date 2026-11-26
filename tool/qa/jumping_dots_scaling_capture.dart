import 'package:flutter/material.dart';
import 'package:stroom/widgets/llm/jumping_dots.dart';

void main() {
  runApp(const _JumpingDotsCaptureApp());
}

class _JumpingDotsCaptureApp extends StatelessWidget {
  const _JumpingDotsCaptureApp();

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.light(useMaterial3: true),
        home: Scaffold(
          backgroundColor: const Color(0xfff7f8fa),
          body: SafeArea(
            child: Center(
              child: Container(
                width: 280,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xffdce1e8)),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Chat response indicator',
                      style: TextStyle(
                        color: Color(0xff1a2433),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 16),
                    _ScaleExample(label: 'Normal text · 1×', scale: 1),
                    SizedBox(height: 12),
                    _ScaleExample(label: 'Enlarged text · 2×', scale: 2),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

class _ScaleExample extends StatelessWidget {
  const _ScaleExample({required this.label, required this.scale});

  final String label;
  final double scale;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xff536273),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              disableAnimations: Uri.base.queryParameters['motion'] != 'true',
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: JumpingDotsProgressIndicator(
                color: Color(0xff66758a),
                fontSize: 14,
              ),
            ),
          ),
        ],
      );
}
