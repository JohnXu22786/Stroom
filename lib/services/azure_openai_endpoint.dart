/// Builds the deployment-specific Chat Completions URL used by Azure AI
/// Foundry and Azure OpenAI API-key accounts.
abstract final class AzureOpenAiEndpoint {
  static const defaultApiVersion = '2024-12-01-preview';

  static Uri chatCompletionsUri({
    required String resourceUrl,
    required String deploymentId,
    required String apiVersion,
  }) {
    final resource = Uri.tryParse(resourceUrl.trim());
    final deployment = deploymentId.trim();
    final version = apiVersion.trim();
    if (resource == null ||
        resource.scheme != 'https' ||
        resource.host.isEmpty ||
        resource.userInfo.isNotEmpty ||
        resource.hasQuery ||
        resource.hasFragment ||
        (resource.path.isNotEmpty && resource.path != '/') ||
        !isAzureResourceHost(resource.host) ||
        deployment.isEmpty ||
        version.isEmpty) {
      throw const FormatException('Invalid Azure deployment endpoint.');
    }
    return resource.replace(
      pathSegments: [
        'openai',
        'deployments',
        deployment,
        'chat',
        'completions',
      ],
      queryParameters: {'api-version': version},
      fragment: null,
    );
  }

  static bool isAzureResourceHost(String host) {
    final normalized = host.toLowerCase();
    return normalized.endsWith('.openai.azure.com') ||
        normalized.endsWith('.services.ai.azure.com') ||
        normalized.endsWith('.cognitiveservices.azure.com');
  }
}
