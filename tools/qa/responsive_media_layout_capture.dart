import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/widgets/app_media_picker_dialog.dart';
import 'package:stroom/widgets/markdown_extensions.dart';

void main() => runApp(const _ResponsiveMediaLayoutCapture());

class _ResponsiveMediaLayoutCapture extends StatefulWidget {
  const _ResponsiveMediaLayoutCapture();

  @override
  State<_ResponsiveMediaLayoutCapture> createState() =>
      _ResponsiveMediaLayoutCaptureState();
}

class _ResponsiveMediaLayoutCaptureState
    extends State<_ResponsiveMediaLayoutCapture> {
  final _component = Uri.base.queryParameters['component'] ?? 'picker';
  final _requestedScale =
      double.tryParse(Uri.base.queryParameters['scale'] ?? '') ?? 1;
  late double _textScale = _component == 'picker' ? 1 : _requestedScale;

  @override
  void initState() {
    super.initState();
    if (_component == 'picker' && _requestedScale > 1) {
      Timer(const Duration(seconds: 12), () {
        if (mounted) setState(() => _textScale = _requestedScale);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQueryData(
        textScaler: TextScaler.linear(_textScale),
        disableAnimations: Uri.base.queryParameters['static'] == '1',
      ),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('fr', 'FR'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          brightness: Brightness.light,
        ),
        home: _component == 'mermaid'
            ? const _MermaidCapture()
            : const _MediaPickerCapture(),
      ),
    );
  }
}

class _MediaPickerCapture extends StatelessWidget {
  const _MediaPickerCapture();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => showMediaPickerDialog<_CaptureRecord>(
              context,
              MediaPickerConfig<_CaptureRecord>(
                title: 'Médias locaux',
                emptyIcon: Icons.folder_outlined,
                emptyText: 'Aucun média',
                fileIcon: Icons.image_outlined,
                fileIconColor: Colors.blue,
                multiSelect: true,
                loadRecords: () async => const [
                  _CaptureRecord(
                    id: 'one',
                    name: 'photo-alpha.png',
                    folder: '',
                  ),
                ],
                loadFolders: () async => <String>{},
                readFile: (_) async => Uint8List.fromList([1, 2, 3]),
                displayName: (record) => record.name,
                subtitleBuilder: (_) => const Text('PNG · 1,2 Ko'),
              ),
            ),
            child: const Text('Ouvrir le sélecteur'),
          ),
        ),
      );
}

class _CaptureRecord {
  final String id;
  final String name;
  final String folder;

  const _CaptureRecord({
    required this.id,
    required this.name,
    required this.folder,
  });
}

class _MermaidCapture extends StatelessWidget {
  const _MermaidCapture();

  @override
  Widget build(BuildContext context) {
    final config = buildMessageMarkdownConfig(
      isDark: false,
      conversationIsStreaming: true,
      streamingMsgId: 'capture-message',
      messageId: 'capture-message',
      streamingText: '```mermaid\ngraph TD\nA-->B',
    );
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Diagramme en cours de préparation.'),
            const SizedBox(height: 12),
            config.pre.builder!('graph TD\nA-->B', 'mermaid'),
            const SizedBox(height: 12),
            const Text('Le contenu Markdown continue après le bloc Mermaid.'),
          ],
        ),
      ),
    );
  }
}
