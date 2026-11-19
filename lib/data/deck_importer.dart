import 'dart:convert';

import 'models.dart';

/// One file picked by the user: its name (used in messages and for matching
/// manifest entries) and its text.
class SourceFile {
  const SourceFile(this.name, this.text);

  final String name;
  final String text;
}

/// A deck parsed from the user's files, ready to be saved.
///
/// [toJson] produces the "course file" format: one JSON file that holds the
/// whole deck. That is also how imported decks are stored on the device.
class DeckDraft {
  DeckDraft({
    required this.title,
    required this.sections,
    required this.topics,
  });

  String title;
  final List<String> sections;

  /// Normalised topic objects (every field present, ids unique).
  final List<Map<String, dynamic>> topics;

  int _count(String key) =>
      topics.fold(0, (sum, t) => sum + (t[key] as List).length);

  int get flashcardCount => _count('flashcards');
  int get quizCount => _count('quiz');
  int get glossaryCount => _count('glossary');

  Map<String, dynamic> toJson() => {
        'course': title,
        'sections': sections,
        'topics': topics,
      };
}

/// Thrown when the picked files can't be imported. [problems] lists every
/// issue found, each prefixed with the file it came from.
class DeckImportException implements Exception {
  const DeckImportException(this.problems);

  final List<String> problems;

  @override
  String toString() => 'DeckImportException:\n${problems.join('\n')}';
}

/// Turns user-supplied JSON files into [DeckDraft]s.
///
/// Accepted files (see README.md for the full format):
/// * **Course file**: `{"course": "...", "sections": [...], "topics": [{...}]}`
///   - a whole deck in one file. Each one becomes its own deck.
/// * **Topic file**: `{"title": "...", "flashcards": [...], "quiz": [...],
///   "glossary": [...]}`. All topic files picked together become one deck.
/// * **manifest.json**: `{"course": "...", "sections": [...], "topics":
///   ["topics/001_x.json", ...]}`. Optional; names the deck and sets the
///   topic order when importing a folder of topic files.
///
/// Import is all-or-nothing: if any file has a problem, nothing is imported
/// and every problem is reported.
class DeckImporter {
  DeckImporter._();

  static List<DeckDraft> parse(
    List<SourceFile> files, {
    String? fallbackTitle,
  }) {
    final problems = <String>[];
    final drafts = <DeckDraft>[];
    final topicFiles = <(SourceFile, Map<String, dynamic>)>[];
    Map<String, dynamic>? manifest;

    for (final file in files) {
      final Object? json;
      try {
        // Some editors (e.g. Windows Notepad) start the file with a BOM.
        json = jsonDecode(file.text.replaceFirst('﻿', ''));
      } on FormatException catch (e) {
        problems.add('${file.name}: not valid JSON (${e.message}'
            '${e.offset != null ? ' at character ${e.offset}' : ''}).');
        continue;
      }
      if (json is! Map<String, dynamic>) {
        problems.add('${file.name}: the file must contain a JSON object '
            '({ ... }), not ${_describe(json)}.');
        continue;
      }

      final topics = json['topics'];
      if (topics is List && topics.isNotEmpty && topics.every((t) => t is String)) {
        manifest = json;
      } else if (topics is List) {
        final draft = _parseCourseFile(file, json, problems);
        if (draft != null) drafts.add(draft);
      } else if (json.containsKey('courses')) {
        // A copy of the app's own courses.json: nothing to import from it.
        continue;
      } else if (_topicKeys.any(json.containsKey)) {
        topicFiles.add((file, json));
      } else {
        problems.add('${file.name}: not a deck file. Expected "flashcards", '
            '"quiz" or "glossary" (a topic file), or a "topics" list '
            '(a course file). See the template in the app.');
      }
    }

    if (topicFiles.isNotEmpty) {
      final draft = _parseTopicFiles(
        topicFiles,
        manifest,
        problems,
        fallbackTitle: _humanize(fallbackTitle ?? topicFiles.first.$1.name),
      );
      if (draft != null) drafts.add(draft);
    } else if (manifest != null && drafts.isEmpty && problems.isEmpty) {
      problems.add('manifest.json lists topic files, but none of them were '
          'selected. Select the topic files too (or the whole folder).');
    }

    if (drafts.isEmpty && problems.isEmpty) {
      problems.add('No JSON deck files were found.');
    }
    if (problems.isNotEmpty) throw DeckImportException(problems);
    return drafts;
  }

  static const _topicKeys = ['flashcards', 'quiz', 'glossary'];

  static DeckDraft? _parseCourseFile(
    SourceFile file,
    Map<String, dynamic> json,
    List<String> problems,
  ) {
    final before = problems.length;
    final rawTopics = json['topics'] as List;
    final topics = <Map<String, dynamic>>[];
    for (var i = 0; i < rawTopics.length; i++) {
      final t = rawTopics[i];
      final where = '${file.name} › topics[$i]';
      if (t is! Map<String, dynamic>) {
        problems.add('$where: must be an object, not ${_describe(t)}.');
        continue;
      }
      final topic = _normalizeTopic(t, where, fallbackTitle: 'Topic ${i + 1}',
          problems: problems);
      if (topic != null) topics.add(topic);
    }
    if (rawTopics.isEmpty) problems.add('${file.name}: "topics" is empty.');
    if (problems.length > before) return null;

    return _finish(
      title: _string(json['course']) ??
          _string(json['title']) ??
          _humanize(file.name),
      declaredSections: json['sections'],
      topics: topics,
      where: file.name,
      problems: problems,
    );
  }

  static DeckDraft? _parseTopicFiles(
    List<(SourceFile, Map<String, dynamic>)> files,
    Map<String, dynamic>? manifest,
    List<String> problems, {
    required String fallbackTitle,
  }) {
    final before = problems.length;

    // Manifest order first (matched by file name), then the rest by name.
    final manifestOrder = <String, int>{
      if (manifest != null)
        for (final (i, path) in (manifest['topics'] as List).indexed)
          _baseName(path as String): i,
    };
    final sorted = [...files]..sort((a, b) {
        final ia = manifestOrder[_baseName(a.$1.name)];
        final ib = manifestOrder[_baseName(b.$1.name)];
        if (ia != null && ib != null) return ia.compareTo(ib);
        if (ia != null) return -1;
        if (ib != null) return 1;
        return a.$1.name.compareTo(b.$1.name);
      });

    final topics = <Map<String, dynamic>>[];
    for (final (file, json) in sorted) {
      final topic = _normalizeTopic(json, file.name,
          fallbackTitle: _humanize(file.name), problems: problems);
      if (topic != null) topics.add(topic);
    }
    if (problems.length > before) return null;

    return _finish(
      title: _string(manifest?['course']) ?? fallbackTitle,
      declaredSections: manifest?['sections'],
      topics: topics,
      where: 'manifest.json',
      problems: problems,
    );
  }

  /// Orders topics, makes ids unique, settles the section list, and drops
  /// glossary links to terms that don't exist in the deck.
  static DeckDraft? _finish({
    required String title,
    required Object? declaredSections,
    required List<Map<String, dynamic>> topics,
    required String where,
    required List<String> problems,
  }) {
    // Stable sort by the topic's own "order", when every topic has one.
    if (topics.every((t) => t['order'] is num)) {
      final indexed = topics.indexed.toList()
        ..sort((a, b) {
          final byOrder = (a.$2['order'] as num).compareTo(b.$2['order'] as num);
          return byOrder != 0 ? byOrder : a.$1.compareTo(b.$1);
        });
      topics
        ..clear()
        ..addAll(indexed.map((e) => e.$2));
    }

    final usedIds = <String>{};
    for (final (i, t) in topics.indexed) {
      t['order'] = i + 1;
      var id = t['id'] as String;
      for (var n = 2; !usedIds.add(id); n++) {
        id = '${t['id']}-$n';
      }
      t['id'] = id;
    }

    final sections = <String>[];
    if (declaredSections != null) {
      if (declaredSections is List && declaredSections.every((s) => s is String)) {
        sections.addAll(declaredSections.cast<String>());
      } else {
        problems.add('$where: "sections" must be a list of strings.');
        return null;
      }
    }
    for (final t in topics) {
      final s = t['section'] as String;
      if (!sections.contains(s)) sections.add(s);
    }

    final terms = {
      for (final t in topics)
        for (final g in t['glossary'] as List) (g as Map)['term'],
    };
    for (final t in topics) {
      for (final g in (t['glossary'] as List).cast<Map<String, dynamic>>()) {
        (g['related'] as List).retainWhere(terms.contains);
      }
    }

    return DeckDraft(title: title.trim(), sections: sections, topics: topics);
  }

  /// Validates one topic and returns it with every field filled in, or null
  /// (after adding to [problems]) when it can't be used.
  static Map<String, dynamic>? _normalizeTopic(
    Map<String, dynamic> json,
    String where, {
    required String fallbackTitle,
    required List<String> problems,
  }) {
    final before = problems.length;
    final title = _string(json['title']) ?? fallbackTitle;

    final flashcards = <Map<String, dynamic>>[];
    for (final (i, raw) in _list(json, 'flashcards', where, problems).indexed) {
      final at = '$where › flashcards[$i]';
      final c = _asObject(raw, at, problems);
      if (c == null) continue;
      final front = _required(c, 'front', at, problems);
      final back = _required(c, 'back', at, problems);
      final explanation = _optional(c, 'explanation', at, problems);
      if (front == null || back == null) continue;
      flashcards.add({
        'front': front,
        'back': back,
        'explanation': ?explanation,
      });
    }

    final quiz = <Map<String, dynamic>>[];
    for (final (i, raw) in _list(json, 'quiz', where, problems).indexed) {
      final at = '$where › quiz[$i]';
      final q = _asObject(raw, at, problems);
      if (q == null) continue;
      final question = _required(q, 'question', at, problems);
      final explanation = _optional(q, 'explanation', at, problems) ?? '';
      final options = q['options'];
      final answer = q['answerIndex'];
      if (options is! List ||
          options.length < 2 ||
          !options.every((o) => o is String && o.trim().isNotEmpty)) {
        problems.add('$at: "options" must be a list of at least 2 '
            'non-empty strings.');
        continue;
      }
      if (options.toSet().length != options.length) {
        problems.add('$at: "options" contains the same answer twice.');
        continue;
      }
      if (answer is! int || answer < 0 || answer >= options.length) {
        problems.add('$at: "answerIndex" must be a whole number from 0 to '
            '${options.length - 1} (the position of the correct option, '
            'counting from 0).');
        continue;
      }
      if (question == null) continue;
      quiz.add({
        'question': question,
        'options': List<String>.from(options),
        'answerIndex': answer,
        'explanation': explanation,
      });
    }

    final glossary = <Map<String, dynamic>>[];
    for (final (i, raw) in _list(json, 'glossary', where, problems).indexed) {
      final at = '$where › glossary[$i]';
      final g = _asObject(raw, at, problems);
      if (g == null) continue;
      final term = _required(g, 'term', at, problems);
      final definition = _required(g, 'definition', at, problems);
      final extras = {
        for (final key in const ['analogy', 'example', 'supplement'])
          key: _optional(g, key, at, problems),
      };
      final related = g['related'];
      if (related != null &&
          (related is! List || !related.every((r) => r is String))) {
        problems.add('$at: "related" must be a list of term names.');
        continue;
      }
      if (term == null || definition == null) continue;
      glossary.add({
        'term': term,
        'definition': definition,
        for (final e in extras.entries)
          if (e.value != null) e.key: e.value,
        'related': [...?related as List?],
      });
    }

    if (problems.length > before) return null;
    if (flashcards.isEmpty && quiz.isEmpty && glossary.isEmpty) {
      problems.add('$where: has no flashcards, quiz questions or glossary '
          'terms.');
      return null;
    }

    final order = json['order'];
    return {
      'id': _string(json['id']) ?? _slug(title),
      'order': order is num ? order : null,
      'section': _string(json['section']) ?? Topic.defaultSection,
      'title': title,
      'summary': _string(json['summary']) ?? '',
      'glossary': glossary,
      'flashcards': flashcards,
      'quiz': quiz,
    };
  }

  static List<Object?> _list(
    Map<String, dynamic> json,
    String key,
    String where,
    List<String> problems,
  ) {
    final value = json[key];
    if (value == null) return const [];
    if (value is List) return value;
    problems.add('$where: "$key" must be a list ([ ... ]).');
    return const [];
  }

  static Map<String, dynamic>? _asObject(
    Object? value,
    String at,
    List<String> problems,
  ) {
    if (value is Map<String, dynamic>) return value;
    problems.add('$at: must be an object ({ ... }), not ${_describe(value)}.');
    return null;
  }

  static String? _required(
    Object? obj,
    String key,
    String at,
    List<String> problems,
  ) {
    final value = (obj as Map)[key];
    if (value is String && value.trim().isNotEmpty) return value;
    problems.add(value == null
        ? '$at: missing "$key".'
        : '$at: "$key" must be non-empty text.');
    return null;
  }

  static String? _optional(
    Object? obj,
    String key,
    String at,
    List<String> problems,
  ) {
    final value = (obj as Map)[key];
    if (value == null || value is String) {
      return (value as String?)?.trim().isEmpty ?? true ? null : value;
    }
    problems.add('$at: "$key" must be text.');
    return null;
  }

  static String? _string(Object? value) =>
      value is String && value.trim().isNotEmpty ? value.trim() : null;

  static String _describe(Object? value) => switch (value) {
        null => 'null',
        List() => 'a list',
        String() => 'text',
        num() => 'a number',
        bool() => 'true/false',
        _ => 'something else',
      };

  static String _baseName(String path) =>
      path.split(RegExp(r'[/\\]')).last.toLowerCase();

  /// "003_my-topic.json" → "My topic".
  static String _humanize(String fileName) {
    var name = _baseName(fileName).replaceAll(RegExp(r'\.json$'), '');
    name = name.replaceFirst(RegExp(r'^\d+[_\-\s]*'), '');
    name = name.replaceAll(RegExp(r'[_\-]+'), ' ').trim();
    if (name.isEmpty) return 'My deck';
    return name[0].toUpperCase() + name.substring(1);
  }

  static String _slug(String text) {
    final slug = text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return slug.isEmpty ? 'topic' : slug;
  }
}
