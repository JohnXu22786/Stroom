import 'package:flutter/material.dart';
import 'package:stroom/widgets/drag_sort_area.dart';

void main() {
  final scale = double.tryParse(Uri.base.queryParameters['scale'] ?? '') ?? 1;
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
        ),
        child: child!,
      ),
      home: Scaffold(
        appBar: AppBar(title: const Text('Reasoning options')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Option values'),
              const SizedBox(height: 8),
              DragSortArea(
                wrap: true,
                values: const [
                  'deliberate',
                  'balanced',
                  'maximum-effort',
                ],
                selected: (value) => value == 'balanced',
                deletable: (_) => true,
                onDelete: (_) {},
                onTap: (_) {},
                onReorder: (_, __) {},
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
