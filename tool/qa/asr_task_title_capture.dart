import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/unified_task_list/background_task_card.dart';
import 'package:stroom/providers/background_task_provider.dart';
import 'package:stroom/providers/task_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final query = Uri.base.queryParameters;
  final localeParts = (query['locale'] ?? 'en-US').split('-');
  final locale = Locale(
    localeParts.first,
    localeParts.length > 1 ? localeParts[1] : null,
  );
  final brightness = query['theme'] == 'dark'
      ? Brightness.dark
      : Brightness.light;
  const syntheticUrl =
      'https://media.example.test/recordings/recording-session-2026-11-22-interview-take-two-final-transcript.wav';
  final task = BackgroundTask(
    id: 'qa-asr-task-title',
    type: BackgroundTaskType.asr,
    title: 'ASR_${Uri.parse(syntheticUrl).pathSegments.last}',
    status: TaskStatus.completed,
    createdAt: DateTime.utc(2026, 11, 22),
    completedAt: DateTime.utc(2026, 11, 22, 0, 1),
  );

  runApp(
    ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: brightness,
          ),
        ),
        home: Scaffold(
          appBar: AppBar(title: const Text('ASR task')),
          body: ListView(children: [BackgroundTaskCard(task: task)]),
        ),
      ),
    ),
  );
}
