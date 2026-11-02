# Android Node/MCP feasibility POC

This isolated prototype checks the `nodejs-mobile` v18.20.4 Android library in its upstream Android sample host. It does not modify or integrate into Stroom.

The CI-only workflow will:

1. Build the upstream sample app with the official x86_64 `libnode.so` release.
2. Run it on a hosted Android 29 emulator.
3. Verify Node version/BigInt/Buffer and app-private filesystem read/write.
4. Run the npm CLI inside the app to install `@modelcontextprotocol/sdk@1.32.2` and `zod@3.25.76` into app-private storage.
5. Execute the SDK's standard `StdioServerTransport` over explicit in-memory Node streams and verify initialize, `tools/list`, and `tools/call`.

The stdio check does not claim that Stroom's native host currently exposes an interactive stdin/stdout bridge. Host lifecycle, transport bridging, child-process behavior, iOS, and app-store acceptance remain separate questions.

The upstream library is tested at Node 18.20.4 because that is the latest published release. The checked-in sample binary is for test use only and is not a Stroom release-size estimate.
