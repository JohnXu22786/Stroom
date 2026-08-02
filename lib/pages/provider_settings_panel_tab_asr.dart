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
        '音频切块',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 18,
          color: cs.primary,
          letterSpacing: 0.3,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        '智能裁切：分析音频环境、候选切点评分、句末优先。不重叠输出。',
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
            '切块方式',
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
                value: _chunking,
                isDense: true,
                items: const [
                  DropdownMenuItem(
                    value: 'none',
                    child: Text('不切块', style: TextStyle(fontSize: 13)),
                  ),
                  DropdownMenuItem(
                    value: 'silence',
                    child: Text('智能裁切（推荐）',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                  DropdownMenuItem(
                    value: 'fixedDuration',
                    child: Text('固定时长切块', style: TextStyle(fontSize: 13)),
                  ),
                  DropdownMenuItem(
                    value: 'fixedSize',
                    child: Text('固定大小切块', style: TextStyle(fontSize: 13)),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _chunking = v);
                },
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 6),
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
        '压缩编码',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 18,
          color: cs.primary,
          letterSpacing: 0.3,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        '选择音频压缩格式，减小上传体积。',
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
            '压缩方式',
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
                value: _compression,
                isDense: true,
                items: const [
                  DropdownMenuItem(
                    value: 'none',
                    child: Text('无（原样发送）', style: TextStyle(fontSize: 13)),
                  ),
                  DropdownMenuItem(
                    value: 'adpcm',
                    child:
                        Text('ADPCM（~4x 压缩）', style: TextStyle(fontSize: 13)),
                  ),
                  DropdownMenuItem(
                    value: 'flac',
                    child: Text('FLAC（无损 ~2x）', style: TextStyle(fontSize: 13)),
                  ),
                  DropdownMenuItem(
                    value: 'opus',
                    child:
                        Text('Opus（需 ffmpeg）', style: TextStyle(fontSize: 13)),
                  ),
                  DropdownMenuItem(
                    value: 'mp3',
                    child:
                        Text('MP3（需 ffmpeg）', style: TextStyle(fontSize: 13)),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _compression = v);
                },
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 6),
      Text(
        _compression == 'adpcm'
            ? 'IMA ADPCM，4:1 有损压缩。纯 Dart 实现，音质适合语音转写。'
            : _compression == 'flac'
                ? 'FLAC 无损压缩，纯 Dart 实现。体积缩小约一半。'
                : _compression == 'opus'
                    ? 'Opus 编码器，需系统 ffmpeg。最优语音压缩。'
                    : _compression == 'mp3'
                        ? 'MP3 编码器，需系统 ffmpeg。通用兼容性最好。'
                        : '不压缩，以原始 WAV 格式发送。',
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
        'LLM 参数',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 16,
          color: cs.primary,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        '开启的参数将作为默认值发送到 API 请求中',
        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
      ),
      const SizedBox(height: 12),
      LlmToggleSlider(
        label: '温度 (Temperature)',
        value: _temperature,
        min: 0.0,
        max: 2.0,
        divisions: 40,
        enabled: _enableTemperature,
        onChanged: (v) => setState(() => _temperature = v),
        onToggle: (v) => setState(() => _enableTemperature = v),
        description: '控制输出的随机性，值越高越有创造性',
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
        description: '核采样参数，控制词汇选择的累积概率',
      ),
      LlmToggleSlider(
        label: '频率惩罚 (Frequency Penalty)',
        value: _frequencyPenalty,
        min: -2.0,
        max: 2.0,
        divisions: 40,
        enabled: _enableFrequencyPenalty,
        onChanged: (v) => setState(() => _frequencyPenalty = v),
        onToggle: (v) => setState(() => _enableFrequencyPenalty = v),
        description: '减少重复词的频率，负值增加重复',
      ),
      LlmToggleSlider(
        label: '存在惩罚 (Presence Penalty)',
        value: _presencePenalty,
        min: -2.0,
        max: 2.0,
        divisions: 40,
        enabled: _enablePresencePenalty,
        onChanged: (v) => setState(() => _presencePenalty = v),
        onToggle: (v) => setState(() => _enablePresencePenalty = v),
        description: '鼓励讨论新话题，负值鼓励重复话题',
      ),
      LlmToggleTextField(
        label: '最大输出 Token 数',
        controller: _maxTokensController,
        enabled: _enableMaxTokens,
        onToggle: (v) => setState(() => _enableMaxTokens = v),
        hintText: '可选，如 4096',
        keyboardType: TextInputType.number,
        description: '每次响应最多生成的 token 数',
      ),
      LlmToggleTextField(
        label: '随机种子 (Seed)',
        controller: _seedController,
        enabled: _enableSeed,
        onToggle: (v) => setState(() => _enableSeed = v),
        hintText: '可选，如 42',
        keyboardType: TextInputType.number,
        description: '设置后可使输出结果可复现',
      ),
      const SizedBox(height: 24),
    ];
  }

  String _chunkingDescription() {
    switch (_chunking) {
      case 'silence':
        return '智能分析音频环境 + 候选切点评分。'
            '优先在句末/长静音处切，不重叠输出。'
            '默认 20s min / 45s target / 60s max。';
      case 'fixedDuration':
        return '每 N 秒切一块（默认 60 秒）。简单直接，可能截断语句。';
      case 'fixedSize':
        return '按字节大小切块，确保不超限制。最机械，可能截断语句。';
      default:
        return '不切块。超过限制的文件将被拒绝。';
    }
  }
}
