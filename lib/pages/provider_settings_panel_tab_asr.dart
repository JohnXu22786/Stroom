part of 'provider_settings_panel.dart';

// Extension methods on the State class cannot use @protected members
// (setState / state) without analyzer warnings, but the receiver IS the
// State/StateNotifier, so runtime behavior is identical to the original
// inline code.
// ignore_for_file: invalid_use_of_protected_member

extension _ProviderSettingsPanelTabAsrExt on _ProviderSettingsPanelState {
  List<Widget> _buildAsrChunkingSection(ColorScheme cs) {
    return [
      Text(
        AppLocalizations.of(context)!.providerAudioChunkingTitle,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 18,
          color: cs.primary,
          letterSpacing: 0.3,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        AppLocalizations.of(context)!.providerAudioChunkingHint,
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: cs.onSurfaceVariant, height: 1.4),
      ),
      const SizedBox(height: 16),
      _buildResponsiveSettingsRow(
        context,
        label: AppLocalizations.of(context)!.providerChunkingMode,
        control: Container(
          decoration: BoxDecoration(
            border: Border.all(color: cs.outlineVariant),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              dropdownColor: StroomMenuStyle.surface(context),
              borderRadius: StroomMenuStyle.borderRadius,
              value: _chunking,
              isDense: true,
              isExpanded: MediaQuery.sizeOf(context).width < 1100,
              selectedItemBuilder: (context) => [
                _buildAsrSelectedDropdownText(
                  context,
                  AppLocalizations.of(context)!.providerChunkNone,
                ),
                _buildAsrSelectedDropdownText(
                  context,
                  AppLocalizations.of(context)!.providerChunkSmart,
                  style: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                _buildAsrSelectedDropdownText(
                  context,
                  AppLocalizations.of(context)!.providerChunkFixedDuration,
                ),
                _buildAsrSelectedDropdownText(
                  context,
                  AppLocalizations.of(context)!.providerChunkFixedSize,
                ),
              ],
              items: [
                DropdownMenuItem(
                  value: 'none',
                  child: ConstrainedText(
                    AppLocalizations.of(context)!.providerChunkNone,
                    style: Theme.of(context).textTheme.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                DropdownMenuItem(
                  value: 'silence',
                  child: ConstrainedText(
                    AppLocalizations.of(context)!.providerChunkSmart,
                    style: Theme.of(context).textTheme.labelLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                DropdownMenuItem(
                  value: 'fixedDuration',
                  child: ConstrainedText(
                    AppLocalizations.of(context)!.providerChunkFixedDuration,
                    style: Theme.of(context).textTheme.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                DropdownMenuItem(
                  value: 'fixedSize',
                  child: ConstrainedText(
                    AppLocalizations.of(context)!.providerChunkFixedSize,
                    style: Theme.of(context).textTheme.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _chunking = v);
              },
            ),
          ),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        _chunkingDescription(),
        style: TextStyle(
          fontSize: 12,
          color: cs.onSurfaceVariant.withAlpha(180),
          height: 1.4,
        ),
      ),
    ];
  }

  List<Widget> _buildAsrCompressionSection(ColorScheme cs) {
    return [
      Text(
        AppLocalizations.of(context)!.providerCompressionTitle,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 18,
          color: cs.primary,
          letterSpacing: 0.3,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        AppLocalizations.of(context)!.providerCompressionHint,
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: cs.onSurfaceVariant, height: 1.4),
      ),
      const SizedBox(height: 16),
      _buildResponsiveSettingsRow(
        context,
        label: AppLocalizations.of(context)!.providerCompressionMode,
        control: Container(
          decoration: BoxDecoration(
            border: Border.all(color: cs.outlineVariant),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              dropdownColor: StroomMenuStyle.surface(context),
              borderRadius: StroomMenuStyle.borderRadius,
              value: _compression,
              isDense: true,
              isExpanded: MediaQuery.sizeOf(context).width < 1100,
              selectedItemBuilder: (context) => [
                _buildAsrSelectedDropdownText(
                  context,
                  AppLocalizations.of(context)!.providerCompressionNone,
                ),
                _buildAsrSelectedDropdownText(
                  context,
                  AppLocalizations.of(context)!.providerCompressionAdpcm,
                ),
                _buildAsrSelectedDropdownText(
                  context,
                  AppLocalizations.of(context)!.providerCompressionFlac,
                ),
              ],
              items: [
                DropdownMenuItem(
                  value: 'none',
                  child: ConstrainedText(
                    AppLocalizations.of(context)!.providerCompressionNone,
                    style: Theme.of(context).textTheme.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                DropdownMenuItem(
                  value: 'adpcm',
                  child: ConstrainedText(
                    AppLocalizations.of(context)!.providerCompressionAdpcm,
                    style: Theme.of(context).textTheme.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                DropdownMenuItem(
                  value: 'flac',
                  child: ConstrainedText(
                    AppLocalizations.of(context)!.providerCompressionFlac,
                    style: Theme.of(context).textTheme.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _compression = v);
              },
            ),
          ),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        _compression == 'adpcm'
            ? AppLocalizations.of(context)!.providerCompressionAdpcmDescription
            : _compression == 'flac'
            ? AppLocalizations.of(context)!.providerCompressionFlacDescription
            : AppLocalizations.of(context)!.providerCompressionWavDescription,
        style: TextStyle(
          fontSize: 12,
          color: cs.onSurfaceVariant.withAlpha(180),
          height: 1.4,
        ),
      ),
    ];
  }

  List<Widget> _buildLlmParamsSection(ColorScheme cs) {
    return [
      Text(
        AppLocalizations.of(context)!.providerLlmParams,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 16,
          color: cs.primary,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        AppLocalizations.of(context)!.providerEnabledParamsHelp,
        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
      ),
      const SizedBox(height: 12),
      LlmToggleSlider(
        label: AppLocalizations.of(context)!.providerTemperatureLabel,
        value: _temperature,
        min: 0.0,
        max: 2.0,
        divisions: 40,
        enabled: _enableTemperature,
        onChanged: (v) => setState(() => _temperature = v),
        onToggle: (v) => setState(() => _enableTemperature = v),
        description: AppLocalizations.of(context)!.providerTemperatureHelp,
      ),
      LlmToggleSlider(
        label: 'Top P',
        value: _topP,
        min: 0.0,
        max: 1.0,
        divisions: 20,
        enabled: _enableTopP,
        onChanged: (v) => setState(() => _topP = v),
        onToggle: (v) => setState(() => _enableTopP = v),
        description: AppLocalizations.of(context)!.providerTopPHelp,
      ),
      LlmToggleSlider(
        label: AppLocalizations.of(context)!.providerFrequencyPenaltyLabel,
        value: _frequencyPenalty,
        min: -2.0,
        max: 2.0,
        divisions: 40,
        enabled: _enableFrequencyPenalty,
        onChanged: (v) => setState(() => _frequencyPenalty = v),
        onToggle: (v) => setState(() => _enableFrequencyPenalty = v),
        description: AppLocalizations.of(context)!.providerFrequencyPenaltyHelp,
      ),
      LlmToggleSlider(
        label: AppLocalizations.of(context)!.providerPresencePenaltyLabel,
        value: _presencePenalty,
        min: -2.0,
        max: 2.0,
        divisions: 40,
        enabled: _enablePresencePenalty,
        onChanged: (v) => setState(() => _presencePenalty = v),
        onToggle: (v) => setState(() => _enablePresencePenalty = v),
        description: AppLocalizations.of(context)!.providerPresencePenaltyHelp,
      ),
      LlmToggleTextField(
        label: AppLocalizations.of(context)!.providerMaxOutputTokensLabel,
        controller: _maxTokensController,
        enabled: _enableMaxTokens,
        onToggle: (v) => setState(() => _enableMaxTokens = v),
        hintText: AppLocalizations.of(context)!.providerOptionalExample('4096'),
        keyboardType: TextInputType.number,
        description: AppLocalizations.of(context)!.providerResponseTokensHelp,
      ),
      LlmToggleTextField(
        label: AppLocalizations.of(context)!.providerSeedLabel,
        controller: _seedController,
        enabled: _enableSeed,
        onToggle: (v) => setState(() => _enableSeed = v),
        hintText: AppLocalizations.of(context)!.providerOptionalExample('42'),
        keyboardType: TextInputType.number,
        description: AppLocalizations.of(context)!.providerSeedHelp,
      ),
      const SizedBox(height: 24),
    ];
  }

  String _chunkingDescription() {
    final strings = AppLocalizations.of(context)!;
    switch (_chunking) {
      case 'silence':
        return strings.providerChunkSmartDescription;
      case 'fixedDuration':
        return strings.providerChunkDurationDescription;
      case 'fixedSize':
        return strings.providerChunkSizeDescription;
      default:
        return strings.providerChunkNoneDescription;
    }
  }
}
