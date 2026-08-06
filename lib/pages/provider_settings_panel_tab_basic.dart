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
            decoration: const InputDecoration(
              labelText: '供应商名称',
              hintText: '输入供应商名称',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.label, color: Colors.teal),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _hostController,
            decoration: const InputDecoration(
              labelText: 'API 地址',
              hintText: '输入完整的 API 端点地址',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.link, color: Colors.orange),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _keyController,
            decoration: InputDecoration(
              labelText: 'Key',
              hintText: '输入 API 密钥',
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
            // 端点类型：该供应商下所有对话统一使用的协议格式
            DropdownButtonFormField<String>(
              initialValue: _endpointType,
              decoration: const InputDecoration(
                labelText: '端点类型',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.hub_outlined, color: Colors.blue),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'openai',
                  child: Text('OpenAI 兼容 (Chat Completions)'),
                ),
                DropdownMenuItem(
                  value: 'anthropic',
                  child: Text('Anthropic 格式 (Messages API)'),
                ),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _endpointType = v);
              },
            ),
            const SizedBox(height: 8),
            Text(
              _endpointType == 'anthropic'
                  ? '使用官方 Anthropic Messages API 格式（x-api-key 请求头），'
                      'API 地址示例: https://api.anthropic.com/v1/messages'
                  : '使用官方 OpenAI Chat Completions 兼容格式（Bearer 请求头），'
                      'API 地址示例: https://api.openai.com/v1/chat/completions',
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
                '请求时将同时使用供应商和模型的所有已开启参数；如果存在重复参数，模型的参数值将覆盖供应商的。',
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onTertiaryContainer,
                ),
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
        '上传设置',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 18,
          color: cs.primary,
          letterSpacing: 0.3,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        '选择音频发送方式，不同供应商支持的上传方式和大小限制不同。',
        style: TextStyle(
          fontSize: 13,
          color: cs.onSurfaceVariant,
          height: 1.4,
        ),
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Text(
            '上传方式',
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
                value: _uploadMethod,
                isDense: true,
                items: const [
                  DropdownMenuItem(
                    value: AudioUploadMethod.multipart,
                    child:
                        Text('Multipart（通用）', style: TextStyle(fontSize: 13)),
                  ),
                  DropdownMenuItem(
                    value: AudioUploadMethod.base64Json,
                    child: Text('Base64 JSON', style: TextStyle(fontSize: 13)),
                  ),
                  DropdownMenuItem(
                    value: AudioUploadMethod.url,
                    child: Text('URL（链接）', style: TextStyle(fontSize: 13)),
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
      const SizedBox(height: 6),
      Text(
        _uploadMethod == AudioUploadMethod.multipart
            ? 'multipart/form-data 直传。最通用，受各供应商大小限制（通常 25 MB）。'
            : _uploadMethod == AudioUploadMethod.base64Json
                ? 'Base64 编码后 JSON 发送。可绕过部分供应商 multipart 大小限制。'
                : '提供公网 URL，供应商自行下载。支持超大文件（Together AI 1 GB 等）。',
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
                  '最大文件大小',
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
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
            const SizedBox(height: 6),
            Text(
              '超过 ${_maxFileSizeMb.toStringAsFixed(1)} MB 的文件将被拒绝。'
              '默认 25 MB 是 OpenAI 音频 API 上限。',
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
        '兜底策略',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 18,
          color: cs.primary,
          letterSpacing: 0.3,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        '当文件超过大小限制时的处理方式。特定兜底（Base64）优先于通用兜底（压缩/切块）。',
        style: TextStyle(
          fontSize: 13,
          color: cs.onSurfaceVariant,
          height: 1.4,
        ),
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Text(
            '兜底方式',
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
                value: _fallbackMethod,
                isDense: true,
                items: const [
                  DropdownMenuItem(
                    value: 'none',
                    child: Text('无（直接拒绝）', style: TextStyle(fontSize: 13)),
                  ),
                  DropdownMenuItem(
                    value: 'specific',
                    child: Text('特定兜底（Base64）',
                        style: TextStyle(fontSize: 13)),
                  ),
                  DropdownMenuItem(
                    value: 'generic',
                    child: Text('通用兜底（压缩/切块）', style: TextStyle(fontSize: 13)),
                  ),
                  DropdownMenuItem(
                    value: 'all',
                    child: Text('全部尝试（推荐）',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
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
      const SizedBox(height: 6),
      Text(
        _fallbackMethod == 'specific'
            ? '优先尝试 Base64 JSON 上传，绕过部分供应商的 multipart 大小限制。'
            : _fallbackMethod == 'generic'
                ? '先应用压缩，再尝试切块，最后重新上传。'
                : _fallbackMethod == 'all'
                    ? '先尝试特定兜底，再尝试通用兜底。最大化成功率。'
                    : '文件超过限制时直接拒绝，不尝试任何兜底。',
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
        '音频预处理',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 18,
          color: cs.primary,
          letterSpacing: 0.3,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        '降低音频文件大小，不影响转写准确率。',
        style: TextStyle(
          fontSize: 13,
          color: cs.onSurfaceVariant,
          height: 1.4,
        ),
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Text(
            '预处理方式',
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
                value: _preprocessing,
                isDense: true,
                items: const [
                  DropdownMenuItem(
                    value: 'none',
                    child: Text('无', style: TextStyle(fontSize: 13)),
                  ),
                  DropdownMenuItem(
                    value: 'resampleMono',
                    child: Text('WAV 优化（16kHz Mono）',
                        style: TextStyle(fontSize: 13)),
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
      const SizedBox(height: 6),
      Text(
        _preprocessing == 'resampleMono'
            ? '重采样到 16kHz + 单声道混音。体积缩小约 4-6x，语音转写准确率几乎不变。'
            : '不进行预处理，原样发送。',
        style: TextStyle(
          fontSize: 12,
          color: cs.onSurfaceVariant.withAlpha(180),
          height: 1.4,
        ),
      ),
    ];
  }
}
