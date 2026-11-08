'use strict'
// Isolated prototype: route a narrow npm node JS/TS lifecycle hook through
// this already-running Node Mobile process. This is not a sandbox.
const fs = require('node:fs')
const path = require('node:path')
const Module = require('node:module')
const { EventEmitter } = require('node:events')
const { AsyncLocalStorage, createHook } = require('node:async_hooks')
const lifecycleExitToken = Symbol('stroomLifecycleExit')

const npmCli = process.env.STROOM_NPM_CLI
if (!npmCli) throw new Error('STROOM_NPM_CLI must point to npm-cli.js')
const npmRoot = path.dirname(path.dirname(npmCli))
const spawnPath = require.resolve('@npmcli/promise-spawn', { paths: [npmRoot] })
const original = require(spawnPath)
const nodeEntry = /^node\s+((?:\.\.?\/)?[\w./-]+\.(?:cjs|mjs|js|ts))$/i
const lifecycleScope = new AsyncLocalStorage()
const lifecycleOwners = new Map()
const lifecycleResourceTypes = new Set(['PROMISE', 'Microtask', 'PIPEWRAP', 'TTYWRAP'])
createHook({
  init(asyncId, type, triggerAsyncId, resource) {
    const state = lifecycleScope.getStore()
    if (!state || lifecycleResourceTypes.has(type)) return
    state.resources.set(asyncId, { type, resource })
    lifecycleOwners.set(asyncId, state)
  },
  destroy(asyncId) {
    const state = lifecycleOwners.get(asyncId)
    if (state) state.resources.delete(asyncId)
    lifecycleOwners.delete(asyncId)
  },
}).enable()
const originalModuleLoad = Module._load

Module._load = function (request, parent, isMain) {
  if (lifecycleScope.getStore() &&
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

function runEntry(entry, opts, inlineSource) {
  const cwd = opts.cwd || process.cwd()
  const filename = inlineSource === undefined
    ? path.resolve(cwd, entry)
    : path.join(path.resolve(cwd), '__stroom_node_eval__.cjs')
  if (inlineSource === undefined &&
      (filename.indexOf(path.resolve(cwd) + path.sep) !== 0 || !fs.existsSync(filename))) {
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
  const state = {
    resources: new Map(), error: null, exitCode: null, synchronous: true,
  }
  const onUncaughtException = (error) => {
    if (error && error[lifecycleExitToken]) {
      state.exitCode = error.exitCode
      stopLifecycleResources(state)
    } else {
      if (lifecycleScope.getStore() !== state) throw error
      state.error = error instanceof Error ? error : new Error(String(error))
      stopLifecycleResources(state)
    }
  }
  const onUnhandledRejection = (reason) => {
    if (reason && reason[lifecycleExitToken]) {
      state.exitCode = reason.exitCode
      stopLifecycleResources(state)
    } else {
      if (lifecycleScope.getStore() !== state) {
        throw reason instanceof Error ? reason : new Error(String(reason))
      }
      state.error = reason instanceof Error ? reason : new Error(String(reason))
      stopLifecycleResources(state)
    }
  }
  process.on('uncaughtException', onUncaughtException)
  process.on('unhandledRejection', onUnhandledRejection)
  const promise = (async () => {
    let code = 0
    const originalCallbacks = new Map()
    try {
      for (const name of ['setTimeout', 'setInterval', 'setImmediate', 'queueMicrotask', 'nextTick']) {
        const owner = name === 'nextTick' ? process : global
        const originalCallback = owner[name]
        if (typeof originalCallback !== 'function') continue
        originalCallbacks.set(name, { owner, name, callback: originalCallback })
        owner[name] = function (callback, ...args) {
          const ownerState = lifecycleScope.getStore()
          if (!ownerState || typeof callback !== 'function') {
            return originalCallback.call(this, callback, ...args)
          }
          const guardedCallback = function (...callbackArgs) {
            try {
              return lifecycleScope.run(ownerState, () => callback.apply(this, callbackArgs))
            } catch (error) {
              if (!error || !error[lifecycleExitToken]) throw error
              ownerState.exitCode = error.exitCode
              stopLifecycleResources(ownerState)
            }
          }
          return originalCallback.call(this, guardedCallback, ...args)
        }
      }
      process.chdir(cwd)
      Object.assign(process.env, opts.env || {})
      process.argv = inlineSource === undefined
        ? [process.execPath, filename]
        : [process.execPath]
      process.exit = (value) => {
        const exitCode = value === undefined ? Number(process.exitCode) || 0 : Number(value) || 0
        if (lifecycleScope.getStore() !== state) {
          process.exitCode = exitCode
          return
        }
        const exit = {
          [lifecycleExitToken]: true,
          exitCode,
        }
        state.exitCode = exit.exitCode
        stopLifecycleResources(state)
        throw Object.assign(new Error('lifecycle requested exit'), exit)
      }
      const mod = new Module(filename, module)
      mod.filename = filename
      mod.paths = Module._nodeModulePaths(path.dirname(filename))
      lifecycleScope.run(state, () => {
        try {
          if (inlineSource !== undefined) {
            mod._compile(inlineSource, filename)
          } else if (filename.endsWith('.ts')) {
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
        } catch (error) {
          if (error[lifecycleExitToken]) {
            code = error.exitCode
            stopLifecycleResources(state)
          } else throw error
        }
      })
      state.synchronous = false
      await lifecycleScope.exit(() => waitForLifecycle(state))
      if (state.error) throw state.error
      if (state.exitCode !== null) code = state.exitCode
      if (state.exitCode === null && process.exitCode !== undefined && process.exitCode !== oldExitCode) {
        code = Number(process.exitCode) || 0
      }
      const result = { cmd: 'node', args: [filename], code, signal: null, stdout: null, stderr: null }
      if (code !== 0) throw Object.assign(new Error('lifecycle JS entry failed'), result)
      return result
    } finally {
      process.removeListener('uncaughtException', onUncaughtException)
      process.removeListener('unhandledRejection', onUnhandledRejection)
      process.exit = oldExit
      process.argv = oldArgv
      process.exitCode = oldExitCode
      for (const { owner, name, callback } of originalCallbacks.values()) {
        owner[name] = callback
      }
      for (const key of Object.keys(process.env)) {
        if (!(key in oldEnv)) delete process.env[key]
      }
      Object.assign(process.env, oldEnv)
      process.chdir(oldCwd)
    }
  })()
  promise.process = fakeProc
  promise.stdin = null
  promise.then(
    (result) => queueMicrotask(() => fakeProc.emit('exit', result.code, null)),
    () => queueMicrotask(() => fakeProc.emit('exit', 1, null)),
  )
  return promise
}

function waitForLifecycle(state) {
  const timeoutMs = Math.max(50, Number(process.env.STROOM_LIFECYCLE_TIMEOUT_MS) || 30000)
  const deadline = Date.now() + timeoutMs
  return new Promise((resolve, reject) => {
    let settled = false
    const timer = setTimeout(() => {
      const pending = Array.from(state.resources.values(), (resource) => resource.type)
      settled = true
      stopLifecycleResources(state)
      reject(Object.assign(
        new Error('npm lifecycle JavaScript did not become idle within ' + timeoutMs + 'ms: ' + pending.join(', ')),
        { code: 'ERR_STROOM_LIFECYCLE_ASYNC_TIMEOUT' },
      ))
    }, timeoutMs)
    function check() {
      if (settled) return
      if (state.resources.size === 0) {
        settled = true
        clearTimeout(timer)
        if (state.error) reject(state.error)
        else resolve()
      } else if (Date.now() >= deadline) {
        settled = true
        clearTimeout(timer)
        const pending = Array.from(state.resources.values(), (resource) => resource.type)
        reject(Object.assign(
          new Error('npm lifecycle JavaScript did not become idle within ' + timeoutMs + 'ms: ' + pending.join(', ')),
          { code: 'ERR_STROOM_LIFECYCLE_ASYNC_TIMEOUT' },
        ))
      } else {
        setTimeout(check, 1)
      }
    }
    setTimeout(check, 1)
  })
}

function stopLifecycleResources(state) {
  for (const { type, resource } of state.resources.values()) {
    try {
      if (type === 'Timeout') clearTimeout(resource)
      else if (type === 'Immediate') clearImmediate(resource)
      else if (typeof resource.close === 'function') resource.close()
      else if (typeof resource.destroy === 'function') resource.destroy()
      else if (typeof resource.cancel === 'function') resource.cancel()
    } catch (_) {
      // Best-effort cleanup for a lifecycle that exceeded its execution limit.
    }
  }
}

function hasShellOperators(script) {
  return /&&|\|\||[;|<>]|\$\(/.test(script) ||
    script.indexOf(String.fromCharCode(96)) !== -1
}

function parseNodeEval(script) {
  const match = /^node\s+-e\s+("(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*')\s*$/.exec(script.trim())
  if (!match) return null
  const quoted = match[1]
  return quoted.slice(1, -1).replace(/\\(["'\\])/g, '$1')
}

require.cache[spawnPath].exports = function (cmd, args, opts = {}, extra = {}) {
  const script = extra.script || ''
  if (path.basename(cmd) === 'sh' || opts.shell) {
    const inlineSource = parseNodeEval(script)
    if (inlineSource !== null) return runEntry(null, opts, inlineSource)
    if (hasShellOperators(script)) return rejected(script, opts.cwd)
    const match = nodeEntry.exec(script.trim())
    if (!match) return rejected(script, opts.cwd)
    return runEntry(match[1], opts)
  }
  return rejected(script || [cmd].concat(args || []).join(' '), opts.cwd)
}
require.cache[spawnPath].exports.open = original.open
