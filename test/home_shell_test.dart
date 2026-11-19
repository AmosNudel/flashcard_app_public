import 'package:flashcards/data/repository.dart';
import 'package:flashcards/data/deck_importer.dart';
import 'package:flashcards/ui/home_shell.dart';
import 'package:flashcards/ui/flashcards/flashcards_screen.dart';
import 'package:flashcards/ui/glossary/glossary_screen.dart';
import 'package:flashcards/ui/quiz/quiz_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StudyRepository repo;

  setUpAll(() async {
    repo = await StudyRepository.load();
  });

  group('HomeShell', () {
    testWidgets('renders top tab bar with Glossary, Flashcards, and Quiz tabs',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: HomeShell(
            repository: repo,
            themeMode: ThemeMode.dark,
            onToggleTheme: () {},
          ),
        ),
      );

      expect(find.byType(TabBar), findsOneWidget);
      expect(find.widgetWithText(Tab, 'Glossary'), findsOneWidget);
      expect(find.widgetWithText(Tab, 'Flashcards'), findsOneWidget);
      expect(find.widgetWithText(Tab, 'Quiz'), findsOneWidget);
    });

    testWidgets('opens on Flashcards screen by default', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: HomeShell(
            repository: repo,
            themeMode: ThemeMode.dark,
            onToggleTheme: () {},
          ),
        ),
      );

      expect(find.byType(FlashcardsScreen), findsOneWidget);
    });

    testWidgets('switches to Glossary tab when tapped', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: HomeShell(
            repository: repo,
            themeMode: ThemeMode.dark,
            onToggleTheme: () {},
          ),
        ),
      );

      await tester.tap(find.widgetWithText(Tab, 'Glossary'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(GlossaryScreen), findsOneWidget);
    });

    testWidgets('switches to Quiz tab when tapped', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: HomeShell(
            repository: repo,
            themeMode: ThemeMode.dark,
            onToggleTheme: () {},
          ),
        ),
      );

      await tester.tap(find.widgetWithText(Tab, 'Quiz'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(QuizScreen), findsOneWidget);
    });

    testWidgets('preserves IndexedStack across tab switches', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: HomeShell(
            repository: repo,
            themeMode: ThemeMode.dark,
            onToggleTheme: () {},
          ),
        ),
      );

      final indexedStack = tester.widget<IndexedStack>(find.byType(IndexedStack));
      expect(indexedStack.children.length, 3);
      expect(indexedStack.index, 1); // Flashcards initially

      await tester.tap(find.widgetWithText(Tab, 'Glossary'));
      await tester.pump(const Duration(milliseconds: 300));

      final updatedStack = tester.widget<IndexedStack>(find.byType(IndexedStack));
      expect(updatedStack.index, 0); // Glossary
    });
  });

  testWidgets('a deck with only glossary terms opens without crashing',
      (tester) async {
    final draft = DeckImporter.parse([
      const SourceFile('g.json',
          '{"glossary": [{"term": "A", "definition": "Letter A"}]}'),
    ]).single;
    await tester.pumpWidget(
      MaterialApp(
        home: HomeShell(
          repository: StudyRepository.fromCourseJson('g', draft.toJson()),
          themeMode: ThemeMode.dark,
          onToggleTheme: () {},
        ),
      ),
    );
    expect(find.text('No flashcards available.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
