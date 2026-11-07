import 'package:flutter/widgets.dart';
import 'package:markdown/markdown.dart' as m;

import '../config/markdown_generator.dart';
import '../config/configs.dart';
import '../config/toc.dart';
import 'widget_visitor.dart';

typedef MarkdownIncrementalConfigBuilder = MarkdownConfig Function(
  String activeText,
);

/// Holds stable widgets for complete top-level Markdown blocks and reparses
/// only a bounded number of updates to the final block while its meaning can
/// still change. Oversized active blocks use a source-preserving plain-text
/// preview until the finalized message receives its canonical Markdown render.
///
/// The caller must provide append-only input. A new document is required when
/// the stream is reset, the generator/configuration changes, or the text is
/// replaced instead of appended.
class MarkdownStreamSession {
  /// Keep expensive Markdown work bounded while a single top-level block is
  /// still open. The final message is rendered through the normal full parser
  /// after streaming ends.
  static const int _maxIncrementalBlockLength = 16 * 1024;
  static const int _maxIncrementalChunkUpdates = 64;
  static const int _maxPreviewFragments = 32;

  final MarkdownGenerator generator;
  final ValueCallback<List<Toc>>? onTocList;
  final MarkdownIncrementalConfigBuilder? activeConfigBuilder;
  final List<Widget> _sealedWidgets = [];
  List<Widget> _activeWidgets = const [];
  final List<String> _plainPreviewFragments = [];
  late m.Document _document;
  late _ReferenceState _baseReferenceState;
  String _activeText = '';
  bool _initialized = false;
  bool _usingPlainPreview = false;
  int _chunkAppendCount = 0;

  MarkdownStreamSession({
    required this.generator,
    this.onTocList,
    this.activeConfigBuilder,
  });

  /// Starts a new document session and parses [data] once to locate the active
  /// final block.
  MarkdownStreamUpdate reset(
    String data, {
    MarkdownConfig? config,
    int updatesAlreadyReceived = 0,
  }) {
    _sealedWidgets.clear();
    _activeWidgets = const [];
    _plainPreviewFragments.clear();
    _usingPlainPreview = false;
    _chunkAppendCount = 0;
    _activeText = '';
    _initialized = true;
    if (data.length > _maxIncrementalBlockLength) {
      _enterPlainPreview(data, config: config);
      return MarkdownStreamUpdate(
        resetAll: true,
        sealedWidgets: const [],
        activeWidgets: _activeWidgets,
      );
    }
    _rebuildFromFullText(data, config: config);
    _chunkAppendCount = updatesAlreadyReceived;
    if (!_usingPlainPreview &&
        _chunkAppendCount > _maxIncrementalChunkUpdates) {
      // Re-entry restores a chunk-wide append count. Match an uninterrupted
      // session by keeping sealed blocks and previewing only its active tail.
      _usingPlainPreview = true;
      _appendPlainPreview(_activeText);
      _activeText = '';
      _activeWidgets = _buildPlainPreview(config);
    }
    return MarkdownStreamUpdate(
      resetAll: true,
      sealedWidgets: List.of(_sealedWidgets),
      activeWidgets: _activeWidgets,
    );
  }

  /// Appends [delta] to the currently active block. Complete preceding blocks
  /// are converted to widgets once and retained. If a newly sealed block
  /// changes document-wide references or footnotes, the session explicitly
  /// invalidates and reparses the document once so earlier affected nodes are
  /// revisited.
  MarkdownStreamUpdate append(
    String delta, {
    required String Function() fullTextOnInvalidation,
    MarkdownConfig? config,
  }) {
    if (!_initialized) {
      return reset(delta, config: config);
    }

    if (_usingPlainPreview) {
      _appendPlainPreview(delta);
      _activeWidgets = _buildPlainPreview(config);
      return MarkdownStreamUpdate(
        resetAll: false,
        sealedWidgets: const [],
        activeWidgets: _activeWidgets,
      );
    }

    // A Markdown block may remain open for the whole response (for example a
    // long paragraph or an unclosed fence). Parsing it again on every delta
    // makes work and temporary AST/widget allocation grow with the response.
    // Once the block reaches the preview limit or update budget, stop parsing that live suffix
    // and append its source to a bounded fragment list. The finalized message
    // still gets the canonical full Markdown parse in MarkdownWidgetState.
    _chunkAppendCount++;
    if (_activeText.length + delta.length > _maxIncrementalBlockLength ||
        _chunkAppendCount > _maxIncrementalChunkUpdates) {
      _usingPlainPreview = true;
      _appendPlainPreview('$_activeText$delta');
      _activeText = '';
      _activeWidgets = _buildPlainPreview(config);
      return MarkdownStreamUpdate(
        resetAll: false,
        sealedWidgets: const [],
        activeWidgets: _activeWidgets,
      );
    }

    final sealedCountBeforeUpdate = _sealedWidgets.length;
    final workingText = '$_activeText$delta';
    _restoreBaseReferenceState();
    final activeResult = _parse(workingText);
    if (!_baseReferenceState.matches(_document)) {
      // A newly seen definition or footnote reference can change the meaning
      // of already sealed widgets. Keep the live source accurate without
      // retaining stale links/backrefs; final rendering resolves the complete
      // document with the normal parser.
      _enterPlainPreview(
        fullTextOnInvalidation(),
        config: config,
      );
      return MarkdownStreamUpdate(
        resetAll: true,
        sealedWidgets: const [],
        activeWidgets: _activeWidgets,
      );
    }
    if (activeResult.blocks.length < 2) {
      _activeText = workingText;
      _activeWidgets = _buildWidgets(
        activeResult.nodes,
        _activeConfig(workingText, config),
      );
      return MarkdownStreamUpdate(
        resetAll: false,
        sealedWidgets: const [],
        activeWidgets: _activeWidgets,
      );
    }

    final lastBlockStart = _lineOffset(
      workingText,
      activeResult.blocks.last.startLine,
    );
    final sealedText = workingText.substring(0, lastBlockStart);
    final nextActiveText = workingText.substring(lastBlockStart);

    _restoreBaseReferenceState();
    final referenceStateBeforeSeal = _ReferenceState.from(_document);
    final sealedResult = _parse(sealedText);
    final referencesChanged = !referenceStateBeforeSeal.matches(_document);
    if (referencesChanged) {
      _enterPlainPreview(
        fullTextOnInvalidation(),
        config: config,
      );
      return MarkdownStreamUpdate(
        resetAll: true,
        sealedWidgets: const [],
        activeWidgets: _activeWidgets,
      );
    }

    _sealedWidgets.addAll(
      _buildWidgets(sealedResult.nodes, _activeConfig(sealedText, config)),
    );
    _activeText = nextActiveText;
    _baseReferenceState = _ReferenceState.from(_document);

    _restoreBaseReferenceState();
    final nextActiveResult = _parse(_activeText);
    _activeWidgets = _buildWidgets(
      nextActiveResult.nodes,
      _activeConfig(_activeText, config),
    );
    return MarkdownStreamUpdate(
      resetAll: false,
      sealedWidgets: _sealedWidgets.sublist(sealedCountBeforeUpdate),
      activeWidgets: _activeWidgets,
    );
  }

  void dispose() {
    _sealedWidgets.clear();
    _activeWidgets = const [];
    _plainPreviewFragments.clear();
    _usingPlainPreview = false;
    _chunkAppendCount = 0;
    _activeText = '';
    _initialized = false;
  }

  m.Document _newDocument() => m.Document(
        extensionSet: generator.extensionSet ?? m.ExtensionSet.gitHubFlavored,
        encodeHtml: false,
        inlineSyntaxes: generator.inlineSyntaxList,
        blockSyntaxes: generator.blockSyntaxList,
      );

  m.DocumentParseResult _parse(String text) {
    final regExp = generator.splitRegExp ?? WidgetVisitor.defaultSplitRegExp;
    final lines = text.split(regExp).map(m.Line.new).toList();
    return _document.parseLineListWithRanges(lines);
  }

  int _lineOffset(String text, int lineIndex) {
    if (lineIndex <= 0) return 0;
    final regExp = generator.splitRegExp ?? WidgetVisitor.defaultSplitRegExp;
    var line = 0;
    for (final match in regExp.allMatches(text)) {
      line++;
      if (line == lineIndex) return match.end;
    }
    return text.length;
  }

  List<Widget> _buildWidgets(List<m.Node> nodes, MarkdownConfig? config) =>
      generator.buildWidgetsFromNodes(
        nodes,
        onTocList: onTocList,
        config: config,
      );

  List<Widget> _buildPlainPreview(MarkdownConfig? config) =>
      generator.buildPlainTextPreview(
        _plainPreviewFragments,
        config: _activeConfig('', config),
      );

  void _enterPlainPreview(String source, {MarkdownConfig? config}) {
    _sealedWidgets.clear();
    _activeWidgets = const [];
    _plainPreviewFragments.clear();
    _usingPlainPreview = true;
    _chunkAppendCount = 0;
    _activeText = '';
    _appendPlainPreview(source);
    _activeWidgets = _buildPlainPreview(config);
  }

  void _appendPlainPreview(String text) {
    if (text.isEmpty) return;
    _plainPreviewFragments.add(text);
    while (_plainPreviewFragments.length > _maxPreviewFragments) {
      var mergeIndex = 0;
      var shortestPairLength =
          _plainPreviewFragments[0].length + _plainPreviewFragments[1].length;
      for (var i = 1; i < _plainPreviewFragments.length - 1; i++) {
        final pairLength = _plainPreviewFragments[i].length +
            _plainPreviewFragments[i + 1].length;
        if (pairLength < shortestPairLength) {
          mergeIndex = i;
          shortestPairLength = pairLength;
        }
      }
      _plainPreviewFragments[mergeIndex] +=
          _plainPreviewFragments.removeAt(mergeIndex + 1);
    }
  }

  MarkdownConfig? _activeConfig(String activeText, MarkdownConfig? fallback) =>
      activeConfigBuilder?.call(activeText) ?? fallback;

  void _restoreBaseReferenceState() {
    _document.linkReferences
      ..clear()
      ..addAll(_baseReferenceState.linkReferences);
    _document.footnoteReferences
      ..clear()
      ..addAll(_baseReferenceState.footnoteReferences);
    _document.footnoteLabels
      ..clear()
      ..addAll(_baseReferenceState.footnoteLabels);
  }

  void _rebuildFromFullText(String data, {MarkdownConfig? config}) {
    _sealedWidgets.clear();
    _activeWidgets = const [];
    _document = _newDocument();
    _baseReferenceState = _ReferenceState.from(_document);

    final initialReferenceState = _ReferenceState.from(_document);
    final fullResult = _parse(data);
    if (!initialReferenceState.matches(_document)) {
      // Re-entry may seed the stream with a full chunk that already contains
      // definitions. Parsing the sealed prefix with only its own document
      // state would make those earlier links/footnotes incorrect.
      _enterPlainPreview(data, config: config);
      return;
    }
    if (fullResult.blocks.isEmpty) {
      _activeText = data;
      _activeWidgets = _buildWidgets(
        fullResult.nodes,
        _activeConfig(data, config),
      );
      return;
    }

    final activeStart = _lineOffset(data, fullResult.blocks.last.startLine);
    final sealedText = data.substring(0, activeStart);
    _activeText = data.substring(activeStart);
    _chunkAppendCount = 0;

    _document = _newDocument();
    _baseReferenceState = _ReferenceState.from(_document);
    final sealedResult = _parse(sealedText);
    _sealedWidgets.addAll(
      _buildWidgets(sealedResult.nodes, _activeConfig(sealedText, config)),
    );
    _baseReferenceState = _ReferenceState.from(_document);

    _restoreBaseReferenceState();
    final activeResult = _parse(_activeText);
    _activeWidgets = _buildWidgets(
      activeResult.nodes,
      _activeConfig(_activeText, config),
    );
  }
}

/// The widget-list changes made by one Markdown stream update.
class MarkdownStreamUpdate {
  /// Whether the prior widget list must be replaced because the session was
  /// reset or document-wide references invalidated earlier blocks.
  final bool resetAll;

  /// All sealed widgets when [resetAll] is true; otherwise only the newly
  /// sealed widgets appended by this update.
  final List<Widget> sealedWidgets;

  /// The replacement widgets for the currently active final block.
  final List<Widget> activeWidgets;

  const MarkdownStreamUpdate({
    required this.resetAll,
    required this.sealedWidgets,
    required this.activeWidgets,
  });
}

class _ReferenceState {
  final Map<String, m.LinkReference> linkReferences;
  final Map<String, int> footnoteReferences;
  final List<String> footnoteLabels;

  _ReferenceState({
    required this.linkReferences,
    required this.footnoteReferences,
    required this.footnoteLabels,
  });

  factory _ReferenceState.from(m.Document document) => _ReferenceState(
        linkReferences: Map.of(document.linkReferences),
        footnoteReferences: Map.of(document.footnoteReferences),
        footnoteLabels: List.of(document.footnoteLabels),
      );

  bool matches(m.Document document) {
    if (linkReferences.length != document.linkReferences.length ||
        footnoteReferences.length != document.footnoteReferences.length ||
        footnoteLabels.length != document.footnoteLabels.length) {
      return false;
    }
    for (final entry in linkReferences.entries) {
      final other = document.linkReferences[entry.key];
      final value = entry.value;
      if (other == null ||
          other.label != value.label ||
          other.destination != value.destination ||
          other.title != value.title) {
        return false;
      }
    }
    for (final entry in footnoteReferences.entries) {
      if (document.footnoteReferences[entry.key] != entry.value) return false;
    }
    for (var i = 0; i < footnoteLabels.length; i++) {
      if (document.footnoteLabels[i] != footnoteLabels[i]) return false;
    }
    return true;
  }
}
