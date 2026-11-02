# Android Node/MCP feasibility POC

This isolated prototype exercises the upstream `nodejs-mobile` v18.20.4 Android library in its sample host. It does not modify or integrate into Stroom.

The CI workflow checks, on a hosted Android 29 emulator:

1. Node runtime version on the hosted Android emulator.
2. The unmodified Node Mobile UTF-8 module-loading failure (`RangeError: Index out of range`).
3. A separately loaded, committed UTF-8 compatibility shim, followed by a clean `npm ci` into an app-private fixture directory from the checked-in manifest and lockfile. The manifest uses a real npm `overrides` entry pinning transitive `fast-uri` to 3.1.0.
4. Runtime verification of the installed override, TypeScript-to-JavaScript transpilation with Sucrase, and execution of the result.
5. MCP `initialize`, `tools/list`, and `tools/call` using the SDK's linked in-memory client/server transport.

The MCP test runs both endpoints in the same embedded Node process. It does **not** test a separately spawned MCP server, a Node command bridge, or Stroom's host transport. Likewise, npm package lifecycle scripts that invoke a `node` executable are outside this passing test: the embedded runtime's `process.execPath` points to Android's `app_process`, and previous probes showed `spawn('node')` is denied and a `postinstall: node ...` script fails. The POC therefore demonstrates a bounded npm/JS/TS/MCP slice, not general Node CLI compatibility.

The workflow downloads the official Node Mobile v18.20.4 Android release, verifies its published archive SHA-256, and packages the x86_64 library only for the emulator test. It also downloads npm 10.8.2 from the npm registry, verifies its published SHA-512 integrity, and bundles it only into the test APK so the embedded runtime can invoke npm's JavaScript CLI. The npm package is Artistic-2.0 licensed; its license file is kept in the packaged test assets. This APK is not a Stroom artifact or a release-size estimate. iOS, desktop, production integration, and App Store acceptance are not tested here.
