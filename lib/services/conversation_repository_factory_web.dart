import 'conversation_repository.dart';
import 'conversation_repository_indexed_db.dart';

ConversationRepository createConversationRepository() =>
    IndexedDbConversationRepository();
