import 'package:flutter/material.dart';
import 'package:stroom/services/notification_service.dart';

void main() {
  final isDark = Uri.base.queryParameters['theme'] == 'dark';
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: isDark ? Brightness.dark : Brightness.light,
        ),
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => Stack(
            children: [
              Positioned(
                top: MediaQuery.paddingOf(context).top + 12,
                left: 12,
                right: 12,
                child: InAppNotificationBanner(
                  payload: const NotificationPayload(
                    taskId: 'local-screenshot-fixture',
                    type: NotificationType.taskCompleted,
                    title:
                        'Completed audio separation for the selected recording and saved the generated tracks',
                    typeLabel: 'Audio separation',
                  ),
                  locale: const Locale('en', 'US'),
                  isDark: isDark,
                  onDismiss: () {},
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
