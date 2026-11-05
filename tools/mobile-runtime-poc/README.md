# Android Node/MCP feasibility POC

This isolated prototype exercises the upstream `nodejs-mobile` v18.20.4 Android library in its sample host. It does not modify or integrate into Stroom.

The Android and iOS Simulator CI workflows check:

1. Node runtime version and the unmodified Node Mobile UTF-8 module-loading failure (RangeError: Index out of range).
3. A separately loaded, committed UTF-8 compatibility shim, followed by a clean `npm ci` into an app-private fixture directory from the checked-in manifest and lockfile. The manifest uses a real npm `overrides` entry pinning transitive `fast-uri` to 3.1.0.
4. Runtime verification of the installed override, TypeScript-to-JavaScript transpilation with Sucrase, and execution of the result.
5. MCP `initialize`, `tools/list`, and `tools/call` using the SDK's linked in-memory client/server transport.

The MCP test runs both endpoints in the same embedded Node process. It does **not** test a separately spawned MCP server or Stroom's host transport.

The Android workflow downloads the official Node Mobile v18.20.4 release, verifies its published archive SHA-256, and packages the x86_64 library only for emulator testing. The iOS workflow downloads the official v18.20.4 iOS framework, verifies its published SHA-256, and runs the upstream sample in an iOS Simulator. Both workflows download npm 10.8.2, verify its published SHA-512 integrity, and bundle it only into the sample app. The npm package is Artistic-2.0 licensed; its license file is included in the test app. These are not Stroom release artifacts or release-size estimates.

## Lifecycle bridge experiment

Both simulator workflows install four local npm packages through npm 10.8.2 while the embedded Node process is running:

- node postinstall.cjs must run in-process and write a marker file.
- node postinstall.ts must transpile with the installed Sucrase package, run in-process, and write a marker file.
- A JS hook calling child_process.execFileSync must fail with an unsupported-external-executable error.
- node-gyp rebuild must fail with an unsupported-lifecycle-command error.

The prototype intercepts npm's internal @npmcli/promise-spawn implementation. This is not a supported npm extension point and is pinned to npm 10.8.2. The bridge only accepts a direct JS/TS file entry; shell compositions, ESM lifecycle files, native compilers/modules, and unavailable external programs remain unsupported. It is not a security boundary and does not ask an assistant to substitute or invent commands. Passing simulator tests would establish only these fixtures and this npm version, not general package compatibility.

Desktop, production integration, and App Store acceptance are not tested here.
