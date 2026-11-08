import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

/// Configuration for a platform tutorial.
class PlatformTutorialConfig {
  final String platformName;
  final IconData icon;
  final Color color;

  const PlatformTutorialConfig({
    required this.platformName,
    required this.icon,
    required this.color,
  });
}

/// A platform list page that routes to the detailed tutorial for each OS.
class PlatformTutorialSelectionPage extends StatelessWidget {
  const PlatformTutorialSelectionPage({super.key});

  static const platforms = [
    PlatformTutorialConfig(
      platformName: 'Android',
      icon: Icons.android,
      color: Colors.green,
    ),
    PlatformTutorialConfig(
      platformName: 'iOS',
      icon: Icons.phone_iphone,
      color: Colors.grey,
    ),
    PlatformTutorialConfig(
      platformName: 'Windows',
      icon: Icons.desktop_windows,
      color: Colors.blue,
    ),
    PlatformTutorialConfig(
      platformName: 'macOS',
      icon: Icons.desktop_mac,
      color: Colors.blueGrey,
    ),
    PlatformTutorialConfig(
      platformName: 'Linux',
      icon: Icons.terminal,
      color: Colors.orange,
    ),
    PlatformTutorialConfig(
      platformName: 'Web',
      icon: Icons.language,
      color: Colors.purple,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.platformTutorialPageTitle),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            l10n.backgroundOptimizationTutorialDescription,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          ...platforms.map((config) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: config.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Icon(config.icon, color: config.color, size: 24),
                  ),
                  title: Text(
                    config.platformName,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    l10n.platformTutorialPlatformSubtitle(config.platformName),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PlatformTutorialPage(config: config),
                      ),
                    );
                  },
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// A detail page showing background running tutorial for a specific platform.
class PlatformTutorialPage extends StatelessWidget {
  final PlatformTutorialConfig config;

  const PlatformTutorialPage({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.platformTutorialDetailTitle(config.platformName)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeaderCard(theme, l10n),
          const SizedBox(height: 16),
          ..._buildTutorialSteps(theme, l10n),
          const SizedBox(height: 24),
          _buildTipsCard(theme, l10n),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(ThemeData theme, AppLocalizations l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(config.icon, size: 64, color: config.color),
            const SizedBox(height: 12),
            Text(
              l10n.platformTutorialGuideTitle(config.platformName),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.platformTutorialGuideIntro(config.platformName),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildTutorialSteps(
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    final steps = _getStepsForPlatform(config.platformName, l10n);
    return [
      _buildSectionHeader(l10n.platformTutorialStepsHeading, theme),
      const SizedBox(height: 12),
      ...List.generate(steps.length, (index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: config.color,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          steps[index].title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          steps[index].description,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    ];
  }

  List<_TutorialStep> _getStepsForPlatform(
    String platform,
    AppLocalizations l10n,
  ) {
    switch (platform) {
      case 'Android':
        return [
          _TutorialStep(
            title: l10n.platformTutorialAndroidStep1Title,
            description: l10n.platformTutorialAndroidStep1Description,
          ),
          _TutorialStep(
            title: l10n.platformTutorialAndroidStep2Title,
            description: l10n.platformTutorialAndroidStep2Description,
          ),
          _TutorialStep(
            title: l10n.platformTutorialAndroidStep3Title,
            description: l10n.platformTutorialAndroidStep3Description,
          ),
          _TutorialStep(
            title: l10n.platformTutorialAndroidStep4Title,
            description: l10n.platformTutorialAndroidStep4Description,
          ),
          _TutorialStep(
            title: l10n.platformTutorialAndroidStep5Title,
            description: l10n.platformTutorialAndroidStep5Description,
          ),
          _TutorialStep(
            title: l10n.platformTutorialAndroidStep6Title,
            description: l10n.platformTutorialAndroidStep6Description,
          ),
          _TutorialStep(
            title: l10n.platformTutorialAndroidStep7Title,
            description: l10n.platformTutorialAndroidStep7Description,
          ),
        ];
      case 'iOS':
        return [
          _TutorialStep(
            title: l10n.platformTutorialIosStep1Title,
            description: l10n.platformTutorialIosStep1Description,
          ),
          _TutorialStep(
            title: l10n.platformTutorialIosStep2Title,
            description: l10n.platformTutorialIosStep2Description,
          ),
          _TutorialStep(
            title: l10n.platformTutorialIosStep3Title,
            description: l10n.platformTutorialIosStep3Description,
          ),
          _TutorialStep(
            title: l10n.platformTutorialIosStep4Title,
            description: l10n.platformTutorialIosStep4Description,
          ),
          _TutorialStep(
            title: l10n.platformTutorialIosStep5Title,
            description: l10n.platformTutorialIosStep5Description,
          ),
          _TutorialStep(
            title: l10n.platformTutorialIosStep6Title,
            description: l10n.platformTutorialIosStep6Description,
          ),
        ];
      case 'Windows':
        return [
          _TutorialStep(
            title: l10n.platformTutorialWindowsStep1Title,
            description: l10n.platformTutorialWindowsStep1Description,
          ),
          _TutorialStep(
            title: l10n.platformTutorialWindowsStep2Title,
            description: l10n.platformTutorialWindowsStep2Description,
          ),
          _TutorialStep(
            title: l10n.platformTutorialWindowsStep3Title,
            description: l10n.platformTutorialWindowsStep3Description,
          ),
          _TutorialStep(
            title: l10n.platformTutorialWindowsStep4Title,
            description: l10n.platformTutorialWindowsStep4Description,
          ),
          _TutorialStep(
            title: l10n.platformTutorialWindowsStep5Title,
            description: l10n.platformTutorialWindowsStep5Description,
          ),
        ];
      case 'macOS':
        return [
          _TutorialStep(
            title: l10n.platformTutorialMacosStep1Title,
            description: l10n.platformTutorialMacosStep1Description,
          ),
          _TutorialStep(
            title: l10n.platformTutorialMacosStep2Title,
            description: l10n.platformTutorialMacosStep2Description,
          ),
          _TutorialStep(
            title: l10n.platformTutorialMacosStep3Title,
            description: l10n.platformTutorialMacosStep3Description,
          ),
          _TutorialStep(
            title: l10n.platformTutorialMacosStep4Title,
            description: l10n.platformTutorialMacosStep4Description,
          ),
          _TutorialStep(
            title: l10n.platformTutorialMacosStep5Title,
            description: l10n.platformTutorialMacosStep5Description,
          ),
        ];
      case 'Linux':
        return [
          _TutorialStep(
            title: l10n.platformTutorialLinuxStep1Title,
            description: l10n.platformTutorialLinuxStep1Description,
          ),
          _TutorialStep(
            title: l10n.platformTutorialLinuxStep2Title,
            description: l10n.platformTutorialLinuxStep2Description,
          ),
          _TutorialStep(
            title: l10n.platformTutorialLinuxStep3Title,
            description: l10n.platformTutorialLinuxStep3Description,
          ),
          _TutorialStep(
            title: l10n.platformTutorialLinuxStep4Title,
            description: l10n.platformTutorialLinuxStep4Description,
          ),
          _TutorialStep(
            title: l10n.platformTutorialLinuxStep5Title,
            description: l10n.platformTutorialLinuxStep5Description,
          ),
        ];
      case 'Web':
        return [
          _TutorialStep(
            title: l10n.platformTutorialWebStep1Title,
            description: l10n.platformTutorialWebStep1Description,
          ),
          _TutorialStep(
            title: l10n.platformTutorialWebStep2Title,
            description: l10n.platformTutorialWebStep2Description,
          ),
        ];
      default:
        return [];
    }
  }

  Widget _buildTipsCard(ThemeData theme, AppLocalizations l10n) {
    return Card(
      color: config.color.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lightbulb_outline, color: config.color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.platformTutorialTipsHeading,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: config.color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.platformTutorialTipsDescription,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _TutorialStep {
  final String title;
  final String description;

  const _TutorialStep({required this.title, required this.description});
}
