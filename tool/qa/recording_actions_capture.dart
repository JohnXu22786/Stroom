import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/audio_recording_page.dart';

void main() {
  final state = Uri.base.queryParameters['state'] ?? 'recording';
  runApp(_RecordingActionsCaptureApp(state: state));
}

class _RecordingActionsCaptureApp extends StatelessWidget {
  const _RecordingActionsCaptureApp({required this.state});

  final String state;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('en', 'US'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
      home: _RecordingActionsCapturePage(state: state),
    );
  }
}

class _RecordingActionsCapturePage extends StatelessWidget {
  const _RecordingActionsCapturePage({required this.state});

  final String state;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final actions = switch (state) {
      'paused' => [
          _RecordingAction(
            icon: Icons.play_circle_filled,
            label: strings.audioRecordingResume,
            color: Colors.green,
          ),
          _RecordingAction(
            icon: Icons.stop,
            label: strings.audioRecordingStop,
            color: Colors.red,
          ),
        ],
      'completed' => [
          _RecordingAction(
            icon: Icons.save,
            label: strings.audioRecordingSave,
            color: theme.colorScheme.primary,
          ),
          _RecordingAction(
            icon: Icons.refresh,
            label: strings.audioRecordingRecordAgain,
            color: Colors.grey,
          ),
        ],
      _ => [
          _RecordingAction(
            icon: Icons.pause_circle_filled,
            label: strings.audioRecordingPause,
            color: Colors.orange,
          ),
          _RecordingAction(
            icon: Icons.stop,
            label: strings.audioRecordingStop,
            color: Colors.red,
          ),
        ],
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.audioRecordingTitle),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 32),
              Text(
                '00:15',
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w200,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              if (state == 'recording' || state == 'paused') ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: (state == 'paused' ? Colors.orange : Colors.red)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    state == 'paused'
                        ? strings.audioRecordingPaused
                        : strings.audioRecordingRecording,
                    style: TextStyle(
                      color: state == 'paused' ? Colors.orange : Colors.red,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ] else
                const SizedBox(height: 32),
              RecordingActionGroup(
                buttons: [
                  for (final action in actions)
                    RecordingActionButton(
                      onPressed: () {},
                      icon: action.icon,
                      label: action.label,
                      color: action.color,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecordingAction {
  const _RecordingAction({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;
}
