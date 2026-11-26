const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

function validateProviderEntries(entries) {
  const workerSource = fs.readFileSync(
    path.resolve(__dirname, '../../web/data_integrity_json_worker.js'),
    'utf8',
  );
  let onMessage;
  let response;
  const context = {
    self: {
      addEventListener: (_event, handler) => { onMessage = handler; },
      postMessage: (message) => { response = message; },
    },
  };
  vm.runInNewContext(workerSource, context);
  onMessage({data: [
    'validateDataFormats',
    JSON.stringify(entries),
    null,
  ]});
  return JSON.parse(response);
}

test('web startup validation reports malformed saved model field shapes', () => {
  const issues = validateProviderEntries([
    {
      id: 'broken_provider',
      type: 'tts',
      name: 'Broken Provider',
      configs: [{
        models: [{
          voices: 'not a list',
          customParams: {paramName: 'temperature'},
          reasoningParams: 42,
          typeConfig: ['not', 'a', 'map'],
        }],
      }],
    },
    {id: '', type: 'tts', name: 'Also Broken', configs: []},
    {
      id: 'legacy_provider',
      type: 'tts',
      name: 'Legacy Provider',
      providerName: 'Legacy Config',
      models: [{
        voices: 'not a list',
        customParams: {paramName: 'temperature'},
        reasoningParams: 42,
        typeConfig: ['not', 'a', 'map'],
      }],
    },
  ]);
  const messages = issues.map((issue) => issue.message);

  assert.deepEqual(messages, [
    'provider_entries[0].configs[0].models[0].customParams: 字段不是合法列表',
    'provider_entries[0].configs[0].models[0].voices: 字段不是合法列表',
    'provider_entries[0].configs[0].models[0].reasoningParams: 字段不是合法列表',
    'provider_entries[0].configs[0].models[0].typeConfig: 字段不是合法对象',
    'provider_entries[1]: id 字段缺失或为空',
    'provider_entries[2].models[0].customParams: 字段不是合法列表',
    'provider_entries[2].models[0].voices: 字段不是合法列表',
    'provider_entries[2].models[0].reasoningParams: 字段不是合法列表',
    'provider_entries[2].models[0].typeConfig: 字段不是合法对象',
  ]);
});

test('web startup validation reports malformed configs and models once each', () => {
  const issues = validateProviderEntries([
    {
      id: 'broken_provider',
      type: 'tts',
      name: 'Broken Provider',
      configs: 'not a list',
    },
    {
      id: 'broken_models',
      type: 'tts',
      name: 'Broken Models',
      configs: [{models: 'not a list'}],
    },
  ]);
  const messages = issues.map((issue) => issue.message);

  assert.equal(
    messages.filter((message) => message ===
      'provider_entries[0].configs: 字段不是合法列表').length,
    1,
  );
  assert.equal(
    messages.filter((message) => message ===
      'provider_entries[1].configs[0].models: 字段不是合法列表').length,
    1,
  );
});
