import '../providers/conversation_provider.dart';

int countMessageMatches(Conversation conv, String query) {
  if (query.isEmpty) return 0;
  final lowerQuery = query.toLowerCase();
  int count = 0;
  for (final msg in conv.messages) {
    final lowerContent = msg.content.toLowerCase();
    int start = 0;
    while (true) {
      final idx = lowerContent.indexOf(lowerQuery, start);
      if (idx == -1) break;
      count++;
      start = idx + lowerQuery.length;
    }
  }
  return count;
}
