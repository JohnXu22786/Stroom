# Repository guidance for coding agents

Before changing first-party Flutter UI, read the [Stroom UI guidelines](docs/ui-guidelines.md) and search both `lib/` and `packages/streaming_markdown/` for existing shared widgets, theme roles, and every affected call site. Reuse the established component where it fits, update all affected callers, and preserve documented intentional exceptions. The externally maintained math component is out of scope.

For a shared component or theme change, verify repository-wide callers rather than fixing only the screen that exposed the issue. Check light and dark themes and the relevant responsive/layout state, including text scaling or keyboard/overlay behavior when affected. Follow repository test and contribution instructions, and summarize the screens, call-site search, validation, and UI state checked in the pull request.
