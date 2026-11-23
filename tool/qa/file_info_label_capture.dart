import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/pages/chat/dialogs/file_info_dialog.dart';

void main() {
  final query = Uri.base.queryParameters;
  final localeTag = query['locale'] ?? 'fr-FR';
  final parts = localeTag.split('-');
  final locale = Locale.fromSubtags(
    languageCode: parts.first,
    countryCode: parts.length > 1 ? parts[1].toUpperCase() : null,
  );
  final scale = double.tryParse(query['scale'] ?? '1') ?? 1;
  final dark = query['theme'] == 'dark';
  final attachment = Attachment(
    fileName: 'sample-document.pdf',
    mimeType: 'application/pdf',
    fileType: 'document',
    hash: 'local-fixture-hash',
    storagePath: '/local/fixture/sample-document.pdf',
    fileSize: 2048,
  );

  runApp(
    MaterialApp(
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
          brightness: dark ? Brightness.dark : Brightness.light,
        ),
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          disableAnimations: query['motion'] == 'false',
        ),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => showFileInfoPreviewDialog(
                context: context,
                attachment: attachment,
              ),
              child: const Text('Open safe fixture'),
            ),
          ),
        ),
      ),
    ),
  );
}
