import 'package:flutter/material.dart';

import '../config/markdown_generator.dart';
import 'link_recognizer_lifecycle.dart';

///use [ProxyRichText] to give `textScaleFactor` a default value
class ProxyRichText extends StatelessWidget {
  final InlineSpan textSpan;
  final RichTextBuilder? richTextBuilder;

  const ProxyRichText(
    this.textSpan, {
    super.key,
    this.richTextBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return LinkRecognizerLifecycle(
      span: textSpan,
      child: richTextBuilder?.call(textSpan) ?? Text.rich(textSpan),
    );
  }
}
