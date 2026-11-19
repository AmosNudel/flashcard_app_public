import 'package:flutter/material.dart';

import '../data/repository.dart';
import 'flashcards/flashcards_screen.dart';
import 'glossary/glossary_screen.dart';
import 'quiz/quiz_screen.dart';
import 'widgets/background_rays.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.repository,
    required this.themeMode,
    required this.onToggleTheme,
    this.courseTitle,
    this.onChangeCourse,
    this.onAddDeck,
    this.initialIndex = 1,
  });

  final StudyRepository repository;
  final ThemeMode themeMode;
  final VoidCallback onToggleTheme;

  /// App bar title; defaults to the course name from the manifest.
  final String? courseTitle;

  /// Opens the course picker. When null, the title is not tappable.
  final VoidCallback? onChangeCourse;

  /// Opens the "Add your own deck" screen. When null, the button is hidden.
  final VoidCallback? onAddDeck;
  final int initialIndex;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      initialIndex: widget.initialIndex,
      vsync: this,
    );
    _tabController.addListener(_handleTabSelection);
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging ||
        _tabController.index != _tabController.previousIndex) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.themeMode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        title: _CourseTitle(
          title: widget.courseTitle ?? widget.repository.manifest.course,
          onTap: widget.onChangeCourse,
        ),
        centerTitle: true,
        actions: [
          if (widget.onAddDeck != null)
            IconButton(
              icon: const Icon(Icons.library_add_rounded),
              tooltip: 'Add your own deck',
              onPressed: widget.onAddDeck,
            ),
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_outlined,
            ),
            tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
            onPressed: widget.onToggleTheme,
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.menu_book_rounded),
              text: 'Glossary',
            ),
            Tab(
              icon: Icon(Icons.style_rounded),
              text: 'Flashcards',
            ),
            Tab(
              icon: Icon(Icons.quiz_rounded),
              text: 'Quiz',
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          const BackgroundRays(),
          IndexedStack(
            index: _tabController.index,
            children: [
              GlossaryScreen(repository: widget.repository),
              FlashcardsScreen(repository: widget.repository),
              QuizScreen(repository: widget.repository),
            ],
          ),
        ],
      ),
    );
  }
}

/// The course name in the app bar; tapping it opens the course picker.
class _CourseTitle extends StatelessWidget {
  const _CourseTitle({required this.title, this.onTap});

  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Text(title, maxLines: 1, overflow: TextOverflow.ellipsis);
    if (onTap == null) return text;

    return Tooltip(
      message: 'Change course',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: text),
              const Icon(Icons.arrow_drop_down_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
