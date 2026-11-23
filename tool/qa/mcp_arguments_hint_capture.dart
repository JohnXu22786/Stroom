import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/semantics.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/mcp_server_config_page.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:web/web.dart' as web;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SemanticsBinding.instance.ensureSemantics();

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
          builder: (context) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              web.window.document.documentElement?.setAttribute(
                'data-mcp-capture-launcher-ready',
                'true',
              );
            });

            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    showMcpServerConfigDialog(
                      context: context,
                      entryId: 'safe_fixture_mcp',
                      configIndex: -1,
                    );
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      web.window.document.documentElement?.setAttribute(
                        'data-mcp-arguments-dialog-ready',
                        'true',
                      );
                    });
                  },
                  child: const Text('Open MCP settings'),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}
