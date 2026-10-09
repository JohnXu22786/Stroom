import 'dart:html' as html;

const _legacyKeyPrefix = 'flutter.';

/// Enumerates legacy preference names without reading or decoding their values.
Set<String> getLegacyPreferenceKeys() => {
      for (final key in html.window.localStorage.keys)
        if (key.startsWith(_legacyKeyPrefix))
          key.substring(_legacyKeyPrefix.length),
    };
