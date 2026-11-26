import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/widgets/html_code_block_widget.dart';

void main() {
  final query = Uri.base.queryParameters;
  final fitting = query['state'] == 'fitting';
  final locale =
      query['locale'] == 'en' ? const Locale('en') : const Locale('de', 'DE');
  final scale = double.tryParse(query['scale'] ?? '') ?? (fitting ? 1 : 1.8);

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
      theme: ThemeData(useMaterial3: true),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
        ),
        child: child!,
      ),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: fitting ? 480 : 180,
            child: const HtmlCodeBlockWidget(
              htmlCode: '<p>Streaming preview</p>',
              isStreaming: true,
            ),
          ),
        ),
      ),
    ),
  );
}
