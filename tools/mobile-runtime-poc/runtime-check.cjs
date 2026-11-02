const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

assert.equal(process.release.name, 'node');
assert.equal(typeof BigInt, 'function');
assert.equal(Buffer.from('mobile').toString('utf8'), 'mobile');

const marker = path.join(__dirname, 'node-mobile-write-check.txt');
fs.writeFileSync(marker, 'node-fs-ok');
assert.equal(fs.readFileSync(marker, 'utf8'), 'node-fs-ok');
fs.unlinkSync(marker);

console.log(`NODE_RUNTIME_PASS ${process.version}`);
