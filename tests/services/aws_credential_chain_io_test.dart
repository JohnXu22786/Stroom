import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/services/aws_credential_chain_io.dart';

void main() {
  group('AWS credential chain', () {
    test('uses environment credentials before other providers', () async {
      final credentials = await resolveAwsCredentialChain(
        environment: {
          'AWS_ACCESS_KEY_ID': 'environment-access',
          'AWS_SECRET_ACCESS_KEY': 'environment-secret',
          'AWS_SESSION_TOKEN': 'environment-session',
          'AWS_CONTAINER_CREDENTIALS_FULL_URI':
              'http://invalid.example.test/token',
        },
      );

      expect(credentials?.accessKeyId, 'environment-access');
      expect(credentials?.secretAccessKey, 'environment-secret');
      expect(credentials?.sessionToken, 'environment-session');
    });

    test('uses USERPROFILE for shared credentials when HOME is absent',
        () async {
      final home = await Directory.systemTemp.createTemp(
        'stroom-aws-userprofile-',
      );
      addTearDown(() => home.delete(recursive: true));
      final aws = Directory('${home.path}/.aws')..createSync();
      File('${aws.path}/credentials').writeAsStringSync('''[default]
aws_access_key_id = windows-access
aws_secret_access_key = windows-secret
''');

      final credentials = await resolveAwsCredentialChain(
        environment: {
          'USERPROFILE': home.path,
          'AWS_EC2_METADATA_DISABLED': 'true',
        },
      );

      expect(credentials?.accessKeyId, 'windows-access');
      expect(credentials?.secretAccessKey, 'windows-secret');
    });

    test('resolves shared-profile credential_process credentials', () async {
      if (Platform.isWindows) return;
      final home = await Directory.systemTemp.createTemp(
        'stroom-aws-credential-process-',
      );
      addTearDown(() => home.delete(recursive: true));
      final aws = Directory('${home.path}/.aws')..createSync();
      final processFile = File('${home.path}/credentials-command.sh')
        ..writeAsStringSync('''#!/bin/sh
printf '%s\\n' '{"Version":1,"AccessKeyId":"process-access","SecretAccessKey":"process-secret","SessionToken":"process-session"}'
''');
      Process.runSync('chmod', ['700', processFile.path]);
      File('${aws.path}/config').writeAsStringSync('''[profile app]
credential_process = ${processFile.path}
''');

      final credentials = await resolveAwsCredentialChain(
        environment: {
          'AWS_PROFILE': 'app',
          'HOME': home.path,
          'AWS_EC2_METADATA_DISABLED': 'true',
        },
      );

      expect(credentials?.accessKeyId, 'process-access');
      expect(credentials?.secretAccessKey, 'process-secret');
      expect(credentials?.sessionToken, 'process-session');
    });

    test(
      'resolves temporary container credentials with authorization token',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(server.close);
        String? receivedAuthorization;
        server.listen((request) async {
          receivedAuthorization = request.headers.value('Authorization');
          request.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode({
                'AccessKeyId': 'container-access',
                'SecretAccessKey': 'container-secret',
                'Token': 'container-session',
              }),
            );
          await request.response.close();
        });
        final uri =
            'http://${server.address.address}:${server.port}/credentials';

        final credentials = await resolveAwsCredentialChain(
          environment: {
            'AWS_CONTAINER_CREDENTIALS_FULL_URI': uri,
            'AWS_CONTAINER_AUTHORIZATION_TOKEN': 'container-auth-token',
          },
        );
        expect(receivedAuthorization, 'container-auth-token');
        expect(credentials?.accessKeyId, 'container-access');
        expect(credentials?.secretAccessKey, 'container-secret');
        expect(credentials?.sessionToken, 'container-session');
      },
    );

    test(
      'assumes a shared-profile role with source-profile credentials',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(server.close);
        String? receivedForm;
        String? receivedAuthorization;
        server.listen((request) async {
          receivedForm = await utf8.decoder.bind(request).join();
          receivedAuthorization = request.headers.value('Authorization');
          request.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType('text', 'xml')
            ..write(
              '''<AssumeRoleResponse><AssumeRoleResult><Credentials><AccessKeyId>assumed-access</AccessKeyId><SecretAccessKey>assumed-secret</SecretAccessKey><SessionToken>assumed-session</SessionToken></Credentials></AssumeRoleResult></AssumeRoleResponse>''',
            );
          await request.response.close();
        });
        final home = await Directory.systemTemp.createTemp(
          'stroom-aws-profile-',
        );
        addTearDown(() => home.delete(recursive: true));
        final aws = Directory('${home.path}/.aws')..createSync();
        File('${aws.path}/credentials').writeAsStringSync('''[source]
aws_access_key_id = source-access
aws_secret_access_key = source-secret
aws_session_token = source-session
''');
        File('${aws.path}/config').writeAsStringSync('''[profile app]
role_arn = arn:aws:iam::123:role/app
source_profile = source
role_session_name = stroom-test
region = us-east-2
''');

        final credentials = await resolveAwsCredentialChain(
          environment: {
            'AWS_PROFILE': 'app',
            'HOME': home.path,
            'AWS_ENDPOINT_URL_STS':
                'http://${server.address.address}:${server.port}/',
          },
        );

        expect(receivedForm, contains('Action=AssumeRole'));
        expect(
          receivedForm,
          contains('RoleArn=arn%3Aaws%3Aiam%3A%3A123%3Arole%2Fapp'),
        );
        expect(
          receivedAuthorization,
          startsWith('AWS4-HMAC-SHA256 Credential=source-access/'),
        );
        expect(credentials?.accessKeyId, 'assumed-access');
        expect(credentials?.secretAccessKey, 'assumed-secret');
        expect(credentials?.sessionToken, 'assumed-session');
      },
    );

    test('resolves an active AWS SSO profile token from the CLI cache',
        () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);
      String? receivedAuthorization;
      String? receivedQuery;
      server.listen((request) async {
        receivedAuthorization = request.headers.value('Authorization');
        receivedQuery = request.uri.query;
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              'roleCredentials': {
                'accessKeyId': 'sso-access',
                'secretAccessKey': 'sso-secret',
                'sessionToken': 'sso-session',
              },
            }),
          );
        await request.response.close();
      });
      final home = await Directory.systemTemp.createTemp('stroom-aws-sso-');
      addTearDown(() => home.delete(recursive: true));
      final config = Directory('${home.path}/.aws')..createSync();
      File('${config.path}/config').writeAsStringSync('''[profile app]
sso_session = stroom
sso_account_id = 123456789012
sso_role_name = Developer
[sso-session stroom]
sso_start_url = https://example.awsapps.com/start
sso_region = us-east-1
''');
      final cache = Directory('${config.path}/sso/cache')
        ..createSync(recursive: true);
      File('${cache.path}/stroom.json').writeAsStringSync(
        jsonEncode({
          'startUrl': 'https://example.awsapps.com/start',
          'region': 'us-east-1',
          'accessToken': 'cached-sso-token',
          'expiresAt': DateTime.now()
              .toUtc()
              .add(const Duration(hours: 1))
              .toIso8601String(),
        }),
      );

      final credentials = await resolveAwsCredentialChain(
        environment: {
          'AWS_PROFILE': 'app',
          'HOME': home.path,
          'AWS_ENDPOINT_URL_SSO':
              'http://${server.address.address}:${server.port}/federation/credentials',
        },
      );

      expect(receivedAuthorization, 'Bearer cached-sso-token');
      expect(receivedQuery, contains('account_id=123456789012'));
      expect(receivedQuery, contains('role_name=Developer'));
      expect(credentials?.accessKeyId, 'sso-access');
      expect(credentials?.secretAccessKey, 'sso-secret');
      expect(credentials?.sessionToken, 'sso-session');
    });

    test('uses IMDSv2 to resolve an EC2 instance role', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);
      var receivedTokenHeader = false;
      server.listen((request) async {
        if (request.method == 'PUT' &&
            request.uri.path == '/latest/api/token') {
          request.response
            ..statusCode = HttpStatus.ok
            ..write('imds-session-token');
        } else if (request.uri.path.endsWith('/security-credentials/')) {
          receivedTokenHeader =
              request.headers.value('X-aws-ec2-metadata-token') ==
                  'imds-session-token';
          request.response
            ..statusCode = HttpStatus.ok
            ..write('instance-role');
        } else {
          expect(
            request.headers.value('X-aws-ec2-metadata-token'),
            'imds-session-token',
          );
          request.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode({
                'AccessKeyId': 'instance-access',
                'SecretAccessKey': 'instance-secret',
                'Token': 'instance-session',
              }),
            );
        }
        await request.response.close();
      });

      final credentials = await resolveAwsCredentialChain(
        environment: {
          'AWS_EC2_METADATA_SERVICE_ENDPOINT':
              'http://${server.address.address}:${server.port}',
        },
      );

      expect(receivedTokenHeader, isTrue);
      expect(credentials?.accessKeyId, 'instance-access');
      expect(credentials?.secretAccessKey, 'instance-secret');
      expect(credentials?.sessionToken, 'instance-session');
    });

    test('exchanges a web identity token for temporary credentials', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);
      String? receivedForm;
      server.listen((request) async {
        receivedForm = await utf8.decoder.bind(request).join();
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType('text', 'xml')
          ..write(
            '''<AssumeRoleWithWebIdentityResponse><AssumeRoleWithWebIdentityResult><Credentials><AccessKeyId>web-access</AccessKeyId><SecretAccessKey>web-secret</SecretAccessKey><SessionToken>web-session</SessionToken></Credentials></AssumeRoleWithWebIdentityResult></AssumeRoleWithWebIdentityResponse>''',
          );
        await request.response.close();
      });
      final temp = await Directory.systemTemp.createTemp('stroom-aws-chain-');
      addTearDown(() => temp.delete(recursive: true));
      final tokenFile = File('${temp.path}/oidc-token')
        ..writeAsStringSync('oidc-test-token');

      final credentials = await resolveAwsCredentialChain(
        environment: {
          'AWS_ROLE_ARN': 'arn:aws:iam::123:role/app',
          'AWS_WEB_IDENTITY_TOKEN_FILE': tokenFile.path,
          'AWS_ROLE_SESSION_NAME': 'stroom-test',
          'AWS_ENDPOINT_URL_STS':
              'http://${server.address.address}:${server.port}/',
          'AWS_REGION': 'us-east-2',
        },
      );
      expect(receivedForm, contains('Action=AssumeRoleWithWebIdentity'));
      expect(
        receivedForm,
        contains('RoleArn=arn%3Aaws%3Aiam%3A%3A123%3Arole%2Fapp'),
      );
      expect(receivedForm, contains('WebIdentityToken=oidc-test-token'));
      expect(credentials?.accessKeyId, 'web-access');
      expect(credentials?.secretAccessKey, 'web-secret');
      expect(credentials?.sessionToken, 'web-session');
    });
  });
}
