import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/services/assistant_tool_policy.dart';

void main() {
  test('includes built-in Stroom tools in the accepted tool-name set', () {
    final names = supportedAssistantToolNames(const ProviderEntriesState());

    expect(names, contains('todowrite'));
    expect(names, contains('web_search'));
    expect(names, contains('brave_web_search'));
    expect(names, isNot(contains('third_party_unknown_tool')));
  });
}
