import 'dart:convert';

import 'm3u8_parser.dart';

/// Stores the merged container choice for each HLS playlist on a task.
///
/// Task metadata is persisted as string values, so the playlist-to-extension
/// map is JSON encoded. The legacy single-extension value remains a fallback
/// for tasks saved before per-playlist metadata was introduced.
abstract final class PlaylistMergedExtensions {
  static const metadataKey = 'playlistMergedExtensions';
  static const legacyMetadataKey = 'playlistMergedExtension';

  static String encode(Map<String, String> extensionsByPlaylist) =>
      jsonEncode(extensionsByPlaylist);

  static Map<String, String> fromPlaylists(
    Iterable<({String url, bool hasInitializationMap})> playlists,
  ) =>
      {
        for (final playlist in playlists)
          playlist.url: M3U8Parser.mergedFileExtension(
            hasInitializationMap: playlist.hasInitializationMap,
          ),
      };

  static Map<String, String> decode(String? encoded) {
    if (encoded == null) return const {};
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) return const {};
      return {
        for (final entry in decoded.entries)
          if (entry.key is String && entry.value is String)
            entry.key as String: entry.value as String,
      };
    } on FormatException {
      return const {};
    }
  }

  static String? forPlaylist(Map<String, String> metadata, String playlistUrl) {
    if (metadata.containsKey(metadataKey)) {
      return decode(metadata[metadataKey])[playlistUrl];
    }
    return metadata[legacyMetadataKey];
  }
}
