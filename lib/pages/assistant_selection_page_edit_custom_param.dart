part of 'assistant_selection_page.dart';

void showEditCustomParameterDialog(
  BuildContext context,
  CustomParameter cp,
  void Function(String name, String type, dynamic value) onEdit,
) {
  final nameController = TextEditingController(text: cp.name);
  String type = cp.type;
  // Display JSON values using jsonEncode (proper JSON format) instead of
  // .toString() (Dart format like {key: value}) which would produce
  // invalid JSON and break round-trip editing.
  String initialValue;
  if (cp.type == 'json' && (cp.value is Map || cp.value is List)) {
    initialValue = jsonEncode(cp.value);
  } else {
    initialValue = cp.value?.toString() ?? '';
  }
  final valueController = TextEditingController(text: initialValue);
  String? jsonError;

  void validateJsonValue() {
    if (type == 'json' && valueController.text.trim().isNotEmpty) {
      try {
        jsonDecode(valueController.text.trim());
        jsonError = null;
      } catch (e) {
        // 用与 jsonDecode 相同的（去首尾空白）源文本计算行列。
        jsonError = formatJsonError(valueController.text.trim(), e);
      }
    } else {
      jsonError = null;
    }
  }

  // Initial validation
  validateJsonValue();

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDlgState) {
        final name = nameController.text.trim();
        final hasInvalidName = name.isNotEmpty && !isValidParamName(name);
        return AlertDialog(
          title: ConstrainedText(
            AppLocalizations.of(context)!.assistantEditCustomParameter,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!
                      .assistantParameterName,
                  hintText: AppLocalizations.of(context)!
                      .assistantParameterNameHint,
                  border: const OutlineInputBorder(),
                  errorText: hasInvalidName
                      ? AppLocalizations.of(context)!
                            .assistantParameterNameInvalid
                      : null,
                ),
                onChanged: (_) => setDlgState(() {}),
              ),
              // 点号参数名（如 provider.only）自动分行展示嵌套结构
              ParamNamePathPreview(name: name),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                dropdownColor: StroomMenuStyle.surface(context),
                borderRadius: StroomMenuStyle.borderRadius,
                isExpanded: true,
                initialValue: type,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.chatInfoType,
                  border: OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'string',
                    child: ConstrainedText(
                      AppLocalizations.of(context)!
                          .assistantParamValueTypeString,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'number',
                    child: ConstrainedText(
                      AppLocalizations.of(context)!
                          .assistantParamValueTypeNumber,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'boolean',
                    child: ConstrainedText(
                      AppLocalizations.of(context)!
                          .assistantParamValueTypeBoolean,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'json',
                    child: ConstrainedText(
                      AppLocalizations.of(context)!.assistantParamValueTypeJson,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setDlgState(() {
                      type = v;
                      validateJsonValue();
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: valueController,
                      // JSON 值是多行代码：拉高输入框便于编辑
                      minLines: type == 'json' ? 4 : 1,
                      maxLines: type == 'json' ? 8 : 1,
                      style: type == 'json'
                          ? const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 13,
                            )
                          : null,
                      inputFormatters: type == 'json'
                          ? const [CodeSmartInputFormatter()]
                          : null,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.assistantValue,
                        hintText: type == 'boolean'
                            ? AppLocalizations.of(context)!
                                  .assistantTrueFalseHint
                            : type == 'number'
                            ? AppLocalizations.of(context)!.assistantNumberHint
                            : type == 'json'
                            ? AppLocalizations.of(context)!
                                  .assistantJsonHint('{"key": "value"}')
                            : AppLocalizations.of(context)!.assistantValueHint,
                        border: const OutlineInputBorder(),
                        errorText: jsonError,
                        errorMaxLines: 3,
                        alignLabelWithHint: true,
                      ),
                      onChanged: (_) {
                        validateJsonValue();
                        setDlgState(() {});
                      },
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.fullscreen, size: 20),
                    tooltip: AppLocalizations.of(context)!.chatFullscreenEdit,
                    onPressed: () {
                      showJsonValueEditorDialog(
                        ctx,
                        initialValue: valueController.text,
                        hintText: type == 'boolean'
                            ? AppLocalizations.of(context)!
                                  .assistantTrueFalseHint
                            : type == 'number'
                            ? AppLocalizations.of(context)!.assistantNumberHint
                            : type == 'json'
                            ? AppLocalizations.of(context)!
                                  .assistantJsonHint('{"key": "value"}')
                            : AppLocalizations.of(context)!.assistantValueHint,
                        type: type,
                        onSave: (text) {
                          setDlgState(() {
                            valueController.text = text;
                            valueController.selection =
                                TextSelection.fromPosition(
                                  TextPosition(offset: text.length),
                                );
                            validateJsonValue();
                          });
                        },
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: ConstrainedText(
                AppLocalizations.of(context)!.batchDlgCancel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty || !isValidParamName(name)) return;
                if (jsonError != null) return;
                dynamic value = valueController.text.trim();
                if (type == 'number') {
                  value =
                      double.tryParse(value) ?? int.tryParse(value) ?? value;
                } else if (type == 'boolean') {
                  value = (value as String).toLowerCase() == 'true';
                } else if (type == 'json') {
                  try {
                    value = jsonDecode(value as String);
                  } catch (_) {
                    // Keep as string if not valid JSON
                  }
                }
                onEdit(name, type, value);
                nameController.dispose();
                valueController.dispose();
                Navigator.pop(ctx);
              },
              child: ConstrainedText(
                AppLocalizations.of(context)!.mermaidSaveButton,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      },
    ),
  );
}
