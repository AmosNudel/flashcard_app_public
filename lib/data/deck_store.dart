import 'dart:convert';

import '../platform/device.dart';
import 'deck_importer.dart';
import 'models.dart';
import 'repository.dart';

/// The decks the user imported. Each is saved as one course file (see
/// [DeckDraft.toJson]) in storage private to the app.
class DeckStore {
  DeckStore({DeckStorage? storage}) : _storage = storage ?? DeckStorage();

  final DeckStorage _storage;

  /// Prefix for imported deck ids, so they never clash with bundled ones.
  static const idPrefix = 'user-';

  static bool isImportedId(String id) => id.startsWith(idPrefix);

  /// All imported decks, sorted by title. Unreadable files are skipped.
  Future<List<CourseInfo>> list() async {
    final courses = <CourseInfo>[];
    for (final id in await _storage.ids()) {
      try {
        final json = await _readJson(id);
        if (json == null) continue;
        final title = json['course'] as String;
        courses.add(CourseInfo(
          id: id,
          title: title,
          shortTitle: title,
          topicCount: (json['topics'] as List).length,
          isImported: true,
        ));
      } on Object {
        // A damaged file shouldn't stop the app from starting.
      }
    }
    courses.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return courses;
  }

  /// Saves [draft] as a new deck and returns its id.
  Future<String> save(DeckDraft draft) async {
    final slug = draft.title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final short = slug.length > 40 ? slug.substring(0, 40) : slug;
    final id = '$idPrefix${short.isEmpty ? 'deck' : short}-'
        '${DateTime.now().millisecondsSinceEpoch}';
    await _storage.write(id, jsonEncode(draft.toJson()));
    return id;
  }

  Future<StudyRepository> load(String id) async {
    final json = await _readJson(id);
    if (json == null) throw StateError('Deck "$id" no longer exists.');
    return StudyRepository.fromCourseJson(id, json);
  }

  Future<void> delete(String id) => _storage.delete(id);

  Future<Map<String, dynamic>?> _readJson(String id) async {
    final text = await _storage.read(id);
    return text == null ? null : jsonDecode(text) as Map<String, dynamic>;
  }
}
