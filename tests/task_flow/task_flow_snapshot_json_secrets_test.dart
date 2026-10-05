import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/assistant.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/task_flow/models/block_type_definition.dart';
import 'package:stroom/task_flow/models/flow_launch_snapshot.dart';
import 'package:stroom/task_flow/models/task_flow_definition.dart';
import 'package:stroom/utils/provider_models.dart';

void main() {
  ProviderEntriesState modelProviders(String secret, String tuning) =>
      ProviderEntriesState(entries: [
        ProviderEntry(id: 'entry', type: 'tts', name: 'TTS', configs: [
          ProviderConfigItem(
              id: 'config',
              providerName: 'TTS',
              host: 'https://example.com',
              key: 'live-key',
              typeConfig: {
                'headers': jsonEncode(
                    {'Authorization': 'Bearer $secret', 'temperature': tuning})
              },
              models: [
                ModelConfig(
                    id: 'model',
                    name: 'Voice',
                    modelId: 'voice-api',
                    typeConfig: {
                      'headers': jsonEncode({
                        'Authorization': 'Bearer $secret',
                        'temperature': tuning
                      })
                    },
                    customParams: [
                      CustomParam(
                          paramName: 'headers',
                          type: 'json',
                          defaultValue: jsonEncode({
                            'Authorization': 'Bearer $secret',
                            'temperature': tuning
                          }),
                          options: [
                            jsonEncode(
                                {'X-API-Key': secret, 'temperature': tuning})
                          ],
                          optionOrder: [
                            jsonEncode(
                                {'X-API-Key': secret, 'temperature': tuning})
                          ])
                    ],
                    reasoningParams: [
                      ReasoningParam(
                          paramName: 'reasoning',
                          type: 'json',
                          options: [
                            jsonEncode(
                                {'Authorization': secret, 'effort': tuning})
                          ])
                    ])
              ])
        ])
      ]);

  final flow = TaskFlowDefinition(blocks: [
    TaskFlowBlock(typeKey: BlockType.tts, params: {
      'modelRef': {'configId': 'config', 'modelId': 'model'}
    })
  ]);

  const launchCallback =
      'https://launch.example/callback?region=launch#region=launch&access_token=old-fragment-secret';
  const liveCallback =
      'https://edited.example/changed?region=edited#region=edited&access_token=fresh-fragment-secret';
  const fragmentNote =
      'Explain #access_token=ordinary-text without changing it';

  test(
    'fragment URLs redact saved values and hydrate config and model callbacks',
    () {
      ProviderEntriesState callbacks(String url, String tuning) {
        final providers = modelProviders('json-secret', tuning);
        final config = providers.entries.single.configs.single;
        for (final settings in [
          config.typeConfig,
          config.models.single.typeConfig,
        ]) {
          settings['callback'] = url;
          settings['routing'] = jsonEncode({'callback': url, 'tuning': tuning});
          settings['plainNote'] = fragmentNote;
        }
        config.models.single.customParams.addAll([
          CustomParam(
            paramName: 'callback',
            type: 'string',
            defaultValue: url,
            options: [url],
            optionOrder: [url],
          ),
          CustomParam(
            paramName: 'request',
            type: 'json',
            defaultValue: jsonEncode({'callback': url, 'tuning': tuning}),
          ),
          CustomParam(
            paramName: 'note',
            type: 'string',
            defaultValue: fragmentNote,
          ),
        ]);
        return providers;
      }

      final launched = callbacks(launchCallback, '0.5');
      final snapshot = FlowLaunchSnapshot.capture(flow, launched, []);
      expect(
        jsonEncode(snapshot.toMap()),
        isNot(contains('old-fragment-secret')),
      );
      final restored = FlowLaunchSnapshot.fromMap(snapshot.toMap());

      void verify(ProviderEntriesState live, String expectedCallback) {
        final resolved = resolveProviderModel(
          restored.resolveProviders(live),
          'tts',
          flow.blocks.single.params['modelRef'],
        )!;
        for (final settings in [
          resolved.config.typeConfig,
          resolved.model.typeConfig,
        ]) {
          expect(settings['callback'], expectedCallback);
          expect(jsonDecode(settings['routing'] as String), {
            'callback': expectedCallback,
            'tuning': '0.5',
          });
          expect(settings['plainNote'], fragmentNote);
        }
        final params = resolved.model.customParams;
        final callback = params.singleWhere(
          (param) => param.paramName == 'callback',
        );
        for (final value in [
          callback.defaultValue,
          callback.options.single,
          callback.optionOrder.single,
        ]) {
          expect(value, expectedCallback);
        }
        expect(
          jsonDecode(
            params
                .singleWhere((param) => param.paramName == 'request')
                .defaultValue,
          ),
          {'callback': expectedCallback, 'tuning': '0.5'},
        );
        expect(
          params.singleWhere((param) => param.paramName == 'note').defaultValue,
          fragmentNote,
        );
      }

      verify(launched, launchCallback);
      final expected = Uri.parse(launchCallback)
          .replace(fragment: Uri.parse(liveCallback).fragment)
          .toString();
      verify(callbacks(liveCallback, '0.9'), expected);
      expect(
        () => restored.resolveProviders(
          callbacks(Uri.parse(liveCallback).removeFragment().toString(), '0.9'),
        ),
        throwsStateError,
      );
    },
  );

  test('assistant fragment callbacks hydrate string and JSON values', () {
    Assistant callbacks(String url, String tuning) => Assistant(
          id: 'assistant',
          name: 'Assistant',
          prompt: 'Help',
          settings: AssistantSettings(
            customParameters: [
              CustomParameter(name: 'callback', type: 'string', value: url),
              CustomParameter(
                name: 'request',
                type: 'json',
                value: jsonEncode({'callback': url, 'tuning': tuning}),
              ),
              CustomParameter(
                  name: 'note', type: 'string', value: fragmentNote),
            ],
          ),
        );
    final chatFlow = TaskFlowDefinition(
      blocks: [
        TaskFlowBlock(
          typeKey: BlockType.chat,
          params: {'assistantId': 'assistant'},
        ),
      ],
    );
    final launched = callbacks(launchCallback, '0.5');
    final snapshot = FlowLaunchSnapshot.capture(
      chatFlow,
      const ProviderEntriesState(),
      [launched],
    );
    expect(
      jsonEncode(snapshot.toMap()),
      isNot(contains('old-fragment-secret')),
    );
    final restored = FlowLaunchSnapshot.fromMap(snapshot.toMap());

    void verify(Assistant live, String expectedCallback) {
      final params =
          restored.resolveAssistants([live]).single.settings.customParameters;
      expect(
        params.singleWhere((param) => param.name == 'callback').value,
        expectedCallback,
      );
      expect(
        jsonDecode(
          params.singleWhere((param) => param.name == 'request').value
              as String,
        ),
        {'callback': expectedCallback, 'tuning': '0.5'},
      );
      expect(
        params.singleWhere((param) => param.name == 'note').value,
        fragmentNote,
      );
    }

    verify(launched, launchCallback);
    final expected = Uri.parse(launchCallback)
        .replace(fragment: Uri.parse(liveCallback).fragment)
        .toString();
    verify(callbacks(liveCallback, '0.9'), expected);
    expect(
      () => restored.resolveAssistants([
        callbacks(Uri.parse(liveCallback).removeFragment().toString(), '0.9'),
      ]),
      throwsStateError,
    );
  });

  for (final encoded in [false, true]) {
    test(
        'removed ${encoded ? 'encoded' : 'direct'} invalid JSON setting cannot run',
        () {
      const malformed = '{"Authorization":"old-malformed-secret"';
      final old = modelProviders('old-json-secret', '0.5');
      final launchConfig = old.entries.single.configs.single;
      if (encoded) {
        launchConfig.typeConfig['routing'] = jsonEncode({
          'headers': malformed,
          'region': 'launch',
        });
      } else {
        launchConfig.typeConfig['headers'] = malformed;
      }
      final snapshot = FlowLaunchSnapshot.capture(flow, old, []);
      expect(jsonEncode(snapshot.toMap()),
          isNot(contains('old-malformed-secret')));
      final restored = FlowLaunchSnapshot.fromMap(snapshot.toMap());
      final live = modelProviders('fresh-json-secret', '0.9');
      final liveConfig = live.entries.single.configs.single;
      if (encoded) {
        liveConfig.typeConfig['routing'] = jsonEncode({'region': 'edited'});
      } else {
        liveConfig.typeConfig.remove('headers');
      }

      expect(() => restored.resolveProviders(live), throwsStateError);

      if (encoded) {
        liveConfig.typeConfig['routing'] = jsonEncode({
          'headers': jsonEncode({'Authorization': 'fresh-header-secret'}),
          'region': 'edited',
        });
      } else {
        liveConfig.typeConfig['headers'] =
            jsonEncode({'Authorization': 'fresh-header-secret'});
      }
      final resolved = restored.resolveProviders(live);
      final config = resolved.entries.single.configs.single;
      final headers = encoded
          ? (jsonDecode(config.typeConfig['routing'] as String)
              as Map)['headers']
          : config.typeConfig['headers'];
      expect(jsonDecode(headers as String),
          {'Authorization': 'fresh-header-secret'});
    });
  }

  for (final (vendor, keys) in [
    ('AWS', ['X-Amz-Signature', 'X-Amz-Credential', 'X-Amz-Security-Token']),
    ('Google', ['X-Goog-Signature', 'X-Goog-Credential']),
  ]) {
    final dateKey = keys.first.replaceFirst('Signature', 'Date');
    final expiresKey = keys.first.replaceFirst('Signature', 'Expires');
    String signedUrl(String version) {
      final query = {
        'region': 'launch',
        dateKey: '20261003T120000Z',
        expiresKey: '900',
        for (var i = 0; i < keys.length; i++) keys[i]: '$version-private-$i',
      };
      return Uri.https(
        'signed.example',
        '/resource',
        version == 'fresh'
            ? Map.fromEntries(query.entries.toList().reversed)
            : query,
      ).toString();
    }

    ProviderEntriesState endpointProviders(String url) {
      final providers = modelProviders('json-secret', '0.5');
      providers.entries.single.configs.single.host = url;
      return providers;
    }

    String optionUrl(String id, String version) {
      final uri = Uri.parse(signedUrl(version));
      final query = {
        ...uri.queryParametersAll,
        'route': ['zeta', 'alpha', 'alpha'],
        for (var i = 0; i < keys.length; i++)
          keys[i]: ['$version-$id-private-$i'],
      };
      return uri
          .replace(
            host: '$id.signed.example',
            path: '/$id',
            queryParameters: version == 'fresh'
                ? Map.fromEntries(query.entries.toList().reversed.map(
                      (entry) =>
                          MapEntry(entry.key, entry.value.reversed.toList()),
                    ))
                : query,
          )
          .toString();
    }

    test('$vendor signed URL credentials refresh with reordered signing inputs',
        () {
      ProviderEntriesState withSignedEndpoint(String version) {
        final providers = modelProviders('$version-json-secret', version);
        final config = providers.entries.single.configs.single;
        final url = signedUrl(version);
        config.host = url;
        config.typeConfig['callback'] = url;
        config.typeConfig['routing'] = jsonEncode({
          'url': url,
          'region': version,
        });
        config.models.single.customParams.addAll([
          CustomParam(
            paramName: 'endpoint',
            type: 'string',
            defaultValue: url,
            options: [url],
            optionOrder: [url],
          ),
          CustomParam(
            paramName: 'request',
            type: 'json',
            defaultValue: jsonEncode({'callback': url, 'region': version}),
          ),
        ]);
        return providers;
      }

      final snapshot = FlowLaunchSnapshot.capture(
        flow,
        withSignedEndpoint('old'),
        [],
      );
      final saved = jsonEncode(snapshot.toMap());
      for (var i = 0; i < keys.length; i++) {
        expect(saved, isNot(contains('old-private-$i')), reason: keys[i]);
      }
      final restored = FlowLaunchSnapshot.fromMap(snapshot.toMap());
      final resolved = resolveProviderModel(
        restored.resolveProviders(withSignedEndpoint('fresh')),
        'tts',
        flow.blocks.single.params['modelRef'],
      )!;

      void verifyUrl(String value) {
        final uri = Uri.parse(value);
        expect(uri.host, 'signed.example');
        expect(uri.path, '/resource');
        expect(uri.queryParameters['region'], 'launch');
        expect(uri.queryParameters[dateKey], '20261003T120000Z');
        expect(uri.queryParameters[expiresKey], '900');
        for (var i = 0; i < keys.length; i++) {
          expect(uri.queryParameters[keys[i]], 'fresh-private-$i');
        }
      }

      verifyUrl(resolved.config.host);
      verifyUrl(resolved.config.typeConfig['callback'] as String);
      final routing =
          jsonDecode(resolved.config.typeConfig['routing'] as String) as Map;
      verifyUrl(routing['url'] as String);
      expect(routing['region'], 'old');
      final endpoint = resolved.model.customParams.singleWhere(
        (param) => param.paramName == 'endpoint',
      );
      for (final value in [
        endpoint.defaultValue,
        endpoint.options.single,
        endpoint.optionOrder.single,
      ]) {
        verifyUrl(value);
      }
      final request = jsonDecode(
        resolved.model.customParams
            .singleWhere((param) => param.paramName == 'request')
            .defaultValue,
      ) as Map;
      verifyUrl(request['callback'] as String);
      expect(request['region'], 'old');
    });

    for (final encoded in [false, true]) {
      test('$vendor reordered signed URL options hydrate with encoded=$encoded',
          () {
        String option(String id, String version) {
          final url = optionUrl(id, version);
          return encoded
              ? jsonEncode({
                  'routing': jsonEncode({'url': url})
                })
              : url;
        }

        ProviderEntriesState options(String version) {
          final providers = modelProviders('json-secret', '0.5');
          final ids =
              version == 'fresh' ? ['second', 'first'] : ['first', 'second'];
          providers.entries.single.configs.single.models.single.customParams
              .add(CustomParam(
            paramName: 'endpoints',
            type: encoded ? 'json' : 'string',
            defaultValue: option('first', version),
            options: [for (final id in ids) option(id, version)],
            optionOrder: [for (final id in ids.reversed) option(id, version)],
          ));
          return providers;
        }

        final snapshot = FlowLaunchSnapshot.fromMap(FlowLaunchSnapshot.capture(
          flow,
          options('old'),
          [],
        ).toMap());
        final saved = jsonEncode(snapshot.toMap());
        expect(saved, isNot(contains('old-first-private')));
        expect(saved, isNot(contains('old-second-private')));
        final resolved = resolveProviderModel(
          snapshot.resolveProviders(options('fresh')),
          'tts',
          flow.blocks.single.params['modelRef'],
        )!
            .model
            .customParams
            .last;

        void verifyOption(String value, String id) {
          final url = encoded
              ? (jsonDecode((jsonDecode(value) as Map)['routing'] as String)
                  as Map)['url'] as String
              : value;
          final launch = Uri.parse(optionUrl(id, 'old'));
          final expected = launch.replace(queryParameters: {
            ...launch.queryParametersAll,
            for (var i = 0; i < keys.length; i++)
              keys[i]: ['fresh-$id-private-$i'],
          });
          expect(url, expected.toString());
          expect(Uri.parse(url).queryParametersAll['route'],
              ['zeta', 'alpha', 'alpha']);
        }

        verifyOption(resolved.defaultValue, 'first');
        verifyOption(resolved.options[0], 'first');
        verifyOption(resolved.options[1], 'second');
        verifyOption(resolved.optionOrder[0], 'second');
        verifyOption(resolved.optionOrder[1], 'first');
      });
    }

    test('$vendor query reordering cannot distinguish ambiguous URL options',
        () {
      ProviderEntriesState options(bool rotate) {
        final providers = modelProviders('json-secret', '0.5');
        final urls = [optionUrl('first', 'old'), optionUrl('first', 'fresh')];
        providers.entries.single.configs.single.models.single.customParams
            .add(CustomParam(
          paramName: 'endpoints',
          type: 'string',
          options: [
            for (final url in urls)
              if (rotate)
                Uri.parse(url).replace(queryParameters: {
                  ...Uri.parse(url).queryParametersAll,
                  for (var i = 0; i < keys.length; i++) keys[i]: ['rotated-$i'],
                }).toString()
              else
                url,
          ],
        ));
        return providers;
      }

      final snapshot = FlowLaunchSnapshot.fromMap(FlowLaunchSnapshot.capture(
        flow,
        options(false),
        [],
      ).toMap());
      expect(() => snapshot.resolveProviders(options(true)), throwsStateError);
    });

    final signingInputsChanged = throwsA(isA<StateError>().having(
      (error) => error.message,
      'message',
      allOf(contains('签名'), contains('最新配置'), contains('重新运行')),
    ));
    for (final changedKey in [dateKey, expiresKey, 'region']) {
      test('$vendor signed URL rejects changed $changedKey', () {
        final snapshot = FlowLaunchSnapshot.fromMap(FlowLaunchSnapshot.capture(
          flow,
          endpointProviders(signedUrl('old')),
          [],
        ).toMap());
        final live = Uri.parse(signedUrl('fresh'));
        final changed = live.replace(queryParameters: {
          ...live.queryParameters,
          changedKey: changedKey == dateKey ? '20261003T130000Z' : '1800',
        });

        expect(
          () =>
              snapshot.resolveProviders(endpointProviders(changed.toString())),
          signingInputsChanged,
        );
      });
    }

    for (final (field, change) in <(String, Uri Function(Uri))>[
      ('scheme', (uri) => uri.replace(scheme: 'http')),
      ('host', (uri) => uri.replace(host: 'changed.example')),
      ('port', (uri) => uri.replace(port: 8443)),
      ('path', (uri) => uri.replace(path: '/changed')),
    ]) {
      test('$vendor signed URL rejects changed destination $field', () {
        final snapshot = FlowLaunchSnapshot.fromMap(FlowLaunchSnapshot.capture(
          flow,
          endpointProviders(signedUrl('old')),
          [],
        ).toMap());
        final changed = change(Uri.parse(signedUrl('fresh')));

        expect(
          () =>
              snapshot.resolveProviders(endpointProviders(changed.toString())),
          signingInputsChanged,
        );
      });
    }

    test('$vendor newly signed URL rejects changed public query inputs', () {
      final launch = Uri.parse(signedUrl('old'));
      final snapshot = FlowLaunchSnapshot.fromMap(FlowLaunchSnapshot.capture(
        flow,
        endpointProviders(launch.replace(queryParameters: {
          for (final entry in launch.queryParameters.entries)
            if (!keys.contains(entry.key)) entry.key: entry.value,
        }).toString()),
        [],
      ).toMap());
      final live = Uri.parse(signedUrl('fresh'));

      expect(
        () => snapshot.resolveProviders(endpointProviders(live.replace(
          queryParameters: {...live.queryParameters, expiresKey: '1800'},
        ).toString())),
        signingInputsChanged,
      );
    });
  }

  test('JSON model and provider parameters redact then hydrate by identity',
      () {
    final snapshot = FlowLaunchSnapshot.capture(
        flow, modelProviders('old-secret', '0.5'), []);
    final encoded = jsonEncode(snapshot.toMap());
    expect(encoded, isNot(contains('old-secret')));
    expect(encoded, contains('temperature'));

    final restored = FlowLaunchSnapshot.fromMap(snapshot.toMap());
    expect(jsonEncode(restored.toMap()), isNot(contains('old-secret')));
    final hydrated = resolveProviderModel(
        restored.resolveProviders(modelProviders('fresh-secret', '0.9')),
        'tts',
        flow.blocks.single.params['modelRef'])!;
    final configHeaders =
        jsonDecode(hydrated.config.typeConfig['headers'] as String) as Map;
    expect(configHeaders,
        {'Authorization': 'Bearer fresh-secret', 'temperature': '0.5'});
    expect(jsonDecode(hydrated.model.typeConfig['headers'] as String),
        {'Authorization': 'Bearer fresh-secret', 'temperature': '0.5'});
    final param = hydrated.model.customParams.single;
    expect(jsonDecode(param.defaultValue),
        {'Authorization': 'Bearer fresh-secret', 'temperature': '0.5'});
    expect(jsonDecode(param.options.single),
        {'X-API-Key': 'fresh-secret', 'temperature': '0.5'});
    expect(jsonDecode(param.optionOrder.single),
        {'X-API-Key': 'fresh-secret', 'temperature': '0.5'});
    expect(jsonDecode(hydrated.model.reasoningParams.single.options.single),
        {'Authorization': 'fresh-secret', 'effort': '0.5'});

    final duplicated = modelProviders('fresh-secret', '0.9');
    duplicated.entries.single.configs.single.models.single.customParams.add(
      CustomParam(
        paramName: 'headers',
        type: 'json',
        defaultValue: jsonEncode({'Authorization': 'another-secret'}),
      ),
    );
    expect(() => restored.resolveProviders(duplicated), throwsStateError);
  });

  test('launch endpoint stays frozen while URL and JSON credentials are fresh',
      () {
    ProviderEntriesState withEndpoint(
        String host, String secret, String tuning) {
      final providers = modelProviders(secret, tuning);
      final config = providers.entries.single.configs.single;
      config.host = host;
      config.typeConfig['apiSecret'] = secret;
      config.typeConfig['url'] = host;
      config.typeConfig['serverAddress'] = host;
      config.typeConfig['routing'] = jsonEncode({
        'refreshToken': secret,
        'endpointUrl': host,
        'timeout': tuning,
      });
      config.typeConfig['routingArray'] = jsonEncode([
        {'id': 'primary', 'url': host, 'timeout': tuning},
      ]);
      config.models.single.typeConfig['apiSecret'] = secret;
      config.models.single.customParams.add(CustomParam(
        paramName: 'refreshToken',
        defaultValue: secret,
      ));
      return providers;
    }

    final old = withEndpoint(
      'https://old-user:old-pass@launch.example/v1?region=launch&apiSecret=old-url-secret&refreshToken=old-refresh#old-fragment',
      'old-json-secret',
      '0.5',
    );
    final snapshot = FlowLaunchSnapshot.capture(flow, old, []);
    final saved = jsonEncode(snapshot.toMap());
    for (final secret in [
      'old-user',
      'old-pass',
      'old-url-secret',
      'old-refresh',
      'old-fragment',
      'old-json-secret',
    ]) {
      expect(saved, isNot(contains(secret)));
    }
    expect(saved, contains('launch.example'));
    expect(saved, contains('region=launch'));

    final live = withEndpoint(
      'https://new-user:new-pass@edited.example/v2?region=edited&apiSecret=fresh-url-secret&refreshToken=fresh-refresh#fresh-fragment',
      'fresh-json-secret',
      '0.9',
    );
    final restored = FlowLaunchSnapshot.fromMap(snapshot.toMap());
    final config = resolveProviderModel(
      restored.resolveProviders(live),
      'tts',
      flow.blocks.single.params['modelRef'],
    )!
        .config;
    final endpoint = Uri.parse(config.host);
    expect(endpoint.host, 'launch.example');
    expect(endpoint.path, '/v1');
    expect(endpoint.userInfo, 'new-user:new-pass');
    expect(endpoint.queryParameters['region'], 'launch');
    expect(endpoint.queryParameters['apiSecret'], 'fresh-url-secret');
    expect(endpoint.queryParameters['refreshToken'], 'fresh-refresh');
    expect(endpoint.fragment, 'fresh-fragment');
    expect(config.typeConfig['apiSecret'], 'fresh-json-secret');
    expect(config.typeConfig['url'], config.host);
    expect(config.typeConfig['serverAddress'], config.host);
    expect(jsonDecode(config.typeConfig['routing'] as String), {
      'refreshToken': 'fresh-json-secret',
      'endpointUrl': config.host,
      'timeout': '0.5',
    });
    expect(jsonDecode(config.typeConfig['routingArray'] as String), [
      {'id': 'primary', 'url': config.host, 'timeout': '0.5'},
    ]);
    expect(config.models.single.typeConfig['apiSecret'], 'fresh-json-secret');
    expect(
        config.models.single.customParams
            .where((param) => param.paramName == 'refreshToken')
            .single
            .defaultValue,
        'fresh-json-secret');

    live.entries.single.configs.single.host = 'https://edited.example/v2';
    expect(() => restored.resolveProviders(live), throwsStateError);
  });

  test('legacy snapshot without host uses the current endpoint', () {
    final old = modelProviders('old-secret', '0.5');
    final snapshot = FlowLaunchSnapshot.capture(flow, old, []);
    final legacy = snapshot.toMap();
    (legacy['configs'] as List).single.remove('host');
    final current = modelProviders('fresh-secret', '0.9');
    current.entries.single.configs.single.host = 'https://current.example/v2';

    final resolved =
        FlowLaunchSnapshot.fromMap(legacy).resolveProviders(current);
    expect(resolved.entries.single.configs.single.host,
        'https://current.example/v2');
  });

  test('string custom URL parameters omit secrets and hydrate by name', () {
    const oldUrl =
        'https://old-user:old-pass@launch.example/v1?region=launch&apiSecret=old-token';
    const liveUrl =
        'https://new-user:new-pass@edited.example/v2?region=edited&apiSecret=fresh-token';
    final old = modelProviders('old-secret', '0.5');
    old.entries.single.configs.single.models.single.customParams
        .add(CustomParam(
      paramName: 'endpoint',
      type: 'string',
      defaultValue: oldUrl,
      options: [oldUrl],
      optionOrder: [oldUrl],
    ));
    final snapshot = FlowLaunchSnapshot.capture(flow, old, []);
    final saved = jsonEncode(snapshot.toMap());
    expect(saved, isNot(contains('old-user')));
    expect(saved, isNot(contains('old-pass')));
    expect(saved, isNot(contains('old-token')));

    final live = modelProviders('fresh-secret', '0.9');
    live.entries.single.configs.single.models.single.customParams
        .add(CustomParam(
      paramName: 'endpoint',
      type: 'string',
      defaultValue: liveUrl,
      options: [liveUrl],
      optionOrder: [liveUrl],
    ));
    final resolved = resolveProviderModel(
      FlowLaunchSnapshot.fromMap(snapshot.toMap()).resolveProviders(live),
      'tts',
      flow.blocks.single.params['modelRef'],
    )!;
    final endpoint = resolved.model.customParams.last;
    for (final value in [
      endpoint.defaultValue,
      endpoint.options.single,
      endpoint.optionOrder.single,
    ]) {
      final uri = Uri.parse(value);
      expect(uri.host, 'launch.example');
      expect(uri.path, '/v1');
      expect(uri.queryParameters['region'], 'launch');
      expect(uri.queryParameters['apiSecret'], 'fresh-token');
      expect(uri.userInfo, 'new-user:new-pass');
    }

    live.entries.single.configs.single.models.single.customParams.removeLast();
    expect(() => snapshot.resolveProviders(live), throwsStateError);
  });

  test('assistant string URL parameter uses its matching live assistant', () {
    const oldUrl = 'https://old-user:old-pass@launch.example/v1?token=old';
    const liveUrl = 'https://new-user:new-pass@edited.example/v2?token=fresh';
    Assistant withEndpoint(String url) => Assistant(
          id: 'assistant',
          name: 'Assistant',
          prompt: 'Help',
          settings: AssistantSettings(customParameters: [
            CustomParameter(name: 'endpoint', type: 'string', value: url),
          ]),
        );
    final chatFlow = TaskFlowDefinition(blocks: [
      TaskFlowBlock(
          typeKey: BlockType.chat, params: {'assistantId': 'assistant'})
    ]);
    final snapshot = FlowLaunchSnapshot.capture(
        chatFlow, const ProviderEntriesState(), [withEndpoint(oldUrl)]);
    expect(jsonEncode(snapshot.toMap()), isNot(contains('old-pass')));

    final resolved = FlowLaunchSnapshot.fromMap(snapshot.toMap())
        .resolveAssistants([withEndpoint(liveUrl)]);
    final uri = Uri.parse(
        resolved.single.settings.customParameters.single.value as String);
    expect(uri.host, 'launch.example');
    expect(uri.userInfo, 'new-user:new-pass');
    expect(uri.queryParameters['token'], 'fresh');
  });

  test('removed live URL field cannot leave a marker in JSON settings', () {
    final old = modelProviders('old-secret', '0.5');
    old.entries.single.configs.single.typeConfig['routing'] = jsonEncode({
      'url': 'https://old:secret@launch.example/v1?apiSecret=old-token',
      'timeout': '0.5',
    });
    old.entries.single.configs.single.typeConfig['routes'] = jsonEncode([
      {
        'id': 'primary',
        'url': 'https://old:secret@launch.example/v1?apiSecret=old-token',
      }
    ]);
    final snapshot = FlowLaunchSnapshot.capture(flow, old, []);
    final live = modelProviders('fresh-secret', '0.9');
    final config = live.entries.single.configs.single;
    config.typeConfig['routing'] = jsonEncode({'timeout': '0.9'});
    config.typeConfig['routes'] = jsonEncode([
      {'id': 'primary'}
    ]);

    expect(
        () =>
            FlowLaunchSnapshot.fromMap(snapshot.toMap()).resolveProviders(live),
        throwsStateError);
    config.typeConfig['routing'] = jsonEncode({
      'url': 'https://new:fresh@edited.example/v2?apiSecret=fresh-token',
      'timeout': '0.9',
    });
    expect(
        () =>
            FlowLaunchSnapshot.fromMap(snapshot.toMap()).resolveProviders(live),
        throwsStateError);
  });

  test('Cookie and Proxy-Authorization stay out of saved snapshots', () {
    ProviderEntriesState withCredentials(
        String cookie, String proxy, String tuning) {
      final providers = modelProviders('base-secret', tuning);
      final config = providers.entries.single.configs.single;
      config.typeConfig['headers'] = jsonEncode({
        'Cookie': cookie,
        'Proxy-Authorization': proxy,
        'temperature': tuning,
      });
      config.models.single.customParams.addAll([
        CustomParam(paramName: 'Cookie', defaultValue: cookie),
        CustomParam(paramName: 'Proxy-Authorization', defaultValue: proxy),
      ]);
      return providers;
    }

    final snapshot = FlowLaunchSnapshot.capture(
      flow,
      withCredentials('old-cookie', 'old-proxy', '0.5'),
      [],
    );
    final saved = jsonEncode(snapshot.toMap());
    expect(saved, isNot(contains('old-cookie')));
    expect(saved, isNot(contains('old-proxy')));
    expect(saved, contains('temperature'));

    final restored = FlowLaunchSnapshot.fromMap(snapshot.toMap());
    final resolved = resolveProviderModel(
      restored.resolveProviders(
          withCredentials('fresh-cookie', 'fresh-proxy', '0.9')),
      'tts',
      flow.blocks.single.params['modelRef'],
    )!;
    expect(jsonDecode(resolved.config.typeConfig['headers'] as String), {
      'Cookie': 'fresh-cookie',
      'Proxy-Authorization': 'fresh-proxy',
      'temperature': '0.5',
    });
    expect(
        resolved.model.customParams
            .where((param) => param.paramName == 'Cookie')
            .single
            .defaultValue,
        'fresh-cookie');
    expect(
        resolved.model.customParams
            .where((param) => param.paramName == 'Proxy-Authorization')
            .single
            .defaultValue,
        'fresh-proxy');
  });

  test('reordered JSON routes hydrate credentials by id and freeze tuning', () {
    final old = modelProviders('old', '0.5');
    old.entries.single.configs.single.typeConfig['routing'] = jsonEncode([
      {'id': 'a', 'temperature': '0.3', 'Authorization': 'old-a'},
      {'id': 'b', 'temperature': '0.7', 'Authorization': 'old-b'},
    ]);
    final snapshot = FlowLaunchSnapshot.capture(flow, old, []);
    expect(jsonEncode(snapshot.toMap()), isNot(contains('old-a')));
    expect(jsonEncode(snapshot.toMap()), isNot(contains('old-b')));

    final live = modelProviders('fresh', '0.9');
    live.entries.single.configs.single.typeConfig['routing'] = jsonEncode([
      {'id': 'b', 'temperature': '0.2', 'Authorization': 'fresh-b'},
      {'id': 'a', 'temperature': '0.8', 'Authorization': 'fresh-a'},
    ]);
    final resolved =
        FlowLaunchSnapshot.fromMap(snapshot.toMap()).resolveProviders(live);
    final config = resolveProviderModel(
            resolved, 'tts', flow.blocks.single.params['modelRef'])!
        .config;
    expect(jsonDecode(config.typeConfig['routing'] as String), [
      {'id': 'a', 'temperature': '0.3', 'Authorization': 'fresh-a'},
      {'id': 'b', 'temperature': '0.7', 'Authorization': 'fresh-b'},
    ]);

    live.entries.single.configs.single.typeConfig['routing'] = jsonEncode([
      {'id': 'a', 'temperature': '0.2', 'Authorization': 'fresh-b'},
      {'id': 'a', 'temperature': '0.8', 'Authorization': 'fresh-a'},
    ]);
    expect(() => snapshot.resolveProviders(live), throwsStateError);
  });

  group('JSON URL scalars', () {
    String scalarUrl(String id, String version) => version == 'old'
        ? 'https://old-user:old-password@launch.example/$id?region=launch&token=old-token-$id#old-fragment-$id'
        : 'https://fresh-user:fresh-password@launch.example/$id?token=fresh-token-$id&region=launch#fresh-fragment-$id';

    String encodeScalar(String value, int depth) {
      for (var i = 0; i < depth; i++) {
        value = jsonEncode(value);
      }
      return value;
    }

    String decodeScalar(String value, int depth) {
      for (var i = 0; i < depth; i++) {
        value = jsonDecode(value) as String;
      }
      return value;
    }

    void verifyScalar(String value, String id, int depth) {
      final launch = Uri.parse(scalarUrl(id, 'old'));
      final fresh = Uri.parse(scalarUrl(id, 'fresh'));
      final expected = launch.replace(
        userInfo: fresh.userInfo,
        queryParameters: {
          ...launch.queryParametersAll,
          'token': fresh.queryParametersAll['token']!,
        },
        fragment: fresh.fragment,
      );
      expect(decodeScalar(value, depth), expected.toString());
    }

    void verifyRedacted(FlowLaunchSnapshot snapshot) {
      final saved = jsonEncode(snapshot.toMap());
      for (final secret in [
        'old-user',
        'old-password',
        'old-token',
        'old-fragment'
      ]) {
        expect(saved, isNot(contains(secret)));
      }
    }

    final chatFlow = TaskFlowDefinition(blocks: [
      TaskFlowBlock(
          typeKey: BlockType.chat, params: {'assistantId': 'assistant'})
    ]);
    Assistant scalarAssistant(List<CustomParameter> parameters) => Assistant(
          id: 'assistant',
          name: 'Assistant',
          prompt: 'Frozen prompt',
          settings: AssistantSettings(customParameters: parameters),
        );

    for (final depth in [1, 2]) {
      test('provider and model quoted URLs redact and hydrate at depth $depth',
          () {
        ProviderEntriesState providers(String version) {
          final providers = modelProviders('json-secret', '0.5');
          final config = providers.entries.single.configs.single;
          final model = config.models.single;
          String scalar(String id) =>
              encodeScalar(scalarUrl(id, version), depth);
          for (final settings in [config.typeConfig, model.typeConfig]) {
            settings['url'] = scalar('first');
            settings['callback'] = scalar('first');
            settings['routing'] = jsonEncode({
              'callback': scalar('first'),
              'tuning': version == 'old' ? '0.5' : '0.9',
            });
          }
          final ids =
              version == 'old' ? ['first', 'second'] : ['second', 'first'];
          model.customParams.add(CustomParam(
            paramName: 'callback',
            type: 'json',
            defaultValue: scalar('first'),
            options: [for (final id in ids) scalar(id)],
            optionOrder: [for (final id in ids.reversed) scalar(id)],
          ));
          model.reasoningParams.add(ReasoningParam(
            paramName: 'callback',
            type: 'json',
            options: [for (final id in ids) scalar(id)],
            optionOrder: [for (final id in ids.reversed) scalar(id)],
            onValue: scalar('first'),
            offValue: scalar('second'),
          ));
          return providers;
        }

        final snapshot = FlowLaunchSnapshot.fromMap(
          FlowLaunchSnapshot.capture(flow, providers('old'), []).toMap(),
        );
        verifyRedacted(snapshot);
        final resolved = resolveProviderModel(
          snapshot.resolveProviders(providers('fresh')),
          'tts',
          flow.blocks.single.params['modelRef'],
        )!;
        for (final settings in [
          resolved.config.typeConfig,
          resolved.model.typeConfig
        ]) {
          verifyScalar(settings['url'] as String, 'first', depth);
          verifyScalar(settings['callback'] as String, 'first', depth);
          final routing = jsonDecode(settings['routing'] as String) as Map;
          verifyScalar(routing['callback'] as String, 'first', depth);
          expect(routing['tuning'], '0.5');
        }
        final custom = resolved.model.customParams.last;
        verifyScalar(custom.defaultValue, 'first', depth);
        verifyScalar(custom.options[0], 'first', depth);
        verifyScalar(custom.options[1], 'second', depth);
        verifyScalar(custom.optionOrder[0], 'second', depth);
        verifyScalar(custom.optionOrder[1], 'first', depth);
        final reasoning = resolved.model.reasoningParams.last;
        verifyScalar(reasoning.options[0], 'first', depth);
        verifyScalar(reasoning.options[1], 'second', depth);
        verifyScalar(reasoning.optionOrder[0], 'second', depth);
        verifyScalar(reasoning.optionOrder[1], 'first', depth);
        verifyScalar(reasoning.onValue!, 'first', depth);
        verifyScalar(reasoning.offValue!, 'second', depth);
      });

      test('assistant quoted URLs redact and hydrate at depth $depth', () {
        Assistant assistant(String version) => scalarAssistant([
              CustomParameter(
                name: 'callback',
                type: 'json',
                value: encodeScalar(scalarUrl('first', version), depth),
              ),
              CustomParameter(
                name: 'routing',
                type: 'json',
                value: jsonEncode({
                  'callback': encodeScalar(scalarUrl('first', version), depth),
                  'tuning': version == 'old' ? '0.5' : '0.9',
                }),
              ),
            ]);
        final snapshot = FlowLaunchSnapshot.fromMap(FlowLaunchSnapshot.capture(
          chatFlow,
          const ProviderEntriesState(),
          [assistant('old')],
        ).toMap());
        verifyRedacted(snapshot);
        final resolved =
            snapshot.resolveAssistants([assistant('fresh')]).single;
        verifyScalar(resolved.settings.customParameters.first.value as String,
            'first', depth);
        final routing =
            jsonDecode(resolved.settings.customParameters.last.value as String)
                as Map;
        verifyScalar(routing['callback'] as String, 'first', depth);
        expect(routing['tuning'], '0.5');
        expect(resolved.prompt, 'Frozen prompt');
      });
    }

    test('ordinary JSON scalars and untyped invalid text stay at launch values',
        () {
      final oldValues = [
        '  "ordinary quoted string"  ',
        jsonEncode('[ordinary text]'),
        jsonEncode('"unfinished ordinary text'),
        jsonEncode('https://public.example/v1'),
        ' 0.5 ',
        'true',
        'null',
      ];
      const ordinaryText = '"unfinished untyped note';
      ProviderEntriesState providers(bool edited) {
        final providers = modelProviders('json-secret', '0.5');
        final config = providers.entries.single.configs.single;
        final values = edited ? [for (final _ in oldValues) '42'] : oldValues;
        for (final settings in [
          config.typeConfig,
          config.models.single.typeConfig
        ]) {
          settings['plainNote'] = edited ? 'edited note' : ordinaryText;
          for (var i = 0; i < values.length; i++) {
            settings['scalar-$i'] = values[i];
          }
        }
        config.models.single.customParams.add(CustomParam(
          paramName: 'scalars',
          type: 'json',
          defaultValue: values.first,
          options: values,
        ));
        return providers;
      }

      final snapshot = FlowLaunchSnapshot.capture(flow, providers(false), []);
      final model = resolveProviderModel(
          snapshot.resolveProviders(providers(true)),
          'tts',
          flow.blocks.single.params['modelRef'])!;
      expect(model.model.customParams.last.defaultValue, oldValues.first);
      expect(model.model.customParams.last.options, oldValues);
      for (final settings in [
        model.config.typeConfig,
        model.model.typeConfig
      ]) {
        expect(settings['plainNote'], ordinaryText);
        for (var i = 0; i < oldValues.length; i++) {
          expect(settings['scalar-$i'], oldValues[i]);
        }
      }
      Assistant assistant(bool edited) => scalarAssistant([
            for (var i = 0; i < oldValues.length; i++)
              CustomParameter(
                  name: 'scalar-$i',
                  type: 'json',
                  value: edited ? '42' : oldValues[i]),
          ]);
      final assistantSnapshot = FlowLaunchSnapshot.capture(
          chatFlow, const ProviderEntriesState(), [assistant(false)]);
      expect(
          assistantSnapshot
              .resolveAssistants([assistant(true)])
              .single
              .settings
              .customParameters
              .map((parameter) => parameter.value)
              .toList(),
          oldValues);
    });

    for (final (label, liveValue) in <(String, String?)>[
      (
        'removed credentials',
        jsonEncode('https://launch.example/first?region=launch')
      ),
      (
        'malformed JSON',
        '"https://fresh-user:fresh-password@launch.example/first'
      ),
      ('wrong scalar type', '42'),
      ('removed parameter', null),
    ]) {
      test('marked JSON URL scalar fails clearly with $label', () {
        ProviderEntriesState providers(String? value) {
          final providers = modelProviders('json-secret', '0.5');
          if (value != null) {
            providers.entries.single.configs.single.models.single.customParams
                .add(
              CustomParam(
                  paramName: 'callback', type: 'json', defaultValue: value),
            );
          }
          return providers;
        }

        Assistant assistant(String? value) => scalarAssistant([
              if (value != null)
                CustomParameter(name: 'callback', type: 'json', value: value),
            ]);
        final launchValue = jsonEncode(scalarUrl('first', 'old'));
        final snapshot = FlowLaunchSnapshot.fromMap(
          FlowLaunchSnapshot.capture(flow, providers(launchValue), []).toMap(),
        );
        final assistantSnapshot =
            FlowLaunchSnapshot.fromMap(FlowLaunchSnapshot.capture(
          chatFlow,
          const ProviderEntriesState(),
          [assistant(launchValue)],
        ).toMap());
        final clearError = throwsA(isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('最新配置'),
        ));
        expect(
            () => snapshot.resolveProviders(providers(liveValue)), clearError);
        expect(
            () => assistantSnapshot.resolveAssistants([assistant(liveValue)]),
            clearError);
      });
    }
  });

  test('malformed JSON parameter fails closed and uses the live value', () {
    final old = modelProviders('old-secret', '0.5');
    old.entries.single.configs.single.models.single.customParams.single
        .defaultValue = '{"Authorization":"old-secret"';
    final snapshot = FlowLaunchSnapshot.capture(flow, old, []);
    expect(jsonEncode(snapshot.toMap()), isNot(contains('old-secret')));
    final live = modelProviders('fresh-secret', '0.9');
    live.entries.single.configs.single.models.single.customParams.single
        .defaultValue = '{"Authorization":"fresh-secret"';
    final hydrated = resolveProviderModel(
        FlowLaunchSnapshot.fromMap(snapshot.toMap()).resolveProviders(live),
        'tts',
        flow.blocks.single.params['modelRef'])!;
    expect(hydrated.model.customParams.single.defaultValue,
        '{"Authorization":"fresh-secret"');
  });

  test('bare invalid JSON values fail closed while valid scalars stay frozen',
      () {
    final old = modelProviders('old-secret', '0.5');
    final oldConfig = old.entries.single.configs.single;
    oldConfig.typeConfig['plainNote'] = 'plain-text-literal';
    final oldModel = oldConfig.models.single;
    oldModel.customParams.single
      ..defaultValue = 'old-secret'
      ..options = ['old-secret']
      ..optionOrder = ['old-secret'];
    oldModel.customParams.add(CustomParam(
        paramName: 'scalar',
        type: 'json',
        defaultValue: '0.5',
        options: ['true', '"quoted-old"']));
    oldModel.reasoningParams.single.options = ['old-secret'];
    final snapshot = FlowLaunchSnapshot.capture(flow, old, []);
    expect(jsonEncode(snapshot.toMap()), isNot(contains('old-secret')));
    expect(
        (snapshot.toMap()['configs'] as List).single['typeConfig']['plainNote'],
        'plain-text-literal');

    final live = modelProviders('fresh-secret', '0.9');
    final liveModel = live.entries.single.configs.single.models.single;
    liveModel.customParams.single
      ..defaultValue = 'fresh-secret'
      ..options = ['fresh-secret']
      ..optionOrder = ['fresh-secret'];
    liveModel.customParams.add(CustomParam(
        paramName: 'scalar',
        type: 'json',
        defaultValue: '0.9',
        options: ['false', '"quoted-new"']));
    liveModel.reasoningParams.single.options = ['fresh-secret'];
    final model = resolveProviderModel(
            FlowLaunchSnapshot.fromMap(snapshot.toMap()).resolveProviders(live),
            'tts',
            flow.blocks.single.params['modelRef'])!
        .model;
    expect(model.customParams.first.defaultValue, 'fresh-secret');
    expect(model.customParams.first.options, ['fresh-secret']);
    expect(model.customParams.first.optionOrder, ['fresh-secret']);
    expect(model.reasoningParams.single.options, ['fresh-secret']);
    expect(model.customParams.last.defaultValue, '0.5');
    expect(model.customParams.last.options, ['true', '"quoted-old"']);
  });

  test('bare invalid assistant JSON value is hydrated from the live assistant',
      () {
    Assistant withValue(String value) => Assistant(
        id: 'assistant',
        name: 'Assistant',
        prompt: '{"Authorization":"prompt-literal"}',
        settings: AssistantSettings(customParameters: [
          CustomParameter(name: 'headers', type: 'json', value: value)
        ]));
    final chatFlow = TaskFlowDefinition(blocks: [
      TaskFlowBlock(
          typeKey: BlockType.chat, params: {'assistantId': 'assistant'})
    ]);
    final snapshot = FlowLaunchSnapshot.capture(
        chatFlow, const ProviderEntriesState(), [withValue('old-secret')]);
    expect(jsonEncode(snapshot.toMap()), isNot(contains('old-secret')));
    final resolved = FlowLaunchSnapshot.fromMap(snapshot.toMap())
        .resolveAssistants([withValue('fresh-secret')]);
    expect(
        resolved.single.settings.customParameters.single.value, 'fresh-secret');
    expect(resolved.single.prompt, '{"Authorization":"prompt-literal"}');
  });

  Assistant assistant(String secret, String tuning) => Assistant(
      id: 'assistant',
      name: 'Assistant',
      prompt: '{"Authorization":"prompt-literal"}',
      settings: AssistantSettings(customParameters: [
        CustomParameter(
            name: 'headers',
            type: 'json',
            value: jsonEncode(
                {'Authorization': 'Bearer $secret', 'temperature': tuning})),
        CustomParameter(
            name: 'note',
            type: 'string',
            value: '{"Authorization":"plain-text-literal"}')
      ]));

  test('assistant JSON value hydrates without rewriting prompt or plain text',
      () {
    final assistantFlow = TaskFlowDefinition(blocks: [
      TaskFlowBlock(
          typeKey: BlockType.chat, params: {'assistantId': 'assistant'})
    ]);
    final snapshot = FlowLaunchSnapshot.capture(assistantFlow,
        const ProviderEntriesState(), [assistant('old-secret', '0.5')]);
    final encoded = jsonEncode(snapshot.toMap());
    expect(encoded, isNot(contains('old-secret')));
    expect(encoded, contains('prompt-literal'));
    expect(encoded, contains('plain-text-literal'));

    final restored = FlowLaunchSnapshot.fromMap(snapshot.toMap());
    final hydrated =
        restored.resolveAssistants([assistant('fresh-secret', '0.9')]).single;
    expect(jsonDecode(hydrated.settings.customParameters.first.value as String),
        {'Authorization': 'Bearer fresh-secret', 'temperature': '0.5'});
    expect(hydrated.prompt, '{"Authorization":"prompt-literal"}');
    expect(hydrated.settings.customParameters.last.value,
        '{"Authorization":"plain-text-literal"}');
  });

  test('duplicate live assistant identities cannot hydrate saved settings', () {
    final assistantFlow = TaskFlowDefinition(blocks: [
      TaskFlowBlock(
          typeKey: BlockType.chat, params: {'assistantId': 'assistant'})
    ]);
    final snapshot = FlowLaunchSnapshot.capture(assistantFlow,
        const ProviderEntriesState(), [assistant('old-secret', '0.5')]);
    final restored = FlowLaunchSnapshot.fromMap(snapshot.toMap());
    final first = assistant('first-secret', '0.9');
    final second = assistant('second-secret', '0.8');

    expect(() => restored.resolveAssistants([first, second]), throwsStateError);
    expect(() => restored.resolveAssistants([second, first]), throwsStateError);
    expect(() => restored.resolveAssistants([]), throwsStateError);
  });

  test('assistant Cookie parameter uses the current matching identity', () {
    Assistant withCookie(String cookie) => Assistant(
          id: 'assistant',
          name: 'Assistant',
          prompt: 'Frozen prompt',
          settings: AssistantSettings(customParameters: [
            CustomParameter(name: 'Cookie', type: 'string', value: cookie),
          ]),
        );
    final chatFlow = TaskFlowDefinition(blocks: [
      TaskFlowBlock(
          typeKey: BlockType.chat, params: {'assistantId': 'assistant'})
    ]);
    final snapshot = FlowLaunchSnapshot.capture(chatFlow,
        const ProviderEntriesState(), [withCookie('old-assistant-cookie')]);
    expect(
        jsonEncode(snapshot.toMap()), isNot(contains('old-assistant-cookie')));
    final hydrated = FlowLaunchSnapshot.fromMap(snapshot.toMap())
        .resolveAssistants([withCookie('fresh-assistant-cookie')]).single;
    expect(hydrated.prompt, 'Frozen prompt');
    expect(hydrated.settings.customParameters.single.value,
        'fresh-assistant-cookie');
  });

  test('unbound chat keeps the selected model identity across a queued run',
      () {
    ProviderEntriesState providers(String selectedTuning) =>
        ProviderEntriesState(entries: [
          ProviderEntry(id: 'llm', type: 'llm', name: 'Chat', configs: [
            ProviderConfigItem(
                id: 'first-config',
                providerName: 'First',
                host: 'https://first.example',
                key: 'first-key',
                models: [
                  ModelConfig(
                      id: 'first-model', name: 'First', modelId: 'first')
                ]),
            ProviderConfigItem(
                id: 'selected-config',
                providerName: 'Selected',
                host: 'https://selected.example',
                key: 'selected-key',
                models: [
                  ModelConfig(
                    id: 'selected-model',
                    name: 'Selected',
                    modelId: 'selected',
                    typeConfig: {'temperature': selectedTuning},
                  ),
                ]),
          ])
        ]);
    final chatFlow = TaskFlowDefinition(blocks: [
      TaskFlowBlock(typeKey: BlockType.chat, params: {'assistantId': ''})
    ]);
    final blockId = chatFlow.blocks.single.id;
    final snapshot = FlowLaunchSnapshot.capture(
      chatFlow,
      providers('0.5'),
      [],
      selectedChatModel: {
        'configId': 'selected-config',
        'modelId': 'selected-model',
      },
    );
    final restored = FlowLaunchSnapshot.fromMap(snapshot.toMap());
    final reference = restored.chatModelReference(blockId);
    expect(reference, {
      'configId': 'selected-config',
      'modelId': 'selected-model',
    });
    final model = resolveProviderModel(
      restored.resolveProviders(providers('0.9')),
      'llm',
      reference,
    );
    expect(model?.model.id, 'selected-model');
    expect(model?.model.typeConfig['temperature'], '0.5');
    expect(jsonEncode(snapshot.toMap()), isNot(contains('selected-key')));
  });
}
