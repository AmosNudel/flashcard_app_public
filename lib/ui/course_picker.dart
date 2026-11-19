import 'package:flutter/material.dart';

import '../data/models.dart';

/// What the user chose in the course picker.
sealed class CoursePickerResult {}

class CoursePicked extends CoursePickerResult {
  CoursePicked(this.course);
  final CourseInfo course;
}

class AddDeckRequested extends CoursePickerResult {}

/// Shows the list of courses in a bottom sheet. Returns the chosen course,
/// a request to add a deck, or null if the sheet was dismissed.
///
/// Imported decks can be deleted from here; [onDelete] does the deletion
/// and the sheet then drops the deck from its list.
Future<CoursePickerResult?> showCoursePicker(
  BuildContext context, {
  required List<CourseInfo> courses,
  required String currentCourseId,
  required Future<void> Function(CourseInfo course) onDelete,
}) {
  return showModalBottomSheet<CoursePickerResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) => _CourseList(
        courses: courses,
        currentCourseId: currentCourseId,
        scrollController: scrollController,
        onDelete: onDelete,
      ),
    ),
  );
}

class _CourseList extends StatefulWidget {
  const _CourseList({
    required this.courses,
    required this.currentCourseId,
    required this.scrollController,
    required this.onDelete,
  });

  final List<CourseInfo> courses;
  final String currentCourseId;
  final ScrollController scrollController;
  final Future<void> Function(CourseInfo course) onDelete;

  @override
  State<_CourseList> createState() => _CourseListState();
}

class _CourseListState extends State<_CourseList> {
  late final List<CourseInfo> _courses = [...widget.courses];

  Future<void> _confirmDelete(CourseInfo course) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete deck?'),
        content: Text(
          '"${course.title}" will be removed from this device. '
          'Your original JSON files are not affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.onDelete(course);
    if (mounted) setState(() => _courses.remove(course));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bundled = _courses.where((c) => !c.isImported).toList();
    final imported = _courses.where((c) => c.isImported).toList();
    // Ready courses first, keeping catalog order within each group.
    bundled.sort((a, b) => (a.isReady ? 0 : 1).compareTo(b.isReady ? 0 : 1));

    Widget header(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
          child: Text(text, style: theme.textTheme.titleSmall),
        );

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: Text('Choose a deck', style: theme.textTheme.titleLarge),
        ),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 24),
          leading: const Icon(Icons.add_circle_outline_rounded),
          title: const Text('Add your own deck'),
          subtitle: const Text('Import JSON files or see the template'),
          onTap: () => Navigator.of(context).pop(AddDeckRequested()),
        ),
        if (imported.isNotEmpty) ...[
          header('Your decks'),
          for (final c in imported) _tile(c),
        ],
        header('Included'),
        for (final c in bundled) _tile(c),
      ],
    );
  }

  Widget _tile(CourseInfo course) {
    final colorScheme = Theme.of(context).colorScheme;
    final selected = course.id == widget.currentCourseId;
    return ListTile(
      enabled: course.isReady,
      selected: selected,
      contentPadding: const EdgeInsets.only(left: 24, right: 12),
      leading: Icon(
        course.isImported
            ? Icons.folder_special_rounded
            : course.isReady
                ? Icons.school_rounded
                : Icons.hourglass_empty_rounded,
      ),
      title: Text(course.title),
      subtitle: Text(
        course.isReady ? '${course.topicCount} topics' : 'Coming soon',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selected) Icon(Icons.check_rounded, color: colorScheme.primary),
          if (course.isImported)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: 'Delete deck',
              onPressed: () => _confirmDelete(course),
            ),
        ],
      ),
      onTap: () => Navigator.of(context).pop(CoursePicked(course)),
    );
  }
}
