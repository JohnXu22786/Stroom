import '../providers/provider_config.dart';
import 'chat_adapter.dart' show kMcpSearchToolNames;
import 'chat_service.dart';
import 'http_tool_service.dart';
import 'todo_tool_service.dart';
import 'web_search_service.dart';

Set<String> supportedAssistantToolNames(ProviderEntriesState entries) {
  final names = <String>{
    ...ChatService.getRegisteredToolDefinitions().map((tool) => tool.name),
    ...HttpToolService.toolDefinitions.map((tool) => tool.name),
    ...TodoToolService.toolDefinitions.map((tool) => tool.name),
    ...WebSearchService.toolDefinitions.map((tool) => tool.name),
    ...kMcpSearchToolNames,
  };
  for (final entry in entries.entries.where((entry) => entry.type == 'mcp')) {
    names.addAll(mcpPlaceholderToolNamesByConfigId(entry.configs).values);
  }
  names.addAll(disabledMcpToolNames(entries));
  return names;
}
