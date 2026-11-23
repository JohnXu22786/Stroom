import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/provider_config_page.dart';
import 'package:stroom/providers/provider_config.dart';

class _CaptureProviderEntriesNotifier extends ProviderEntriesNotifier {
  _CaptureProviderEntriesNotifier() {
    state = ProviderEntriesState(
      entries: [
        ProviderEntry(
          id: 'builtin_mcp',
          type: 'mcp',
          name: 'MCP',
          configs: [
            ProviderConfigItem(
              id: 'vendor_service',
              providerName:
                  'Ein sehr langer integrierter Dienstname für schmale Displays',
              models: [
                ModelConfig(
                  name: 'Vendor service',
                  modelId: 'vendor-service',
                  typeConfig: {
                    'isVendor': true,
                    'transport': 'stdio',
                    'command': 'local-fixture',
                  },
                ),
              ],
            ),
            ProviderConfigItem(
              id: 'custom_service',
              providerName: 'A second configured MCP server',
              models: [
                ModelConfig(
                  name: 'Custom service',
                  modelId: 'custom-service',
                  typeConfig: {
                    'transport': 'sse',
                    'url': 'https://example.test',
                  },
                ),
              ],
            ),
          ],
        ),
      ],
      mcpGroups: builtinMcpProviderGroups,
    );
  }
}

void main() {
  final query = Uri.base.queryParameters;
  final scale = double.tryParse(query['scale'] ?? '') ?? 1;
  final brightness =
      query['theme'] == 'dark' ? Brightness.dark : Brightness.light;

  runApp(
    ProviderScope(
      overrides: [
        providerEntriesProvider.overrideWith(
          (ref) => _CaptureProviderEntriesNotifier(),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('de', 'DE'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: ThemeData(useMaterial3: true, brightness: brightness),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: const ProviderConfigPage(entryId: 'builtin_mcp'),
      ),
    ),
  );
}
