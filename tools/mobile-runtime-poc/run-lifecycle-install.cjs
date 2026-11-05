'use strict'
const fs = require('node:fs')
const path = require('node:path')

const caseName = global.__STROOM_LIFECYCLE_CASE
const cases = {
  javascript: { marker: 'JS lifecycle ran in Node Mobile', accepted: true },
  'async-javascript': { marker: 'Async JS lifecycle ran in Node Mobile', accepted: true },
  'async-exit': {
    marker: null,
    logMarker: 'MOBILE_LIFECYCLE_ASYNC_EXIT_PASS',
    accepted: true,
  },
  'async-exit-default': {
    marker: null,
    logMarker: 'MOBILE_LIFECYCLE_ASYNC_EXIT_DEFAULT',
    forbiddenLogMarker: 'MOBILE_LIFECYCLE_ASYNC_EXIT_CONTINUED',
    accepted: false,
    exitCode: 17,
    diagnostic: 'lifecycle JS entry failed',
    exitCodeDiagnostic: 'npm error code 17',
  },
  'async-failure': {
    marker: null,
    logMarker: 'MOBILE_LIFECYCLE_ASYNC_FAILURE_STARTED',
    accepted: false,
    diagnostic: 'MOBILE_LIFECYCLE_ASYNC_FAILURE_THROWN',
  },
  'sync-exit': {
    marker: null,
    logMarker: 'MOBILE_LIFECYCLE_SYNC_EXIT_PASS',
    accepted: true,
  },
  'async-timeout': {
    marker: null,
    accepted: false,
    diagnostic: 'npm lifecycle JavaScript did not become idle within',
  },
  'inline-js': { marker: 'Inline JS lifecycle ran in Node Mobile', accepted: true },
  'core-js': { marker: null, logMarker: 'Thank you for using core-js', packageName: 'core-js', accepted: true },
  typescript: { marker: 'TypeScript lifecycle ran in Node Mobile', accepted: true },
  'child-process': {
    marker: null,
    accepted: false,
    diagnostic: 'Unsupported external executable from npm lifecycle script:',
  },
  'native-command': {
    marker: null,
    accepted: false,
    diagnostic: 'Unsupported npm lifecycle command on this mobile runtime:',
  },
}
const expected = cases[caseName]
if (!expected) throw new Error('Unknown lifecycle fixture: ' + caseName)

const fixtureRoot = path.join(__dirname, 'lifecycle-fixtures')
const packagePath = path.join(fixtureRoot, caseName)
const target = path.join(__dirname, 'lifecycle-install-' + caseName)
fs.rmSync(target, { recursive: true, force: true })
const markerPath = path.join(target, 'bridge-marker.txt')
const tempPath = path.join(target, '.tmp')
fs.mkdirSync(tempPath, { recursive: true })
const runtimeFiles = path.resolve(__dirname, '../..')
const npmCli = path.join(runtimeFiles, 'test/npm/package/bin/npm-cli.js')
const shim = path.join(__dirname, 'compatibility-shim.cjs')
const bridge = path.join(__dirname, 'npm-lifecycle-bridge.cjs')
const sucrase = path.join(__dirname, 'npm-fixture/node_modules/sucrase')
const diagnostics = []
const lifecycleOutput = []
const stderrOutput = []
const originalConsoleError = console.error
const originalConsoleLog = console.log
const originalStderrWrite = process.stderr.write
console.error = (...args) => {
  diagnostics.push(args.map(String).join(' '))
  originalConsoleError(...args)
}
console.log = (...args) => {
  lifecycleOutput.push(args.map(String).join(' '))
  originalConsoleLog(...args)
}
process.stderr.write = function (chunk, ...args) {
  stderrOutput.push(String(chunk))
  return originalStderrWrite.call(this, chunk, ...args)
}

// Bootstrap the UTF-8 shim before reading the bridge or npm's modules.
eval(new TextDecoder('utf-8').decode(fs.readFileSync(shim)))
process.env.STROOM_NPM_CLI = npmCli
process.env.STROOM_SUCRASE_MODULE = sucrase
process.env.STROOM_LIFECYCLE_MARKER = markerPath
process.env.TMPDIR = tempPath
if (caseName === 'async-timeout') process.env.STROOM_LIFECYCLE_TIMEOUT_MS = '100'
require(bridge)
process.argv = [
  process.execPath, npmCli, 'install', '--prefix', target, '--foreground-scripts',
  '--package-lock=false', '--no-audit', '--no-fund',
  caseName === 'core-js' ? 'core-js@3.45.1' : packagePath,
]
process.env.CI = ''
console.log('MOBILE_LIFECYCLE_INSTALL_BEGIN ' + caseName)
process.on('exit', () => {
  const packageName = expected.packageName || require(path.join(packagePath, 'package.json')).name
  const installedPath = path.join(target, 'node_modules', packageName)
  const packageInstalled = fs.existsSync(path.join(installedPath, 'package.json'))
  const markerMatches = expected.marker !== null
    ? fs.existsSync(markerPath) && fs.readFileSync(markerPath, 'utf8') === expected.marker
    : lifecycleOutput.some((line) => line.indexOf(expected.logMarker) !== -1)
  const statusMatches = expected.accepted
    ? Number(process.exitCode || 0) === 0 && packageInstalled && markerMatches
    : Number(process.exitCode || 0) !== 0 &&
      (expected.exitCode === undefined || Number(process.exitCode) === expected.exitCode) &&
      (!expected.logMarker || markerMatches) &&
      (!expected.forbiddenLogMarker || !lifecycleOutput.some((line) =>
        line.indexOf(expected.forbiddenLogMarker) !== -1)) &&
      (!expected.diagnostic || diagnostics.concat(stderrOutput).some((entry) =>
        entry.indexOf(expected.diagnostic) !== -1)) &&
      (!expected.exitCodeDiagnostic || stderrOutput.some((entry) =>
        entry.indexOf(expected.exitCodeDiagnostic) !== -1))
  console.log(
    statusMatches
      ? 'MOBILE_LIFECYCLE_EXPECTED_RESULT_PASS ' + caseName
      : 'MOBILE_LIFECYCLE_EXPECTED_RESULT_FAIL ' + caseName +
        ' exit=' + String(Number(process.exitCode || 0)),
  )
  console.log(statusMatches ? 'RESULT:PASS' : 'RESULT:FAIL')
  process.stderr.write = originalStderrWrite
})
module.exports = require(npmCli)
