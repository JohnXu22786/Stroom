import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/audio_player_shared.dart';

void main() => runApp(const _AudioSelectionToolbarCapture());

class _AudioSelectionToolbarCapture extends StatefulWidget {
  const _AudioSelectionToolbarCapture();

  @override
  State<_AudioSelectionToolbarCapture> createState() =>
      _AudioSelectionToolbarCaptureState();
}

class _AudioSelectionToolbarCaptureState
    extends State<_AudioSelectionToolbarCapture> {
  final _controller = TextEditingController(
    text: 'A short local companion text selected for audio playback.',
  );

  @override
  void initState() {
    super.initState();
    _controller.selection = const TextSelection(
      baseOffset: 2,
      extentOffset: 16,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('de', 'DE'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
      home: Builder(
        builder: (context) {
          final l10n = AppLocalizations.of(context)!;
          return Scaffold(
            appBar: AppBar(title: const Text('Audio player')),
            body: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    readOnly: true,
                    maxLines: null,
                    expands: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.all(12),
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 140,
                  child: AudioPlayerSelectionToolbar(
                    playLabel: l10n.audioPlayerPlaySelection,
                    generateLabel: l10n.audioPlayerGenerateSelection,
                    onPlay: () {},
                    onGenerate: () {},
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
