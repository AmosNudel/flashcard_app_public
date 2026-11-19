import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../data/models.dart';

class GlossaryTextHighlighter {
  /// Builds a [TextSpan] tree that highlights recognized glossary terms in [text].
  static InlineSpan buildSpans({
    required String text,
    required List<GlossaryTerm> allTerms,
    required void Function(GlossaryTerm term) onTermTap,
    required TextStyle baseStyle,
    required Color highlightColor,
  }) {
    if (text.isEmpty || allTerms.isEmpty) {
      return TextSpan(text: text, style: baseStyle);
    }

    // Sort terms by length descending to match multi-word terms first
    final sortedTerms = [...allTerms]
      ..sort((a, b) => b.term.length.compareTo(a.term.length));

    // Find all non-overlapping matches
    final matches = <_TermMatch>[];
    final textLower = text.toLowerCase();

    for (final gTerm in sortedTerms) {
      final termLower = gTerm.term.toLowerCase();
      var startIndex = 0;

      while (true) {
        final foundIndex = textLower.indexOf(termLower, startIndex);
        if (foundIndex == -1) break;

        final endIndex = foundIndex + termLower.length;

        // Check word boundaries so "in" doesn't match inside "indexing"
        final isStartBoundary = foundIndex == 0 ||
            !_isWordChar(text.codeUnitAt(foundIndex - 1));
        final isEndBoundary = endIndex == text.length ||
            !_isWordChar(text.codeUnitAt(endIndex));

        if (isStartBoundary && isEndBoundary) {
          // Verify no overlap with previously found longer term matches
          final overlaps = matches.any((m) =>
              (foundIndex >= m.start && foundIndex < m.end) ||
              (endIndex > m.start && endIndex <= m.end));

          if (!overlaps) {
            matches.add(_TermMatch(
              start: foundIndex,
              end: endIndex,
              term: gTerm,
              matchedText: text.substring(foundIndex, endIndex),
            ));
          }
        }

        startIndex = foundIndex + 1;
      }
    }

    if (matches.isEmpty) {
      return TextSpan(text: text, style: baseStyle);
    }

    // Sort matches by start position
    matches.sort((a, b) => a.start.compareTo(b.start));

    final spans = <InlineSpan>[];
    var currentPos = 0;

    for (final match in matches) {
      if (match.start > currentPos) {
        spans.add(TextSpan(
          text: text.substring(currentPos, match.start),
          style: baseStyle,
        ));
      }

      final recognizer = TapGestureRecognizer()
        ..onTap = () => onTermTap(match.term);

      spans.add(TextSpan(
        text: match.matchedText,
        style: baseStyle.copyWith(
          color: highlightColor,
          fontWeight: FontWeight.bold,
          decoration: TextDecoration.underline,
          decorationStyle: TextDecorationStyle.dotted,
          decorationColor: highlightColor.withValues(alpha: 0.8),
        ),
        recognizer: recognizer,
      ));

      currentPos = match.end;
    }

    if (currentPos < text.length) {
      spans.add(TextSpan(
        text: text.substring(currentPos),
        style: baseStyle,
      ));
    }

    return TextSpan(children: spans);
  }

  static bool _isWordChar(int codeUnit) {
    return (codeUnit >= 48 && codeUnit <= 57) || // 0-9
        (codeUnit >= 65 && codeUnit <= 90) || // A-Z
        (codeUnit >= 97 && codeUnit <= 122) || // a-z
        codeUnit == 95 || // _
        codeUnit == 45; // -
  }
}

class _TermMatch {
  _TermMatch({
    required this.start,
    required this.end,
    required this.term,
    required this.matchedText,
  });

  final int start;
  final int end;
  final GlossaryTerm term;
  final String matchedText;
}
