import 'package:flutter/foundation.dart' show debugPrint;

/// DASH MPD 解析器
///
/// 支持：
/// - SegmentTemplate (含 $Number$ / $Time$ 模板)
/// - SegmentList (显式 URL 列表)
/// - SegmentTimeline (S 元素定义的时长序列)
/// - BaseURL / AdaptationSet / Representation 层级
/// - 相对路径 → 绝对 URL 转换
class MPDParser {
  MPDParser._();
  static const int defaultMaxSegments = 300000;

  /// 解析 MPD 内容，返回所有分段 URL
  static Future<List<String>> parseManifest(
    String content,
    String baseUrl, {
    int maxSegments = defaultMaxSegments,
  }) async {
    _validateMaxSegments(maxSegments);
    final segments = await _parseAllSegments(content, baseUrl, maxSegments);
    return segments.map((s) => s.url).toList();
  }

  /// 获取所有分段的时长信息
  static Future<List<({String url, double duration})>> parseSegments(
    String content,
    String baseUrl, {
    int maxSegments = defaultMaxSegments,
  }) async {
    _validateMaxSegments(maxSegments);
    return _parseAllSegments(content, baseUrl, maxSegments);
  }

  static void _validateMaxSegments(int maxSegments) {
    if (maxSegments <= 0) {
      throw ArgumentError.value(maxSegments, 'maxSegments');
    }
  }

  static Future<List<({String url, double duration})>> _parseAllSegments(
    String content,
    String baseUrl,
    int maxSegments,
  ) async {
    final result = <({String url, double duration})>[];
    final document = _parseXml(content);
    final mpd = document.firstWhereOrNull((node) => _isDash(node, 'MPD'));
    final root = mpd ?? _MpdElement('MPD');
    final mpdBase = _applyBaseUrl(root, baseUrl);
    final periods =
        root.children.where((node) => _isDash(node, 'Period')).toList();
    final totalDuration = _parseIsoDuration(
      root.attributes['mediaPresentationDuration'],
    );

    if (periods.isEmpty) {
      _appendSegments(
        result,
        _parseContainer(root, [root], mpdBase, totalDuration, maxSegments),
        maxSegments,
      );
    } else {
      for (var i = 0; i < periods.length; i++) {
        final period = periods[i];
        final periodBase = _applyBaseUrl(period, mpdBase);
        _appendSegments(
          result,
          _parseContainer(
            period,
            [root, period],
            periodBase,
            _getPeriodDuration(periods, i, totalDuration),
            maxSegments,
          ),
          maxSegments,
        );
      }
    }

    debugPrint('[MPDParser] Parsed ${result.length} segments');
    return result;
  }

  static List<({String url, double duration})> _parseContainer(
    _MpdElement container,
    List<_MpdElement> ancestors,
    String baseUrl,
    _Rational periodDuration,
    int maxSegments,
  ) {
    final result = <({String url, double duration})>[];
    final adaptationSets = container.children.where(
      (node) => _isDash(node, 'AdaptationSet'),
    );

    if (adaptationSets.isEmpty) {
      final representations = container.children.where(
        (node) => _isDash(node, 'Representation'),
      );
      for (final representation in representations) {
        final representationBase = _applyBaseUrl(representation, baseUrl);
        _appendSegments(
          result,
          _parseRepresentation(
            [...ancestors, representation],
            representation,
            representationBase,
            periodDuration,
            maxSegments,
          ),
          maxSegments,
        );
      }
      return result;
    }

    for (final adaptationSet in adaptationSets) {
      final adaptationBase = _applyBaseUrl(adaptationSet, baseUrl);
      final representations = adaptationSet.children.where(
        (node) => _isDash(node, 'Representation'),
      );
      for (final representation in representations) {
        final representationBase = _applyBaseUrl(
          representation,
          adaptationBase,
        );
        _appendSegments(
          result,
          _parseRepresentation(
            [...ancestors, adaptationSet, representation],
            representation,
            representationBase,
            periodDuration,
            maxSegments,
          ),
          maxSegments,
        );
      }
    }
    return result;
  }

  static List<({String url, double duration})> _parseRepresentation(
    List<_MpdElement> hierarchy,
    _MpdElement representation,
    String baseUrl,
    _Rational periodDuration,
    int maxSegments,
  ) {
    final templateAttributes = <String, String>{};
    _MpdElement? timeline;
    var hasRepresentationTemplate = false;
    for (final element in hierarchy) {
      final template = element.children.firstWhereOrNull(
        (node) => _isDash(node, 'SegmentTemplate'),
      );
      if (template == null) continue;
      if (identical(element, representation)) hasRepresentationTemplate = true;
      templateAttributes.addAll(template.attributes);
      timeline = template.children.firstWhereOrNull(
            (node) => _isDash(node, 'SegmentTimeline'),
          ) ??
          timeline;
    }

    final list = representation.children.firstWhereOrNull(
      (node) => _isDash(node, 'SegmentList'),
    );
    if (list != null && !hasRepresentationTemplate) {
      return _parseSegmentList(list, baseUrl, maxSegments);
    }

    if (templateAttributes.containsKey('media')) {
      return _parseSegmentTemplate(
        templateAttributes,
        timeline,
        representation.attributes['id'] ?? '',
        periodDuration,
        baseUrl,
        maxSegments,
      );
    }

    if (list != null) return _parseSegmentList(list, baseUrl, maxSegments);
    return [];
  }

  static List<({String url, double duration})> _parseSegmentTemplate(
    Map<String, String> template,
    _MpdElement? timeline,
    String representationId,
    _Rational periodDuration,
    String baseUrl,
    int maxSegments,
  ) {
    final result = <({String url, double duration})>[];
    final timescale = int.tryParse(template['timescale'] ?? '') ?? 1;
    final duration = int.tryParse(template['duration'] ?? '');
    final startNumber = int.tryParse(template['startNumber'] ?? '') ?? 1;
    final mediaTemplate = template['media'];
    final initialization = template['initialization'];
    if (mediaTemplate == null) return result;

    if (timeline != null) {
      final sElements =
          timeline.children.where((node) => _isDash(node, 'S')).toList();
      final timelineEntries = <({int startTime, int duration, int count})>[];
      var timelineSegmentCount = BigInt.zero;
      var currentTime = 0;
      for (var index = 0; index < sElements.length; index++) {
        final element = sElements[index];
        currentTime =
            int.tryParse(element.attributes['t'] ?? '') ?? currentTime;
        final segmentDuration =
            int.tryParse(element.attributes['d'] ?? '') ?? 0;
        final repeat = int.tryParse(element.attributes['r'] ?? '') ?? 0;
        var count = 0;
        if (repeat >= 0) {
          final countBig = BigInt.from(repeat) + BigInt.one;
          if (countBig > BigInt.from(maxSegments)) {
            throw FormatException(
              'DASH SegmentTimeline exceeds the $maxSegments segment limit',
            );
          }
          count = countBig.toInt();
        } else if (repeat == -1 && segmentDuration > 0) {
          int? nextTime;
          for (final next in sElements.skip(index + 1)) {
            final explicitTime = int.tryParse(next.attributes['t'] ?? '');
            if (explicitTime != null) {
              nextTime = explicitTime;
              break;
            }
          }
          if (nextTime != null && nextTime > currentTime) {
            final distance = BigInt.from(nextTime - currentTime);
            final divisor = BigInt.from(segmentDuration);
            final countBig = _ceilPositiveRatio(distance, divisor);
            if (countBig > BigInt.from(maxSegments)) {
              throw FormatException(
                'DASH SegmentTimeline exceeds the $maxSegments segment limit',
              );
            }
            count = countBig.toInt();
          } else if (nextTime == null &&
              periodDuration.isPositive &&
              timescale > 0) {
            final periodEnd = periodDuration * _Rational.fromInt(timescale);
            final remaining = periodEnd - _Rational.fromInt(currentTime);
            if (remaining.isPositive) {
              final numerator = remaining.numerator;
              final denominator =
                  remaining.denominator * BigInt.from(segmentDuration);
              final countBig = _ceilPositiveRatio(numerator, denominator);
              if (countBig > BigInt.from(maxSegments)) {
                throw FormatException(
                  'DASH SegmentTimeline exceeds the $maxSegments segment limit',
                );
              }
              count = countBig.toInt();
            }
          }
        }
        timelineEntries.add((
          startTime: currentTime,
          duration: segmentDuration,
          count: count,
        ));
        timelineSegmentCount += BigInt.from(count);
        if (timelineSegmentCount > BigInt.from(maxSegments)) {
          throw FormatException(
            'DASH SegmentTimeline exceeds the $maxSegments segment limit',
          );
        }
        currentTime += segmentDuration * count;
      }
      int segmentNumber = startNumber;
      for (final entry in timelineEntries) {
        var currentTime = entry.startTime;
        for (int i = 0; i < entry.count; i++) {
          final segmentUrl = _applyTemplate(
            mediaTemplate,
            segmentNumber,
            currentTime,
            representationId,
          );
          result.add((
            url: _resolveBase(segmentUrl, baseUrl),
            duration: entry.duration / timescale,
          ));
          segmentNumber++;
          currentTime += entry.duration;
        }
      }
      if (initialization != null) {
        result.insert(0, (
          url: _resolveBase(
            _applyTemplate(initialization, startNumber, 0, representationId),
            baseUrl,
          ),
          duration: 0,
        ));
      }
      return result;
    }

    if (duration == null || duration <= 0) return result;
    if (!periodDuration.isPositive) {
      result.add((
        url: _resolveBase(
          _applyTemplate(mediaTemplate, startNumber, 0, representationId),
          baseUrl,
        ),
        duration: duration / timescale,
      ));
    } else {
      if (timescale <= 0) return result;
      final numerator = periodDuration.numerator * BigInt.from(timescale);
      final denominator = periodDuration.denominator * BigInt.from(duration);
      var requestedCount = numerator ~/ denominator;
      if (numerator % denominator != BigInt.zero) {
        requestedCount += BigInt.one;
      }
      if (requestedCount > BigInt.from(maxSegments)) {
        throw FormatException(
          'DASH SegmentTemplate exceeds the $maxSegments segment limit',
        );
      }
      final segmentCount = requestedCount.toInt();
      for (int i = 0; i < segmentCount; i++) {
        final segmentNumber = startNumber + i;
        result.add((
          url: _resolveBase(
            _applyTemplate(mediaTemplate, segmentNumber, 0, representationId),
            baseUrl,
          ),
          duration: duration / timescale,
        ));
      }
    }

    if (initialization != null) {
      result.insert(0, (
        url: _resolveBase(
          _applyTemplate(initialization, startNumber, 0, representationId),
          baseUrl,
        ),
        duration: 0,
      ));
    }
    return result;
  }

  static List<({String url, double duration})> _parseSegmentList(
    _MpdElement list,
    String baseUrl,
    int maxSegments,
  ) {
    final result = <({String url, double duration})>[];
    final segments =
        list.children.where((node) => _isDash(node, 'SegmentURL')).toList();
    if (segments.length > maxSegments) {
      throw FormatException(
        'DASH SegmentList exceeds the $maxSegments segment limit',
      );
    }
    for (final segment in segments) {
      final media = segment.attributes['media'];
      if (media != null) {
        result.add((url: _resolveBase(media, baseUrl), duration: 0));
      }
    }
    return result;
  }

  static void _appendSegments(
    List<({String url, double duration})> target,
    List<({String url, double duration})> additions,
    int maxSegments,
  ) {
    if (target.length + additions.length > maxSegments) {
      throw FormatException(
        'DASH manifest exceeds the $maxSegments segment limit',
      );
    }
    target.addAll(additions);
  }

  static String _applyTemplate(
    String template,
    int number,
    int time,
    String representationId,
  ) {
    const maxFormattedTokenWidth = 2048;
    return template.replaceAllMapped(
      RegExp(r'\$(RepresentationID|Number|Time)(?:%0(\d+)d)?\$'),
      (match) {
        final token = match.group(0)!;
        late final String replacement;
        switch (match.group(1)) {
          case 'RepresentationID':
            replacement = representationId;
          case 'Number':
          case 'Time':
            final value = match.group(1) == 'Number' ? number : time;
            final widthText = match.group(2);
            final valueString = value.toString();
            final width = widthText == null
                ? valueString.length
                : int.tryParse(widthText);
            if (width == null) {
              replacement = token;
              break;
            }
            if (width > maxFormattedTokenWidth) {
              replacement = token;
              break;
            }
            final outputWidth =
                width > valueString.length ? width : valueString.length;
            replacement = valueString.padLeft(outputWidth, '0');
            return replacement;
          default:
            replacement = token;
        }
        return replacement;
      },
    );
  }

  static String _applyBaseUrl(_MpdElement element, String baseUrl) {
    for (final child in element.children.where(
      (node) => _isDash(node, 'BaseURL'),
    )) {
      final value = child.text.trim();
      if (value.isNotEmpty) return _resolveBase(value, baseUrl);
    }
    return baseUrl;
  }

  static List<_MpdElement> _parseXml(String xml) {
    final roots = <_MpdElement>[];
    final stack = <_MpdElement>[];
    var offset = 0;
    while (offset < xml.length) {
      if (xml.startsWith('<!--', offset)) {
        final end = xml.indexOf('-->', offset + 4);
        if (end < 0) break;
        offset = end + 3;
        continue;
      }
      if (xml.startsWith('<![CDATA[', offset)) {
        final end = xml.indexOf(']]>', offset + 9);
        if (end < 0) break;
        if (stack.isNotEmpty) {
          stack.last.textBuffer.write(xml.substring(offset + 9, end));
        }
        offset = end + 3;
        continue;
      }
      if (xml.startsWith('<?', offset)) {
        final end = xml.indexOf('?>', offset + 2);
        if (end < 0) break;
        offset = end + 2;
        continue;
      }

      if (xml.codeUnitAt(offset) != 0x3C) {
        final nextTag = xml.indexOf('<', offset);
        final end = nextTag < 0 ? xml.length : nextTag;
        if (stack.isNotEmpty) {
          stack.last.textBuffer.write(_decodeXml(xml.substring(offset, end)));
        }
        offset = end;
        continue;
      }

      final tagEnd = _findXmlTagEnd(xml, offset);
      if (tagEnd < 0) break;
      final tag = xml.substring(offset, tagEnd + 1);
      offset = tagEnd + 1;
      if (tag.startsWith('<!')) continue;
      if (tag.startsWith('</')) {
        final closingName =
            RegExp(r'^</\s*([^\s>]+)').firstMatch(tag)?.group(1);
        if (closingName != null) {
          while (stack.isNotEmpty) {
            final closed = stack.removeLast();
            if (closed.qualifiedName == closingName) break;
          }
        }
        continue;
      }

      final nameMatch = RegExp(r'^<\s*([^\s/>]+)').firstMatch(tag);
      if (nameMatch == null) continue;
      final qualifiedName = nameMatch.group(1)!;
      final attributes = <String, String>{};
      final attributeText = tag.substring(nameMatch.end, tag.length - 1);
      for (final match in RegExp(
        r'''([^\s=]+)\s*=\s*(["'])([\s\S]*?)\2''',
      ).allMatches(attributeText)) {
        attributes[match.group(1)!] = _decodeXml(match.group(3)!);
      }

      final namespaces = stack.isEmpty
          ? <String, String>{}
          : Map<String, String>.of(stack.last.namespaces);
      for (final entry in attributes.entries) {
        if (entry.key == 'xmlns') namespaces[''] = entry.value;
        if (entry.key.startsWith('xmlns:')) {
          namespaces[entry.key.substring(6)] = entry.value;
        }
      }
      final colon = qualifiedName.indexOf(':');
      final prefix = colon < 0 ? null : qualifiedName.substring(0, colon);
      final localName =
          colon < 0 ? qualifiedName : qualifiedName.substring(colon + 1);
      final namespaceUri = prefix == null
          ? namespaces['']
          : namespaces[prefix] ?? '__unbound_namespace_prefix__';
      final node = _MpdElement(
        localName,
        qualifiedName: qualifiedName,
        attributes: attributes,
        namespaceUri: namespaceUri,
        namespaces: namespaces,
      );
      if (stack.isEmpty) {
        roots.add(node);
      } else {
        stack.last.children.add(node);
      }
      if (!tag.trimRight().endsWith('/>')) stack.add(node);
    }
    return roots;
  }

  static int _findXmlTagEnd(String xml, int start) {
    var quote = 0;
    var bracketDepth = 0;
    for (var i = start + 1; i < xml.length; i++) {
      final codeUnit = xml.codeUnitAt(i);
      if (quote != 0) {
        if (codeUnit == quote) quote = 0;
        continue;
      }
      if (codeUnit == 0x22 || codeUnit == 0x27) {
        quote = codeUnit;
      } else if (codeUnit == 0x5B) {
        bracketDepth++;
      } else if (codeUnit == 0x5D && bracketDepth > 0) {
        bracketDepth--;
      } else if (codeUnit == 0x3E && bracketDepth == 0) {
        return i;
      }
    }
    return -1;
  }

  static bool _isDash(_MpdElement element, String localName) {
    final namespaceUri = element.namespaceUri;
    return element.name == localName &&
        (namespaceUri == null ||
            namespaceUri.isEmpty ||
            namespaceUri == 'urn:mpeg:dash:schema:mpd:2011');
  }

  static String _decodeXml(String value) {
    return value.replaceAllMapped(
      RegExp(r'&(amp|lt|gt|quot|apos);|&#(x[0-9a-fA-F]+|[0-9]+);'),
      (match) {
        final namedReference = match.group(1);
        if (namedReference != null) {
          return switch (namedReference) {
            'amp' => '&',
            'lt' => '<',
            'gt' => '>',
            'quot' => '"',
            'apos' => "'",
            _ => match.group(0)!,
          };
        }
        final reference = match.group(2)!;
        final codePoint = int.tryParse(
          reference.startsWith('x') ? reference.substring(1) : reference,
          radix: reference.startsWith('x') ? 16 : 10,
        );
        if (codePoint == null ||
            codePoint > 0x10FFFF ||
            (codePoint >= 0xD800 && codePoint <= 0xDFFF)) {
          return match.group(0)!;
        }
        if (codePoint <= 0xFFFF) return String.fromCharCode(codePoint);
        final scalar = codePoint - 0x10000;
        return String.fromCharCode(0xD800 + (scalar >> 10)) +
            String.fromCharCode(0xDC00 + (scalar & 0x3FF));
      },
    );
  }

  static _Rational _getPeriodDuration(
    List<_MpdElement> periods,
    int index,
    _Rational totalDuration,
  ) {
    final period = periods[index];
    final duration = _parseIsoDuration(period.attributes['duration']);
    if (duration.isPositive) return duration;

    final start = _getPeriodStart(periods, index);
    final nextStart = periods
        .skip(index + 1)
        .map((element) => _parseIsoDuration(element.attributes['start']))
        .firstWhereOrNull((value) => value.compareTo(start) > 0);
    if (nextStart != null) return nextStart - start;
    if (totalDuration.compareTo(start) > 0) return totalDuration - start;
    return periods.length == 1 ? totalDuration : _Rational.zero;
  }

  static _Rational _getPeriodStart(List<_MpdElement> periods, int index) {
    var inferredStart = _Rational.zero;
    for (var i = 0; i < index; i++) {
      final period = periods[i];
      final explicitStart = _parseIsoDuration(period.attributes['start']);
      final start = explicitStart.isPositive ? explicitStart : inferredStart;
      final duration = _parseIsoDuration(period.attributes['duration']);
      if (duration.isPositive) {
        inferredStart = start + duration;
        continue;
      }
      final nextStart = periods
          .skip(i + 1)
          .map((element) => _parseIsoDuration(element.attributes['start']))
          .firstWhereOrNull((value) => value.compareTo(start) > 0);
      inferredStart = nextStart ?? start;
    }
    final explicitStart = _parseIsoDuration(periods[index].attributes['start']);
    return explicitStart.isPositive ? explicitStart : inferredStart;
  }

  static _Rational _parseIsoDuration(String? durationString) {
    if (durationString == null || !durationString.startsWith('PT')) {
      return _Rational.zero;
    }
    final timePart = durationString.substring(2);
    var totalSeconds = _Rational.zero;
    final hours = RegExp(r'(\d+(?:\.\d+)?)H').firstMatch(timePart);
    final minutes = RegExp(r'(\d+(?:\.\d+)?)M').firstMatch(timePart);
    final seconds = RegExp(r'(\d+(?:\.\d+)?)S').firstMatch(timePart);
    if (hours != null) {
      totalSeconds += _parseDecimal(hours.group(1)!) * _Rational.fromInt(3600);
    }
    if (minutes != null) {
      totalSeconds += _parseDecimal(minutes.group(1)!) * _Rational.fromInt(60);
    }
    if (seconds != null) {
      totalSeconds += _parseDecimal(seconds.group(1)!);
    }
    return totalSeconds;
  }

  static _Rational _parseDecimal(String value) {
    final parts = value.split('.');
    if (parts.length == 1) {
      return _Rational(BigInt.parse(value), BigInt.one);
    }
    final denominator = BigInt.from(10).pow(parts[1].length);
    final numerator =
        BigInt.parse(parts[0]) * denominator + BigInt.parse(parts[1]);
    return _Rational(numerator, denominator);
  }

  static BigInt _ceilPositiveRatio(BigInt numerator, BigInt denominator) {
    if (numerator <= BigInt.zero) return BigInt.zero;
    final quotient = numerator ~/ denominator;
    return numerator % denominator == BigInt.zero
        ? quotient
        : quotient + BigInt.one;
  }

  static String _resolveBase(String url, String baseUrl) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    var placeholderPrefix = 'DASH_PERCENT_ESCAPE';
    while ((baseUrl + url).contains(placeholderPrefix)) {
      placeholderPrefix += 'X';
    }
    final escapedValues = <String>[];
    String protectEscapes(String value) {
      final componentStart = _uriPathQueryStart(value);
      final head = value.substring(0, componentStart);
      final tail = value.substring(componentStart).replaceAllMapped(
        RegExp(r'%[0-9a-fA-F]{2}'),
        (match) {
          final token = '$placeholderPrefix${escapedValues.length}TOKEN';
          escapedValues.add(match.group(0)!);
          return token;
        },
      );
      return head + tail;
    }

    final protectedBaseUrl = protectEscapes(baseUrl);
    final protectedUrl = protectEscapes(url);
    final uri = Uri.tryParse(protectedBaseUrl);
    if (uri == null) return url;
    var resolved = uri.resolve(protectedUrl).toString();
    for (var i = 0; i < escapedValues.length; i++) {
      resolved = resolved.replaceAll(
        '$placeholderPrefix${i}TOKEN',
        escapedValues[i],
      );
    }
    return resolved;
  }

  static int _uriPathQueryStart(String value) {
    final scheme = RegExp(r'^[A-Za-z][A-Za-z0-9+.-]*://').firstMatch(value);
    final authorityStart = scheme?.end ?? (value.startsWith('//') ? 2 : null);
    if (authorityStart == null) return 0;
    final componentStart = value.indexOf(RegExp(r'[/\?#]'), authorityStart);
    return componentStart < 0 ? value.length : componentStart;
  }
}

class _MpdElement {
  _MpdElement(
    this.name, {
    String? qualifiedName,
    this.attributes = const {},
    this.namespaceUri,
    this.namespaces = const {},
  }) : qualifiedName = qualifiedName ?? name;

  final String name;
  final String qualifiedName;
  final Map<String, String> attributes;
  final String? namespaceUri;
  final Map<String, String> namespaces;
  final List<_MpdElement> children = [];
  final StringBuffer textBuffer = StringBuffer();
  String get text => textBuffer.toString();
}

class _Rational implements Comparable<_Rational> {
  factory _Rational(BigInt numerator, BigInt denominator) {
    if (denominator == BigInt.zero) {
      throw ArgumentError.value(denominator, 'denominator');
    }
    final sign = denominator.isNegative ? BigInt.from(-1) : BigInt.one;
    final positiveDenominator = denominator.abs();
    final adjustedNumerator = numerator * sign;
    final divisor = adjustedNumerator.abs().gcd(positiveDenominator);
    return _Rational._(
      adjustedNumerator ~/ divisor,
      positiveDenominator ~/ divisor,
    );
  }

  const _Rational._(this.numerator, this.denominator);

  static final _Rational zero = _Rational._(BigInt.zero, BigInt.one);

  final BigInt numerator;
  final BigInt denominator;

  factory _Rational.fromInt(int value) =>
      _Rational(BigInt.from(value), BigInt.one);

  bool get isPositive => numerator > BigInt.zero;

  _Rational operator +(_Rational other) => _Rational(
        numerator * other.denominator + other.numerator * denominator,
        denominator * other.denominator,
      );

  _Rational operator -(_Rational other) => _Rational(
        numerator * other.denominator - other.numerator * denominator,
        denominator * other.denominator,
      );

  _Rational operator *(_Rational other) =>
      _Rational(numerator * other.numerator, denominator * other.denominator);

  @override
  int compareTo(_Rational other) =>
      (numerator * other.denominator).compareTo(other.numerator * denominator);
}

extension<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final value in this) {
      if (test(value)) return value;
    }
    return null;
  }
}
