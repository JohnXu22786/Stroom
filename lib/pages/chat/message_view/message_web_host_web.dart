import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:web/web.dart' as web;

class MessageWebHost extends StatefulWidget {
  final String html;
  final ValueNotifier<Map<String, dynamic>?> commands;
  final void Function(Map<String, dynamic>) onEvent;

  const MessageWebHost(
      {super.key,
      required this.html,
      required this.commands,
      required this.onEvent});

  @override
  State<MessageWebHost> createState() => _MessageWebHostState();
}

class _MessageWebHostState extends State<MessageWebHost> {
  final _channel = const Uuid().v4();
  web.HTMLIFrameElement? _frame;
  late final JSFunction _listener;

  @override
  void initState() {
    super.initState();
    _listener = ((web.Event event) {
      final message = event as web.MessageEvent;
      if (_frame == null || message.source != _frame!.contentWindow) return;
      final data = message.data.dartify();
      if (data is! Map) return;
      if (data['type'] == 'stroomMessageReady') {
        widget.onEvent({'type': 'ready'});
      } else if (data['channel'] == _channel && data['event'] is Map) {
        widget.onEvent(Map<String, dynamic>.from(data['event'] as Map));
      }
    }).toJS;
    web.window.addEventListener('message', _listener);
    widget.commands.addListener(_send);
  }

  void _send() {
    final command = widget.commands.value;
    if (command == null) return;
    _frame?.contentWindow?.postMessage(
        {'channel': _channel, 'command': command}.jsify(), '*'.toJS);
  }

  @override
  void dispose() {
    widget.commands.removeListener(_send);
    web.window.removeEventListener('message', _listener);
    _frame = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HtmlElementView.fromTagName(
        tagName: 'iframe',
        onElementCreated: (element) {
          final frame = element as web.HTMLIFrameElement;
          _frame = frame;
          frame.style
            ..border = '0'
            ..width = '100%'
            ..height = '100%';
          frame.title = '对话消息';
          // Opaque origin: HTML in another preview cannot inspect this document.
          frame.setAttribute('sandbox', 'allow-scripts');
          frame.srcdoc = widget.html.toJS;
        },
      );
}
