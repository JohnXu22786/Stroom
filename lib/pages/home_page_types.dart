import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 页面枚举，定义应用中的主要页面（不含加号按钮）
enum AppPage { home, chat, files, settings }

/// 当前选中页面的状态提供器
final selectedPageProvider = StateProvider<AppPage>((ref) => AppPage.home);
