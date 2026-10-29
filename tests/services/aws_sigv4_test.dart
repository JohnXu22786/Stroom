import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/services/aws_sigv4.dart';

void main() {
  group('AwsSigV4', () {
    test('uses the AWS China endpoint suffix for China regions', () {
      expect(
        awsRegionalEndpointHost('sts', 'cn-north-1'),
        'sts.cn-north-1.amazonaws.com.cn',
      );
      expect(
        awsRegionalEndpointHost('bedrock-runtime', 'us-east-1'),
        'bedrock-runtime.us-east-1.amazonaws.com',
      );
    });

    test('signs canonical method, path, query, body and session token', () {
      final credentials = AwsSigV4Credentials(
        accessKeyId: 'AKIDEXAMPLE',
        secretAccessKey: 'wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY',
        sessionToken: 'session-token-example',
      );
      final uri = Uri.parse(
        'https://bedrock-runtime.us-east-1.amazonaws.com/model/'
        'anthropic.claude-v2:invoke?b=two%20words&a=1',
      );
      final headers = AwsSigV4.sign(
        method: 'POST',
        uri: uri,
        region: 'us-east-1',
        service: 'bedrock',
        headers: const {'content-type': 'application/json'},
        payload: Uint8List.fromList(utf8.encode('{"inputText":"hello"}')),
        credentials: credentials,
        now: DateTime.utc(2024, 1, 2, 3, 4, 5),
      );

      expect(
        headers['Authorization'],
        'AWS4-HMAC-SHA256 Credential=AKIDEXAMPLE/20240102/us-east-1/'
        'bedrock/aws4_request, '
        'SignedHeaders=content-type;host;x-amz-content-sha256;x-amz-date;x-amz-security-token, '
        'Signature=97e3a34166faa91f4b0b469b0dcadd3a5638c618729e37fd87c81cbec9287733',
      );
      expect(headers['x-amz-date'], '20240102T030405Z');
      expect(headers['x-amz-security-token'], 'session-token-example');
      expect(headers['host'], uri.host);
    });

    test(
      'reads AWS SDK JSON credential field names including session token',
      () {
        final credentials = AwsSigV4Credentials.fromJson({
          'AccessKeyId': 'uppercase-access',
          'SecretAccessKey': 'uppercase-secret',
          'Token': 'uppercase-session',
        });

        expect(credentials.accessKeyId, 'uppercase-access');
        expect(credentials.secretAccessKey, 'uppercase-secret');
        expect(credentials.sessionToken, 'uppercase-session');
      },
    );

    test('rejects incomplete credentials', () {
      expect(
        () => AwsSigV4.sign(
          method: 'POST',
          uri: Uri.https('bedrock-runtime.us-east-1.amazonaws.com', '/'),
          region: 'us-east-1',
          service: 'bedrock',
          headers: const {},
          payload: Uint8List(0),
          credentials: const AwsSigV4Credentials(
            accessKeyId: '',
            secretAccessKey: 'secret',
          ),
          now: DateTime.utc(2024),
        ),
        throwsArgumentError,
      );
    });
  });
}
