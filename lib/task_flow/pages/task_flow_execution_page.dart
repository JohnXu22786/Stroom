import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/block_type_definition.dart';
import '../models/io_type.dart';
import '../models/task_flow_definition.dart';
import '../providers/task_flow_provider.dart';
import '../services/task_flow_execution_service.dart';

class TaskFlowExecutionPage extends ConsumerStatefulWidget {
  final String flowId;
  const TaskFlowExecutionPage({super.key, required this.flowId});
  @override
  ConsumerState<TaskFlowExecutionPage> createState() =>
      _TaskFlowExecutionPageState();
}

class _TaskFlowExecutionPageState extends ConsumerState<TaskFlowExecutionPage> {
  final _inputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _inputController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // Trigger execution via the standalone service, then pop
  // ===========================================================================

  Future<void> _startFlow() async {
    final inputText = _inputController.text.trim();
    if (inputText.isEmpty) return;

    // Get the service BEFORE pop — its Ref is from a global Provider, NOT a widget.
    // It will continue running after the page is disposed.
    final service = ref.read(taskFlowExecutionServiceProvider);

    if (mounted) {
      Navigator.popUntil(context, (r) => r.isFirst);
    }

    // Fire-and-forget: the service runs independently of widget lifecycle
    service.startFlow(widget.flowId, inputText);
  }

  // ===========================================================================
  // UI
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final flow = ref
        .watch(taskFlowListProvider)
        .where((f) => f.id == widget.flowId)
        .firstOrNull;

    if (flow == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('任务流')),
        body: const Center(child: Text('任务流未找到')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(flow.name), centerTitle: true),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildFlowOverviewCard(flow, cs),
            const SizedBox(height: 20),
            _buildInputSection(flow.inputType, cs),
            const SizedBox(height: 16),
            ...flow.blocks.asMap().entries.map((entry) =>
                _buildStepCard(block: entry.value, index: entry.key, cs: cs)),
          ],
        ),
      ),
    );
  }

  Widget _buildFlowOverviewCard(TaskFlowDefinition flow, ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16)),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.account_tree, size: 20, color: cs.primary),
          const SizedBox(width: 8),
          Text(flow.name,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface)),
        ]),
        if (flow.description.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(flow.description,
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
        ],
        const SizedBox(height: 12),
        SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
                children: flow.blocks.asMap().entries.map((entry) {
              final def = entry.value.getDefinition();
              return Row(children: [
                if (entry.key > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(Icons.arrow_forward,
                        size: 14, color: cs.onSurfaceVariant),
                  ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: def?.color.withValues(alpha: 0.12) ??
                        Colors.grey.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(def?.label ?? entry.value.typeKey,
                      style: TextStyle(
                          fontSize: 11,
                          color: def?.color ?? Colors.grey,
                          fontWeight: FontWeight.w500)),
                ),
              ]);
            }).toList()))
      ]),
    );
  }

  Widget _buildInputSection(IOType inputType, ColorScheme cs) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.input, size: 18, color: cs.primary),
            const SizedBox(width: 8),
            Text('输入（${inputType.label}）',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface)),
          ]),
          const SizedBox(height: 8),
          if (inputType == IOType.url)
            TextField(
              controller: _inputController,
              decoration: InputDecoration(
                hintText: '输入网页链接',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: const Icon(Icons.link, size: 18),
                filled: true,
                fillColor: cs.surface,
              ),
              style: const TextStyle(fontSize: 14),
              keyboardType: TextInputType.url,
            )
          else if (inputType == IOType.text)
            TextField(
              controller: _inputController,
              decoration: InputDecoration(
                hintText: '输入文本',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: const Icon(Icons.text_fields, size: 18),
                filled: true,
                fillColor: cs.surface,
              ),
              style: const TextStyle(fontSize: 14),
              maxLines: 3,
            )
          else
            TextField(
              controller: _inputController,
              decoration: InputDecoration(
                hintText: '输入 ${inputType.label} 路径或标识',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: cs.surface,
              ),
              style: const TextStyle(fontSize: 14),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton.icon(
                onPressed:
                    _inputController.text.trim().isNotEmpty ? _startFlow : null,
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text('开始任务流'),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildStepCard({
    required TaskFlowBlock block,
    required int index,
    required ColorScheme cs,
  }) {
    final def = block.getDefinition();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (index > 0)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Icon(Icons.arrow_downward,
                size: 18, color: cs.onSurfaceVariant),
          ),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: cs.outlineVariant, width: 0.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                      color: cs.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(8)),
                  child: Icon(def?.icon ?? Icons.extension,
                      size: 16, color: cs.onSurfaceVariant)),
              const SizedBox(width: 10),
              Expanded(
                child: Text('${index + 1}. ${def?.label ?? block.typeKey}',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface)),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
