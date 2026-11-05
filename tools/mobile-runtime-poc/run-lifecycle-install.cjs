'use strict'
const fs = require('node:fs')
const path = require('node:path')

const caseName = global.__STROOM_LIFECYCLE_CASE
const cases = {
  javascript: { marker: 'JS lifecycle ran in Node Mobile', accepted: true },
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
const markerPath = path.join(target, 'bridge-marker.txt')
const runtimeFiles = path.resolve(__dirname, '../..')
const npmCli = path.join(runtimeFiles, 'test/npm/package/bin/npm-cli.js')
const shim = path.join(__dirname, 'compatibility-shim.cjs')
const bridge = path.join(__dirname, 'npm-lifecycle-bridge.cjs')
const sucrase = path.join(__dirname, 'npm-fixture/node_modules/sucrase')
const diagnostics = []
const originalConsoleError = console.error
console.error = (...args) => {
  diagnostics.push(args.map(String).join(' '))
  originalConsoleError(...args)
}

// Bootstrap the UTF-8 shim before reading the bridge or npm's modules.
eval(new TextDecoder('utf-8').decode(fs.readFileSync(shim)))
process.env.STROOM_NPM_CLI = npmCli
process.env.STROOM_SUCRASE_MODULE = sucrase
process.env.STROOM_LIFECYCLE_MARKER = markerPath
require(bridge)
process.argv = [
  process.execPath, npmCli, 'install', '--prefix', target, '--foreground-scripts',
  '--package-lock=false', '--no-audit', '--no-fund', packagePath,
]
console.log('MOBILE_LIFECYCLE_INSTALL_BEGIN ' + caseName)
process.on('exit', () => {
  const installedPath = path.join(target, 'node_modules', require(path.join(packagePath, 'package.json')).name)
  const packageInstalled = fs.existsSync(path.join(installedPath, 'package.json'))
  const markerMatches = expected.marker !== null && fs.existsSync(markerPath) &&
    fs.readFileSync(markerPath, 'utf8') === expected.marker
  const statusMatches = expected.accepted
    ? Number(process.exitCode || 0) === 0 && packageInstalled && markerMatches
    : Number(process.exitCode || 0) !== 0 &&
      diagnostics.some((entry) => entry.indexOf(expected.diagnostic) === 0)
  console.log(
    statusMatches
      ? 'MOBILE_LIFECYCLE_EXPECTED_RESULT_PASS ' + caseName
      : 'MOBILE_LIFECYCLE_EXPECTED_RESULT_FAIL ' + caseName +
        ' exit=' + String(Number(process.exitCode || 0)),
  )
  console.log(statusMatches ? 'RESULT:PASS' : 'RESULT:FAIL')
})
module.exports = require(npmCli)
