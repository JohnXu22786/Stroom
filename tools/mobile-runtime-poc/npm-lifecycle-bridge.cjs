'use strict'
// Isolated prototype: route a narrow npm node JS/TS lifecycle hook through
// this already-running Node Mobile process. This is not a sandbox.
const fs = require('node:fs')
const path = require('node:path')
const Module = require('node:module')
const { EventEmitter } = require('node:events')

const npmCli = process.env.STROOM_NPM_CLI
if (!npmCli) throw new Error('STROOM_NPM_CLI must point to npm-cli.js')
const npmRoot = path.dirname(path.dirname(npmCli))
const spawnPath = require.resolve('@npmcli/promise-spawn', { paths: [npmRoot] })
const original = require(spawnPath)
const nodeEntry = /^node\s+((?:\.\.?\/)?[\w./-]+\.(?:cjs|mjs|js|ts))$/i
let lifecycleDepth = 0
const originalModuleLoad = Module._load

Module._load = function (request, parent, isMain) {
  if (lifecycleDepth > 0 &&
      (request === 'child_process' || request === 'node:child_process')) {
    const childProcess = originalModuleLoad.call(this, request, parent, isMain)
    const guarded = Object.assign({}, childProcess)
    for (const name of [
      'spawn', 'spawnSync', 'exec', 'execSync', 'execFile', 'execFileSync', 'fork',
    ]) {
      guarded[name] = (...args) => {
        const command = String(args[0] || name)
        const error = Object.assign(
          new Error('Unsupported external executable from npm lifecycle script: ' + command),
          { code: 'ERR_STROOM_UNSUPPORTED_EXECUTABLE' },
        )
        console.error(error.message)
        throw error
      }
    }
    return guarded
  }
  return originalModuleLoad.call(this, request, parent, isMain)
}

function rejected(script, cwd) {
  const error = new Error('Unsupported npm lifecycle command on this mobile runtime: ' + script)
  error.code = 'ERR_STROOM_UNSUPPORTED_LIFECYCLE_COMMAND'
  error.cmd = script
  error.path = cwd
  error.codeNumber = 1
  error.signal = null
  console.error(error.message)
  return Promise.reject(error)
}

function runEntry(entry, opts) {
  const cwd = opts.cwd || process.cwd()
  const filename = path.resolve(cwd, entry)
  if (filename.indexOf(path.resolve(cwd) + path.sep) !== 0 || !fs.existsSync(filename)) {
    const error = new Error('Lifecycle JS/TS entry is missing or escapes package: ' + entry)
    error.code = 'ERR_STROOM_LIFECYCLE_ENTRY'
    throw error
  }
  if (filename.endsWith('.mjs')) {
    const error = new Error('ESM lifecycle entry is not implemented in this prototype')
    error.code = 'ERR_STROOM_ESM_LIFECYCLE_UNIMPLEMENTED'
    throw error
  }

  const oldCwd = process.cwd()
  const oldArgv = process.argv
  const oldExit = process.exit
  const oldExitCode = process.exitCode
  const oldEnv = Object.assign({}, process.env)
  const fakeProc = new EventEmitter()
  fakeProc.kill = () => true
  let code = 0
  process.exit = (value = 0) => {
    throw Object.assign(new Error('lifecycle requested exit'), {
      lifecycleExit: true,
      exitCode: Number(value) || 0,
    })
  }
  try {
    process.chdir(cwd)
    Object.assign(process.env, opts.env || {})
    process.argv = [process.execPath, filename]
    const mod = new Module(filename, module)
    mod.filename = filename
    mod.paths = Module._nodeModulePaths(path.dirname(filename))
    lifecycleDepth++
    try {
      if (filename.endsWith('.ts')) {
        const compilerModule = process.env.STROOM_SUCRASE_MODULE
        if (!compilerModule) {
          throw Object.assign(
            new Error('TypeScript lifecycle entry needs the bundled TS transpiler'),
            { code: 'ERR_STROOM_TS_TRANSPILER_REQUIRED' },
          )
        }
        const compiler = require(compilerModule)
        const source = fs.readFileSync(filename, 'utf8')
        const transpiled = compiler.transform(source, {
          transforms: ['typescript'],
          filePath: filename,
        }).code
        mod._compile(transpiled, filename)
      } else {
        mod.load(filename)
      }
      if (process.exitCode !== undefined && process.exitCode !== oldExitCode) {
        code = Number(process.exitCode) || 0
      }
    } catch (error) {
      if (error.lifecycleExit) code = error.exitCode
      else throw error
    } finally {
      lifecycleDepth--
    }
  } finally {
    process.exit = oldExit
    process.argv = oldArgv
    process.exitCode = oldExitCode
    for (const key of Object.keys(process.env)) {
      if (!(key in oldEnv)) delete process.env[key]
    }
    Object.assign(process.env, oldEnv)
    process.chdir(oldCwd)
  }
  const result = { cmd: 'node', args: [filename], code, signal: null, stdout: null, stderr: null }
  const promise = code === 0
    ? Promise.resolve(result)
    : Promise.reject(Object.assign(new Error('lifecycle JS entry failed'), result))
  promise.process = fakeProc
  promise.stdin = null
  queueMicrotask(() => fakeProc.emit('exit', code, null))
  return promise
}

function hasShellOperators(script) {
  return /&&|\|\||[;|<>]|\$\(/.test(script) ||
    script.indexOf(String.fromCharCode(96)) !== -1
}

require.cache[spawnPath].exports = function (cmd, args, opts = {}, extra = {}) {
  const script = extra.script || ''
  if (path.basename(cmd) === 'sh' || opts.shell) {
    if (hasShellOperators(script)) return rejected(script, opts.cwd)
    const match = nodeEntry.exec(script.trim())
    if (!match) return rejected(script, opts.cwd)
    return runEntry(match[1], opts)
  }
  return rejected(script || [cmd].concat(args || []).join(' '), opts.cwd)
}
require.cache[spawnPath].exports.open = original.open
