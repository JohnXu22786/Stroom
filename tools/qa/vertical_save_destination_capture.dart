import 'package:flutter/material.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/chat/dialogs/message_save_destination_dialog.dart';

void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('fr', 'FR'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        brightness: Brightness.light,
      ),
      home: const _SaveDestinationCapture(),
    ),
  );
}

class _SaveDestinationCapture extends StatefulWidget {
  const _SaveDestinationCapture();

  @override
  State<_SaveDestinationCapture> createState() =>
      _SaveDestinationCaptureState();
}

class _SaveDestinationCaptureState extends State<_SaveDestinationCapture> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showMessageSaveDestinationDialog(context);
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold();
}
