import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../data/deck_importer.dart';

const bool canPickFolder = true;

/// Reads every `.json` file in [folder] and its subfolders.
///
/// On Android the folder comes from the Storage Access Framework as a
/// `content://` tree URI, which `dart:io` can't open, so a small native
/// helper in `MainActivity.kt` reads it. Everywhere else it's a normal path.
Future<List<SourceFile>> readJsonFolder(Uri folder) async {
  if (Platform.isAndroid) {
    final files = await _channel.invokeMapMethod<String, String>(
      'readJsonTree',
      {'uri': folder.toString()},
    );
    return [for (final e in (files ?? {}).entries) SourceFile(e.key, e.value)];
  }

  final dir = Directory(folder.toFilePath());
  final result = <SourceFile>[];
  await for (final entity in dir.list(recursive: true, followLinks: false)) {
    if (entity is File && entity.path.toLowerCase().endsWith('.json')) {
      final relative = entity.path.substring(dir.path.length + 1);
      result.add(SourceFile(relative, await entity.readAsString()));
    }
  }
  return result;
}

const _channel = MethodChannel('flashcards/folder');

/// Stores each imported deck as `<app support dir>/decks/<id>.json`.
/// That folder is private to the app and removed when it's uninstalled.
class DeckStorage {
  Future<Directory> _dir() async {
    final base = await getApplicationSupportDirectory();
    return Directory('${base.path}/decks').create(recursive: true);
  }

  Future<File> _file(String id) async => File('${(await _dir()).path}/$id.json');

  Future<List<String>> ids() async {
    final ids = <String>[];
    await for (final e in (await _dir()).list()) {
      if (e is File && e.path.endsWith('.json')) {
        ids.add(e.uri.pathSegments.last.replaceAll(RegExp(r'\.json$'), ''));
      }
    }
    return ids;
  }

  Future<String?> read(String id) async {
    final file = await _file(id);
    return await file.exists() ? file.readAsString() : null;
  }

  Future<void> write(String id, String json) async =>
      (await _file(id)).writeAsString(json, flush: true);

  Future<void> delete(String id) async {
    final file = await _file(id);
    if (await file.exists()) await file.delete();
  }
}
