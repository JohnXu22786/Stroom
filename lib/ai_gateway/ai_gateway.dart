/// Public Stroom AI Gateway module boundary.
///
/// Chat, Task Flow, and account-management surfaces use this application
/// facade. Provider, auth, discovery, routing, protocol-bridge, and executor
/// responsibilities have independent contracts here; implementations can be
/// introduced without moving provider decisions into callers.
import 'ai_gateway_facade.dart' as implementation;

export 'ai_gateway_contracts.dart';
export 'ai_gateway_facade.dart'
    show
        LlmChatRouteDiagnostic,
        LlmChatRouteDiagnostics,
        stableLlmModelGroupId,
        stableLlmModelGroupLocalModelId,
        llmRouteDecisionLabel;

/// Public factory for the stable application-facing Gateway API.
class AiGateway {
  static Future<AiGatewayFacade> sharedPlatform() =>
      implementation.LlmChatRoutingRuntime.sharedPlatform();

  static AiGatewayProviderCatalog get defaultProviderCatalog =>
      implementation.LlmChatRoutingRuntime.defaultProviderCatalog;
}
