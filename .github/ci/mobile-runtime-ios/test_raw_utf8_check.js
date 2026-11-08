const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const source = fs.readFileSync(path.join(__dirname, 'raw_utf8_check.js'), 'utf8');
const value = 'Stroom 学习 🙂';
const hex = '5374726f6f6d20e5ada6e4b9a020f09f9982';

function execute(buffer) {
  const output = [];
  vm.runInNewContext(source, {
    Buffer: buffer,
    RangeError,
    console: { log: (message) => output.push(message) },
  });
  return output;
}

function roundTripBuffer({ failHex = false, failDecode = false } = {}) {
  let call = 0;
  return {
    from(input) {
      assert.equal(input, value);
      call += 1;
      return {
        toString(encoding) {
          if (encoding === 'utf8' && failDecode) throw new RangeError('Index out of range');
          if (encoding === 'hex' && failHex) throw new RangeError('Index out of range');
          return encoding === 'utf8' ? value : hex;
        },
      };
    },
  };
}

assert.deepEqual(execute(roundTripBuffer()), [
  `IOS_RAW_UTF8_ROUNDTRIP:${hex}`,
  'RESULT:PASS',
]);

assert.deepEqual(execute(roundTripBuffer({ failDecode: true })), [
  'IOS_RAW_UTF8_RANGEERROR:RangeError:Index out of range',
  'RESULT:PASS',
]);

const output = [];
assert.throws(() => vm.runInNewContext(source, {
  Buffer: roundTripBuffer({ failHex: true }),
  RangeError,
  console: { log: (message) => output.push(message) },
}), /Index out of range/);
assert.equal(output.includes('IOS_RAW_UTF8_RANGEERROR:RangeError:Index out of range'), false);
assert.equal(output.includes('RESULT:PASS'), false);
