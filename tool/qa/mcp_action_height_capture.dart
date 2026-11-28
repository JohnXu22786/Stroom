import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/mcp_server_config_page.dart';
import 'package:stroom/providers/provider_config.dart';

void main() {
  final query = Uri.base.queryParameters;
  final locale = query['locale'] == 'fr-FR'
      ? const Locale('fr', 'FR')
      : const Locale('en', 'US');
  final textScale = double.tryParse(query['scale'] ?? '') ?? 1;
  final viewInsetBottom = double.tryParse(query['inset'] ?? '') ?? 0;
  final dark = query['theme'] == 'dark';

  runApp(
    ProviderScope(
      overrides: [
        providerEntriesProvider.overrideWith(
          (ref) => ProviderEntriesNotifier(),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: dark ? Brightness.dark : Brightness.light,
          ),
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            viewInsets: EdgeInsets.only(bottom: viewInsetBottom),
          ),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => showMcpServerConfigDialog(
                  context: context,
                  entryId: 'missing-entry',
                  configIndex: -1,
                ),
                child: const Text('Open MCP settings'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
