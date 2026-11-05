// Work around Node Mobile's observed UTF-8 decoding failures in Buffer and
// fs.readFileSync. Keep this opt-in and load it only in patched-path tests.
const fs = require('node:fs');
const originalReadFileSync = fs.readFileSync;
const originalToString = Buffer.prototype.toString;
const originalToLocaleString = Buffer.prototype.toLocaleString;

function decodeUtf8(buffer) {
  return new TextDecoder('utf-8').decode(buffer);
}

fs.readFileSync = function readFileSync(path, options, ...args) {
  const encoding = typeof options === 'string' ? options : options?.encoding;
  if (typeof encoding === 'string' && encoding.toLowerCase().replace('-', '') === 'utf8') {
    const bytes = originalReadFileSync.call(this, path, ...args);
    const text = decodeUtf8(bytes);
    return text;
  }
  return originalReadFileSync.call(this, path, options, ...args);
};

Buffer.prototype.toString = function toString(encoding, ...args) {
  const bytes = this.subarray(args[0], args[1]);
  if (encoding == null || String(encoding).toLowerCase().replace('-', '') === 'utf8') {
    return decodeUtf8(bytes);
  }
  if (String(encoding).toLowerCase() === 'hex') {
    return Array.from(bytes, (byte) => byte.toString(16).padStart(2, '0')).join('');
  }
  return originalToString.call(this, encoding, ...args);
};

Buffer.prototype.toLocaleString = function toLocaleString(encoding, ...args) {
  if (encoding == null || String(encoding).toLowerCase().replace('-', '') === 'utf8') {
    return decodeUtf8(this.subarray(args[0], args[1]));
  }
  return originalToLocaleString.call(this, encoding, ...args);
};

console.log('NODE_MOBILE_UTF8_SHIM_ACTIVE');
