import 'conversation_repository.dart';
import 'conversation_repository_sqflite.dart';

ConversationRepository createConversationRepository() =>
    SqfliteConversationRepository();
