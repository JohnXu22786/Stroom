// ============================================================================
// 模型拖动排序顺序辅助函数
//
// 对话页面的模型选择面板与供应商配置页的模型列表共享同一份"全局顺序"：
// SharedPreferences 的 `model_order`，值为全部 LLM 模型的显示名
// （"模型名 | 供应商名"）按合并后的顺序排列。
//
// - [applySavedOrder]：把保存的全局顺序套用到一组名字上（已保存的按保存
//   顺序前置，未保存的按原顺序追加）。聊天面板和各供应商页都用它从全局
//   顺序推导出各自的显示顺序（"去掉其它供应商后剩下的顺序"）。
// - [rebuildGlobalOrder]：供应商页拖动排序后，把该供应商在全局顺序中的
//   子序列替换为拖动后的新顺序，其它供应商的相对位置保持不变，生成新的
//   全局顺序并保存。
// ============================================================================
library;

/// 将保存的全局顺序 [savedOrder] 应用到 [names]：
/// 已知名字按保存顺序前置，其余名字保持原顺序追加在末尾。
/// [savedOrder] 为 null 或空时原样返回 [names]（不修改入参）。
List<String> applySavedOrder(List<String> names, List<String>? savedOrder) {
  if (savedOrder == null || savedOrder.isEmpty) return List.of(names);
  final ordered = <String>[];
  final remaining = Set<String>.from(names);
  for (final savedName in savedOrder) {
    if (remaining.remove(savedName)) {
      ordered.add(savedName);
    }
  }
  ordered.addAll(remaining);
  return ordered;
}

/// 生成拖动后的新全局顺序：遍历 [currentGlobal]，其中属于 [inProvider]
/// 的名字按出现顺序依次替换为 [newProviderOrder] 里的名字，其余名字保持
/// 原位；[newProviderOrder] 中未能在 [currentGlobal] 里配对到位置的名字
/// （如新建的模型）追加到末尾。
List<String> rebuildGlobalOrder({
  required List<String> currentGlobal,
  required Set<String> inProvider,
  required List<String> newProviderOrder,
}) {
  final queue = List<String>.from(newProviderOrder);
  final newGlobal = <String>[];
  for (final name in currentGlobal) {
    if (inProvider.contains(name)) {
      if (queue.isNotEmpty) newGlobal.add(queue.removeAt(0));
    } else {
      newGlobal.add(name);
    }
  }
  newGlobal.addAll(queue);
  return newGlobal;
}
