const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const selectManifest = require('../../web/manifest_locale.js');

function readManifest(fileName) {
  return JSON.parse(fs.readFileSync(
    path.resolve(__dirname, `../../web/${fileName}`),
    'utf8',
  ));
}

test('English and Simplified Chinese manifests contain localized product metadata', () => {
  const manifests = [
    [readManifest('manifest.json'), 'An AI study workspace'],
    [readManifest('manifest.zh_CN.json'), '面向在校学生的 AI 学习工作台'],
  ];

  for (const [manifest, descriptionPrefix] of manifests) {
    assert.equal(manifest.name, 'Stroom');
    assert.equal(manifest.short_name, 'Stroom');
    assert.ok(manifest.description.startsWith(descriptionPrefix));
    assert.doesNotMatch(manifest.description, /A new Flutter project\./);
    assert.equal(manifest.start_url, '.');
    assert.equal(manifest.background_color, '#0175C2');
    assert.equal(manifest.theme_color, '#0175C2');
    assert.deepEqual(
      manifest.icons.map(({src, sizes, purpose}) => ({src, sizes, purpose})),
      [
        {src: 'icons/Icon-192.png', sizes: '192x192', purpose: undefined},
        {src: 'icons/Icon-512.png', sizes: '512x512', purpose: undefined},
        {src: 'icons/Icon-maskable-192.png', sizes: '192x192', purpose: 'maskable'},
        {src: 'icons/Icon-maskable-512.png', sizes: '512x512', purpose: 'maskable'},
      ],
    );
  }
});

test('browser language selection chooses the matching PWA manifest', () => {
  assert.equal(selectManifest(['zh-CN', 'en-US']), 'manifest.zh_CN.json');
  assert.equal(selectManifest(['ZH-TW']), 'manifest.zh_CN.json');
  assert.equal(selectManifest(['en-US', 'zh-CN']), 'manifest.json');
  assert.equal(selectManifest([]), 'manifest.json');

  const indexHtml = fs.readFileSync(
    path.resolve(__dirname, '../../web/index.html'),
    'utf8',
  );
  const inlineManifestLoader = indexHtml.match(/<script>\s*([\s\S]*?)\s*<\/script>/);
  assert.ok(inlineManifestLoader, 'Index must select and install a manifest link');
  assert.ok(
    indexHtml.indexOf('manifest_locale.js') < indexHtml.indexOf(inlineManifestLoader[0]),
    'Manifest selection helper must load before the manifest link is inserted',
  );
  assert.ok(
    indexHtml.indexOf(inlineManifestLoader[0]) < indexHtml.indexOf('flutter_bootstrap.js'),
    'Manifest link must be inserted before Flutter starts',
  );

  for (const [languages, expectedManifest] of [
    [['zh-CN'], 'manifest.zh_CN.json'],
    [['en-US'], 'manifest.json'],
  ]) {
    let insertedManifest;
    const context = {
      navigator: {languages},
      selectStroomManifest: selectManifest,
      document: {
        createElement: () => ({}),
        head: {appendChild: (link) => { insertedManifest = link; }},
      },
    };
    vm.runInNewContext(inlineManifestLoader[1], context);
    assert.equal(insertedManifest.rel, 'manifest');
    assert.equal(insertedManifest.href, expectedManifest);
  }
});
