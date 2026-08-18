import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/providers/context_management_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('上下文管理设置 - 默认值', () {
    test('总开关开启、全局 95%、无模型独立设置', () {
      const settings = ContextManagementSettings();
      expect(settings.pruneEnabled, isTrue);
      expect(settings.compactionEnabled, isTrue);
      expect(settings.globalCompactionPercent, kDefaultCompactionPercent);
      expect(settings.globalCompactionPercent, 95);
      expect(settings.perModelCompaction, isEmpty);
    });
  });

  group('ContextManagementSettingsNotifier - 总开关与全局百分比', () {
    test('setCompactionEnabled 切换总开关', () async {
      final notifier = ContextManagementSettingsNotifier();
      expect(notifier.state.compactionEnabled, isTrue);
      await notifier.setCompactionEnabled(false);
      expect(notifier.state.compactionEnabled, isFalse);
      await notifier.setCompactionEnabled(true);
      expect(notifier.state.compactionEnabled, isTrue);
    });

    test('setGlobalCompactionPercent 写入并持久化', () async {
      final notifier = ContextManagementSettingsNotifier();
      await notifier.setGlobalCompactionPercent(80);
      expect(notifier.state.globalCompactionPercent, 80);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('context_compaction_global_percent'), 80);
    });

    test('百分比越界被钳制到 1–100', () async {
      final notifier = ContextManagementSettingsNotifier();
      await notifier.setGlobalCompactionPercent(0);
      expect(notifier.state.globalCompactionPercent, 1);
      await notifier.setGlobalCompactionPercent(150);
      expect(notifier.state.globalCompactionPercent, 100);
    });

    test('resetGlobalCompactionPercent 一键重置回 95', () async {
      final notifier = ContextManagementSettingsNotifier();
      await notifier.setGlobalCompactionPercent(60);
      await notifier.resetGlobalCompactionPercent();
      expect(notifier.state.globalCompactionPercent, kDefaultCompactionPercent);
      expect(notifier.state.globalCompactionPercent, 95);
    });
  });

  group('ContextManagementSettingsNotifier - 模型独立设置', () {
    test('setPerModelEnabled：关闭保留已填值，重新开启值恢复', () async {
      final notifier = ContextManagementSettingsNotifier();
      final key = compactionModelKey(modelId: 'm1');
      await notifier.setPerModelEnabled(key, true);
      await notifier.setPerModelThreshold(key, 48000);
      await notifier.setPerModelEnabled(key, false);
      final config = notifier.state.perModelCompaction[key];
      expect(config?.enabled, isFalse);
      expect(config?.threshold, 48000, reason: '关闭后保留已填写的值');
      await notifier.setPerModelEnabled(key, true);
      expect(notifier.state.perModelCompaction[key]?.enabled, isTrue);
      expect(notifier.state.perModelCompaction[key]?.threshold, 48000,
          reason: '重新开启后独立值恢复生效');
    });

    test('setPerModelThreshold 接受 >=1000 的值', () async {
      final notifier = ContextManagementSettingsNotifier();
      final key = compactionModelKey(modelId: 'm1');
      await notifier.setPerModelEnabled(key, true);
      await notifier.setPerModelThreshold(key, 48000);
      expect(notifier.state.perModelCompaction[key]?.threshold, 48000);
      expect(notifier.state.perModelCompaction[key]?.enabled, isTrue);
    });

    test('setPerModelThreshold 清空/无效值 → 值置空但保留开关状态', () async {
      final notifier = ContextManagementSettingsNotifier();
      final key = compactionModelKey(modelId: 'm1');
      await notifier.setPerModelEnabled(key, true);
      await notifier.setPerModelThreshold(key, 48000);
      // 无效值（<1000）→ 值置空，开关保留
      await notifier.setPerModelThreshold(key, 999);
      expect(notifier.state.perModelCompaction[key]?.enabled, isTrue);
      expect(notifier.state.perModelCompaction[key]?.threshold, isNull);
      // 再填有效值 → 生效
      await notifier.setPerModelThreshold(key, 48000);
      expect(notifier.state.perModelCompaction[key]?.threshold, 48000);
      // 清空（null）→ 值置空，开关保留
      await notifier.setPerModelThreshold(key, null);
      expect(notifier.state.perModelCompaction[key]?.enabled, isTrue);
      expect(notifier.state.perModelCompaction[key]?.threshold, isNull);
      // 关闭独立设置由 setPerModelEnabled 负责
      await notifier.setPerModelEnabled(key, false);
      expect(notifier.state.perModelCompaction[key]?.enabled, isFalse);
    });

    test('setPerModelThreshold 对从未配置的模型清空 → 无操作', () async {
      final notifier = ContextManagementSettingsNotifier();
      final key = compactionModelKey(modelId: 'm1');
      await notifier.setPerModelThreshold(key, null);
      expect(notifier.state.perModelCompaction.containsKey(key), isFalse);
    });

    test('per-model 设置持久化往返', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      container.read(contextManagementSettingsProvider);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final notifier =
          container.read(contextManagementSettingsProvider.notifier);
      final key = compactionModelKey(modelId: 'model-a', providerName: 'P');
      await notifier.setPerModelEnabled(key, true);
      await notifier.setPerModelThreshold(key, 20000);
      await notifier.setGlobalCompactionPercent(90);
      await notifier.setCompactionEnabled(false);
      container.dispose();

      final container2 = ProviderContainer();
      container2.read(contextManagementSettingsProvider);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final reloaded = container2.read(contextManagementSettingsProvider);
      expect(reloaded.compactionEnabled, isFalse);
      expect(reloaded.globalCompactionPercent, 90);
      expect(reloaded.perModelCompaction[key]?.enabled, isTrue);
      expect(reloaded.perModelCompaction[key]?.threshold, 20000);
      container2.dispose();
    });
  });

  group('旧版自定义压缩触发值迁移', () {
    test('旧 key 被清理，新格式使用默认值', () async {
      SharedPreferences.setMockInitialValues({
        'context_compaction_threshold_enabled': true,
        'context_compaction_threshold': 48000,
      });
      final container = ProviderContainer();
      container.read(contextManagementSettingsProvider);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final settings = container.read(contextManagementSettingsProvider);
      expect(settings.compactionEnabled, isTrue);
      expect(settings.globalCompactionPercent, kDefaultCompactionPercent);
      expect(settings.perModelCompaction, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.containsKey('context_compaction_threshold_enabled'),
        isFalse,
        reason: '旧版自定义触发值 key 应被清理',
      );
      expect(
        prefs.containsKey('context_compaction_threshold'),
        isFalse,
        reason: '旧版自定义触发值 key 应被清理',
      );
      container.dispose();
    });
  });

  group('ContextManagementSettings - effectiveCompactionThreshold', () {
    test('默认：全局 95% × 模型上下文', () {
      const settings = ContextManagementSettings();
      expect(settings.effectiveCompactionThreshold(10000), 9500);
      expect(settings.effectiveCompactionThreshold(128000), 121600);
    });

    test('自定义全局百分比生效', () {
      const settings = ContextManagementSettings(globalCompactionPercent: 50);
      expect(settings.effectiveCompactionThreshold(100000), 50000);
    });

    test('模型独立触发值优先（按模型 key）', () {
      const settings = ContextManagementSettings(
        perModelCompaction: {
          'm1': PerModelCompactionConfig(enabled: true, threshold: 48000),
        },
      );
      expect(
          settings.effectiveCompactionThreshold(128000, modelKey: 'm1'), 48000);
      // 其它模型跟随全局百分比
      expect(
        settings.effectiveCompactionThreshold(128000, modelKey: 'other'),
        121600,
      );
    });

    test('不同供应商的同名 modelId 是独立的配置（复合 key）', () {
      const settings = ContextManagementSettings(
        perModelCompaction: {
          'ProviderA\u0000gpt-4o':
              PerModelCompactionConfig(enabled: true, threshold: 48000),
          'ProviderB\u0000gpt-4o':
              PerModelCompactionConfig(enabled: true, threshold: 8000),
        },
      );
      expect(
        settings.effectiveCompactionThreshold(
          128000,
          modelKey:
              compactionModelKey(modelId: 'gpt-4o', providerName: 'ProviderA'),
        ),
        48000,
      );
      expect(
        settings.effectiveCompactionThreshold(
          128000,
          modelKey:
              compactionModelKey(modelId: 'gpt-4o', providerName: 'ProviderB'),
        ),
        8000,
      );
    });

    test('模型开启但未填写值 → 跟随全局百分比', () {
      const settings = ContextManagementSettings(
        perModelCompaction: {
          'm1': PerModelCompactionConfig(enabled: true, threshold: null),
        },
      );
      expect(
        settings.effectiveCompactionThreshold(128000, modelKey: 'm1'),
        121600,
      );
    });

    test('模型开关关闭 → 跟随全局百分比（即使有独立值）', () {
      const settings = ContextManagementSettings(
        perModelCompaction: {
          'm1': PerModelCompactionConfig(enabled: false, threshold: 48000),
        },
      );
      expect(
        settings.effectiveCompactionThreshold(128000, modelKey: 'm1'),
        121600,
      );
    });

    test('模型独立值超过模型窗口 → 钳制到窗口', () {
      const settings = ContextManagementSettings(
        perModelCompaction: {
          'm1': PerModelCompactionConfig(enabled: true, threshold: 100000),
        },
      );
      expect(
          settings.effectiveCompactionThreshold(32000, modelKey: 'm1'), 32000);
    });

    test('总开关关闭 → null（不触发压缩）', () {
      const settings = ContextManagementSettings(compactionEnabled: false);
      expect(settings.effectiveCompactionThreshold(128000), isNull);
      expect(settings.effectiveCompactionThreshold(128000, modelKey: 'm1'),
          isNull);
    });

    test('模型无上下文配置 → null', () {
      const settings = ContextManagementSettings();
      expect(settings.effectiveCompactionThreshold(null), isNull);
      expect(settings.effectiveCompactionThreshold(0), isNull);
    });
  });
}
