import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 排序字段
enum SortField {
  createdAt,
  name,
  size,
}

/// 排序方向
enum SortOrder {
  ascending,
  descending,
}

/// 排序配置
class SortConfig {
  final SortField field;
  final SortOrder order;

  const SortConfig({
    this.field = SortField.createdAt,
    this.order = SortOrder.descending,
  });

  SortConfig copyWith({SortField? field, SortOrder? order}) {
    return SortConfig(
      field: field ?? this.field,
      order: order ?? this.order,
    );
  }

  /// 切换排序字段，相同字段则反转方向
  SortConfig toggle(SortField newField) {
    if (field == newField) {
      return SortConfig(
        field: field,
        order: order == SortOrder.descending
            ? SortOrder.ascending
            : SortOrder.descending,
      );
    }
    return SortConfig(field: newField, order: SortOrder.descending);
  }

  Map<String, dynamic> toJson() => {
        'field': field.name,
        'order': order.name,
      };

  factory SortConfig.fromJson(Map<String, dynamic> json) => SortConfig(
        field: SortField.values.firstWhere(
          (e) => e.name == json['field'],
          orElse: () => SortField.createdAt,
        ),
        order: SortOrder.values.firstWhere(
          (e) => e.name == json['order'],
          orElse: () => SortOrder.descending,
        ),
      );

  /// 排序标签（用于显示）
  String get label {
    if (field == SortField.createdAt) {
      return order == SortOrder.descending ? '最新在前' : '最旧在前';
    }
    final fieldName = switch (field) {
      SortField.createdAt => '时间',
      SortField.name => '文件名',
      SortField.size => '大小',
    };
    final orderName = order == SortOrder.descending ? '大到小' : '小到大';
    return '$fieldName（$orderName）';
  }
}

/// 持久化的排序配置提供器
class SortConfigNotifier extends StateNotifier<SortConfig> {
  final String _storageKey;

  SortConfigNotifier(this._storageKey) : super(const SortConfig());

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_storageKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final map = Map<String, dynamic>.from(jsonDecode(jsonStr) as Map);
        state = SortConfig.fromJson(map);
      }
    } catch (_) {}
  }

  Future<void> save(SortConfig config) async {
    state = config;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(config.toJson()));
    } catch (_) {}
  }

  Future<void> toggle(SortField field) async {
    await save(state.toggle(field));
  }
}

// ============================================================================
// Provider 工厂
// ============================================================================

/// 录音页排序（storage key: 'audio_sort_config'）
final audioSortConfigProvider =
    StateNotifierProvider<SortConfigNotifier, SortConfig>((ref) {
  final notifier = SortConfigNotifier('audio_sort_config');
  notifier.load();
  return notifier;
});

/// 相册页排序（storage key: 'image_sort_config'）
final imageSortConfigProvider =
    StateNotifierProvider<SortConfigNotifier, SortConfig>((ref) {
  final notifier = SortConfigNotifier('image_sort_config');
  notifier.load();
  return notifier;
});

/// 视频页排序（storage key: 'video_sort_config'）
final videoSortConfigProvider =
    StateNotifierProvider<SortConfigNotifier, SortConfig>((ref) {
  final notifier = SortConfigNotifier('video_sort_config');
  notifier.load();
  return notifier;
});

/// 文本页排序（storage key: 'text_sort_config'）
final textSortConfigProvider =
    StateNotifierProvider<SortConfigNotifier, SortConfig>((ref) {
  final notifier = SortConfigNotifier('text_sort_config');
  notifier.load();
  return notifier;
});
