part of 'chat_page.dart';
// ignore_for_file: invalid_use_of_protected_member

const _externalMessageLinkSchemes = {
  'http',
  'https',
  'mailto',
  'tel',
  'sms',
};

extension _ChatPageWebMessagesExt on _ChatPageState {
  List<Map<String, dynamic>> _webMessageData() {
    final activeId = ref.read(activeConversationIdProvider);
    final historyMutationBlocked = _historyMutationBlocked;
    if (_loadedConversationId != activeId) {
      _messageThumbnails.clear();
    } else {
      final retainedAttachmentIds = _history
          .expand((message) => message.attachments)
          .map((attachment) => attachment.id)
          .toSet();
      _messageThumbnails
          .removeWhere((id, _) => !retainedAttachmentIds.contains(id));
    }
    final messages = <Map<String, dynamic>>[];
    final start = _isSearching ? 0 : _loadedUpToIndex.clamp(0, _history.length);
    final history = _history.skip(start).toList();
    if (_isStreamingActive &&
        _streamingMsgId != null &&
        !history.any((m) => m.id == _streamingMsgId)) {
      history.add(ChatMessage(
          id: _streamingMsgId, role: 'assistant', content: '', blocks: []));
    }
    for (final message in history) {
      final streaming = _isStreamingActive && message.id == _streamingMsgId;
      final blocks = streaming
          ? _liveWebBlocks(message.id)
          : message.blocks?.map((b) => b.toMap()).toList() ??
              <Map<String, dynamic>>[];
      final hasRaw = message.rawRequest != null || message.rawResponse != null;
      messages.add({
        'id': message.id,
        'role': message.role,
        'createdAt': message.createdAt.toIso8601String(),
        'content': message.content,
        'blocks': blocks,
        'streaming': streaming,
        'error': message.isError,
        'actions': [
          'copy',
          if (message.role == 'assistant' && !streaming) 'save',
          if (!streaming && !historyMutationBlocked)
            message.role == 'assistant' ? 'retry' : 'edit',
          if (message.role == 'assistant' && hasRaw) 'raw',
          if (message.role == 'assistant' && hasRaw && _developerMode) 'json',
          if (!streaming && !historyMutationBlocked) 'delete',
        ],
        'attachments': message.attachments
            .map((a) => {
                  'id': a.id,
                  'fileName': a.fileName,
                  'fileType': a.fileType,
                  if (_messageThumbnails[a.id] != null)
                    'thumbnail': _messageThumbnails[a.id],
                })
            .toList(),
      });
    }
    return messages;
  }

  List<Map<String, dynamic>> _liveWebBlocks(String id) {
    final segments = _chatSegments[id] ?? [];
    return segments.indexed.map((entry) {
      final (index, segment) = entry;
      return switch (segment) {
        TextSegment() => {
            'type': 'text',
            'text': segment.text,
            'streaming': index == segments.length - 1
          },
        ReasoningSegment() => {
            'type': 'reasoning',
            'sectionIndex': segment.sectionIndex,
            'text': (_reasoningContents[id] ?? [])
                    .elementAtOrNull(segment.sectionIndex) ??
                '',
            'isComplete': !segment.isStreaming
          },
        ToolCallSegment() => {'type': 'tool_call', ...segment.data.toMap()},
      };
    }).toList();
  }

  Widget _buildWebMessages(String? activeId, bool isDark) {
    final colors = Theme.of(context).colorScheme;
    String css(Color color) =>
        '#${color.toARGB32().toRadixString(16).substring(2)}';
    return DshMessageView(
      key: _webMessageKey,
      conversationId: activeId,
      historyLoaded: _loadedConversationId == activeId,
      messages: _webMessageData(),
      hasOlder: !_isSearching && _hasMoreMessages,
      theme: {
        'dark': isDark,
        'fontSize': MediaQuery.textScalerOf(context).scale(16),
        'colors': {
          '--surface': css(colors.surface),
          '--foreground': css(colors.onSurface),
          '--subtle': css(colors.surfaceContainerLow),
          '--secondary': css(colors.onSurfaceVariant),
          '--border': css(colors.outlineVariant),
          '--accent': css(colors.primary)
        }
      },
      onEvent: _onWebMessageEvent,
      hostBuilder: widget.messageHostBuilder,
    );
  }

  void _searchWebMessages({bool locate = false}) {
    SearchMatch? match;
    if (locate &&
        _currentMatchIndex < _searchMatches.length &&
        _currentMatchIndex >= 0) {
      match = _searchMatches[_currentMatchIndex];
    }
    _webMessageKey.currentState?.send({
      'type': 'search',
      'query': _searchQuery,
      'emitResults': !locate,
      if (match != null) 'messageId': match.messageId,
      if (match != null) 'occurrence': match.matchStart
    });
  }

  void _onWebMessageEvent(Map<String, dynamic> event) async {
    if (!mounted ||
        _loadedConversationId != ref.read(activeConversationIdProvider)) return;
    final type = event['type'];
    if (type == 'ready') {
      if (_isSearching) _searchWebMessages();
      return;
    }
    if (type == 'searchResults' &&
        event['query'] == _searchQuery &&
        event['matches'] is List) {
      final validIds = _history.map((m) => m.id).toSet();
      final matches = <SearchMatch>[];
      for (final value in event['matches'] as List) {
        if (value is! Map || !validIds.contains(value['messageId'])) continue;
        final occurrence = messageWebInteger(value['occurrence']);
        if (occurrence == null) continue;
        matches.add(
            SearchMatch(value['messageId'] as String, occurrence, occurrence));
      }
      setState(() {
        _searchMatches
          ..clear()
          ..addAll(matches);
        _currentMatchIndex = _currentMatchIndex.clamp(
            0, matches.isEmpty ? 0 : matches.length - 1);
      });
      if (matches.isNotEmpty) _scrollToCurrentMatch();
      return;
    }
    if (type == 'loadOlder') {
      await _loadMoreMessages(skipMinDisplayDelay: true);
      return;
    }
    if (type == 'scrollBottom') {
      _onScrollToBottomTap();
      return;
    }
    if (type == 'link' && event['uri'] is String) {
      final uri = Uri.tryParse(event['uri'] as String);
      if (uri != null &&
          _externalMessageLinkSchemes.contains(uri.scheme.toLowerCase())) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }
    if (type != 'action') return;
    final data = _webMessageData()
        .where((m) => m['id'] == event['messageId'])
        .firstOrNull;
    if (data == null) return;
    final id = data['id'] as String;
    final action = event['action'];
    final message = _history.where((m) => m.id == id).firstOrNull;
    if (action == 'attachment' || action == 'thumbnail') {
      final attachment = message?.attachments
          .where((a) => a.id == event['attachmentId'])
          .firstOrNull;
      if (attachment == null) return;
      if (action == 'attachment') {
        _showAttachmentPreview(attachment);
        return;
      }
      final conversationId = _loadedConversationId;
      if (conversationId == null) return;
      final thumbnailLoadKey = (conversationId, attachment.id);
      if (attachment.fileType != 'image' ||
          _messageThumbnails.containsKey(attachment.id) ||
          !_loadingMessageThumbnails.add(thumbnailLoadKey)) return;
      try {
        final path = attachment.thumbnailPath ?? attachment.storagePath;
        final bytes = await (widget.thumbnailBytesReader == null
            ? AttachmentStorage.readFile(path)
            : widget.thumbnailBytesReader!(path));
        if (bytes == null ||
            !mounted ||
            conversationId != _loadedConversationId) return;
        ui.Codec? codec;
        ui.Image? image;
        try {
          codec = await ui.instantiateImageCodec(bytes, targetWidth: 160);
          final frame = await codec.getNextFrame();
          image = frame.image;
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          final stillAttached = _history.any((currentMessage) =>
              currentMessage.attachments.any((a) => a.id == attachment.id));
          if (png != null &&
              mounted &&
              conversationId == _loadedConversationId &&
              conversationId == ref.read(activeConversationIdProvider) &&
              stillAttached) {
            setState(() => _messageThumbnails[attachment.id] =
                'data:image/png;base64,${base64Encode(png.buffer.asUint8List())}');
          }
        } finally {
          image?.dispose();
          codec?.dispose();
        }
      } catch (error) {
        debugPrint('[MessageThumbnail] $error');
      } finally {
        _loadingMessageThumbnails.remove(thumbnailLoadKey);
      }
      return;
    }
    if ((data['actions'] as List).contains(action)) {
      final text = data['streaming'] == true
          ? ref.read(streamingFullReplyProvider(_loadedConversationId!))
          : message?.content ?? '';
      switch (action) {
        case 'copy':
          await Clipboard.setData(ClipboardData(text: text));
          if (mounted)
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('已复制'), duration: Duration(seconds: 1)));
        case 'save':
          await _saveMessageAsMarkdown(
              context,
              Message.text(id: id, authorId: _aiUser.id, text: text)
                  as TextMessage);
        case 'retry':
          _confirmRetryOrEdit(id);
        case 'edit':
          _startEditMessage(id);
        case 'raw':
          _showRawDataDialog(context, id);
        case 'json':
          _showJsonInspection(id);
        case 'delete':
          _confirmDeleteMessage(id);
      }
      return;
    }
    final index = messageWebInteger(event['blockIndex']);
    final blocks = data['blocks'] as List<Map<String, dynamic>>;
    if (index == null || index < 0 || index >= blocks.length) return;
    final block = blocks[index];
    if (action == 'reasoning' && block['type'] == 'reasoning') {
      final ordinal = messageWebInteger(block['sectionIndex']) ??
          blocks.take(index).where((b) => b['type'] == 'reasoning').length;
      showReasoningPanel(
          context: context,
          messageId: id,
          sectionIndex: ordinal,
          reasoningText: block['text'] as String,
          isStreaming:
              data['streaming'] == true && block['isComplete'] != true);
      return;
    }
    if (block['type'] != 'text') return;
    final fence = messageCodeFence(
        block['text'] as String, event['sourceStart'], event['sourceEnd'],
        streaming: block['streaming'] == true);
    if (fence == null) return;
    switch (action) {
      case 'html':
        if (fence.language == 'html' && !fence.generating) {
          showHtmlPreviewDialog(context: context, htmlCode: fence.code);
        }
      case 'mermaid':
        if (fence.language == 'mermaid' && !fence.generating) {
          showMermaidPreviewDialog(context: context, mermaidCode: fence.code);
        }
      case 'copyCode':
        await Clipboard.setData(ClipboardData(text: fence.code));
      case 'saveCode':
        final extension = RegExp(r'^[a-z0-9]+$').hasMatch(fence.language)
            ? fence.language
            : 'txt';
        await FilePicker.saveFile(
            dialogTitle: '保存代码',
            fileName: 'code.$extension',
            bytes: Uint8List.fromList(utf8.encode(fence.code)),
            initialDirectory: SystemPickDirectories.documents());
      case 'code':
        showDialog(
            context: context,
            builder: (_) => Dialog.fullscreen(
                child: Scaffold(
                    appBar: AppBar(
                        title: Text(
                            fence.language.isEmpty ? '代码' : fence.language)),
                    body: CodeBlockSourceView(
                        code: fence.code,
                        language: fence.language,
                        height: MediaQuery.sizeOf(context).height - 100))));
    }
  }
}
