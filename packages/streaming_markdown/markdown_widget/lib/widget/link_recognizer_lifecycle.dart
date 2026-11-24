import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Owns the tap recognizers embedded in an inline span tree for its lifetime.
class LinkRecognizerOwner {
  static final Expando<LinkRecognizerOwner> _owners =
      Expando<LinkRecognizerOwner>('link recognizer owner');

  final Set<TapGestureRecognizer> _recognizers = {};
  bool _disposed = false;

  void register(TapGestureRecognizer recognizer) {
    if (_disposed) {
      recognizer.dispose();
      return;
    }
    _recognizers.add(recognizer);
    _owners[recognizer] = this;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final recognizer in _recognizers) {
      _owners[recognizer] = null;
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  static LinkRecognizerOwner? forSpan(InlineSpan span) {
    LinkRecognizerOwner? owner;

    void visit(InlineSpan current) {
      if (current is TextSpan) {
        final recognizer = current.recognizer;
        if (recognizer is TapGestureRecognizer) {
          owner ??= _owners[recognizer];
        }
        for (final child in current.children ?? const <InlineSpan>[]) {
          visit(child);
        }
      }
    }

    visit(span);
    return owner;
  }

  static LinkRecognizerOwner fromSpan(InlineSpan span) {
    final owner = LinkRecognizerOwner();

    void visit(InlineSpan current) {
      if (current is TextSpan) {
        final recognizer = current.recognizer;
        if (recognizer is TapGestureRecognizer) owner.register(recognizer);
        for (final child in current.children ?? const <InlineSpan>[]) {
          visit(child);
        }
      }
    }

    visit(span);
    return owner;
  }
}

class LinkRecognizerLifecycle extends StatefulWidget {
  final InlineSpan span;
  final Widget child;
  final LinkRecognizerOwner? owner;
  final bool disposeOwner;

  const LinkRecognizerLifecycle({
    super.key,
    required this.span,
    required this.child,
    this.owner,
    this.disposeOwner = false,
  });

  /// Lets the outer Markdown widget release even rows that were never mounted.
  void disposeRecognizers() => owner?.dispose();

  @override
  State<LinkRecognizerLifecycle> createState() =>
      _LinkRecognizerLifecycleState();
}

class _LinkRecognizerLifecycleState extends State<LinkRecognizerLifecycle> {
  late LinkRecognizerOwner _owner;
  late bool _ownsOwner;

  @override
  void initState() {
    super.initState();
    _setOwner();
  }

  @override
  void didUpdateWidget(LinkRecognizerLifecycle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.span, widget.span) ||
        !identical(oldWidget.owner, widget.owner)) {
      if (_ownsOwner) _owner.dispose();
      _setOwner();
    }
  }

  void _setOwner() {
    final sharedOwner =
        widget.owner ?? LinkRecognizerOwner.forSpan(widget.span);
    _owner = sharedOwner ?? LinkRecognizerOwner.fromSpan(widget.span);
    _ownsOwner = widget.disposeOwner || sharedOwner == null;
  }

  @override
  void dispose() {
    if (_ownsOwner) _owner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
