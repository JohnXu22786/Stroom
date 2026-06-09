/// Shared test utilities for MCP tests.

/// Helper to check if running on a desktop platform (for stdio tests).
bool isDesktopPlatform() {
  // In tests, we can't check the actual platform.
  // Return true by default to allow stdio tests to run.
  return true;
}
