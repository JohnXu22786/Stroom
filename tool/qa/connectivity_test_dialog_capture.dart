import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/connectivity_test_dialog.dart';
import 'package:stroom/services/connectivity_test_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  WidgetsBinding.instance.ensureSemantics();

  final dark = Uri.base.queryParameters['theme'] == 'dark';
  final scale = double.tryParse(Uri.base.queryParameters['scale'] ?? '1') ?? 1;

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('de', 'DE'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.blue,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Builder(
        builder: (context) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            final localizations = AppLocalizations.of(context)!;
            final toolNames = List.generate(
              15,
              (index) => 'local_tool_${index + 1}',
            );
            final result = ConnectivityTestResult(
              succeeded: true,
              summary: localizations.connectivityTestMcpSuccess,
              details: localizations.connectivityTestMcpSuccessDetails(
                toolNames.length,
                localizations.connectivityTestToolNames(toolNames.join(', ')),
                '',
              ),
              elapsed: const Duration(milliseconds: 184),
            );
            showDialog<void>(
              context: context,
              builder: (dialogContext) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (dialogContext.mounted) {
                    FocusScope.of(dialogContext).nextFocus();
                  }
                });
                return ConnectivityTestDialog(
                  title: 'MCP tools/list',
                  initialContent:
                      '{\n  "method": "tools/list",\n  "params": {}\n}',
                  note:
                      'Lokaler Vorschauwert. Es wird keine Verbindung gestartet.',
                  initialResult: result,
                  onSave: (_) async {},
                  onRun: (_) async => result,
                );
              },
            );
          });
          return const Scaffold(body: SizedBox.expand());
        },
      ),
    ),
  );
}
