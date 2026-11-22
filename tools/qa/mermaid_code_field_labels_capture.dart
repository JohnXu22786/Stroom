import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/l10n/app_localizations_en.dart';
import 'package:stroom/pages/mermaid_chart_page.dart';

class _LongFieldLabelLocalizations extends AppLocalizationsEn {
  _LongFieldLabelLocalizations() : super('en');

  @override
  String get mermaidEditorCodeLabel =>
      'Mermaid source code for creating detailed diagrams';
}

class _LongFieldLabelDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _LongFieldLabelDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'en';

  @override
  Future<AppLocalizations> load(Locale locale) =>
      SynchronousFuture(_LongFieldLabelLocalizations());

  @override
  bool shouldReload(covariant _LongFieldLabelDelegate old) => false;
}

void main() {
  final query = Uri.base.queryParameters;
  final scale = double.tryParse(query['scale'] ?? '') ?? 1;
  final brightness =
      query['theme'] == 'dark' ? Brightness.dark : Brightness.light;

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        _LongFieldLabelDelegate(),
        ...AppLocalizations.localizationsDelegates,
      ],
      theme: ThemeData(useMaterial3: true, brightness: brightness),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: const MermaidChartPage(
        initialCode: 'graph TD\n  A-->B\n  B-->C',
        initialShowPreview: false,
      ),
    ),
  );
}
