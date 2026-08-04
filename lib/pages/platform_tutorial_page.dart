import 'package:flutter/material.dart';

/// Configuration for a platform tutorial.
class PlatformTutorialConfig {
  final String platformName;
  final IconData icon;
  final Color color;

  const PlatformTutorialConfig({
    required this.platformName,
    required this.icon,
    required this.color,
  });
}

/// A detail page showing background running tutorial for a specific platform.
class PlatformTutorialPage extends StatelessWidget {
  final PlatformTutorialConfig config;

  const PlatformTutorialPage({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('${config.platformName} 后台运行教程'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeaderCard(theme),
          const SizedBox(height: 16),
          ..._buildTutorialSteps(theme),
          const SizedBox(height: 24),
          _buildTipsCard(theme),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(config.icon, size: 64, color: config.color),
            const SizedBox(height: 12),
            Text(
              '${config.platformName} 后台运行优化指南',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '以下步骤可帮助您在 ${config.platformName} 设备上优化 Stroom 的后台运行体验，'
              '确保任务在后台持续执行。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildTutorialSteps(ThemeData theme) {
    final steps = _getStepsForPlatform(config.platformName);
    return [
      _buildSectionHeader('优化步骤', theme),
      const SizedBox(height: 12),
      ...List.generate(steps.length, (index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: config.color,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          steps[index].title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          steps[index].description,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    ];
  }

  List<_TutorialStep> _getStepsForPlatform(String platform) {
    switch (platform) {
      case 'Android':
        return [
          _TutorialStep(
            title: '关闭电池优化',
            description: '进入「设置」→「应用」→「Stroom」→「电池」→ 选择「无限制」或「不优化」。'
                '也可以直接在本 App 的「后台运行优化」页面点击「忽略电池优化」，'
                '一键加入系统省电白名单。不同品牌手机路径可能略有不同。',
          ),
          _TutorialStep(
            title: '允许后台活动',
            description: '进入「设置」→「应用」→「Stroom」→ 开启「允许后台活动」和「允许自启动」。'
                '部分手机还需在「安全中心」或「手机管家」中允许自启动。',
          ),
          _TutorialStep(
            title: '锁定后台进程',
            description: '在多任务界面（最近任务列表）中，将 Stroom 卡片向下拉或点击锁定图标，'
                '锁定应用使其不被系统清理。',
          ),
          _TutorialStep(
            title: '允许通知权限（Android 13+）',
            description: 'Android 13 及以上系统需要单独授予通知权限，'
                '否则后台服务的前台通知不会显示（服务仍会运行）。'
                '首次点击「启动服务」时 App 会自动请求该权限，'
                '也可以前往「设置」→「应用」→「Stroom」→「通知」手动开启。',
          ),
          _TutorialStep(
            title: '忽略电池优化权限',
            description: '在 Stroom 中开启「任务完成通知」时，App 会自动请求相关权限。'
                '您也可以手动前往「设置」→「应用」→「特殊权限」→「电池优化」中确认 Stroom 已设为「不优化」。',
          ),
          _TutorialStep(
            title: '国产系统自启动与后台管理',
            description: '国产系统通常有自己的后台管理策略，请按品牌操作：'
                '\n• 小米/红米（MIUI/HyperOS）：设置 → 应用设置 → 授权管理 → 自启动管理 → 允许 Stroom 自启动；'
                '「省电与电池」→「应用智能省电」→ Stroom → 无限制。'
                '\n• 华为/荣耀（EMUI/HarmonyOS）：设置 → 应用 → 应用启动管理 → Stroom → 手动管理 → '
                '允许自启动/关联启动/后台活动。'
                '\n• OPPO/一加/真我（ColorOS）：设置 → 电池 → 应用耗电管理 → Stroom → 允许完全后台行为。'
                '\n• vivo/iQOO（OriginOS）：i管家 → 应用管理 → 自启动 → 允许 Stroom。',
          ),
          _TutorialStep(
            title: '关闭锁屏清理与省电模式',
            description: '进入「设置」→「电池」→ 关闭「省电模式」或「超级省电」，'
                '并将「锁屏后清理内存」设为「不清理」。'
                '省电模式会限制后台应用活动，影响任务完成。',
          ),
        ];
      case 'iOS':
        return [
          _TutorialStep(
            title: '开启后台应用刷新',
            description: '进入「设置」→「通用」→「后台应用刷新」→ 找到 Stroom 并开启。'
                '建议选择「无线局域网与蜂窝数据」以获得最佳体验。',
          ),
          _TutorialStep(
            title: '允许通知',
            description: '进入「设置」→「通知」→「Stroom」→ 开启「允许通知」。'
                '确保通知样式设为「横幅」和「通知中心」以便及时获知任务状态。',
          ),
          _TutorialStep(
            title: '关闭低电量模式',
            description: '进入「设置」→「电池」→ 关闭「低电量模式」。'
                '低电量模式下系统会限制后台活动。',
          ),
          _TutorialStep(
            title: '理解 iOS 的后台运行限制',
            description: 'iOS 26 以下系统不允许应用像 Android 那样常驻后台运行。'
                '系统仅在特定时机（如后台 App 刷新、定位、播放音频）给应用少量执行时间，'
                '长时间任务会被系统挂起。建议：'
                '\n• 需要长时间运行的任务保持 Stroom 在前台；'
                '\n• 定期切换回 App 以刷新后台执行时间；'
                '\n• 重要任务配合「任务完成通知」及时获知结果。',
          ),
          _TutorialStep(
            title: '任务运行时的后台注意事项',
            description: 'iOS 26 及以上系统支持任务常驻后台：'
                '任务运行期间切换 App 或锁屏，任务通常会继续执行'
                '（系统资源紧张时可能终止），'
                '锁屏界面会显示任务进度。'
                '\n\niOS 26 以下系统不支持常驻后台：'
                '任务运行时请每隔几分钟返回一次 App（建议 5–10 分钟，'
                '具体由系统决定），刷新后台执行时间，防止任务被挂起。'
                '\n\n所有版本都请勿在 App 切换器中划掉 Stroom——'
                '划掉会立即终止所有运行中的任务。',
          ),
          _TutorialStep(
            title: '保持 App 在后台',
            description: '在 iOS 26 以下系统上，App 在后台的运行时间有限。'
                '建议在需要长时间运行任务时，保持 Stroom 在前台或定期切换回来'
                '以延长后台时间。',
          ),
        ];
      case 'Windows':
        return [
          _TutorialStep(
            title: '关闭窗口 = 最小化到托盘',
            description: '点击窗口右上角关闭按钮不会退出 Stroom，'
                '应用会最小化到系统托盘（任务栏右下角）继续后台运行。'
                '点击托盘图标可恢复窗口；右键托盘图标选择「退出 Stroom」才会彻底退出。',
          ),
          _TutorialStep(
            title: '关闭节电模式',
            description: '进入「设置」→「系统」→「电源和睡眠」→ 关闭「节电模式」。'
                '或将节电模式设置为仅在电池电量低于指定百分比时自动开启。',
          ),
          _TutorialStep(
            title: '允许后台运行',
            description: '进入「设置」→「隐私和安全性」→「后台应用」→ 找到 Stroom 并确保已开启。'
                'Windows 11 中此选项位于「设置」→「应用」→「已安装的应用」→ '
                'Stroom →「高级选项」→「后台应用权限」→ 选择「始终」。',
          ),
          _TutorialStep(
            title: '关闭睡眠模式（可选）',
            description: '如果希望 Stroom 在电脑长时间运行时持续工作，可以进入「设置」→「系统」→'
                '「电源」→ 将「睡眠」设置为「从不」（仅在连接电源时）。',
          ),
          _TutorialStep(
            title: '添加到开机自启',
            description: '打开任务管理器（Ctrl+Shift+Esc）→「启动」→ 找到 Stroom → 右键「启用」。'
                '或进入「设置」→「应用」→「启动」→ 开启 Stroom。',
          ),
        ];
      case 'macOS':
        return [
          _TutorialStep(
            title: '关闭窗口 = 最小化到菜单栏',
            description: '点击窗口左上角红色关闭按钮不会退出 Stroom，'
                '应用会驻留在菜单栏（屏幕右上角）继续后台运行。'
                '点击菜单栏图标可恢复窗口；菜单栏菜单选择「退出 Stroom」才会彻底退出。',
          ),
          _TutorialStep(
            title: '允许通知',
            description: '进入「系统设置」→「通知」→「Stroom」→ 开启「允许通知」。'
                '建议同时开启「横幅」和「通知中心」。',
          ),
          _TutorialStep(
            title: '关闭低电量模式（MacBook）',
            description: '进入「系统设置」→「电池」→ 选择「电源适配器」→ 关闭「低电量模式」。'
                '低电量模式会限制后台活动。',
          ),
          _TutorialStep(
            title: '登录时启动（可选）',
            description: '进入「系统设置」→「通用」→「登录项」→ 添加 Stroom，'
                '这样电脑启动时 Stroom 会自动运行。',
          ),
        ];
      case 'Linux':
        return [
          _TutorialStep(
            title: '关闭窗口 = 最小化到托盘',
            description: '点击窗口关闭按钮不会退出 Stroom，应用会隐藏到系统托盘'
                '（需桌面环境支持 StatusNotifierItem，且构建时已安装 '
                'libayatana-appindicator3-dev）。'
                '在托盘菜单选择「显示主窗口」可恢复窗口。',
          ),
          _TutorialStep(
            title: '桌面环境设置',
            description: '根据您使用的桌面环境（GNOME、KDE、XFCE 等），进入「系统设置」→'
                '「应用」→ 找到 Stroom 并确保没有限制后台活动。',
          ),
          _TutorialStep(
            title: '使用 systemd 服务（可选）',
            description: '如需长时间后台运行，可以创建 systemd 用户服务。'
                '在 ~/.config/systemd/user/ 下创建 stroom.service 文件，'
                '配置 ExecStart 指向 Stroom 可执行文件。',
          ),
          _TutorialStep(
            title: '禁止休眠',
            description: '如果服务器或桌面需要长期运行，可以修改 /etc/systemd/logind.conf 中的 '
                'HandleLidSwitch=ignore 防止合盖休眠。',
          ),
          _TutorialStep(
            title: '开启自动启动',
            description: '在 GNOME 中，使用「优化」(Tweaks) 工具 →「开机启动程序」→ 添加 Stroom。'
                '或在 ~/.config/autostart/ 下创建 stroom.desktop 文件。',
          ),
        ];
      case 'Web':
        return [
          _TutorialStep(
            title: '保持标签页打开',
            description: 'Web 浏览器环境不支持后台服务运行。'
                '任务运行时请保持 Stroom 标签页打开，'
                '关闭标签页或刷新页面会立即中断任务。',
          ),
          _TutorialStep(
            title: '避免浏览器挂起标签页',
            description: '浏览器会冻结长时间不活跃的后台标签页以节省资源。'
                '任务运行时请将 Stroom 标签页保持在前台，'
                '或定期点击页面保持其活跃。',
          ),
        ];
      default:
        return [];
    }
  }

  Widget _buildTipsCard(ThemeData theme) {
    return Card(
      color: config.color.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lightbulb_outline, color: config.color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '小提示',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: config.color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '完成以上设置后，建议回到「后台运行优化」页面确认检测状态已更新。'
                    '如果仍有问题，请查看其他平台的教程或前往 GitHub 提交反馈。',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _TutorialStep {
  final String title;
  final String description;

  const _TutorialStep({required this.title, required this.description});
}
