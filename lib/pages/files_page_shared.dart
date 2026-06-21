import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider that tracks whether the file manager handled a system back event
/// (i.e., navigated to parent folder). The outer PopScope in [HomePage]
/// checks this to avoid navigating to home when the file manager is in a subfolder.
final filesPageBackHandledProvider = StateProvider<bool>((ref) => false);
