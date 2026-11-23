import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/ocr/ocr_instruction_dialog.dart';
import 'package:stroom/providers/ocr_instructions_provider.dart';

void main() {
  runApp(
    ProviderScope(
      overrides: [
        ocrInstructionsProvider.overrideWith((ref) {
          final notifier = OcrInstructionsNotifier(ref)
            ..state = const [
              OcrInstruction(
                content:
                    'Transcribe every visible word exactly as it appears.\n'
                    'Preserve line breaks, punctuation, and original language.',
              ),
            ];
          return notifier;
        }),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('en', 'US'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => const OcrInstructionManageDialog(),
                ),
                child: const Text('Open OCR instructions'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
