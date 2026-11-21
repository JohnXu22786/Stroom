import 'package:flutter/material.dart';
import 'package:stroom/pages/chat/composer/composer_shared.dart';

void main() {
  final dark = Uri.base.queryParameters['theme'] == 'dark';
  runApp(
    MaterialApp(
      locale: const Locale('en', 'US'),
      theme: ThemeData.light(useMaterial3: true),
      darkTheme: ThemeData.dark(useMaterial3: true),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1)),
          child: Scaffold(
            body: Align(
              alignment: AlignmentDirectional.topStart,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    SettingsChip(
                      icon: Icons.build_outlined,
                      label: 'Tools',
                      color: Colors.teal,
                      badgeCount: 1,
                    ),
                    SizedBox(height: 8),
                    SettingsChip(
                      icon: Icons.build_outlined,
                      label: 'Tools',
                      color: Colors.teal,
                      badgeCount: 12,
                    ),
                    SizedBox(height: 8),
                    SettingsChip(
                      icon: Icons.build_outlined,
                      label: 'Tools',
                      color: Colors.teal,
                      badgeCount: 100,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
