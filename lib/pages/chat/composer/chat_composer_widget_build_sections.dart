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
          return _PendingAttachmentDragStartListener(
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
    // has a non-empty name AND a non-empty value has been selected: show that
    // value (e.g. "high", "low"). Otherwise: show "推理" (purple when enabled,
    // grey when disabled). 运行时状态以已选值为准，不检查配置的 enabled 标记。
    final String reasoningLabel;
    if (reasoningEnabled &&
        reasoningEffortEnabled &&
        effortParam != null &&
        effortParam.paramName.trim().isNotEmpty &&
        // 仅参数名（无选项值、非布尔）的力度参数不可用：即使 map 中
        // 残留旧值也不显示（面板开关同样不可用，二者保持一致）。
        effortParam.isUsable &&
        (reasoningParamValues[effortParam.paramName]?.isNotEmpty ?? false)) {
      reasoningLabel = reasoningParamValues[effortParam.paramName]!;
    } else {
      reasoningLabel = '推理';
    }
    // Reasoning chip color: purple only when reasoning is actually usable
    // (a model with configured reasoning params AND the toggle on).
    // 无任何可用推理参数（仅参数名/无选项值/非布尔）时与面板一致：
    // 灰色不可用，开关即使残留开启状态也不显示为可用。
    final hasReasoningParams = widget.reasoningParams.any((p) => p.isUsable);
    final reasoningColor =
        (reasoningEnabled && hasReasoningParams) ? Colors.purple : Colors.grey;

    // ═══════════════════════════════════════════════════════════
    // Tool chip: accent color (indigo) when tools enabled, grey when disabled
    // ═══════════════════════════════════════════════════════════
    const Color toolAccentColor = Color(0xFF6366F1);
    // 徽标只统计当前可选择（显示）的工具：MCP 总开关关闭时，
    // 已启用但被隐藏的 MCP 工具不计入（运行时启用集保留保存的偏好，这里
    // 仅做展示层过滤，避免把隐藏的工具从对话偏好中抹掉）。
    final visibleEnabledTools = pruneUnselectableToolNames(
      enabledNames: widget.enabledTools,
      selectableTools: widget.mcpTools,
    );
    final bool noToolsEnabled = visibleEnabledTools.isEmpty;
    final Color toolColor = noToolsEnabled ? Colors.grey : toolAccentColor;
    final int? toolBadgeCount =
        noToolsEnabled ? null : visibleEnabledTools.length;

    // ═══════════════════════════════════════════════════════════
    // Custom params chip: independent color state driven by the session.
    // A custom param (non-toggle, non-effort) counts as ACTIVE when its
    // name is non-empty and a value has been selected for it — and
    // reasoning is on (matching what the request actually sends). The
    // selected-value map is the runtime on/off state (the panel writes/
    // removes values on switch toggle), so param.enabled is not consulted
    // here. The chip shows the accent color + badge with the active count;
    // otherwise grey with no badge.
    // ═══════════════════════════════════════════════════════════
    final int activeCustomParamsCount = reasoningEnabled
        ? widget.reasoningParams
            .where(
              (p) =>
                  p != effortParam &&
                  !p.isReasoningToggle &&
                  !p.isEffortParam &&
                  p.paramName.trim().isNotEmpty &&
                  // 不可用参数（仅参数名、无选项值、非布尔）不计入：
                  // 面板无开关可选，残留值不会被请求发送。
                  p.isUsable &&
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
              // a panel that explains "当前模型未配置自定义参数".
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
  /// Centered in its row (same position as the warning pill it replaces)
  /// and fades in when it returns after the warning is dismissed.
  Widget _buildEditModeCapsule({required ColorScheme cs}) {
    return Padding(
      padding: const EdgeInsets.only(
        left: 12,
        right: 12,
        top: 6,
        bottom: 0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: ChatComposerWidgetState._editWarningFadeOutDuration,
            builder: (context, value, child) =>
                Opacity(opacity: value, child: child),
            child: Container(
              key: const Key('editModeCapsule'),
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
                    size: 16,
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
                  const SizedBox(width: 6),
                  Tooltip(
                    message: '关闭',
                    child: GestureDetector(
                      onTap: widget.onEditCancel,
                      // Small padding around the close icon for a slightly
                      // larger touch target on mobile, kept subtle so the
                      // right side does not read as a button next to the
                      // bare left icon.
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Icon(
                          Icons.close,
                          size: 16,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ── Edit data-loss warning pill ──
  /// Replaces the edit capsule in its row while visible: re-sending the
  /// edit deletes this message and everything below it. Shown immediately
  /// on edit entry when the warning is armed, centered in the capsule's
  /// row, fading in on entry. Dismissed by the auto-hide countdown or the
  /// close button — both set [fadingOut], which fades the pill out first;
  /// the edit capsule fades back in once the pill is removed.
  Widget _buildEditWarningPill({
    required ColorScheme cs,
    required bool fadingOut,
  }) {
    return Padding(
      padding: const EdgeInsets.only(
        left: 12,
        right: 12,
        top: 6,
        bottom: 0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // While fading out the pill must not receive taps (or hover
          // tooltips) at partial/zero opacity.
          IgnorePointer(
            ignoring: fadingOut,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: fadingOut ? 1 : 0, end: fadingOut ? 0 : 1),
              duration: fadingOut
                  ? ChatComposerWidgetState._editWarningFadeOutDuration
                  : ChatComposerWidgetState._editWarningFadeInDuration,
              builder: (context, value, child) =>
                  Opacity(opacity: value, child: child),
              child: Container(
                key: const Key('editWarningPill'),
                decoration: BoxDecoration(
                  color: cs.errorContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: cs.error.withValues(alpha: 0.3),
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
                      Icons.warning_amber_rounded,
                      size: 16,
                      color: cs.error,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '重新编辑发送后下面所有的消息将丢失',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: cs.onErrorContainer,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Tooltip(
                      message: '关闭',
                      child: GestureDetector(
                        onTap: _dismissEditWarning,
                        // Small padding around the close icon (see the
                        // capsule's comment).
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: Icon(
                            Icons.close,
                            key: const Key('editWarningCloseButton'),
                            size: 16,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
              // Part of the chat-composer tap region group: taps on the
              // message list (grouped via [TextFieldTapRegion] on the page)
              // are treated as inside the input, so they do not blur the
              // composer while the user reads/scrolls the list.
              groupId: chatComposerTapRegionGroupId,
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
              icon: Icon(Icons.send_rounded, color: cs.primary),
              tooltip: '发送',
              onPressed: (hasText || hasAttachments)
                  ? () => _handleSubmitted(_textController.text)
                  : null,
            ),
        ],
      ),
    );
  }
}

/// 待发附件芯片的拖拽启动监听器：长按 [kDragSortDelay]（280ms）即开始
/// 拖拽。
///
/// Flutter 自带的 [ReorderableDelayedDragStartListener] 固定使用
/// kLongPressTimeout（500ms），长按体感偏慢且与全应用其余拖拽排序的
/// 手感不一致（DragSortArea 胶囊/行/网格 280ms、OCR 页 300ms）——发送顺序
/// 对 API 请求有意义，用户需要能快速重排附件，因此改用全应用统一的
/// 短延迟。
class _PendingAttachmentDragStartListener
    extends ReorderableDelayedDragStartListener {
  const _PendingAttachmentDragStartListener({
    super.key,
    required super.index,
    required super.child,
  });

  @override
  MultiDragGestureRecognizer createRecognizer() {
    return DelayedMultiDragGestureRecognizer(
      debugOwner: this,
      delay: kDragSortDelay,
    );
  }
}
