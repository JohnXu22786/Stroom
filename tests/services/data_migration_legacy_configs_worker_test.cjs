const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

function mergeLegacyConfigs(migratedConfigs, existingEntries) {
  const workerSource = fs.readFileSync(
    path.resolve(__dirname, '../../web/data_integrity_json_worker.js'),
    'utf8',
  );
  let onMessage;
  const messages = [];
  const context = {
    self: {
      addEventListener: (_event, handler) => { onMessage = handler; },
      postMessage: (message) => messages.push(message),
    },
  };
  vm.runInNewContext(workerSource, context);
  onMessage({data: [
    'mergeLegacyChatConfigs',
    JSON.stringify(migratedConfigs),
    JSON.stringify(existingEntries),
  ]});
  const [metadataJson, payloadJson] = messages[0].split('\n');
  return {
    metadata: JSON.parse(metadataJson),
    payload: payloadJson ? JSON.parse(payloadJson) : null,
  };
}

function fixProviderEntries(entries) {
  const workerSource = fs.readFileSync(
    path.resolve(__dirname, '../../web/data_integrity_json_worker.js'),
    'utf8',
  );
  let onMessage;
  const messages = [];
  const context = {
    self: {
      addEventListener: (_event, handler) => { onMessage = handler; },
      postMessage: (message) => messages.push(message),
    },
  };
  vm.runInNewContext(workerSource, context);
  onMessage({data: ['fixProviderEntries', JSON.stringify(entries)]});
  const [metadataJson, payloadJson] = messages[0].split('\n');
  return {
    metadata: JSON.parse(metadataJson),
    payload: payloadJson ? JSON.parse(payloadJson) : null,
  };
}

function legacyConfig(temperature) {
  return {
    providerName: 'Legacy provider',
    host: 'https://legacy.example.com',
    key: 'legacy-key',
    models: [{
      name: 'legacy-model',
      modelId: 'legacy-model',
      supportStream: true,
      typeConfig: {temperature, customSetting: temperature},
    }],
  };
}

test('web migration preserves distinct model settings and removes duplicates', () => {
  const existingConfig = legacyConfig(0.2);
  existingConfig.id = 'existing_config';
  delete existingConfig.models[0].supportStream;
  const existingEntries = [{
    id: 'existing_llm',
    type: 'llm',
    name: 'Custom LLM',
    configs: [existingConfig],
  }];
  const mergeIntoExisting = mergeLegacyConfigs(
    [legacyConfig(0.2), legacyConfig(0.7), legacyConfig(0.7)],
    existingEntries,
  );
  assert.equal(mergeIntoExisting.metadata.status, 'write');
  assert.deepEqual(
    mergeIntoExisting.payload[0].configs.map(
      (config) => config.models[0].typeConfig.temperature,
    ),
    [0.2, 0.2, 0.7],
  );
  assert.deepEqual(
    mergeIntoExisting.payload[0].configs.map(
      (config) => config.models[0].supportStream ?? false,
    ),
    [false, true, true],
  );
  assert.deepEqual(
    mergeIntoExisting.payload[0].configs.map(
      (config) => config.models[0].typeConfig.customSetting,
    ),
    [0.2, 0.2, 0.7],
  );

  const legacyTopLevelEntry = mergeLegacyConfigs(
    [legacyConfig(0.2), legacyConfig(0.7)],
    [{
      id: 'legacy_llm',
      type: 'llm',
      name: 'Legacy LLM',
      providerName: 'Legacy provider',
      host: 'https://legacy.example.com',
      key: 'legacy-key',
      models: [{
        name: 'legacy-model',
        modelId: 'legacy-model',
        temperature: 0.2,
        typeConfig: {context: 4000},
      }],
    }],
  );
  assert.equal(legacyTopLevelEntry.metadata.status, 'write');
  assert.deepEqual(
    legacyTopLevelEntry.payload[0].configs.map(
      (config) => config.models[0].typeConfig.temperature,
    ),
    [0.2, 0.2, 0.7],
  );
  assert.equal(
    legacyTopLevelEntry.payload[0].configs[0].models[0].typeConfig.context,
    4000,
  );

  const createNewEntry = mergeLegacyConfigs(
    [legacyConfig(0.7), legacyConfig(0.7)],
    [],
  );
  assert.equal(createNewEntry.metadata.status, 'write');
  assert.equal(createNewEntry.payload[0].configs.length, 1);
});

test('web provider cleanup persists when malformed entries are filtered', () => {
  const result = fixProviderEntries([null]);

  assert.deepEqual(result.metadata, {status: 'ok', changed: true});
  assert.deepEqual(result.payload, []);

  const validEntry = {id: 'kept', type: 'tts'};
  const mixedResult = fixProviderEntries([null, validEntry]);
  assert.deepEqual(mixedResult.metadata, {status: 'ok', changed: true});
  assert.deepEqual(mixedResult.payload, [validEntry]);
});
