import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/batch_rename_config.dart';

/// User-named recipes only: never persist a selection or per-file override.
class BatchRenamePresets {
  static const storageKey = 'batch_rename_presets_v1';
  static Future<void> _writes = Future.value();

  Future<void> _mutate(Future<void> Function() action) {
    final result = _writes.then((_) => action());
    _writes = result.catchError((Object _) {});
    return result;
  }

  Future<Map<String, BatchRenameConfig>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final result = <String, BatchRenameConfig>{};
    for (final raw in prefs.getStringList(storageKey) ?? <String>[]) {
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        result[json['name'] as String] =
            BatchRenameConfig.fromJson(json['config'] as Map<String, dynamic>);
      } catch (_) {/* One damaged recipe must not prevent access to others. */}
    }
    return result;
  }

  Future<void> save(String name, BatchRenameConfig config) => _mutate(() async {
        name = name.trim();
        if (name.isEmpty || name.length > 60)
          throw const FormatException('方案名称应为 1–60 个字符');
        final presets = await load();
        if (presets.length >= 50 && !presets.containsKey(name))
          throw const FormatException('最多保存 50 个方案');
        presets[name] = config;
        await _write(presets);
      });

  Future<void> delete(String name) => _mutate(() async {
        final presets = await load();
        presets.remove(name);
        await _write(presets);
      });

  Future<void> _write(Map<String, BatchRenameConfig> presets) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setStringList(storageKey, [
      for (final e in presets.entries)
        jsonEncode({'name': e.key, 'config': e.value.toJson()}),
    ])) throw StateError('保存方案失败');
  }
}
