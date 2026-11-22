import 'package:flutter/material.dart';

/// Displays an app initialization failure and keeps its full diagnostic readable.
class StartupInitializationErrorScreen extends StatelessWidget {
  const StartupInitializationErrorScreen({
    required this.title,
    required this.details,
    super.key,
  });

  final String title;
  final String details;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(details),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
