import 'dart:convert';
import 'dart:typed_data';

import '../models/tool_call.dart';
import '../utils/folder_path_utils.dart';
import '../utils/text_manifest.dart';
import '../utils/web_file_store.dart';

/// Built-in tools for reading and writing Stroom's manifest-backed text space.
class TextStorageToolService {
  static const int _defaultListLimit = 50;
  static const int _maxListLimit = 100;
  static const int _defaultSearchLimit = 10;
  static const int _maxSearchLimit = 20;
  static const int _maxReadLength = 20000;
  static const int _defaultReadLength = 12000;
  static const int _maxToolDocumentBytes = 1024 * 1024;
  static const int _maxSearchContentBytes = 1024 * 1024;
  static const int _maxWriteLength = 100000;
  static const int _maxSearchScan = 1000;
  static const int _maxFolderPathLength = 1024;
  static const int _maxSearchQueryLength = 256;
  static const int _maxSearchSnippetLength = 512;
  static const Set<String> _formats = {'txt', 'md', 'mmd'};
  static final RegExp _contentHashPattern = RegExp(
    r'^[0-9a-f]{32}$',
    caseSensitive: false,
  );

  TextStorageToolService._();

  static final List<ToolDefinition> toolDefinitions = [
    ToolDefinition(
      name: 'stroom_space_list',
      description: '列出 Stroom 文本空间中的文档元数据。可按文件夹筛选。',
      parameters: {
        'type': 'object',
        'properties': {
          'folder': {
            'type': 'string',
            'description': '可选文件夹路径，最多 1024 个字符；省略时列出全部文件夹中的文档。',
          },
          'limit': {'type': 'integer', 'description': '最多返回多少条，默认 50，最大 100。'},
        },
        'required': <String>[],
      },
    ),
    ToolDefinition(
      name: 'stroom_space_search',
      description: '在 Stroom 文本空间中搜索文档标题和正文（单次最多读取 1 MiB 正文），并返回匹配片段。',
      parameters: {
        'type': 'object',
        'properties': {
          'query': {'type': 'string', 'description': '要搜索的文字。'},
          'folder': {
            'type': 'string',
            'description': '可选文件夹路径，最多 1024 个字符；省略时搜索全部文件夹。',
          },
          'limit': {'type': 'integer', 'description': '最多返回多少个结果，默认 10，最大 20。'},
          'search_content': {
            'type': 'boolean',
            'description': '是否搜索正文；默认 true。',
          },
        },
        'required': ['query'],
      },
    ),
    ToolDefinition(
      name: 'stroom_space_read',
      description: '按 Stroom 文档记录 ID 读取文本。长文可使用 offset 分段读取。',
      parameters: {
        'type': 'object',
        'properties': {
          'record_id': {'type': 'string', 'description': 'Stroom 文档记录 ID。'},
          'offset': {'type': 'integer', 'description': '字符起始位置，默认 0。'},
          'length': {
            'type': 'integer',
            'description': '读取字符数，默认 12000，最大 20000。',
          },
        },
        'required': ['record_id'],
      },
    ),
    ToolDefinition(
      name: 'stroom_space_write',
      description:
          '在 Stroom 文本空间创建文档，或按记录 ID 显式替换文档。替换时必须传入上次读取到的 expected_hash，避免覆盖期间被其他编辑修改的内容。支持 txt、md、mmd。',
      parameters: {
        'type': 'object',
        'properties': {
          'record_id': {
            'type': 'string',
            'description': '省略时新建；替换文档时必须提供现有 Stroom 记录 ID。',
          },
          'expected_hash': {
            'type': 'string',
            'description': '替换时必填，使用读取文档时返回的 hash。',
          },
          'expected_metadata_hash': {
            'type': 'string',
            'description': '替换时必填，使用读取文档时返回的 metadata_hash。',
          },
          'name': {'type': 'string', 'description': '文档标题，不含扩展名。'},
          'content': {'type': 'string', 'description': '完整文档正文。'},
          'format': {
            'type': 'string',
            'enum': ['txt', 'md', 'mmd'],
            'description': '文件格式；新建默认 md，替换时省略则保留现有格式。',
          },
          'folder': {
            'type': 'string',
            'description':
                '可选 Stroom 文件夹路径，最多 1024 个字符；新建省略时使用根目录，替换省略时保留原文件夹。',
          },
        },
        'required': ['name', 'content'],
      },
    ),
  ];

  static Future<String> handleTool(
    String name,
    Map<String, dynamic> args,
  ) async {
    try {
      return await _handleTool(name, args);
    } catch (error) {
      return '错误: Stroom 文本空间操作失败：$error';
    }
  }

  static Future<String> _handleTool(
    String name,
    Map<String, dynamic> args,
  ) async {
    switch (name) {
      case 'stroom_space_list':
        return _list(args);
      case 'stroom_space_search':
        return _search(args);
      case 'stroom_space_read':
        return _read(args);
      case 'stroom_space_write':
        return _write(args);
      default:
        return '错误: 未知的 Stroom 文本空间工具 "$name"。';
    }
  }

  static Future<String> _list(Map<String, dynamic> args) async {
    final folderResult = _validateOptionalFolder(args);
    if (folderResult.error != null) return '错误: ${folderResult.error}。';
    final limit = _boundedInt(args['limit'], _defaultListLimit, _maxListLimit);
    final records = await TextManifest.loadRecords();
    final matching =
        records
            .where(
              (record) => _withinFolder(record.folder, folderResult.folder),
            )
            .toList()
          ..sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    final items = matching.take(limit).map(_recordMetadata).toList();
    return jsonEncode({
      'documents': items,
      'count': items.length,
      'has_more': matching.length > items.length,
    });
  }

  static Future<String> _search(Map<String, dynamic> args) async {
    return TextManifest.withSerializedTextRead(() => _searchSnapshot(args));
  }

  static Future<String> _searchSnapshot(Map<String, dynamic> args) async {
    final query = args['query'];
    if (query is! String || query.trim().isEmpty) {
      return '错误: query 必须是非空字符串。';
    }
    if (query.trim().length > _maxSearchQueryLength) {
      return '错误: query 最多支持 $_maxSearchQueryLength 个字符。';
    }
    final folderResult = _validateOptionalFolder(args);
    if (folderResult.error != null) return '错误: ${folderResult.error}。';
    final limit = _boundedInt(
      args['limit'],
      _defaultSearchLimit,
      _maxSearchLimit,
    );
    final searchContent = args['search_content'] != false;
    final needle = query.trim().toLowerCase();
    final records =
        (await TextManifest.loadRecords())
            .where(
              (record) => _withinFolder(record.folder, folderResult.folder),
            )
            .toList()
          ..sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    final results = <Map<String, dynamic>>[];
    var scanned = 0;
    var contentSearchSkippedOversized = 0;
    var contentSearchBytesRead = 0;
    var contentSearchTruncated = false;
    var hasMore = false;
    for (final record in records) {
      if (scanned >= _maxSearchScan) {
        hasMore = true;
        break;
      }
      scanned++;
      final nameMatches = record.name.toLowerCase().contains(needle);
      String? snippet;
      if (!nameMatches && searchContent) {
        final remainingSearchBytes =
            _maxSearchContentBytes - contentSearchBytesRead;
        if (remainingSearchBytes <= 0) {
          contentSearchTruncated = true;
          continue;
        }
        if (record.size > _maxToolDocumentBytes) {
          contentSearchSkippedOversized++;
          continue;
        }
        if (!_isValidContentHash(record.hash)) continue;
        final contentLimit = remainingSearchBytes < _maxToolDocumentBytes
            ? remainingSearchBytes
            : _maxToolDocumentBytes;
        String? content;
        try {
          content = await TextManifest.readTextLimited(
            record.storagePath,
            contentLimit,
          );
        } on StoredFileSizeLimitExceeded {
          if (contentLimit < _maxToolDocumentBytes) {
            contentSearchTruncated = true;
          } else {
            contentSearchSkippedOversized++;
          }
          continue;
        }
        if (content != null) {
          contentSearchBytesRead += utf8.encode(content).length;
          snippet = _findSnippet(content, needle);
        }
      }
      if (!nameMatches && snippet == null) continue;
      if (results.length == limit) {
        hasMore = true;
        break;
      }
      results.add({
        ..._recordMetadata(record),
        ...?(snippet == null ? null : {'snippet': snippet}),
      });
    }
    return jsonEncode({
      'results': results,
      'count': results.length,
      'scanned': scanned,
      'has_more': hasMore,
      'content_search_skipped_oversized': contentSearchSkippedOversized,
      'content_search_truncated': contentSearchTruncated,
    });
  }

  static Future<String> _read(Map<String, dynamic> args) async {
    return TextManifest.withSerializedTextRead(() => _readSnapshot(args));
  }

  static Future<String> _readSnapshot(Map<String, dynamic> args) async {
    final recordId = args['record_id'];
    if (recordId is! String || recordId.trim().isEmpty) {
      return '错误: record_id 必须是非空字符串。';
    }
    final offset = _boundedInt(args['offset'], 0, 1 << 30);
    final length = _boundedInt(
      args['length'],
      _defaultReadLength,
      _maxReadLength,
    );
    TextManifest.invalidateCache();
    final record = await _findRecord(recordId.trim());
    if (record == null) return '错误: 找不到 ID 为 "$recordId" 的文档。';
    if (!_isValidContentHash(record.hash)) {
      return '错误: 文档记录中的内容哈希无效。';
    }
    if (record.size > _maxToolDocumentBytes) {
      return '错误: 文档超过 $_maxToolDocumentBytes 字节，工具读取上限为 1 MiB。';
    }
    late final String? content;
    try {
      content = await TextManifest.readTextLimited(
        record.storagePath,
        _maxToolDocumentBytes,
      );
    } on StoredFileSizeLimitExceeded {
      return '错误: 文档超过 $_maxToolDocumentBytes 字节，工具读取上限为 1 MiB。';
    }
    if (content == null) return '错误: 文档正文不存在，记录可能已损坏。';
    if (offset > content.length) return '错误: offset 超出文档长度。';
    final end = (offset + length).clamp(0, content.length).toInt();
    return jsonEncode({
      ..._recordMetadata(record),
      'hash': record.hash,
      'content': content.substring(offset, end),
      'offset': offset,
      'next_offset': end,
      'complete': end == content.length,
    });
  }

  static Future<String> _write(Map<String, dynamic> args) async {
    final rawName = args['name'];
    final content = args['content'];
    if (rawName is! String || rawName.trim().isEmpty) {
      return '错误: name 必须是非空字符串。';
    }
    if (content is! String) return '错误: content 必须是字符串。';
    if (content.length > _maxWriteLength) {
      return '错误: 文档内容不能超过 $_maxWriteLength 个字符。';
    }
    var name = rawName.trim();
    final formatValue = args['format'] ?? 'md';
    if (formatValue is! String || !_formats.contains(formatValue)) {
      return '错误: format 仅支持 txt、md、mmd。';
    }
    final formatSuffix = RegExp(
      r'\.(txt|md|mmd)$',
      caseSensitive: false,
    ).firstMatch(name);
    if (formatSuffix != null) {
      if (formatSuffix.group(1)!.toLowerCase() != formatValue) {
        return '错误: name 不要包含扩展名；请通过 format 指定文件格式。';
      }
      name = name.substring(0, formatSuffix.start);
    }
    final nameError = FolderPathUtils.validateFileName(name);
    if (nameError != null) return '错误: $nameError。';
    final folderResult = _validateFolder(args['folder']);
    if (folderResult.error != null) return '错误: ${folderResult.error}。';
    final folder = folderResult.folder!;
    final bytes = Uint8List.fromList(utf8.encode(content));
    final hash = computeTextHash(bytes);
    final recordId = args['record_id'];

    if (recordId == null) {
      final record = TextRecord(
        name: name,
        hash: hash,
        format: formatValue,
        createdAt: DateTime.now(),
        size: bytes.length,
        folder: folder,
        textLength: content.length,
      );
      await TextManifest.addRecordWithContent(record, bytes);
      return jsonEncode({
        'status': 'created',
        ..._recordMetadata(record),
        'hash': record.hash,
      });
    }

    if (recordId is! String || recordId.trim().isEmpty) {
      return '错误: record_id 必须是非空字符串。';
    }
    final expectedHash = args['expected_hash'];
    if (expectedHash is! String || expectedHash.isEmpty) {
      return '错误: 替换文档时必须提供 expected_hash。先读取文档以获取当前 hash。';
    }
    final expectedMetadataHash = args['expected_metadata_hash'];
    if (expectedMetadataHash is! String || expectedMetadataHash.isEmpty) {
      return '错误: 替换文档时必须提供 expected_metadata_hash。先读取文档以获取当前 metadata_hash。';
    }
    TextManifest.invalidateCache();
    final oldRecord = await _findRecord(recordId.trim());
    if (oldRecord == null) return '错误: 找不到 ID 为 "$recordId" 的文档。';
    if (!_isValidContentHash(oldRecord.hash)) {
      return '错误: 文档记录中的内容哈希无效。';
    }
    if (oldRecord.hash != expectedHash) {
      return '错误: 文档在读取后已被修改。请重新读取并基于最新内容重试。';
    }
    if (_metadataHash(oldRecord) != expectedMetadataHash) {
      return '错误: 文档的名称、格式或文件夹在读取后已更改。请重新读取并基于最新信息重试。';
    }

    final now = DateTime.now();
    final updated = TextRecord(
      id: oldRecord.id,
      name: name,
      hash: hash,
      format: args['format'] is String ? formatValue : oldRecord.format,
      createdAt: oldRecord.createdAt,
      modifiedAt: hash == oldRecord.hash ? oldRecord.modifiedAt : now,
      size: bytes.length,
      folder: args['folder'] is String ? folder : oldRecord.folder,
      textLength: content.length,
    );
    final replaced = await TextManifest.updateRecordIfHashWithContent(
      oldRecord.id,
      expectedHash,
      {
        'name': oldRecord.name,
        'format': oldRecord.format,
        'folder': oldRecord.folder,
      },
      updated,
      bytes,
    );
    if (!replaced) {
      return '错误: 文档在读取后已被修改。请重新读取并基于最新内容重试。';
    }
    return jsonEncode({
      'status': 'updated',
      ..._recordMetadata(updated),
      'hash': updated.hash,
    });
  }

  static Future<TextRecord?> _findRecord(String id) async {
    for (final record in await TextManifest.loadRecords()) {
      if (record.id == id) return record;
    }
    return null;
  }

  static Map<String, dynamic> _recordMetadata(TextRecord record) => {
    'id': record.id,
    'name': record.name,
    'format': record.format,
    'folder': record.folder,
    'size': record.size,
    'text_length': record.textLength,
    'modified_at': record.modifiedAt.toIso8601String(),
    'metadata_hash': _metadataHash(record),
  };

  static String _metadataHash(TextRecord record) => computeTextHash(
    Uint8List.fromList(
      utf8.encode(jsonEncode([record.name, record.format, record.folder])),
    ),
  );

  static String? _findSnippet(String content, String needle) {
    final index = content.toLowerCase().indexOf(needle);
    if (index < 0) return null;
    var start = (index - 100).clamp(0, content.length).toInt();
    var end = (start + _maxSearchSnippetLength)
        .clamp(0, content.length)
        .toInt();
    final matchEnd = index + needle.length;
    if (end < matchEnd) {
      end = matchEnd;
      start = (end - _maxSearchSnippetLength).clamp(0, content.length).toInt();
    }
    return content.substring(start, end);
  }

  static bool _withinFolder(String recordFolder, String? folder) {
    if (folder == null) return true;
    if (folder.isEmpty) return recordFolder.isEmpty;
    return recordFolder == folder || recordFolder.startsWith('$folder/');
  }

  static bool _isValidContentHash(String hash) =>
      _contentHashPattern.hasMatch(hash);

  static int _boundedInt(dynamic value, int fallback, int max) {
    if (value is! int) return fallback;
    if (value < 0) return 0;
    return value > max ? max : value;
  }

  static ({String? folder, String? error}) _validateOptionalFolder(
    Map<String, dynamic> args,
  ) {
    if (!args.containsKey('folder') || args['folder'] == null) {
      return (folder: null, error: null);
    }
    return _validateFolder(args['folder']);
  }

  static ({String? folder, String? error}) _validateFolder(dynamic value) {
    if (value == null || value == '') return (folder: '', error: null);
    if (value is! String) return (folder: null, error: 'folder 必须是字符串');
    if (value.length > _maxFolderPathLength) {
      return (folder: null, error: 'folder 路径不能超过 $_maxFolderPathLength 个字符');
    }
    if (value.startsWith('/') || value.contains('\\') || value.contains(':')) {
      return (folder: null, error: 'folder 必须是 Stroom 内的相对路径');
    }
    final segments = value.split('/');
    for (final segment in segments) {
      if (segment.isEmpty || segment == '.' || segment == '..') {
        return (folder: null, error: 'folder 路径包含无效片段');
      }
      final error = FolderPathUtils.validateFolderName(segment);
      if (error != null) return (folder: null, error: error);
    }
    return (folder: segments.join('/'), error: null);
  }
}
