import 'dart:convert';

import 'package:flutter/services.dart';

import 'deck_store.dart';
import 'models.dart';

/// Lists the available courses: the bundled ones (`assets/data/courses.json`)
/// followed by the decks the user imported.
class CourseCatalog {
  const CourseCatalog._(this.courses);

  /// Loads the bundled course list and reads each course's manifest to count
  /// its topics, so courses without content yet can be shown as not ready.
  /// Imported decks are added from [deckStore] when given.
  static Future<CourseCatalog> load({
    AssetBundle? bundle,
    DeckStore? deckStore,
  }) async {
    final assets = bundle ?? rootBundle;
    final json = jsonDecode(
      await assets.loadString('${StudyRepository.basePath}/courses.json'),
    ) as Map<String, dynamic>;
    final courses = await Future.wait([
      for (final c in json['courses'] as List)
        _withTopicCount(
          CourseInfo.fromJson(c as Map<String, dynamic>),
          assets,
        ),
    ]);
    final imported = await deckStore?.list() ?? const <CourseInfo>[];
    return CourseCatalog._(List.unmodifiable([...courses, ...imported]));
  }

  static Future<CourseInfo> _withTopicCount(
    CourseInfo course,
    AssetBundle assets,
  ) async {
    final manifest = await StudyRepository.loadManifest(course.id, assets);
    return course.withTopicCount(manifest.topicPaths.length);
  }

  /// All courses, in display order.
  final List<CourseInfo> courses;

  CourseInfo? byId(String id) {
    for (final c in courses) {
      if (c.id == id) return c;
    }
    return null;
  }
}

/// One course's study content, kept in memory. Loaded from the bundled
/// assets ([load]) or from an imported deck ([fromCourseJson]).
class StudyRepository {
  StudyRepository._(this.courseId, this.manifest, this.topics)
      : _topicsById = {for (final t in topics) t.id: t} {
    flashcards = List.unmodifiable(topics.expand((t) => t.flashcards));
    quiz = List.unmodifiable(topics.expand((t) => t.quiz));
    glossary = List.unmodifiable(_mergeGlossary());
    _glossaryByTerm = {for (final g in glossary) g.term: g};
  }

  static const basePath = 'assets/data';
  static const defaultCourseId = 'sample';

  static String courseDir(String courseId) => '$basePath/courses/$courseId';

  static Future<Manifest> loadManifest(
    String courseId,
    AssetBundle assets,
  ) async =>
      Manifest.fromJson(
        jsonDecode(
          await assets.loadString('${courseDir(courseId)}/manifest.json'),
        ) as Map<String, dynamic>,
      );

  /// Loads a course's manifest and every topic file listed in it.
  static Future<StudyRepository> load({
    String courseId = defaultCourseId,
    AssetBundle? bundle,
  }) async {
    final assets = bundle ?? rootBundle;
    final manifest = await loadManifest(courseId, assets);
    final dir = courseDir(courseId);
    final topics = await Future.wait([
      for (final path in manifest.topicPaths)
        assets.loadString('$dir/$path').then(
              (raw) => Topic.fromJson(jsonDecode(raw) as Map<String, dynamic>),
            ),
    ]);
    topics.sort((a, b) => a.order.compareTo(b.order));
    return StudyRepository._(courseId, manifest, topics);
  }

  /// Builds a repository from a whole-course JSON object
  /// (`{"course", "sections", "topics": [...]}`), as saved by [DeckStore].
  factory StudyRepository.fromCourseJson(
    String courseId,
    Map<String, dynamic> json,
  ) {
    final topics = [
      for (final t in json['topics'] as List)
        Topic.fromJson(t as Map<String, dynamic>),
    ]..sort((a, b) => a.order.compareTo(b.order));
    final manifest = Manifest(
      course: json['course'] as String,
      sections: List<String>.from(json['sections'] as List),
      topicPaths: const [],
    );
    return StudyRepository._(courseId, manifest, topics);
  }

  final String courseId;
  final Manifest manifest;

  /// All topics, in course order.
  final List<Topic> topics;
  final Map<String, Topic> _topicsById;
  late final Map<String, GlossaryTerm> _glossaryByTerm;

  late final List<Flashcard> flashcards;
  late final List<QuizQuestion> quiz;

  /// Merged glossary: one entry per term, ordered by section (course order),
  /// then alphabetically by term.
  late final List<GlossaryTerm> glossary;

  List<String> get sections => manifest.sections;

  Topic topicById(String id) => _topicsById[id]!;

  /// Looks up a glossary term by its exact name (as used in `related`).
  GlossaryTerm? glossaryTerm(String term) => _glossaryByTerm[term];

  List<GlossaryTerm> _mergeGlossary() {
    final firstEntry = <String, GlossaryEntry>{};
    final firstSection = <String, String>{};
    final topicIds = <String, Set<String>>{};

    for (final topic in topics) {
      for (final entry in topic.glossary) {
        firstEntry.putIfAbsent(entry.term, () => entry);
        firstSection.putIfAbsent(entry.term, () => topic.section);
        topicIds.putIfAbsent(entry.term, () => <String>{}).add(topic.id);
      }
    }

    final sectionIndex = {
      for (var i = 0; i < manifest.sections.length; i++)
        manifest.sections[i]: i,
    };

    final merged = [
      for (final term in firstEntry.keys)
        GlossaryTerm(
          entry: firstEntry[term]!,
          section: firstSection[term]!,
          topicIds: topicIds[term]!,
        ),
    ];
    merged.sort((a, b) {
      final bySection =
          (sectionIndex[a.section] ?? 0).compareTo(sectionIndex[b.section] ?? 0);
      if (bySection != 0) return bySection;
      return a.term.toLowerCase().compareTo(b.term.toLowerCase());
    });
    return merged;
  }
}
