import 'package:shared_preferences/shared_preferences.dart';

import '../data/deck_importer.dart';

/// Web has no folder access; imported decks live in browser storage.
const bool canPickFolder = false;

Future<List<SourceFile>> readJsonFolder(Uri folder) =>
    throw UnsupportedError('Folders cannot be opened in the browser.');

/// Stores each imported deck as one JSON string, keyed by deck id.
class DeckStorage {
  static const _prefix = 'deck:';

  Future<List<String>> ids() async {
    final prefs = await SharedPreferences.getInstance();
    return [
      for (final k in prefs.getKeys())
        if (k.startsWith(_prefix)) k.substring(_prefix.length),
    ];
  }

  Future<String?> read(String id) async =>
      (await SharedPreferences.getInstance()).getString('$_prefix$id');

  Future<void> write(String id, String json) async =>
      (await SharedPreferences.getInstance()).setString('$_prefix$id', json);

  Future<void> delete(String id) async =>
      (await SharedPreferences.getInstance()).remove('$_prefix$id');
}
