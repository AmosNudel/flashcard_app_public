import 'dart:convert';

import 'package:flashcards/data/deck_importer.dart';
import 'package:flashcards/data/deck_store.dart';
import 'package:flashcards/data/deck_template.dart';
import 'package:flashcards/data/repository.dart';
import 'package:flashcards/platform/device.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

String _json(Object o) => jsonEncode(o);

/// In-memory stand-in for the on-device storage.
class _MemoryStorage implements DeckStorage {
  final files = <String, String>{};
  @override
  Future<List<String>> ids() async => files.keys.toList();
  @override
  Future<String?> read(String id) async => files[id];
  @override
  Future<void> write(String id, String json) async => files[id] = json;
  @override
  Future<void> delete(String id) async => files.remove(id);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the in-app template imports cleanly and loads', () {
    final drafts =
        DeckImporter.parse([const SourceFile('my_deck.json', deckTemplate)]);
    expect(drafts, hasLength(1));
    final repo = StudyRepository.fromCourseJson('x', drafts.single.toJson());
    expect(repo.manifest.course, 'My Deck');
    expect(repo.flashcards, hasLength(1));
    expect(repo.quiz.single.correctOption, 'Correct answer');
    // "Key Term" links to "Other Term", which exists.
    expect(repo.glossaryTerm('Key Term')!.entry.related, ['Other Term']);
  });

  test('the bundled sample folder imports as one deck in manifest order',
      () async {
    final dir = '${StudyRepository.basePath}/courses/sample';
    final manifest = await rootBundle.loadString('$dir/manifest.json');
    final paths = (jsonDecode(manifest)['topics'] as List).cast<String>();
    final files = [
      // Topic files deliberately listed in reverse.
      for (final p in paths.reversed)
        SourceFile(p, await rootBundle.loadString('$dir/$p')),
      SourceFile('manifest.json', manifest),
    ];
    final draft = DeckImporter.parse(files).single;
    expect(draft.title, 'Sample Deck: The Solar System');
    expect(draft.topics.map((t) => t['id']), ['inner-planets', 'outer-planets']);
  });

  test('minimal topic files become one deck with defaults filled in', () {
    final drafts = DeckImporter.parse([
      SourceFile('02_verbs.json', _json({
        'flashcards': [
          {'front': 'hablar', 'back': 'to speak'},
        ],
      })),
      SourceFile('01_greetings.json', _json({
        'flashcards': [
          {'front': 'hola', 'back': 'hello'},
        ],
      })),
    ], fallbackTitle: '3_spanish');
    final d = drafts.single;
    expect(d.title, 'Spanish');
    expect(d.topics.map((t) => t['title']), ['Greetings', 'Verbs']);
    expect(d.sections, ['General']);
    final repo = StudyRepository.fromCourseJson('x', d.toJson());
    expect(repo.flashcards, hasLength(2));
    expect(repo.quiz, isEmpty);
  });

  test('each course file becomes its own deck; duplicate ids are fixed', () {
    final topic = {
      'id': 'same',
      'title': 'T',
      'flashcards': [
        {'front': 'a', 'back': 'b'},
      ],
    };
    final drafts = DeckImporter.parse([
      SourceFile('a.json', _json({'course': 'A', 'topics': [topic, topic]})),
      SourceFile('b.json', _json({'course': 'B', 'topics': [topic]})),
    ]);
    expect(drafts.map((d) => d.title), ['A', 'B']);
    expect(drafts.first.topics.map((t) => t['id']), ['same', 'same-2']);
  });

  test('glossary links to missing terms are dropped', () {
    final d = DeckImporter.parse([
      SourceFile('t.json', _json({
        'glossary': [
          {'term': 'A', 'definition': 'a', 'related': ['B', 'Missing']},
          {'term': 'B', 'definition': 'b'},
        ],
      })),
    ]).single;
    final a = (d.topics.single['glossary'] as List).first as Map;
    expect(a['related'], ['B']);
  });

  test('reports every problem, with file and position, and imports nothing',
      () {
    try {
      DeckImporter.parse([
        const SourceFile('broken.json', '{ "flashcards": [ '),
        SourceFile('bad.json', _json({
          'flashcards': [
            {'front': 'only a front'},
          ],
          'quiz': [
            {
              'question': 'Q',
              'options': ['a', 'b'],
              'answerIndex': 2,
            },
          ],
        })),
        SourceFile('other.json', _json({'hello': 1})),
        const SourceFile('list.json', '[1, 2]'),
      ]);
      fail('expected DeckImportException');
    } on DeckImportException catch (e) {
      final all = e.problems.join('\n');
      expect(all, contains('broken.json: not valid JSON'));
      expect(all, contains('bad.json › flashcards[0]: missing "back"'));
      expect(all, contains('bad.json › quiz[0]: "answerIndex"'));
      expect(all, contains('other.json: not a deck file'));
      expect(all, contains('list.json: the file must contain a JSON object'));
    }
  });

  test('a byte-order mark at the start of a file is ignored', () {
    final d = DeckImporter.parse([
      SourceFile('bom.json', '﻿${_json({
        'flashcards': [
          {'front': 'a', 'back': 'b'},
        ],
      })}'),
    ]).single;
    expect(d.flashcardCount, 1);
  });

  test('DeckStore saves, lists, loads and deletes imported decks', () async {
    final store = DeckStore(storage: _MemoryStorage());
    final draft =
        DeckImporter.parse([const SourceFile('t.json', deckTemplate)]).single;
    final id = await store.save(draft);
    expect(DeckStore.isImportedId(id), isTrue);

    final listed = await store.list();
    expect(listed.single.title, 'My Deck');
    expect(listed.single.isImported, isTrue);
    expect((await store.load(id)).flashcards, hasLength(1));

    final catalog = await CourseCatalog.load(deckStore: store);
    expect(catalog.courses.map((c) => c.id), contains(id));

    await store.delete(id);
    expect(await store.list(), isEmpty);
  });
}
