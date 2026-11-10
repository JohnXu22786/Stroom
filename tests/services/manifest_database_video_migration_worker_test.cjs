const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const {TextDecoder, TextEncoder} = require('node:util');

test('Web worker migrates legacy video rows into an existing video list', () => {
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
    TextDecoder,
    TextEncoder,
  };
  vm.runInNewContext(workerSource, context);

  const input = {
    audio_records: [
      {id: 'audio-1', name: 'voice', format: 'mp3'},
      {id: 'legacy-video', name: 'clip', format: 'mp4'},
    ],
    video_records: [
      {id: 'existing-video', name: 'existing', format: 'mov'},
    ],
  };
  onMessage({data: [
    'migrateWebManifestData',
    new TextEncoder().encode(JSON.stringify(input)),
    [],
    true,
    true,
  ]});

  const metadata = JSON.parse(messages[0]);
  assert.equal(metadata.status, 'ok');
  assert.equal(metadata.changed, true);
  assert.equal(metadata.setVideoFlag, true);
  const migrated = JSON.parse(new TextDecoder().decode(new Uint8Array(messages[1])));
  assert.deepEqual(
    migrated.video_records.map((record) => record.id),
    ['existing-video', 'legacy-video'],
  );
  assert.deepEqual(migrated.audio_records.map((record) => record.id), ['audio-1']);
});
