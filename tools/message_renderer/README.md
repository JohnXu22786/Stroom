# Stroom message renderer

Pinned DSH UI primitives adapted to Flutter-owned messages. See
[the migration record](../../docs/dsh-message-ui-migration.md) for scope,
bridge ownership, platform dependencies and verification limits.

```sh
npm ci
npm test
```

The build writes a self-contained HTML document and dependency notices to
`assets/vendor/dsh_message_view`. Keep these generated assets committed.
No frontend server or DSH agent runtime is needed in a release build.
