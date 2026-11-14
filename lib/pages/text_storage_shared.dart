import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:stroom/widgets/stroom_menu_style.dart';

import '../l10n/app_localizations.dart';
import '../utils/folder_path_utils.dart';
import '../utils/text_manifest.dart';

import '../widgets/constrained_text.dart';

/// 文本文件可切换的格式（新建与重命名下拉框共用同一份列表）
const List<String> kTextFileFormats = ['txt', 'md', 'mmd'];

/// Generates a text-record name not already used by the same format in folder.
String uniqueTextRecordName(
  String baseName,
  String format,
  String folder,
  List<TextRecord> records,
  Set<String> usedInBatch,
) {
  bool taken(String name) =>
      usedInBatch.contains('$name\u0000$format') ||
      records.any(
        (record) =>
            record.name == name &&
            record.format == format &&
            record.folder == folder,
      );

  if (!taken(baseName)) return baseName;
  var index = 2;
  while (taken('$baseName ($index)')) {
    index++;
  }
  return '$baseName ($index)';
}

class TextCreatePage extends StatefulWidget {
  final String initialFolder;

  const TextCreatePage({super.key, this.initialFolder = ''});

  @override
  State<TextCreatePage> createState() => TextCreatePageState();
}

class TextCreatePageState extends State<TextCreatePage> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool _isSaving = false;
  String _selectedFormat = 'txt';

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final content = _contentController.text;

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.textCreateEnterTitle),
        ),
      );
      return;
    }

    final nameError = FolderPathUtils.validateFileName(title);
    if (nameError != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(nameError)));
      return;
    }

    final format = _selectedFormat;
    setState(() => _isSaving = true);

    try {
      final bytes = Uint8List.fromList(utf8.encode(content));
      final hash = computeTextHash(bytes);
      final saved = await TextManifest.saveTextRecordIfUnique(
        TextRecord(
          name: title,
          hash: hash,
          format: format,
          createdAt: DateTime.now(),
          size: bytes.length,
          folder: widget.initialFolder,
          textLength: content.length,
        ),
        content,
      );
      if (!mounted) return;
      if (!saved) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!
                  .fileManagerFileExists(format, title),
            ),
          ),
        );
        return;
      }

      if (mounted) {
        setState(() => _isSaving = false);
        Navigator.pop(context, 'saved');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.textCreateSaveFailed(e.toString()),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: ConstrainedText(
          AppLocalizations.of(context)!.textCreateNewTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(AppLocalizations.of(context)!.textCreateSave),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText:
                          AppLocalizations.of(context)!.textCreateTitleLabel,
                      hintText:
                          AppLocalizations.of(context)!.textCreateTitleHint,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 120,
                  child: DropdownButtonFormField<String>(
                    dropdownColor: StroomMenuStyle.surface(context),
                    borderRadius: StroomMenuStyle.borderRadius,
                    isExpanded: true,
                    initialValue: _selectedFormat,
                    decoration: InputDecoration(
                      labelText:
                          AppLocalizations.of(context)!.textCreateFormatLabel,
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                    ),
                    items: kTextFileFormats
                        .map(
                          (f) => DropdownMenuItem(
                            value: f,
                            child: ConstrainedText(
                              f,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedFormat = value);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: TextField(
                controller: _contentController,
                decoration: InputDecoration(
                  labelText:
                      AppLocalizations.of(context)!.textCreateContentLabel,
                  hintText: AppLocalizations.of(context)!.textCreateContentHint,
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
