part of 'provider_settings_panel.dart';

// Extension methods on the State class cannot use @protected members
// (setState / state) without analyzer warnings, but the receiver IS the
// State/StateNotifier, so runtime behavior is identical to the original
// inline code.
// ignore_for_file: invalid_use_of_protected_member

extension _ProviderSettingsPanelTabBasicExt on _ProviderSettingsPanelState {
  Widget _buildBasicInfoTab(ColorScheme cs) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.providerNameLabel,
              hintText: AppLocalizations.of(context)!.providerNameHint,
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.label, color: Colors.teal),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _hostController,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.providerApiUrlLabel,
              hintText: AppLocalizations.of(context)!.providerApiUrlHint,
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.link, color: Colors.orange),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _keyController,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.mcpApiKey,
              hintText: AppLocalizations.of(context)!.providerApiKeyInputHint,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.key, color: Colors.amber),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureKey ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey,
                ),
                onPressed: () => setState(() => _obscureKey = !_obscureKey),
              ),
            ),
            obscureText: _obscureKey,
          ),
          if (_isLlmType) ...[
            const SizedBox(height: 16),
            // Supplier protocol default; authentication belongs to the connector.
            DropdownButtonFormField<String>(
              dropdownColor: StroomMenuStyle.surface(context),
              borderRadius: StroomMenuStyle.borderRadius,
              initialValue: _apiProtocol,
              decoration: InputDecoration(
                labelText:
                    AppLocalizations.of(context)!.providerEndpointTypeLabel,
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.hub_outlined, color: Colors.blue),
              ),
              items: supportedApiProtocolsForSupplier(
                _apiProtocol,
                connectorType:
                    widget.config.legacyFields['connectorType'] as String?,
              )
                  .map(
                    (protocol) => DropdownMenuItem(
                      value: protocol,
                      child: Text(apiProtocolLabels[protocol] ?? protocol),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _apiProtocol = v);
              },
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.llmEndpointHelp,
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildParameterSettingsTab(ColorScheme cs) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ..._buildOverrideRuleSection(cs),
          if (_isOcrType) ...[
            TextField(
              key: const Key('ocr_provider_request_size_budget_mib'),
              controller: _ocrRequestSizeBudgetController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText:
                    AppLocalizations.of(context)!.providerRequestJsonDefault,
                hintText: AppLocalizations.of(context)!.providerUseAppDefault,
                suffixText: 'MiB',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.providerModelJsonBudgetHelp,
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
          ],
          if (_isAsrType) ...[
            ..._buildAsrUploadSection(cs),
            const SizedBox(height: 32),
            ..._buildAsrFallbackSection(cs),
            const SizedBox(height: 32),
            ..._buildAsrPreprocessingSection(cs),
            const SizedBox(height: 32),
            ..._buildAsrChunkingSection(cs),
            const SizedBox(height: 32),
            ..._buildAsrCompressionSection(cs),
          ],
          if (_isLlmType) ..._buildReasoningParamsSection(cs),
          if (_isLlmType) ..._buildLlmParamsSection(cs),
          ..._buildCustomParamsSection(cs),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  List<Widget> _buildOverrideRuleSection(ColorScheme cs) {
    return [
      // Override rule explanation (like assistant settings)
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: cs.tertiaryContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 16, color: cs.tertiary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                AppLocalizations.of(context)!.providerRequestParamsHelp,
                style: TextStyle(fontSize: 12, color: cs.onTertiaryContainer),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
    ];
  }

  List<Widget> _buildAsrUploadSection(ColorScheme cs) {
    return [
      Text(
        AppLocalizations.of(context)!.providerUploadSettings,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 18,
          color: cs.primary,
          letterSpacing: 0.3,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        AppLocalizations.of(context)!.providerUploadMethodHelp,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.4,
            ),
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Text(
            AppLocalizations.of(context)!.providerUploadMethod,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: cs.onSurface,
            ),
          ),
          const Spacer(),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: cs.outlineVariant),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<AudioUploadMethod>(
                dropdownColor: StroomMenuStyle.surface(context),
                borderRadius: StroomMenuStyle.borderRadius,
                value: _uploadMethod,
                isDense: true,
                items: [
                  DropdownMenuItem(
                    value: AudioUploadMethod.multipart,
                    child: Text(
                      AppLocalizations.of(context)!.providerMultipart,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  DropdownMenuItem(
                    value: AudioUploadMethod.base64Json,
                    child: Text(
                      'Base64 JSON',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  DropdownMenuItem(
                    value: AudioUploadMethod.url,
                    child: Text(
                      AppLocalizations.of(context)!.providerUrlUpload,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _uploadMethod = v);
                },
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Text(
        _uploadMethod == AudioUploadMethod.multipart
            ? AppLocalizations.of(context)!.providerUploadMultipartHelp
            : _uploadMethod == AudioUploadMethod.base64Json
                ? AppLocalizations.of(context)!.providerUploadBase64Help
                : AppLocalizations.of(context)!.providerUploadUrlHelp,
        style: TextStyle(
          fontSize: 12,
          color: cs.onSurfaceVariant.withAlpha(180),
          height: 1.4,
        ),
      ),
      const SizedBox(height: 20),
      if (_uploadMethod != AudioUploadMethod.url)
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  AppLocalizations.of(context)!.providerMaxUploadSize,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: cs.onSurface,
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: 90,
                  child: TextField(
                    controller: _maxFileSizeController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(),
                      suffixText: 'MB',
                    ),
                    onChanged: (v) {
                      final parsed = double.tryParse(v);
                      if (parsed != null && parsed > 0) {
                        setState(() => _maxFileSizeMb = parsed);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.providerUploadBudgetHelp,
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurfaceVariant.withAlpha(180),
                height: 1.4,
              ),
            ),
          ],
        ),
    ];
  }

  List<Widget> _buildAsrFallbackSection(ColorScheme cs) {
    return [
      Text(
        AppLocalizations.of(context)!.providerFallbackStrategy,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 18,
          color: cs.primary,
          letterSpacing: 0.3,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        AppLocalizations.of(context)!.providerFallbackTriggerHelp,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.4,
            ),
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Text(
            AppLocalizations.of(context)!.providerFallbackMethod,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: cs.onSurface,
            ),
          ),
          const Spacer(),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: cs.outlineVariant),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                dropdownColor: StroomMenuStyle.surface(context),
                borderRadius: StroomMenuStyle.borderRadius,
                value: _fallbackMethod,
                isDense: true,
                items: [
                  DropdownMenuItem(
                    value: 'none',
                    child: Text(
                      AppLocalizations.of(context)!.providerFallbackNone,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'specific',
                    child: Text(
                      AppLocalizations.of(context)!.providerFallbackSpecific,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'generic',
                    child: Text(
                      AppLocalizations.of(context)!.providerFallbackGeneric,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'all',
                    child: Text(
                      AppLocalizations.of(context)!.providerFallbackAll,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _fallbackMethod = v);
                },
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Text(
        _fallbackMethod == 'specific'
            ? AppLocalizations.of(context)!.providerFallbackSpecificHelp
            : _fallbackMethod == 'generic'
                ? AppLocalizations.of(context)!.providerFallbackGenericHelp
                : _fallbackMethod == 'all'
                    ? AppLocalizations.of(context)!.providerFallbackAllHelp
                    : AppLocalizations.of(context)!.providerFallbackRejectHelp,
        style: TextStyle(
          fontSize: 12,
          color: cs.onSurfaceVariant.withAlpha(180),
          height: 1.4,
        ),
      ),
    ];
  }

  List<Widget> _buildAsrPreprocessingSection(ColorScheme cs) {
    return [
      Text(
        AppLocalizations.of(context)!.providerPreprocessing,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 18,
          color: cs.primary,
          letterSpacing: 0.3,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        AppLocalizations.of(context)!.providerPreprocessingHelp,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.4,
            ),
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Text(
            AppLocalizations.of(context)!.providerPreprocessingMethod,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: cs.onSurface,
            ),
          ),
          const Spacer(),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: cs.outlineVariant),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                dropdownColor: StroomMenuStyle.surface(context),
                borderRadius: StroomMenuStyle.borderRadius,
                value: _preprocessing,
                isDense: true,
                items: [
                  DropdownMenuItem(
                    value: 'none',
                    child: Text(
                      AppLocalizations.of(context)!.providerPreprocessNone,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'resampleMono',
                    child: Text(
                      AppLocalizations.of(context)!.providerPreprocessResample,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _preprocessing = v);
                },
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Text(
        _preprocessing == 'resampleMono'
            ? AppLocalizations.of(context)!.providerPreprocessResampleHelp
            : AppLocalizations.of(context)!.providerPreprocessNoneHelp,
        style: TextStyle(
          fontSize: 12,
          color: cs.onSurfaceVariant.withAlpha(180),
          height: 1.4,
        ),
      ),
    ];
  }
}
