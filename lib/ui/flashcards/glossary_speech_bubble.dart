import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../data/repository.dart';

/// Shows a speech-bubble popover dialog containing the glossary entry refresher details.
void showGlossarySpeechBubble({
  required BuildContext context,
  required GlossaryTerm term,
  required StudyRepository repository,
}) {
  showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black45,
    builder: (context) => _GlossarySpeechBubbleDialog(
      initialTerm: term,
      repository: repository,
    ),
  );
}

class _GlossarySpeechBubbleDialog extends StatefulWidget {
  const _GlossarySpeechBubbleDialog({
    required this.initialTerm,
    required this.repository,
  });

  final GlossaryTerm initialTerm;
  final StudyRepository repository;

  @override
  State<_GlossarySpeechBubbleDialog> createState() =>
      _GlossarySpeechBubbleDialogState();
}

class _GlossarySpeechBubbleDialogState
    extends State<_GlossarySpeechBubbleDialog> {
  late GlossaryTerm _currentTerm;

  @override
  void initState() {
    super.initState();
    _currentTerm = widget.initialTerm;
  }

  void _selectTerm(String termName) {
    final match = widget.repository.glossaryTerm(termName);
    if (match != null) {
      setState(() {
        _currentTerm = match;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final entry = _currentTerm.entry;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 620),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Speech bubble pointer arrow at top
              CustomPaint(
                size: const Size(24, 12),
                painter: _BubbleTailPainter(
                  color: colorScheme.surface,
                  borderColor: colorScheme.primary.withValues(alpha: 0.6),
                ),
              ),

              // Speech bubble main container
              Flexible(
                child: Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: colorScheme.primary.withValues(alpha: 0.6),
                      width: 1.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.shadow.withValues(alpha: 0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header: Icon, Term Title, Section badge & Close button
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 20,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _currentTerm.term,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _currentTerm.section,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded),
                            tooltip: 'Close Refresher',
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),

                      const Divider(height: 20, thickness: 1),

                      // Content scrollview
                      Flexible(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Main Definition
                              Text(
                                entry.definition,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  height: 1.5,
                                  color: colorScheme.onSurface,
                                ),
                              ),

                              // Everyday Analogy (if present)
                              if (entry.analogy != null &&
                                  entry.analogy!.isNotEmpty) ...[
                                const SizedBox(height: 14),
                                _buildCalloutBox(
                                  theme: theme,
                                  colorScheme: colorScheme,
                                  icon: Icons.lightbulb_outline_rounded,
                                  label: 'Everyday Picture (Analogy)',
                                  content: entry.analogy!,
                                  boxColor: colorScheme.secondaryContainer
                                      .withValues(alpha: 0.4),
                                  accentColor: colorScheme.secondary,
                                ),
                              ],

                              // Example (if present)
                              if (entry.example != null &&
                                  entry.example!.isNotEmpty) ...[
                                const SizedBox(height: 14),
                                _buildCalloutBox(
                                  theme: theme,
                                  colorScheme: colorScheme,
                                  icon: Icons.build_circle_outlined,
                                  label: 'Example',
                                  content: entry.example!,
                                  boxColor: colorScheme.primaryContainer
                                      .withValues(alpha: 0.4),
                                  accentColor: colorScheme.primary,
                                ),
                              ],

                              // Supplement Note (if present)
                              if (entry.supplement != null &&
                                  entry.supplement!.isNotEmpty) ...[
                                const SizedBox(height: 14),
                                _buildCalloutBox(
                                  theme: theme,
                                  colorScheme: colorScheme,
                                  icon: Icons.info_outline_rounded,
                                  label: 'Extra Note',
                                  content: entry.supplement!,
                                  boxColor: colorScheme.tertiaryContainer
                                      .withValues(alpha: 0.4),
                                  accentColor: colorScheme.tertiary,
                                ),
                              ],

                              // Related Terms
                              if (entry.related.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                Text(
                                  'Related Terms',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: entry.related.map((relTerm) {
                                    return ActionChip(
                                      label: Text(relTerm),
                                      avatar: const Icon(
                                        Icons.link_rounded,
                                        size: 14,
                                      ),
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () => _selectTerm(relTerm),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalloutBox({
    required ThemeData theme,
    required ColorScheme colorScheme,
    required IconData icon,
    required String label,
    required String content,
    required Color boxColor,
    required Color accentColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: boxColor,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: accentColor, width: 3.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: accentColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            content,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.45,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _BubbleTailPainter extends CustomPainter {
  _BubbleTailPainter({
    required this.color,
    required this.borderColor,
  });

  final Color color;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(path, paint);

    final borderPath = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height);

    canvas.drawPath(borderPath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _BubbleTailPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.borderColor != borderColor;
}
