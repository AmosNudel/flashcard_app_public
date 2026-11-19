/// Data models for the study content.
///
/// Bundled decks: `assets/data/courses.json` lists them; each lives in
/// `assets/data/courses/<id>/` with a `manifest.json` and a `topics/` folder.
/// Decks the user imports are stored on the device (see `deck_store.dart`).
/// The JSON format is documented in README.md.
library;

/// One entry of `assets/data/courses.json`.
class CourseInfo {
  const CourseInfo({
    required this.id,
    required this.title,
    required this.shortTitle,
    this.topicCount = 0,
    this.isImported = false,
  });

  factory CourseInfo.fromJson(Map<String, dynamic> json) => CourseInfo(
        id: json['id'] as String,
        title: json['title'] as String,
        shortTitle: json['shortTitle'] as String? ?? json['title'] as String,
      );

  final String id;
  final String title;

  /// Compact name for the app bar.
  final String shortTitle;

  /// Number of topics in the course's manifest. 0 = content not ready yet.
  final int topicCount;

  /// True for decks the user imported (stored on the device, deletable).
  final bool isImported;

  bool get isReady => topicCount > 0;

  CourseInfo withTopicCount(int count) => CourseInfo(
        id: id,
        title: title,
        shortTitle: shortTitle,
        topicCount: count,
        isImported: isImported,
      );
}

class Manifest {
  const Manifest({
    required this.course,
    required this.sections,
    required this.topicPaths,
  });

  factory Manifest.fromJson(Map<String, dynamic> json) => Manifest(
        course: json['course'] as String,
        sections: List<String>.from(json['sections'] as List),
        topicPaths: List<String>.from(json['topics'] as List),
      );

  final String course;

  /// The course sections, in course order.
  final List<String> sections;

  /// Topic file paths relative to the course folder, in course order.
  final List<String> topicPaths;
}

class Topic {
  const Topic({
    required this.id,
    required this.order,
    required this.section,
    required this.title,
    required this.summary,
    required this.glossary,
    required this.flashcards,
    required this.quiz,
  });

  /// Only `id` and `title` are required here; the importer fills them in
  /// when a hand-written file leaves them out. Every other field is optional.
  factory Topic.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    return Topic(
      id: id,
      order: (json['order'] as num?)?.toInt() ?? 0,
      section: json['section'] as String? ?? defaultSection,
      title: json['title'] as String,
      summary: json['summary'] as String? ?? '',
      glossary: [
        for (final e in json['glossary'] as List? ?? const [])
          GlossaryEntry.fromJson(e as Map<String, dynamic>),
      ],
      flashcards: [
        for (final e in json['flashcards'] as List? ?? const [])
          Flashcard.fromJson(e as Map<String, dynamic>, topicId: id),
      ],
      quiz: [
        for (final e in json['quiz'] as List? ?? const [])
          QuizQuestion.fromJson(e as Map<String, dynamic>, topicId: id),
      ],
    );
  }

  /// Section used when a topic doesn't name one.
  static const defaultSection = 'General';

  final String id;
  final int order;
  final String section;
  final String title;
  final String summary;
  final List<GlossaryEntry> glossary;
  final List<Flashcard> flashcards;
  final List<QuizQuestion> quiz;
}

class GlossaryEntry {
  const GlossaryEntry({
    required this.term,
    required this.definition,
    this.analogy,
    this.example,
    this.supplement,
    this.related = const [],
  });

  factory GlossaryEntry.fromJson(Map<String, dynamic> json) => GlossaryEntry(
        term: json['term'] as String,
        definition: json['definition'] as String,
        analogy: json['analogy'] as String?,
        example: json['example'] as String?,
        supplement: json['supplement'] as String?,
        related: List<String>.from(json['related'] as List? ?? const []),
      );

  final String term;
  final String definition;

  /// A plain-language, everyday picture of the idea, if any.
  final String? analogy;

  /// A concrete scenario from the course's domain showing the term in use.
  final String? example;

  /// Extra background beyond the core definition, if any.
  final String? supplement;

  /// Names of other glossary terms (each matches an existing `term` exactly).
  final List<String> related;

  /// All searchable text of the entry except the term, lower-cased.
  String get searchableBody => [definition, analogy, example, supplement]
      .whereType<String>()
      .join('\n')
      .toLowerCase();
}

class Flashcard {
  const Flashcard({
    required this.front,
    required this.back,
    required this.topicId,
    this.explanation,
  });

  factory Flashcard.fromJson(
    Map<String, dynamic> json, {
    required String topicId,
  }) =>
      Flashcard(
        front: json['front'] as String,
        back: json['back'] as String,
        explanation: json['explanation'] as String?,
        topicId: topicId,
      );

  final String front;

  /// The short answer to remember.
  final String back;

  /// Optional context: why the answer is true, an example, or a contrast.
  final String? explanation;
  final String topicId;
}

class QuizQuestion {
  const QuizQuestion({
    required this.question,
    required this.options,
    required this.answerIndex,
    required this.explanation,
    required this.topicId,
  });

  factory QuizQuestion.fromJson(
    Map<String, dynamic> json, {
    required String topicId,
  }) =>
      QuizQuestion(
        question: json['question'] as String,
        options: List<String>.from(json['options'] as List),
        answerIndex: (json['answerIndex'] as num).toInt(),
        explanation: json['explanation'] as String? ?? '',
        topicId: topicId,
      );

  final String question;
  final List<String> options;

  /// Index of the correct option in [options] as stored in the data.
  /// Use [correctOption] to identify the answer after shuffling.
  final int answerIndex;
  final String explanation;
  final String topicId;

  String get correctOption => options[answerIndex];
}

/// A glossary term merged across all topics it appears in.
class GlossaryTerm {
  GlossaryTerm({
    required this.entry,
    required this.section,
    required Set<String> topicIds,
  }) : topicIds = Set.unmodifiable(topicIds);

  /// The first occurrence of the term in course order.
  final GlossaryEntry entry;

  /// The section of the first topic the term appears in.
  final String section;

  /// Every topic that defines this term.
  final Set<String> topicIds;

  String get term => entry.term;
}
