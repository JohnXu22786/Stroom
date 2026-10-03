import 'package:uuid/uuid.dart';

const builtinSearchMcpGroupId = 'builtin_search';
const builtinMcpServicesGroupId = 'builtin_mcp_services';

class McpProviderGroup {
  final String id;
  final String name;
  final bool isBuiltin;
  final bool enabled;

  const McpProviderGroup({
    required this.id,
    required this.name,
    this.isBuiltin = false,
    this.enabled = true,
  });

  factory McpProviderGroup.custom(String name) =>
      McpProviderGroup(id: 'mcp_group_${const Uuid().v4()}', name: name);

  McpProviderGroup copyWith({String? name, bool? enabled}) => McpProviderGroup(
        id: id,
        name: name ?? this.name,
        isBuiltin: isBuiltin,
        enabled: enabled ?? this.enabled,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'isBuiltin': isBuiltin,
        'enabled': enabled,
      };

  factory McpProviderGroup.fromMap(Map<String, dynamic> map) =>
      McpProviderGroup(
        id: map['id'] as String,
        name: map['name'] as String? ?? '',
        isBuiltin: map['isBuiltin'] as bool? ?? false,
        enabled: map['enabled'] as bool? ?? true,
      );
}

const builtinMcpProviderGroups = <McpProviderGroup>[
  McpProviderGroup(id: builtinSearchMcpGroupId, name: '搜索', isBuiltin: true),
  McpProviderGroup(
    id: builtinMcpServicesGroupId,
    name: '其他 MCP 服务',
    isBuiltin: true,
  ),
];

String defaultMcpGroupIdForProvider(String providerName) {
  final name = providerName.trim().toLowerCase();
  const searchProviders = {
    'exa',
    'tavily',
    'jina ai',
    'brave search',
    'bocha',
    'querit',
    'searxng',
  };
  return searchProviders.contains(name) ||
          name.contains('search') ||
          name.contains('搜索')
      ? builtinSearchMcpGroupId
      : builtinMcpServicesGroupId;
}
