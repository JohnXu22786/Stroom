/// Public Stroom AI Gateway module boundary.
///
/// Chat, Task Flow, and account-management surfaces use this application
/// facade. Provider, auth, discovery, routing, protocol-bridge, and executor
/// responsibilities have independent contracts here; implementations can be
/// introduced without moving provider decisions into callers.
library;

import 'ai_gateway_contracts.dart';
import '../src/ai_gateway/ai_gateway_facade.dart' as implementation;

export 'ai_gateway_contracts.dart';
export 'ai_gateway_protocol_bridges.dart';
export 'ai_gateway_realtime_session.dart';
export '../src/ai_gateway/ai_gateway_facade.dart'
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

  /// Creates a short-lived Gateway facade for reading account/catalog state.
  /// Routing callers should use [sharedPlatform] to share session affinity.
  static Future<AiGatewayFacade> createPlatform() =>
      implementation.LlmChatRoutingRuntime.createPlatform();

  static AiGatewayProviderCatalog get defaultProviderCatalog =>
      implementation.LlmChatRoutingRuntime.defaultProviderCatalog;
}
