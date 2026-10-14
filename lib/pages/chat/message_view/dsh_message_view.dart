import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import 'message_web_host.dart';

/// One trusted, offline Web document for the whole transcript. Flutter owns
/// message state and validates every event before invoking native operations.
class DshMessageView extends StatefulWidget {
  final String? conversationId;
  final List<Map<String, dynamic>> messages;
  final Map<String, dynamic> theme;
  final bool hasOlder;
  final bool historyLoaded;
  final void Function(Map<String, dynamic>) onEvent;
  @visibleForTesting
  final Widget Function(String, ValueNotifier<Map<String, dynamic>?>,
      void Function(Map<String, dynamic>))? hostBuilder;

  const DshMessageView(
      {super.key,
      required this.conversationId,
      required this.messages,
      required this.theme,
      required this.hasOlder,
      this.historyLoaded = true,
      required this.onEvent,
      this.hostBuilder});

  @override
  State<DshMessageView> createState() => DshMessageViewState();
}

class DshMessageViewState extends State<DshMessageView> {
  static Future<String>? _html;
  final _commands = ValueNotifier<Map<String, dynamic>?>(null);
  String _session = const Uuid().v4();
  bool _ready = false;
  Map<String, dynamic>? _pendingSearch;
  bool _scheduled = false;
  final Map<String, String> _sentMessages = {};
  String? _sentTheme;
  bool? _sentHasOlder;
  bool? _sentHistoryLoaded;

  void send(Map<String, dynamic> command) {
    if (!_ready) {
      if (command['type'] == 'search') {
        _pendingSearch = Map<String, dynamic>.of(command);
      }
      return;
    }
    _commands.value = {...command, 'session': _session};
  }

  void _sync({bool snapshot = false}) {
    if (!_ready) return;
    final changed = <Map<String, dynamic>>[];
    final encoded = <String, String>{};
    for (final message in widget.messages) {
      final id = message['id'] as String;
      final text = jsonEncode(message);
      encoded[id] = text;
      if (snapshot || _sentMessages[id] != text) changed.add(message);
    }
    final theme = jsonEncode(widget.theme);
    final orderChanged = jsonEncode(_sentMessages.keys.toList()) !=
        jsonEncode(encoded.keys.toList());
    if (snapshot ||
        changed.isNotEmpty ||
        orderChanged ||
        theme != _sentTheme ||
        widget.hasOlder != _sentHasOlder ||
        widget.historyLoaded != _sentHistoryLoaded) {
      send({
        'type': snapshot ? 'snapshot' : 'patch',
        'messages': changed,
        'order': encoded.keys.toList(),
        'hasOlder': widget.hasOlder,
        'historyLoaded': widget.historyLoaded,
        if (snapshot || theme != _sentTheme) 'theme': widget.theme,
      });
      _sentMessages
        ..clear()
        ..addAll(encoded);
      _sentTheme = theme;
      _sentHasOlder = widget.hasOlder;
      _sentHistoryLoaded = widget.historyLoaded;
    }
  }

  @override
  void didUpdateWidget(DshMessageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversationId != widget.conversationId) {
      _session = const Uuid().v4();
      _sentMessages.clear();
      _sentTheme = null;
      _sync(snapshot: true);
    } else if (!_scheduled) {
      _scheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scheduled = false;
        if (mounted) _sync();
      });
    }
  }

  void _event(Map<String, dynamic> event) {
    if (event['type'] == 'ready') {
      _ready = true;
      _sync(snapshot: true);
      final pendingSearch = _pendingSearch;
      _pendingSearch = null;
      // If history is still loading, the page drops this ready event until
      // its conversation data is active. Preserve an early search in the
      // renderer so the later history snapshot can apply it. When history is
      // already loaded, the page's ready handler sends the current query.
      if (pendingSearch != null && !widget.historyLoaded) {
        send(pendingSearch);
      }
      widget.onEvent({'type': 'ready'});
      return;
    }
    if (event['session'] != _session) return;
    widget.onEvent(event);
  }

  @override
  void dispose() {
    _commands.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final builder = widget.hostBuilder;
    if (builder != null) return builder('', _commands, _event);
    if (!kIsWeb)
      return MessageWebHost(html: '', commands: _commands, onEvent: _event);
    return FutureBuilder<String>(
      future: _html ??=
          rootBundle.loadString('assets/vendor/dsh_message_view/index.html'),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text('消息界面加载失败'));
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        return MessageWebHost(
            html: snapshot.data!, commands: _commands, onEvent: _event);
      },
    );
  }
}
