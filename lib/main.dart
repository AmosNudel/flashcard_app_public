import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/deck_store.dart';
import 'data/models.dart';
import 'data/repository.dart';
import 'theme/app_theme.dart';
import 'ui/add_deck_screen.dart';
import 'ui/course_picker.dart';
import 'ui/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Lock to portrait on mobile (no effect on desktop/web).
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const StudyApp());
}

class StudyApp extends StatefulWidget {
  const StudyApp({super.key});

  @override
  State<StudyApp> createState() => _StudyAppState();
}

class _StudyAppState extends State<StudyApp> {
  final ValueNotifier<ThemeMode> _themeModeNotifier =
      ValueNotifier<ThemeMode>(ThemeMode.dark);

  @override
  void dispose() {
    _themeModeNotifier.dispose();
    super.dispose();
  }

  void _toggleTheme() {
    _themeModeNotifier.value = _themeModeNotifier.value == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: _themeModeNotifier,
      builder: (context, themeMode, child) {
        return MaterialApp(
          title: 'Flashcards',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          home: AppLoader(
            themeMode: themeMode,
            onToggleTheme: _toggleTheme,
          ),
        );
      },
    );
  }
}

/// Loads the course list and the selected course, then shows the app.
/// The selected course is remembered across launches.
class AppLoader extends StatefulWidget {
  const AppLoader({
    super.key,
    required this.themeMode,
    required this.onToggleTheme,
  });

  final ThemeMode themeMode;
  final VoidCallback onToggleTheme;

  @override
  State<AppLoader> createState() => _AppLoaderState();
}

class _AppLoaderState extends State<AppLoader> {
  static const _selectedCourseKey = 'selected_course_id';

  final _deckStore = DeckStore();
  CourseCatalog? _catalog;
  late Future<StudyRepository> _repository = _loadInitial();

  Future<CourseCatalog> _reloadCatalog() async =>
      _catalog = await CourseCatalog.load(deckStore: _deckStore);

  Future<StudyRepository> _loadInitial() async {
    final catalog = await _reloadCatalog();
    final prefs = await SharedPreferences.getInstance();
    final saved = catalog.byId(prefs.getString(_selectedCourseKey) ?? '');
    final courseId = saved != null && saved.isReady
        ? saved.id
        : _firstReady(catalog).id;
    return _loadCourse(courseId);
  }

  CourseInfo _firstReady(CourseCatalog catalog) => catalog.courses.firstWhere(
        (c) => c.isReady,
        orElse: () => throw StateError('No course has content yet.'),
      );

  Future<StudyRepository> _loadCourse(String id) => DeckStore.isImportedId(id)
      ? _deckStore.load(id)
      : StudyRepository.load(courseId: id);

  Future<void> _select(String courseId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedCourseKey, courseId);
    if (!mounted) return;
    // Block body: an arrow would return the Future, which setState rejects.
    setState(() {
      _repository = _loadCourse(courseId);
    });
  }

  Future<void> _changeCourse(String currentCourseId) async {
    final catalog = _catalog;
    if (catalog == null) return;
    var deletedCurrent = false;
    final result = await showCoursePicker(
      context,
      courses: catalog.courses,
      currentCourseId: currentCourseId,
      onDelete: (course) async {
        await _deckStore.delete(course.id);
        await _reloadCatalog();
        if (course.id == currentCourseId) deletedCurrent = true;
      },
    );
    if (!mounted) return;

    switch (result) {
      case CoursePicked(:final course) when course.id != currentCourseId:
        await _select(course.id);
      case AddDeckRequested():
        await _addDeck();
      case _ when deletedCurrent:
        await _select(_firstReady(_catalog!).id);
      case _:
        break;
    }
  }

  /// Opens the import screen and switches to the new deck, if one was added.
  Future<void> _addDeck() async {
    final newId = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => AddDeckScreen(deckStore: _deckStore)),
    );
    if (newId == null) return;
    await _reloadCatalog();
    await _select(newId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<StudyRepository>(
      future: _repository,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Failed to load study data:\n${snapshot.error}'),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => _select(StudyRepository.defaultCourseId),
                      child: const Text('Open the sample deck'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final repository = snapshot.data!;
        return HomeShell(
          // New key per course, so every tab starts fresh on a course switch.
          key: ValueKey(repository.courseId),
          repository: repository,
          themeMode: widget.themeMode,
          onToggleTheme: widget.onToggleTheme,
          courseTitle: _catalog?.byId(repository.courseId)?.shortTitle,
          onChangeCourse: () => _changeCourse(repository.courseId),
          onAddDeck: _addDeck,
        );
      },
    );
  }
}
