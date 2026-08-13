import 'package:flutter_riverpod/legacy.dart';

/// Refresh signal provider - increment to trigger a data reload of the files
/// sub-pages. The HomePage navigation increments this when the user enters
/// the files page; each sub-page listens to it and reloads its records and
/// folders without being recreated, so an open folder level is preserved.
final filesRefreshSignalProvider = StateProvider<int>((ref) => 0);

/// Provider that tracks the currently-active folder path in the Files page.
/// Empty string means root folder.
/// Each sub-page updates this via [FileManagerConfig.onCurrentFolderChanged].
/// The outer PopScope in [HomePage] reads this to decide navigation.
final filesPageCurrentFolderProvider = StateProvider<String>((ref) => '');

/// Signal provider for the outer PopScope in [HomePage] to request the active
/// file sub-page to navigate to its parent folder.
///
/// The HomePage PopScope handler reads [filesPageCurrentFolderProvider]:
/// - If non-empty (in subfolder): increment this counter → the active sub-page
///   watches this signal and triggers folder navigation to parent.
/// - If empty (at root): navigate to Home directly.
///
/// This approach avoids timing issues between multiple nested/sibling PopScope
/// widgets in the same route.
final filesPageNavigateToParentSignalProvider = StateProvider<int>((ref) => 0);

/// Per-tab reset signal providers.
/// Increment the value for a logical tab index to tell the corresponding
/// [FileManagerView] to reset its folder to root (go to home).
/// Used for the "double-tap same tab → reset to root" behavior.
final fileTabFolderResetSignalProvider =
    StateProvider.family<int, int>((ref, tabIndex) => 0);
