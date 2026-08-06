part of 'chat_composer_widget.dart';

extension _ChatComposerBuildSectionsExt on ChatComposerWidgetState {
  /// ── Pending attachments row (reorderable) ──
  Widget _buildPendingAttachmentsRow() {
    return Container(
      height: 80,
      padding: const EdgeInsets.only(left: 12, top: 8),
      child: ReorderableListView.builder(
        scrollDirection: Axis.horizontal,
        buildDefaultDragHandles: false,
        itemCount: _pendingAttachments.length,
        onReorderItem: _onReorderPendingAttachment,
        itemBuilder: (ctx, i) {
          final att = _pendingAttachments[i];
          return ReorderableDelayedDragStartListener(
            key: ValueKey('pending_att_${att.id}'),
            index: i,
            child: FilePreviewChip(
              attachment: att,
              imageBytes: _pendingImageBytes[att.id],
              onRemove: () => _removePendingAttachment(i),
              onTap: () => _onTapPendingAttachment(i),
            ),
          );
        },
      ),
    );
  }

  /// ── Settings row (model, tools, reasoning) ──
  /// Uses Wrap so tags use their natural width and flow to the next
  /// line when they don't fit side-by-side. ModelNameChip is constrained
  /// to at most the full row width so its internal Flexible can
  /// truncate text properly. Tools and reasoning chips use natural
  /// width since their labels are short and fixed.
  Widget _buildChipsSettingsRow({
    required ColorScheme cs,
    required bool hasAttachments,
  }) {
    final reasoningEnabled = ref.watch(reasoningEnabledProvider);
    final reasoningEffortEnabled = ref.watch(reasoningEffortEnabledProvider);
    final reasoningParamValues = ref.watch(reasoningParamValuesProvider);

    // Find the effort param (推理力度) from widget.reasoningParams.
    // Legacy models without the isEffortParam flag fall back to the first
    // non-toggle param (pre-flag semantics).
    final effortParam = findEffortParam(widget.reasoningParams);

    // Determine reasoning chip label and color based on reasoning state.
    // When reasoning is enabled AND effort toggle is on AND the effort param
    // is enabled with a non-empty name AND a non-empty value has been
    // selected: show that value (e.g. "high", "low"). Otherwise: show "推理"
    // (purple when enabled, grey when disabled).
    final String reasoningLabel;
    if (reasoningEnabled &&
        reasoningEffortEnabled &&
        effortParam != null &&
        effortParam.enabled &&
        effortParam.paramName.trim().isNotEmpty &&
        (reasoningParamValues[effortParam.paramName]?.isNotEmpty ?? false)) {
      reasoningLabel = reasoningParamValues[effortParam.paramName]!;
    } else {
      reasoningLabel = '推理';
    }
    final reasoningColor = reasoningEnabled ? Colors.purple : Colors.grey;

    // ═══════════════════════════════════════════════════════════
    // Tool chip: accent color (indigo) when tools enabled, grey when disabled
    // ═══════════════════════════════════════════════════════════
    const Color toolAccentColor = Color(0xFF6366F1);
    final bool noToolsEnabled = widget.enabledTools.isEmpty;
    final Color toolColor = noToolsEnabled ? Colors.grey : toolAccentColor;
    final int? toolBadgeCount =
        noToolsEnabled ? null : widget.enabledTools.length;

    // ═══════════════════════════════════════════════════════════
    // Custom params chip: independent color state driven by the session.
    // A custom param (non-toggle, non-effort) counts as ACTIVE when its
    // switch is on (enabled), its name is non-empty, and a value has been
    // selected for it — and reasoning is on (matching what the request
    // actually sends). The chip shows the accent color + badge with the
    // active count; otherwise grey with no badge.
    // ═══════════════════════════════════════════════════════════
    final int activeCustomParamsCount = reasoningEnabled
        ? widget.reasoningParams
            .where(
              (p) =>
                  p != effortParam &&
                  !p.isReasoningToggle &&
                  p.paramName.trim().isNotEmpty &&
                  p.enabled &&
                  (reasoningParamValues[p.paramName]?.isNotEmpty ?? false),
            )
            .length
        : 0;
    final bool hasActiveCustomParams = activeCustomParamsCount > 0;
    final Color customParamsColor =
        hasActiveCustomParams ? toolAccentColor : Colors.grey;
    final int? customParamsBadgeCountOrNull =
        hasActiveCustomParams ? activeCustomParamsCount : null;

    return Padding(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: hasAttachments ? 0 : 6,
        bottom: 0,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Leave 4px horizontal margin for "留边" within the settings area.
          final maxTagWidth = constraints.maxWidth - 4;
          return Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxTagWidth),
                child: ModelNameChip(
                  displayName: (widget.modelNames.isNotEmpty &&
                          widget.selectedModelIndex >= 0 &&
                          widget.selectedModelIndex < widget.modelNames.length)
                      ? widget.modelNames[widget.selectedModelIndex]
                      : '',
                  color: Colors.teal,
                  onTap: _showModelPanel,
                ),
              ),
              _SettingsChip(
                icon: Icons.build_outlined,
                label: '工具',
                color: toolColor,
                onTap: _showToolsPanel,
                badgeCount: toolBadgeCount,
              ),
              _SettingsChip(
                icon: Icons.psychology_outlined,
                label: reasoningLabel,
                color: reasoningColor,
                onTap: _showReasoningPanel,
                enabled: true,
              ),
              // Custom reasoning params button — always visible regardless
              // of whether custom params are configured. When no
              // non-toggle/non-effort params exist, the button opens
              // a panel that explains "当前模型未配置自定义推理参数".
              _SettingsChip(
                icon: Icons.tune,
                label: '自定义参数',
                color: customParamsColor,
                onTap: _showCustomParamsPanel,
                enabled: true,
                badgeCount: customParamsBadgeCountOrNull,
              ),
            ],
          );
        },
      ),
    );
  }

  /// ── Edit mode capsule ──
  Widget _buildEditModeCapsule({required ColorScheme cs}) {
    return Padding(
      padding: const EdgeInsets.only(
        left: 12,
        right: 12,
        top: 6,
        bottom: 0,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: cs.primary.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 4,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.edit,
              size: 14,
              color: cs.primary,
            ),
            const SizedBox(width: 6),
            Text(
              '编辑消息',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: cs.primary,
              ),
            ),
            const SizedBox(width: 24),
            GestureDetector(
              onTap: widget.onEditCancel,
              // Add padding around the close icon for a larger
              // touch target on mobile.
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.close,
                  size: 16,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ── Quick-edit processing banner ──
  /// Shown above the input row while an edited image is still being
  /// processed in the background; sending is blocked until it finishes.
  Widget _buildProcessingBanner({required ColorScheme cs}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: cs.primary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '图片处理中，完成后可发送',
              style: TextStyle(fontSize: 12, color: cs.onPrimaryContainer),
            ),
          ),
        ],
      ),
    );
  }

  /// ── Input row ──
  Widget _buildInputRow({
    required ColorScheme cs,
    required bool isStreaming,
    required bool hasText,
    required bool hasAttachments,
  }) {
    return Padding(
      padding: EdgeInsets.only(
        left: 4,
        right: 4,
        top: 4,
        bottom: 8 + MediaQuery.of(context).padding.bottom,
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.attach_file_outlined,
              color: cs.onSurfaceVariant,
            ),
            tooltip: '附件',
            onPressed: _showAttachmentPicker,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: TextField(
              controller: _textController,
              focusNode: _focusNode,
              textInputAction: _isMobile(context)
                  ? TextInputAction.newline
                  : TextInputAction.send,
              onSubmitted: null,
              onChanged: _onTextChanged,
              minLines: 1,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: '输入消息...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: cs.surfaceContainerHigh.withValues(alpha: 0.8),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    Icons.fullscreen,
                    size: 20,
                    color: cs.onSurfaceVariant,
                  ),
                  tooltip: '全屏编辑',
                  onPressed: _showComposerFullscreenEditor,
                ),
                suffixIconConstraints: const BoxConstraints(
                  minWidth: 36,
                  minHeight: 0,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          if (isStreaming)
            IconButton(
              icon: Icon(
                Icons.stop_circle_outlined,
                color: Colors.red[400],
              ),
              tooltip: '停止生成',
              onPressed: widget.onStop,
            )
          else
            IconButton(
              icon: _editsInFlight > 0
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.send_rounded, color: cs.primary),
              tooltip: '发送',
              onPressed: (hasText || hasAttachments) && _editsInFlight == 0
                  ? () => _handleSubmitted(_textController.text)
                  : null,
            ),
        ],
      ),
    );
  }
}
