import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Global streaming state — used by ChatPage and ChatComposerWidget.
final isStreamingProvider = StateProvider<bool>((ref) => false);
