import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../data/repository.dart';

class GlossaryScreen extends StatefulWidget {
  const GlossaryScreen({super.key, required this.repository});

  final StudyRepository repository;

  @override
  State<GlossaryScreen> createState() => _GlossaryScreenState();
}

class _GlossaryScreenState extends State<GlossaryScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String _searchQuery = '';
  String? _selectedSection; // null = All Sections, otherwise section name
  String _selectedLetter = 'All';
  final Set<String> _expandedTerms = {};

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.trim().toLowerCase();
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
    });
  }

  void _toggleExpand(String term) {
    setState(() {
      if (_expandedTerms.contains(term)) {
        _expandedTerms.remove(term);
      } else {
        _expandedTerms.add(term);
      }
    });
  }

  void _selectSection(String? section) {
    setState(() {
      _selectedSection = section;
      _selectedLetter = 'All';
      _searchQuery = '';
      _searchController.clear();
    });
    Navigator.of(context).pop(); // Close drawer
  }

  void _setLetterFilter(String letter) {
    setState(() {
      _selectedLetter = letter;
    });
  }

  void _selectRelatedTerm(String relatedTerm) {
    final match = widget.repository.glossaryTerm(relatedTerm);
    if (match != null) {
      setState(() {
        _searchQuery = '';
        _searchController.clear();
        _selectedSection = match.section;
        _selectedLetter = 'All';
        _expandedTerms.add(match.term);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final allGlossary = widget.repository.glossary;
    final sections = widget.repository.sections;

    // Group terms by section
    final grouped = <String, List<GlossaryTerm>>{
      for (final section in sections) section: [],
    };
    for (final item in allGlossary) {
      grouped[item.section]?.add(item);
    }

    // Filter terms: if a section is selected, base terms are that section's terms; otherwise all terms.
    // Search runs within baseTerms (either the selected section or all terms).
    final baseTerms = _selectedSection != null
        ? (grouped[_selectedSection] ?? [])
        : allGlossary;
    var filtered = baseTerms;

    if (_searchQuery.isNotEmpty) {
      final termMatches = <GlossaryTerm>[];
      final definitionMatches = <GlossaryTerm>[];

      for (final item in baseTerms) {
        final termLower = item.term.toLowerCase();
        if (termLower.contains(_searchQuery)) {
          termMatches.add(item);
        } else if (item.entry.searchableBody.contains(_searchQuery)) {
          definitionMatches.add(item);
        }
      }
      filtered = [...termMatches, ...definitionMatches];
    } else if (_selectedSection == null) {
      // Sort purely alphabetically from A to Z across all sections
      filtered = [...filtered]
        ..sort((a, b) => a.term.toLowerCase().compareTo(b.term.toLowerCase()));
    }

    // Apply A-Z letter filter across current terms (All Sections or specific section)
    final termsForLetters = baseTerms;
    final availableLetters = <String>{
      'All',
      for (final term in termsForLetters)
        if (term.term.isNotEmpty) term.term[0].toUpperCase(),
    }.toList()
      ..sort((a, b) {
        if (a == 'All') return -1;
        if (b == 'All') return 1;
        return a.compareTo(b);
      });

    if (_selectedLetter != 'All') {
      filtered = filtered
          .where((t) => t.term.toUpperCase().startsWith(_selectedLetter))
          .toList();
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.transparent,
      drawer: Drawer(
        backgroundColor: colorScheme.surface,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drawer Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 16, 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.menu_book_rounded,
                      color: colorScheme.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Study Sections',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Section List
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    // All Sections Tile
                    ListTile(
                      leading: Icon(
                        Icons.all_inclusive_rounded,
                        color: _selectedSection == null
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                      ),
                      title: Text(
                        'All Sections',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: _selectedSection == null
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: _selectedSection == null
                              ? colorScheme.primary
                              : colorScheme.onSurface,
                        ),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${allGlossary.length}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      selected: _selectedSection == null,
                      onTap: () => _selectSection(null),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: Divider(),
                    ),
                    for (final sec in sections) ...[
                      ListTile(
                        leading: Icon(
                          Icons.folder_outlined,
                          color: _selectedSection == sec
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                        ),
                        title: Text(
                          sec,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: _selectedSection == sec
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: _selectedSection == sec
                                ? colorScheme.primary
                                : colorScheme.onSurface,
                          ),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer.withAlpha(120),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${grouped[sec]?.length ?? 0}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                        selected: _selectedSection == sec,
                        onTap: () => _selectSection(sec),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Search Bar & Section Drawer Button
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      IconButton.outlined(
                        onPressed: () =>
                            _scaffoldKey.currentState?.openDrawer(),
                        icon: const Icon(Icons.menu_rounded, size: 22),
                        tooltip: 'Select Section',
                        style: IconButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.all(14),
                          side: BorderSide(
                            color: colorScheme.outlineVariant.withAlpha(128),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: _onSearchChanged,
                          decoration: InputDecoration(
                            hintText: _selectedSection != null
                                ? 'Search in ${_selectedSection!}...'
                                : 'Search all terms or definitions...',
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded),
                                    onPressed: _clearSearch,
                                  )
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: colorScheme.outlineVariant,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: colorScheme.outlineVariant.withAlpha(128),
                              ),
                            ),
                            filled: true,
                            fillColor: colorScheme.surfaceContainerHigh,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Active Section Indicator / Count Banner
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _searchQuery.isNotEmpty
                              ? 'Search Results'
                              : (_selectedSection ?? 'All Sections'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                      Text(
                        '${filtered.length} terms found',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Full-Height Term List (CustomScrollView)
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_off_rounded,
                                size: 64,
                                color: colorScheme.outline,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No glossary terms found.',
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        )
                      : CustomScrollView(
                          controller: _scrollController,
                          slivers: [
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 100.0),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final item = filtered[index];
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8.0),
                                      child: _GlossaryItemCard(
                                        item: item,
                                        isExpanded: _expandedTerms.contains(item.term),
                                        onToggle: () => _toggleExpand(item.term),
                                        onRelatedTap: _selectRelatedTerm,
                                        repository: widget.repository,
                                      ),
                                    );
                                  },
                                  childCount: filtered.length,
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),

            // Viewport-Sticky Bottom A-Z Bar
            if (availableLetters.length > 1)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.shadow.withAlpha(40),
                        blurRadius: 10,
                        offset: const Offset(0, -3),
                      ),
                    ],
                    border: Border(
                      top: BorderSide(
                        color: colorScheme.outlineVariant.withAlpha(120),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'A-Z:',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: availableLetters.length,
                          itemBuilder: (context, index) {
                            final letter = availableLetters[index];
                            final isSelected = _selectedLetter == letter;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6.0),
                              child: Center(
                                child: ChoiceChip(
                                  label: Text(letter),
                                  selected: isSelected,
                                  onSelected: (_) => _setLetterFilter(letter),
                                  visualDensity: VisualDensity.compact,
                                  labelStyle: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: isSelected
                                        ? colorScheme.onPrimaryContainer
                                        : colorScheme.onSurfaceVariant,
                                  ),
                                  selectedColor: colorScheme.primaryContainer,
                                  backgroundColor:
                                      colorScheme.surfaceContainerHigh,
                                  side: BorderSide(
                                    color: isSelected
                                        ? colorScheme.primary
                                        : colorScheme.outlineVariant
                                            .withAlpha(100),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A labelled, tinted block used for the analogy and example of a term.
class _GlossaryNote extends StatelessWidget {
  const _GlossaryNote({
    required this.icon,
    required this.label,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              height: 1.45,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlossaryItemCard extends StatelessWidget {
  const _GlossaryItemCard({
    required this.item,
    required this.isExpanded,
    required this.onToggle,
    required this.onRelatedTap,
    required this.repository,
  });

  final GlossaryTerm item;
  final bool isExpanded;
  final VoidCallback onToggle;
  final ValueChanged<String> onRelatedTap;
  final StudyRepository repository;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isExpanded
              ? colorScheme.primary.withAlpha(128)
              : colorScheme.outlineVariant.withAlpha(100),
          width: isExpanded ? 1.5 : 1.0,
        ),
        boxShadow: [
          if (isExpanded)
            BoxShadow(
              color: colorScheme.shadow.withAlpha(20),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Material(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: ExpansionTile(
            initiallyExpanded: isExpanded,
            onExpansionChanged: (_) => onToggle(),
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            title: Text(
              item.term,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: isExpanded ? colorScheme.primary : colorScheme.onSurface,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 2.0),
              child: Text(
                item.section,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.primary.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Source topic(s): gives the term its context in the course
              Text(
                [
                  for (final id in item.topicIds)
                    repository.topicById(id).title,
                ].join(' · '),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.outline,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),

              // Definition
              Text(
                item.entry.definition,
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.5,
                  color: colorScheme.onSurface,
                ),
              ),

              if (item.entry.analogy != null &&
                  item.entry.analogy!.isNotEmpty) ...[
                const SizedBox(height: 12),
                _GlossaryNote(
                  icon: Icons.lightbulb_outline_rounded,
                  label: 'Think of it like',
                  text: item.entry.analogy!,
                  color: colorScheme.tertiary,
                ),
              ],

              if (item.entry.example != null &&
                  item.entry.example!.isNotEmpty) ...[
                const SizedBox(height: 12),
                _GlossaryNote(
                  icon: Icons.dns_outlined,
                  label: 'Example',
                  text: item.entry.example!,
                  color: colorScheme.primary,
                ),
              ],

              // Supplement / Extra Note (if any)
              if (item.entry.supplement != null &&
                  item.entry.supplement!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withAlpha(150),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withAlpha(100),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 16,
                            color: colorScheme.secondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Additional Note',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.secondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.entry.supplement!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          height: 1.4,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Related Terms Chips (if any)
              if (item.entry.related.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Related Terms',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final relatedName in item.entry.related)
                      ActionChip(
                        label: Text(relatedName),
                        onPressed: () => onRelatedTap(relatedName),
                        visualDensity: VisualDensity.compact,
                        labelStyle: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                        backgroundColor: colorScheme.primaryContainer.withAlpha(100),
                        side: BorderSide.none,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
