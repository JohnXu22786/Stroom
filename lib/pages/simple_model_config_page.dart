import 'dart:convert';
import 'package:flutter/material.dart';
import '../providers/provider_config.dart';

/// 简洁模型配置编辑页面（适用于 OCR、ASR 等不需要 TTS 特有字段的类型）
/// 包含：模型名称（可选）、模型ID（必填）、自定义参数（可选）
class SimpleModelConfigPage extends StatefulWidget {
  final ModelConfig? model; // null = 新建, non-null = 编辑

  const SimpleModelConfigPage({super.key, this.model});

  @override
  State<SimpleModelConfigPage> createState() => _SimpleModelConfigPageState();
}

class _SimpleModelConfigPageState extends State<SimpleModelConfigPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _modelIdController;
  late List<CustomParam> _customParams;
  bool _isSaving = false;

  bool get _isEditing => widget.model != null;

  @override
  void initState() {
    super.initState();
    final m = widget.model;
    _nameController = TextEditingController(text: m?.name ?? '');
    _modelIdController = TextEditingController(text: m?.modelId ?? '');
    _customParams = (m?.customParams ?? []).map((p) => p.copy()).toList();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _modelIdController.dispose();
    super.dispose();
  }

  // ===================================================================
  // 自定义参数
  // ===================================================================

  void _addCustomParam() {
    setState(() {
      _customParams.insert(0, CustomParam(paramName: '', defaultValue: ''));
    });
  }

  void _removeCustomParam(int index) {
    setState(() {
      _customParams.removeAt(index);
    });
  }

  // ===================================================================
  // 保存
  // ===================================================================

  void _save() {
    final modelId = _modelIdController.text.trim();
    if (modelId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('模型 ID 为必填项'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // 验证自定义参数：参数名和默认值不能为空，参数名不能重复，
    // JSON 类型的默认值必须是合法 JSON
    final seenNames = <String>{};
    for (int i = 0; i < _customParams.length; i++) {
      final param = _customParams[i];
      final name = param.paramName.trim();
      if (name.isEmpty || param.defaultValue.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('自定义参数的参数名和默认值不能为空'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      if (!seenNames.add(name)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已存在该参数: $name'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      // JSON 类型的默认值必须是合法 JSON
      if (param.type == 'json' && param.defaultValue.trim().isNotEmpty) {
        try {
          jsonDecode(param.defaultValue.trim());
        } catch (_) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('参数 "$name" 的默认值不是合法 JSON：${param.defaultValue}'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
      }
    }

    setState(() => _isSaving = true);

    var name = _nameController.text.trim();
    if (name.isEmpty && modelId.isNotEmpty) {
      name = modelId;
    }

    final result = ModelConfig(
      name: name,
      modelId: modelId,
      customParams: _customParams.map((p) => p.copy()).toList(),
    );

    Navigator.pop(context, result);
  }

  // ===================================================================
  // Build
  // ===================================================================

  @override
  Widget build(BuildContext context) {
    final title = _isEditing
        ? (widget.model!.name.isNotEmpty ? widget.model!.name : '编辑模型')
        : '添加模型';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: const Text('保存'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ==========================================================
          // 模型名称
          // ==========================================================
          const Text('模型名称', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              hintText: '输入显示名称（可选）',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // ==========================================================
          // 模型 ID
          // ==========================================================
          const Text('模型 ID *', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _modelIdController,
            decoration: const InputDecoration(
              hintText: '如 gpt-4o',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // ==========================================================
          // 自定义参数
          // ==========================================================
          Row(
            children: [
              const Text('自定义参数',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('添加参数'),
                onPressed: _addCustomParam,
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (_customParams.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text('暂无自定义参数', style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            ...List.generate(_customParams.length, (i) {
              final param = _customParams[i];
              final name = param.paramName.trim();
              final isDuplicate = name.isNotEmpty &&
                  _customParams.indexWhere((p) => p.paramName.trim() == name) !=
                      i;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              initialValue: param.paramName,
                              decoration: InputDecoration(
                                labelText: '参数名',
                                border: const OutlineInputBorder(),
                                isDense: true,
                                errorText: isDuplicate ? '已存在该参数' : null,
                                errorStyle: const TextStyle(fontSize: 11),
                              ),
                              onChanged: (v) {
                                param.paramName = v;
                                setState(() {});
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          // 类型选择
                          Container(
                            width: 110,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade400),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: param.type,
                                isDense: true,
                                items: ParamType.values
                                    .map((t) => DropdownMenuItem(
                                          value: t.value,
                                          child: Text(t.label,
                                              style: const TextStyle(
                                                  fontSize: 13)),
                                        ))
                                    .toList(),
                                onChanged: (v) {
                                  if (v != null) {
                                    setState(() => param.type = v);
                                  }
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.delete,
                                color: Colors.red, size: 20),
                            onPressed: () => _removeCustomParam(i),
                            tooltip: '删除参数',
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        initialValue: param.defaultValue,
                        decoration: InputDecoration(
                          labelText: '默认参数值',
                          hintText: param.paramType.defaultValueHint,
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (v) => param.defaultValue = v,
                      ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
