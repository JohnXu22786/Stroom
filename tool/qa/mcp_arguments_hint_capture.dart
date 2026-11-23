import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/mcp_server_config_page.dart';
import 'package:stroom/providers/provider_config.dart';

void main() {
  const locale = Locale('en', 'US');

  runApp(
    ProviderScope(
      overrides: [
        providerEntriesProvider.overrideWith((ref) {
          return ProviderEntriesNotifier();
        }),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showMcpServerConfigDialog(
                  context: context,
                  entryId: 'safe_fixture_mcp',
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
