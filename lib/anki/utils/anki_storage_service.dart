import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/collection.dart';

/// Persistence service for the Anki collection.
///
/// Uses SharedPreferences for simple JSON-based storage.
/// In a production app, this would use SQLite for better performance,
/// especially with large collections.
class AnkiStorageService {
  static const String _storageKey = 'anki_collection_data';

  /// Saves the collection to persistent storage.
  Future<void> saveCollection(AnkiCollection collection) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(collection.toJson());
    await prefs.setString(_storageKey, jsonStr);
  }

  /// Loads the collection from persistent storage.
  /// Returns null if no saved collection exists.
  Future<AnkiCollection?> loadCollection() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_storageKey);
    if (jsonStr == null || jsonStr.isEmpty) return null;

    try {
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return AnkiCollection.fromJson(json);
    } catch (e) {
      return null;
    }
  }

  /// Deletes the saved collection.
  Future<void> deleteCollection() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}
