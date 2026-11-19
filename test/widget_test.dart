import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:flashcards/data/random_deck.dart';
import 'package:flashcards/data/repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CourseCatalog', () {
    late CourseCatalog catalog;

    setUpAll(() async {
      catalog = await CourseCatalog.load();
    });

    test('lists every course once, and each manifest loads', () {
      final ids = catalog.courses.map((c) => c.id).toList();
      expect(ids.toSet().length, ids.length);
      expect(ids, contains(StudyRepository.defaultCourseId));
    });

    test('the default course is ready', () {
      expect(catalog.byId(StudyRepository.defaultCourseId)!.isReady, isTrue);
    });
  });

  test('the sample course has both topics', () async {
    final repo = await StudyRepository.load();
    expect(repo.topics.map((t) => t.id), ['inner-planets', 'outer-planets']);
  });

  // Content checks for every course that has topics. New courses get
  // validated automatically as their topic files are added.
  group('Course content', () {
    late List<StudyRepository> repos;

    setUpAll(() async {
      final catalog = await CourseCatalog.load();
      repos = await Future.wait([
        for (final c in catalog.courses.where((c) => c.isReady))
          StudyRepository.load(courseId: c.id),
      ]);
    });

    test('loads every topic listed in the manifest, in course order', () {
      for (final repo in repos) {
        expect(repo.topics.length, repo.manifest.topicPaths.length,
            reason: repo.courseId);
        for (var i = 1; i < repo.topics.length; i++) {
          expect(repo.topics[i].order, greaterThan(repo.topics[i - 1].order),
              reason: '${repo.courseId}: ${repo.topics[i].id}');
        }
      }
    });

    test('topic ids are unique within a course', () {
      for (final repo in repos) {
        final ids = repo.topics.map((t) => t.id).toList();
        expect(ids.toSet().length, ids.length, reason: repo.courseId);
      }
    });

    test('every topic belongs to a known section', () {
      for (final repo in repos) {
        for (final t in repo.topics) {
          expect(repo.sections, contains(t.section),
              reason: '${repo.courseId}: ${t.id}');
        }
      }
    });

    test('content is non-empty', () {
      for (final repo in repos) {
        expect(repo.flashcards, isNotEmpty, reason: repo.courseId);
        expect(repo.quiz, isNotEmpty, reason: repo.courseId);
        expect(repo.glossary, isNotEmpty, reason: repo.courseId);
      }
    });

    test('quiz questions have 4 distinct options and a valid answer', () {
      for (final repo in repos) {
        for (final q in repo.quiz) {
          final reason = '${repo.courseId}: ${q.question}';
          expect(q.options.length, 4, reason: reason);
          expect(q.options.toSet().length, 4, reason: reason);
          expect(q.answerIndex, inInclusiveRange(0, 3), reason: reason);
        }
      }
    });

    test('glossary terms are unique and related links resolve', () {
      for (final repo in repos) {
        final terms = repo.glossary.map((g) => g.term).toList();
        expect(terms.toSet().length, terms.length, reason: repo.courseId);
        for (final g in repo.glossary) {
          for (final r in g.entry.related) {
            expect(repo.glossaryTerm(r), isNotNull,
                reason: '${repo.courseId}: "${g.term}" → "$r"');
          }
        }
      }
    });

    test('flashcards and quiz questions point to existing topics', () {
      for (final repo in repos) {
        for (final f in repo.flashcards) {
          expect(() => repo.topicById(f.topicId), returnsNormally);
        }
        for (final q in repo.quiz) {
          expect(() => repo.topicById(q.topicId), returnsNormally);
        }
      }
    });
  });

  group('RandomDeck', () {
    test('draws every item once before repeating', () {
      final deck = RandomDeck(List.generate(20, (i) => i), random: Random(1));
      final firstRound = List.generate(20, (_) => deck.next());
      expect(firstRound.toSet().length, 20);
    });

    test('never repeats the same item back to back', () {
      final deck = RandomDeck([1, 2, 3], random: Random(7));
      var previous = deck.next();
      for (var i = 0; i < 300; i++) {
        final current = deck.next();
        expect(current, isNot(previous));
        previous = current;
      }
    });

    test('sample returns distinct items, capped at the deck size', () {
      final deck = RandomDeck(List.generate(10, (i) => i));
      expect(deck.sample(5).toSet().length, 5);
      expect(deck.sample(50).length, 10);
    });

    test('rejects an empty deck', () {
      expect(() => RandomDeck<int>([]), throwsArgumentError);
    });
  });
}
