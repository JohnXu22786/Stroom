import 'aws_credential_chain_stub.dart'
    if (dart.library.io) 'aws_credential_chain_io.dart' as platform;
import 'aws_sigv4.dart';

/// Resolves the AWS default credential chain for native clients, including
/// environment/profile credentials, web identity, container/instance roles,
/// shared-profile role assumption, and active SSO login cache credentials.
/// Explicit account credentials take precedence.
abstract final class AwsCredentialChain {
  static Future<AwsSigV4Credentials?> resolve() =>
      platform.resolveAwsCredentialChain();
}
