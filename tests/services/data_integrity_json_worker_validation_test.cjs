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

function migrateConversations(conversations) {
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
    'migrateLegacyConversations',
    JSON.stringify(conversations),
  ]});
  const newline = response.indexOf('\n');
  return {
    status: response.slice(0, newline),
    conversations: JSON.parse(response.slice(newline + 1)),
  };
}

test('web startup validation reports malformed saved model field shapes', () => {
  const issues = validateProviderEntries([
    {
      id: 'broken_provider',
      type: 'tts',
      name: 'Broken Provider',
      configs: [{
        typeConfig: ['not', 'a', 'map'],
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
    'provider_entries[0].configs[0].typeConfig: 字段不是合法对象',
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

test('startup migration validates tool-call round boundaries', () => {
  const cases = [
    {starts: [1], calls: [{id: 'a', name: 'A'}]},
    {
      starts: [0, 2, 1],
      calls: [
        {id: 'a', name: 'A'},
        {id: 'b', name: 'B'},
        {id: 'c', name: 'C'},
      ],
    },
    {
      starts: [0, 3],
      calls: [{id: 'a', name: 'A'}, {id: 'b', name: 'B'}],
    },
  ];
  const result = migrateConversations(cases.map(({starts, calls}) => ({
    messages: [{
      role: 'assistant',
      toolCalls: calls,
      toolCallRoundStarts: starts,
    }],
  })));

  assert.equal(result.status, 'ok:3:0');
  for (const [index, {calls}] of cases.entries()) {
    assert.deepEqual(
      result.conversations[index].messages[0].blocks
        .filter((block) => block.type === 'tool_call')
        .map((block) => block.name),
      calls.map((call) => call.name),
    );
  }

  const validResult = migrateConversations([{
    messages: [{
      role: 'assistant',
      textSections: ['before', 'between', 'after'],
      toolCalls: [
        {id: 'a', name: 'A'},
        {id: 'b', name: 'B'},
        {id: 'c', name: 'C'},
      ],
      toolCallRoundStarts: [0, 2],
    }],
  }]);

  assert.equal(validResult.status, 'ok:1:0');
  assert.deepEqual(
    validResult.conversations[0].messages[0].blocks.map((block) =>
      block.type === 'tool_call' ? `tool:${block.name}` : block.text),
    ['before', 'tool:A', 'tool:B', 'between', 'tool:C', 'after'],
  );
});
