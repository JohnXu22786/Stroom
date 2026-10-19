import '../models/llm_account.dart';
import '../models/tts_models.dart';
import 'llm_chat_runtime.dart';
import 'llm_connector_service.dart';

/// Namespaced account identity for an OCR provider config that predates
/// account/model-group routing.
String llmOcrAccountIdForConfig(String configId) => 'ocr-$configId';

String llmOcrModelGroupIdForConfig(String configId, String localModelId) =>
    stableLlmModelGroupId(llmOcrAccountIdForConfig(configId), localModelId);

const kLlmModelGroupConfigField = 'stroomLlmModelGroupId';
const kLlmModelCapabilitiesConfigField = 'stroomLlmModelCapabilities';
const kLlmChatAdapterUnsupportedSelectorField =
    'stroomLlmChatAdapterUnsupported';

typedef LlmModelGroupMemberReference = ({String groupId, String localModelId});

/// Parses the opaque model reference synthesized for a custom group's local
/// alias. The group ID embedded in this reference remains stable when the
/// group's display name changes.
LlmModelGroupMemberReference? llmModelGroupMemberReferenceForModelId(
  String? modelId,
) {
  const prefix = 'stroom.model-group-member.';
  if (modelId == null || !modelId.startsWith(prefix)) return null;

  var offset = prefix.length;
  String? readLengthPrefixedPart() {
    final separator = modelId.indexOf(':', offset);
    if (separator <= offset) return null;
    final length = int.tryParse(modelId.substring(offset, separator));
    if (length == null || length < 1) return null;
    offset = separator + 1;
    final end = offset + length;
    if (end > modelId.length) return null;
    final value = modelId.substring(offset, end);
    offset = end;
    return value;
  }

  final groupId = readLengthPrefixedPart();
  final localModelId = readLengthPrefixedPart();
  if (groupId == null || localModelId == null || offset != modelId.length) {
    return null;
  }
  return (groupId: groupId, localModelId: localModelId);
}

/// Tags legacy selector rows for accounts whose native connector cannot be
/// executed by ChatAdapter. Their account and model records remain available
/// in account management, but these rows must not offer a direct chat path.
List<ProviderConfigItem> markUnsupportedLegacyLlmConfigs(
  Iterable<ProviderConfigItem> configs,
  Iterable<LlmAccount> accounts,
) {
  final unsupportedIds = accounts
      .where(
        (account) =>
            llmChatEndpointTypeForConnector(account.connectorType) == null,
      )
      .map((account) => account.id)
      .toSet();
  return configs
      .map((config) {
        if (isLlmModelGroupProviderConfig(config) ||
            !unsupportedIds.contains(config.id) ||
            config.legacyFields[kLlmChatAdapterUnsupportedSelectorField] ==
                true) {
          return config;
        }
        return ProviderConfigItem.fromMap({
          ...config.toMap(),
          kLlmChatAdapterUnsupportedSelectorField: true,
        });
      })
      .toList(growable: false);
}

bool isUnsupportedLegacyLlmSelectorConfig(ProviderConfigItem config) =>
    config.legacyFields[kLlmChatAdapterUnsupportedSelectorField] == true;

/// Persists an OCR provider's namespaced account and stable model groups while
/// its source config still contains the endpoint and credential.
Future<void> ensureLegacyOcrProviderConfigGroups({
  required LlmChatRoutingRuntime runtime,
  required ProviderConfigItem config,
  ProviderConfigItem? previousConfig,
}) async {
  final accountId = llmOcrAccountIdForConfig(config.id);
  final previousModels = {
    for (final model in previousConfig?.models ?? const <ModelConfig>[])
      model.id.trim(): model,
  };
  for (final model in config.models) {
    final localModelId = model.id.trim();
    final upstreamModelId = model.modelId.trim().isEmpty
        ? localModelId
        : model.modelId.trim();
    final previousModel = previousModels[localModelId];
    if (localModelId.isEmpty || upstreamModelId.isEmpty) continue;
    await runtime.ensureLegacyOcrModelGroup(
      accountId: accountId,
      groupId: llmOcrModelGroupIdForConfig(config.id, localModelId),
      localModelId: localModelId,
      upstreamModelId: upstreamModelId,
      displayName: model.name.trim().isEmpty ? config.providerName : model.name,
      baseUrl: config.host,
      apiKey: config.key,
      synchronizeEndpoint:
          previousConfig != null && previousConfig.host != config.host,
      synchronizeCredential:
          previousConfig != null && previousConfig.key != config.key,
      synchronizeModel:
          previousModel != null &&
          (previousModel.modelId != model.modelId ||
              previousModel.name != model.name),
    );
  }
}

bool llmModelConfigSupportsCapability(ModelConfig model, String capability) {
  final capabilities = model.legacyFields[kLlmModelCapabilitiesConfigField];
  return capabilities is Map && capabilities[capability] == true;
}

/// Identifies an in-memory provider entry synthesized from a persisted model
/// group. These entries are selector adapters only; credentials and endpoint
/// configuration remain in the account store.
String? llmModelGroupIdForConfig(ProviderConfigItem config) {
  final value = config.legacyFields[kLlmModelGroupConfigField];
  return value is String && value.isNotEmpty ? value : null;
}

bool isLlmModelGroupProviderConfig(ProviderConfigItem config) =>
    llmModelGroupIdForConfig(config) != null;

/// Builds selector-compatible model configs for groups that use protocols
/// supported by ChatService and OCR. Their IDs retain the M1 group and local
/// model identities, while requests are resolved against the account store.
List<ProviderConfigItem> buildLlmModelGroupProviderConfigs({
  required List<LlmAccount> accounts,
  required List<LlmModelGroup> groups,
}) {
  final accountById = {for (final account in accounts) account.id: account};
  final configs = <ProviderConfigItem>[];

  LlmUpstreamModel? resolveMemberModel(
    LlmAccount account,
    LlmModelGroupMember member,
  ) {
    // Routing selects by upstream ID and uses the first matching account
    // model. Project the same model's capabilities so selectors don't
    // advertise a capability that the routed request will reject.
    return account.models
        .where((model) => model.upstreamModelId == member.upstreamModelId)
        .firstOrNull;
  }

  for (final group in groups) {
    final aliases = <String>{
      for (final member in group.members) member.localModelId ?? group.id,
    };
    final models = <ModelConfig>[];
    String? providerName;
    String? endpointType;

    for (final localModelId in aliases) {
      final members = group.members
          .where((member) => (member.localModelId ?? group.id) == localModelId)
          .toList(growable: false);
      if (members.isEmpty) continue;
      // Prefer the member that generated M1's stable group ID. This keeps the
      // existing `(providerName, modelId)` conversation identity intact when
      // that model is now backed by a multi-account group.
      final preferred = members.cast<LlmModelGroupMember?>().firstWhere(
        (member) =>
            stableLlmModelGroupId(member!.accountId, localModelId) == group.id,
        orElse: () => null,
      );
      final orderedMembers = [
        if (preferred != null) preferred,
        ...members.where((member) => member != preferred),
      ];

      LlmAccount? representativeAccount;
      LlmUpstreamModel? representativeModel;
      String? representativeEndpointType;
      for (final member in orderedMembers) {
        final account = accountById[member.accountId];
        if (account == null) continue;
        final endpoint = llmChatEndpointTypeForConnector(account.connectorType);
        if (endpoint == null) continue;
        final model = resolveMemberModel(account, member);
        if (model == null) continue;
        representativeAccount = account;
        representativeModel = model;
        representativeEndpointType = endpoint;
        break;
      }
      if (representativeAccount == null || representativeModel == null) {
        continue;
      }

      final legacyLocalModelId = stableLlmModelGroupLocalModelId(group.id);
      final isStableGroupAnchor =
          group.id ==
          stableLlmModelGroupId(representativeAccount.id, localModelId);
      final keepsLegacyIdentity =
          isStableGroupAnchor ||
          (group.legacyProviderName != null &&
              legacyLocalModelId == localModelId);
      final supportsVision = members.any((member) {
        final account = accountById[member.accountId];
        if (account == null ||
            llmChatEndpointTypeForConnector(account.connectorType) !=
                'openai') {
          return false;
        }
        final model = resolveMemberModel(account, member);
        return model?.capabilities['vision'] == true;
      });
      final supportsStreaming = members.any((member) {
        final account = accountById[member.accountId];
        if (account == null ||
            llmChatEndpointTypeForConnector(account.connectorType) == null) {
          return false;
        }
        final model = resolveMemberModel(account, member);
        return model?.capabilities['streaming'] == true;
      });
      final rawModel = Map<String, dynamic>.from(representativeModel.config)
        ..['id'] = localModelId
        // Stable groups can use their saved name without changing their old
        // provider/model identity. A custom group uses "model | group".
        ..['name'] = keepsLegacyIdentity
            ? group.displayName
            : representativeModel.displayName.isNotEmpty
            ? representativeModel.displayName
            : group.displayName
        ..['modelId'] = keepsLegacyIdentity
            ? group.legacyModelId ?? representativeModel.upstreamModelId
            : _modelGroupMemberReference(group.id, localModelId)
        ..[kLlmModelCapabilitiesConfigField] = {
          'vision': supportsVision,
          'streaming': supportsStreaming,
        };
      final model = ModelConfig.fromMap(rawModel);
      model.endpointType = representativeEndpointType;
      models.add(model);
      providerName ??=
          group.legacyProviderName ??
          (keepsLegacyIdentity
              ? representativeAccount.displayName
              : group.displayName);
      endpointType ??= representativeEndpointType;
    }

    if (models.isEmpty) continue;
    configs.add(
      ProviderConfigItem(
        id: group.id,
        providerName: providerName ?? group.displayName,
        // Endpoint and credential are deliberately absent. Runtime requests
        // obtain both from the exact routed account.
        models: models,
        endpointType: endpointType ?? 'openai',
        legacyFields: {kLlmModelGroupConfigField: group.id},
      ),
    );
  }
  return configs;
}

String? stableLlmModelGroupLocalModelId(String groupId) {
  const prefix = 'stroom.model-group.';
  if (!groupId.startsWith(prefix)) return null;
  final accountLengthEnd = groupId.indexOf(':', prefix.length);
  if (accountLengthEnd < 0) return null;
  final accountLength = int.tryParse(
    groupId.substring(prefix.length, accountLengthEnd),
  );
  if (accountLength == null || accountLength < 1) return null;
  final accountStart = accountLengthEnd + 1;
  final accountEnd = accountStart + accountLength;
  if (accountEnd >= groupId.length) return null;
  final localLengthEnd = groupId.indexOf(':', accountEnd);
  if (localLengthEnd < 0) return null;
  final localLength = int.tryParse(
    groupId.substring(accountEnd, localLengthEnd),
  );
  if (localLength == null || localLength < 1) return null;
  final localStart = localLengthEnd + 1;
  final localEnd = localStart + localLength;
  if (localEnd != groupId.length) return null;
  try {
    return Uri.decodeComponent(groupId.substring(localStart, localEnd));
  } on FormatException {
    return null;
  }
}

String _modelGroupMemberReference(String groupId, String localModelId) =>
    'stroom.model-group-member.${groupId.length}:$groupId'
    '${localModelId.length}:$localModelId';

String? llmChatEndpointTypeForConnector(String connectorType) =>
    LlmConnectorRegistry.chatAdapterEndpointType(connectorType);
