part of 'assistant_selection_page.dart';

/// Shows a combined dialog to edit both basic info and model settings
/// of an assistant. Used from both [AssistantSelectionPage] and
/// [TopicSelectionPage].
void showAssistantFullEditDialog(
  BuildContext context,
  WidgetRef ref,
  Assistant assistant,
) {
  final nameController = TextEditingController(text: assistant.name);
  final promptController = TextEditingController(text: assistant.prompt);
  String selectedEmoji = assistant.emoji;
  final descriptionController = TextEditingController(
    text: assistant.description,
  );

  // Settings state, owned by [_EditDialogVars] so the "参数设置" tab can be
  // built by [_buildEditParamsTab] (kept in a separate part file).
  final vars = _EditDialogVars(
    temperature: assistant.settings.temperature,
    enableTemperature: assistant.settings.enableTemperature,
    topP: assistant.settings.topP,
    enableTopP: assistant.settings.enableTopP,
    maxTokens: assistant.settings.maxTokens,
    enableMaxTokens: assistant.settings.enableMaxTokens,
    maxToolCalls: assistant.settings.maxToolCalls,
    enableMaxToolCalls: assistant.settings.enableMaxToolCalls,
    maxToolOutputChars: assistant.settings.maxToolOutputChars,
    enableMaxToolOutputChars: assistant.settings.enableMaxToolOutputChars,
    streamOutput: assistant.settings.streamOutput,
    enableWebSearch: assistant.settings.enableWebSearch,
    frequencyPenalty: assistant.settings.frequencyPenalty,
    enableFrequencyPenalty: assistant.settings.enableFrequencyPenalty,
    presencePenalty: assistant.settings.presencePenalty,
    enablePresencePenalty: assistant.settings.enablePresencePenalty,
    seed: assistant.settings.seed,
    enableSeed: assistant.settings.enableSeed,
    customParameters: List.from(assistant.settings.customParameters),
    defaultModelName: assistant.defaultModelName,
    defaultModelId: assistant.defaultModelId,
    defaultProviderName: assistant.defaultProviderName,
    // null = 从未配置（保持三态语义：新话题自动启用全部工具）。
    defaultToolNames: assistant.defaultToolNames == null
        ? null
        : Set<String>.from(assistant.defaultToolNames!),
  );
  final seedController =
      TextEditingController(text: vars.seed?.toString() ?? '');

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDlgState) => AlertDialog(
        title: const Text('编辑助手'),
        content: SizedBox(
          width: double.maxFinite,
          child: DefaultTabController(
            length: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Tab bar — scrollable + centered so the tab group is
                // centered (not left-aligned) and the label-sized indicator
                // stays aligned with the selected tab's label.
                TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.center,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 24),
                  indicatorSize: TabBarIndicatorSize.label,
                  tabs: const [
                    Tab(text: '基本设置'),
                    Tab(text: '参数设置'),
                    Tab(text: '默认设置'),
                  ],
                ),
                // Tab content area - expands to fill remaining space
                Expanded(
                  child: TabBarView(
                    children: [
                      // ============ Tab 1: 基本设置 ============
                      SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 12),
                            // Emoji picker (only emoji avatar supported)
                            CategorizedEmojiPicker(
                              selectedEmoji: selectedEmoji,
                              onEmojiSelected: (e) =>
                                  setDlgState(() => selectedEmoji = e),
                            ),
                            const SizedBox(height: 12),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: TextField(
                                controller: nameController,
                                decoration: const InputDecoration(
                                  labelText: '助手名称',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: TextField(
                                controller: descriptionController,
                                decoration: const InputDecoration(
                                  labelText: '描述（可选）',
                                  border: OutlineInputBorder(),
                                ),
                                maxLines: 2,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: TextField(
                                controller: promptController,
                                decoration: const InputDecoration(
                                  labelText: '系统提示词',
                                  border: OutlineInputBorder(),
                                ),
                                maxLines: 4,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),

                      // ============ Tab 2: 参数设置 ============
                      _buildEditParamsTab(
                        context: context,
                        setDlgState: setDlgState,
                        vars: vars,
                        seedController: seedController,
                      ),

                      // ============ Tab 3: 默认设置 ============
                      AssistantDefaultsTab(
                        defaultModelName: vars.defaultModelName,
                        defaultModelId: vars.defaultModelId,
                        defaultProviderName: vars.defaultProviderName,
                        defaultToolNames: vars.defaultToolNames,
                        maxToolOutputChars: vars.maxToolOutputChars,
                        enableMaxToolOutputChars:
                            vars.enableMaxToolOutputChars,
                        onDefaultModelChanged: (model) => setDlgState(() {
                          // 记录显示名 + 绝对身份（模型ID + 供应商名），
                          // 重命名后默认模型仍可解析。
                          vars.defaultModelName = model?.displayName;
                          vars.defaultModelId = model?.modelId;
                          vars.defaultProviderName = model?.providerName;
                          vars.defaultsModelEngaged = true;
                        }),
                        onDefaultToolsChanged: (next) => setDlgState(() {
                          // null = 恢复"未配置"（新话题重新自动启用全部工具）。
                          vars.defaultToolNames =
                              next == null ? null : Set<String>.from(next);
                          vars.defaultsToolsEngaged = true;
                        }),
                        onEnableMaxToolOutputCharsChanged: (v) =>
                            setDlgState(
                                () => vars.enableMaxToolOutputChars = v),
                        onMaxToolOutputCharsChanged: (v) =>
                            setDlgState(() => vars.maxToolOutputChars = v),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) return;

              // Update basic info
              ref.read(assistantProvider.notifier).updateAssistant(
                    id: assistant.id,
                    name: name,
                    prompt: promptController.text.trim(),
                    emoji: selectedEmoji,
                    description: descriptionController.text.trim(),
                  );

              // Update settings
              ref.read(assistantProvider.notifier).updateAssistantSettings(
                    assistantId: assistant.id,
                    temperature: vars.temperature,
                    enableTemperature: vars.enableTemperature,
                    topP: vars.topP,
                    enableTopP: vars.enableTopP,
                    maxTokens: vars.maxTokens,
                    enableMaxTokens: vars.enableMaxTokens,
                    maxToolCalls: vars.maxToolCalls,
                    enableMaxToolCalls: vars.enableMaxToolCalls,
                    maxToolOutputChars: vars.maxToolOutputChars,
                    enableMaxToolOutputChars: vars.enableMaxToolOutputChars,
                    streamOutput: vars.streamOutput,
                    enableWebSearch: vars.enableWebSearch,
                    frequencyPenalty: vars.frequencyPenalty,
                    enableFrequencyPenalty: vars.enableFrequencyPenalty,
                    presencePenalty: vars.presencePenalty,
                    enablePresencePenalty: vars.enablePresencePenalty,
                    seed: vars.seed,
                    enableSeed: vars.enableSeed,
                    customParameters: vars.customParameters,
                  );

              // Update conversation defaults (default model + default tools).
              // Only parts the user actually engaged in the 默认设置 tab are
              // written back: a save that never touched that tab (e.g. a
              // rename) must not silently convert an unconfigured assistant
              // into "configured-empty" (which would switch new topics from
              // auto-enable-all to all-tools-OFF).
              //
              // 记录的默认模型已失效（从供应商配置中删除）时，保存自动清空：
              // 与 tab 的"暂不设置"退化显示保持一致，避免同名模型
              // 重新添加后旧的默认值悄悄复活。
              final adapter = ref.read(chatStreamManagerProvider).adapter;
              final availableModels =
                  adapter.availableModels(ref.read(providerEntriesProvider));
              final defaultRef = resolveModelRef(
                models: availableModels,
                modelId: assistant.defaultModelId,
                providerName: assistant.defaultProviderName,
                displayName: assistant.defaultModelName,
              );
              final modelStale = (assistant.defaultModelName != null ||
                      assistant.defaultModelId != null) &&
                  defaultRef == null;
              ref.read(assistantProvider.notifier).updateAssistantDefaults(
                    id: assistant.id,
                    defaultModelName: vars.defaultsModelEngaged
                        ? vars.defaultModelName
                        : modelStale
                            ? null
                            : assistant.defaultModelName,
                    defaultModelId: vars.defaultsModelEngaged
                        ? vars.defaultModelId
                        : modelStale
                            ? null
                            : assistant.defaultModelId,
                    defaultProviderName: vars.defaultsModelEngaged
                        ? vars.defaultProviderName
                        : modelStale
                            ? null
                            : assistant.defaultProviderName,
                    // 默认工具集合：仅在用户改过（engaged）时写入；
                    // 从未配置的助手保持 null（新话题自动启用全部工具）。
                    // "恢复未配置"入口（clearDefaultToolNames）已随
                    // 取消配置按钮移除，UI 不再产生 null 回调。
                    defaultToolNames: vars.defaultsToolsEngaged
                        ? vars.defaultToolNames
                        : assistant.defaultToolNames,
                  );

              Navigator.pop(ctx);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    ),
  );
}
