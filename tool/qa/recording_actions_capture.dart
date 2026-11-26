import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/audio_recording_page.dart';

void main() {
  final state = Uri.base.queryParameters['state'] ?? 'recording';
  final locale = Uri.base.queryParameters['locale'] ?? 'en';
  final scale = double.tryParse(Uri.base.queryParameters['scale'] ?? '1') ?? 1;
  final focus = Uri.base.queryParameters['focus'] ?? 'page';
  runApp(
    _RecordingActionsCaptureApp(
      state: state,
      locale: locale,
      scale: scale,
      focus: focus,
    ),
  );
}

class _RecordingActionsCaptureApp extends StatelessWidget {
  const _RecordingActionsCaptureApp({
    required this.state,
    required this.locale,
    required this.scale,
    required this.focus,
  });

  final String state;
  final String locale;
  final double scale;
  final String focus;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: Locale(locale, locale == 'en' ? 'US' : null),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
        ),
        child: child!,
      ),
      home: _RecordingActionsCapturePage(
        state: state,
        actionsOnly: focus == 'actions',
      ),
    );
  }
}

class _RecordingActionsCapturePage extends StatelessWidget {
  const _RecordingActionsCapturePage({
    required this.state,
    required this.actionsOnly,
  });

  final String state;
  final bool actionsOnly;

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

    final actionGroup = RecordingActionGroup(
      buttons: [
        for (final action in actions)
          RecordingActionButton(
            onPressed: () {},
            icon: action.icon,
            label: action.label,
            color: action.color,
          ),
      ],
    );
    if (actionsOnly) {
      return Scaffold(body: Center(child: actionGroup));
    }

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
              actionGroup,
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
