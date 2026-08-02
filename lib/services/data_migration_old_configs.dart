part of 'data_migration_service.dart';

// ====================================================================
// 旧配置迁移（v0→v1 相关，从 DataMigrationService 拆出控制行数）
// ====================================================================

/// 旧 chat_configs 迁移辅助（同库可见，外部仍通过
/// DataMigrationService 的私有静态委托调用）。
class DataMigrationOldConfigs {
  /// 迁移旧版 chat_configs（被重构删除的格式）到 provider_entries。
  static Future<void> migrateOldChatConfigs(SharedPreferences prefs) async {
    final oldJson = prefs.getString('chat_configs');
    if (oldJson == null || oldJson.isEmpty) return;

    try {
      // 兜底：使用 whereType 安全过滤非 Map 条目
      final oldList = (jsonDecode(oldJson) as List?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          [];
      if (oldList.isEmpty) return;

      final migratedConfigs = <Map<String, dynamic>>[];
      for (final oldItem in oldList) {
        // 兜底：安全过滤 models 中的非 Map 条目
        final oldModels = (oldItem['models'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .toList() ??
            [];

        final models = oldModels.map((m) {
          final typeConfig = <String, dynamic>{};
          final temperature = m['temperature'];
          if (temperature != null) typeConfig['temperature'] = temperature;
          // 恢复 v0→v1 的 per-model context 迁移（origin/main 原有，
          // 重构时被误删）：旧数据把 context/maxTokens 挂在 model 上。
          // 不迁移则老用户的压缩功能读取 typeConfig['context'] 为 null
          // → effectiveCompactionThreshold 返回 null → 自动压缩静默失效。
          final context = m['maxTokens'] ?? m['context'];
          if (context != null) typeConfig['context'] = context;

          return <String, dynamic>{
            'name': m['modelId'] as String? ?? '',
            'modelId': m['modelId'] as String? ?? '',
            'supportStream': m['supportStream'] as bool? ?? true,
            'typeConfig': typeConfig,
          };
        }).toList();

        migratedConfigs.add(<String, dynamic>{
          'providerName': oldItem['providerName'] as String? ?? '',
          'host': oldItem['host'] as String? ?? '',
          'key': oldItem['key'] as String? ?? '',
          'models': models,
        });
      }

      if (migratedConfigs.isEmpty) return;

      // 读取或初始化当前 provider_entries
      String? existingJson;
      try {
        existingJson = prefs.getString('provider_entries');
      } catch (_) {}

      List<Map<String, dynamic>> existingEntries = [];
      if (existingJson != null && existingJson.isNotEmpty) {
        try {
          // 兜底：使用 whereType 安全过滤非 Map 条目
          existingEntries = (jsonDecode(existingJson) as List)
              .whereType<Map<String, dynamic>>()
              .toList();
        } catch (_) {
          // 现有数据损坏，忽略并用空列表重新开始
        }
      }

      // 如果已有 llm 类型条目则不覆盖
      final hasLlmEntry = existingEntries
          .any((e) => e['type'] == 'llm' && e['id'] != 'builtin_llm');
      if (!hasLlmEntry) {
        existingEntries.add({
          'id': 'migrated_llm',
          'type': 'llm',
          'name': 'LLM供应商',
          'configs': migratedConfigs,
        });

        await prefs.setString('provider_entries', jsonEncode(existingEntries));
        debugPrint(
            '[DataMigrationService] Migrated ${oldList.length} old chat config(s) to provider_entries');
      }

      // 删除旧数据，防止 provider 级别重复迁移
      await prefs.remove('chat_configs');
      await prefs.remove('chat_selected_config_id');
    } catch (e) {
      debugPrint(
          '[DataMigrationService] Failed to migrate old chat configs: $e');
    }
  }

  /// 修复 provider_entries 中所有条目的 id 字段不为空。
  ///
  /// 旧版数据中某些条目的 id 可能为 null，导致 ProviderEntry.fromMap()
  /// 在 `map['id'] as String` 处抛出 TypeError，进而引发闪退。
  static Future<void> fixNullIdsInProviderEntries(
      SharedPreferences prefs) async {
    final json = prefs.getString('provider_entries');
    if (json == null || json.isEmpty) return;

    try {
      // 兜底：使用 whereType 安全过滤非 Map 条目
      final list =
          (jsonDecode(json) as List).whereType<Map<String, dynamic>>().toList();
      bool changed = false;

      for (int i = 0; i < list.length; i++) {
        final entry = list[i];
        if (entry['id'] == null || (entry['id'] as String?)?.isEmpty == true) {
          // 为 null id 的条目生成一个唯一 ID
          final type = entry['type'] as String? ?? 'unknown';
          entry['id'] = 'migrated_${type}_$i';
          changed = true;
          debugPrint(
              '[DataMigrationService] Fixed null id for provider entry at index $i (type: $type)');
        }

        // 修复自定义参数中缺少 type 字段的旧格式
        final configs = entry['configs'] as List?;
        if (configs != null) {
          for (final config in configs) {
            // 兜底：跳过非 Map 的 config 条目
            if (config is! Map<String, dynamic>) continue;
            final configMap = config;
            final models = configMap['models'] as List?;
            if (models == null) continue;
            for (final model in models) {
              // 兜底：跳过非 Map 的 model 条目
              if (model is! Map<String, dynamic>) continue;
              final modelMap = model;
              final customParams = modelMap['customParams'] as List?;
              if (customParams == null) continue;
              for (final param in customParams) {
                // 兜底：跳过非 Map 的 param 条目
                if (param is! Map<String, dynamic>) continue;
                final paramMap = param;
                if (paramMap['type'] == null) {
                  paramMap['type'] = 'string';
                  changed = true;
                }
              }
            }
          }
        }

        // 确保每条记录都有 type 字段（旧版可能缺失）
        if (entry['type'] == null ||
            (entry['type'] as String?)?.isEmpty == true) {
          entry['type'] = 'tts';
          changed = true;
          debugPrint(
              '[DataMigrationService] Fixed null type for provider entry at index $i');
        }
      }

      if (changed) {
        await prefs.setString('provider_entries', jsonEncode(list));
        debugPrint(
            '[DataMigrationService] Fixed null IDs/types in provider_entries');
      }
    } catch (e) {
      debugPrint('[DataMigrationService] Failed to fix provider entries: $e');
    }
  }

  /// v1 → v2: 移除共享 folders 表，完全迁移到每个类型独立的文件夹表。
  ///
  /// 迁移步骤：
  /// 1. 检测并迁移旧版共享 folders 表中的数据到 text/audio/image/video_folders
  /// 2. 删除旧版共享 folders 表（SQLite）或 key（JSON/web）
  /// 3. 迁移完成后，只保留每种类型独立的文件夹表
  ///
}
