import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/widgets/background_service_control_buttons.dart';

void main() {
  final query = Uri.base.queryParameters;
  final localeCode = query['locale'] ?? 'fr-FR';
  final localeParts = localeCode.split('-');
  final locale = Locale(
    localeParts.first,
    localeParts.length > 1 ? localeParts[1] : null,
  );
  final isRunning = query['state'] != 'stopped';
  final brightness =
      query['theme'] == 'dark' ? Brightness.dark : Brightness.light;
  final colorScheme = ColorScheme.fromSeed(
    seedColor: Colors.blue,
    brightness: brightness,
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
      theme: ThemeData(useMaterial3: true, colorScheme: colorScheme),
      home: _ServiceControlsFixture(isRunning: isRunning),
    ),
  );
}

class _ServiceControlsFixture extends StatelessWidget {
  const _ServiceControlsFixture({required this.isRunning});

  final bool isRunning;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.backgroundOptimizationTitle),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isRunning
                            ? Icons.check_circle
                            : Icons.warning_amber_rounded,
                        color: isRunning ? Colors.green : Colors.orange,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isRunning
                              ? strings.backgroundOptimizationServiceRunning
                              : strings.backgroundOptimizationServiceStopped,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isRunning ? Colors.green : Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isRunning
                        ? strings
                            .backgroundOptimizationServiceRunningDescription
                        : strings
                            .backgroundOptimizationServiceNotRunningDescription,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  BackgroundServiceControlButtons(
                    isServiceRunning: isRunning,
                    isOperating: false,
                    startLabel: strings.backgroundOptimizationStartService,
                    stopLabel: strings.backgroundOptimizationStopService,
                    restartLabel: strings.backgroundOptimizationRestartService,
                    redetectLabel: strings.backgroundOptimizationRedetect,
                    onStart: () {},
                    onStop: () {},
                    onRestart: () {},
                    onRedetect: () {},
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
