import 'package:dio/dio.dart';

/// Source-verified AI Horde chat facade endpoints and anonymous credential.
/// These fixed URLs keep account credentials out of caller-configured hosts.
const kAiHordeAnonymousKey = '0000000000';
const kAiHordeChatModelsUri = 'https://oai.aihorde.net/v1/models';
const kAiHordeChatCompletionsUri =
    'https://oai.aihorde.net/v1/chat/completions';
const kAiHordeKeyValidationUri = 'https://aihorde.net/api/v2/find_user';
const kAiHordeChatTimeout = Duration(seconds: 120);

/// Validates an optional user key against Horde's native account endpoint.
/// The OpenAI chat facade accepts arbitrary bearer values, so it cannot be
/// used to establish whether a pasted priority key belongs to a user.
Future<bool> validateAiHordeApiKey(Dio dio, String apiKey) async {
  final key = apiKey.trim();
  if (key.isEmpty) return true;
  final response = await dio.getUri<Object?>(
    Uri.parse(kAiHordeKeyValidationUri),
    options: Options(
      responseType: ResponseType.json,
      followRedirects: false,
      validateStatus: (status) => status != null,
      headers: {'Accept': 'application/json', 'apikey': key},
    ),
  );
  final status = response.statusCode ?? 0;
  if (status < 200 || status >= 300 || response.data is! Map) return false;
  final username = (response.data as Map)['username'];
  return username is String && username.trim().isNotEmpty;
}
