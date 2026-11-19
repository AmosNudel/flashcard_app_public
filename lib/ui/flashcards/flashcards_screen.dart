import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../data/random_deck.dart';
import '../../data/repository.dart';
import 'flip_card.dart';
import 'glossary_speech_bubble.dart';
import 'glossary_text_spans.dart';
import 'swipe_card.dart';

class FlashcardsScreen extends StatefulWidget {
  const FlashcardsScreen({super.key, required this.repository});

  final StudyRepository repository;

  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<FlashcardsScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<FlipCardState> _flipCardKey = GlobalKey<FlipCardState>();
  final GlobalKey<SwipeCardState> _swipeCardKey = GlobalKey<SwipeCardState>();

  late RandomDeck<Flashcard> _deck;
  late Flashcard _currentCard;
  late Flashcard _peekNextCard;
  final List<Flashcard> _history = [];
  bool _isFlipped = false;
  int _cardsSeenCount = 1;

  // Animation controller for easing the next card into the front
  late final AnimationController _transitionController;
  late final Animation<double> _scaleAnimation;
  late final Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    // A user deck may have only a glossary or a quiz; build() then shows an
    // empty state instead, and the deck fields are never read.
    if (widget.repository.flashcards.isNotEmpty) {
      _deck = RandomDeck(widget.repository.flashcards);
      _currentCard = _deck.next();
      _peekNextCard = widget.repository.flashcards.length > 1
          ? _deck.next()
          : _currentCard;
    }

    _transitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 1.0, // start fully in place
    );

    _scaleAnimation = Tween<double>(begin: 0.96, end: 1.0).animate(
      CurvedAnimation(parent: _transitionController, curve: Curves.easeOutCubic),
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, 8),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _transitionController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _transitionController.dispose();
    super.dispose();
  }

  void _nextCard([SwipeDirection? direction]) {
    setState(() {
      _history.add(_currentCard);
      if (_history.length > 50) {
        _history.removeAt(0);
      }
      _currentCard = _peekNextCard;
      _peekNextCard = _deck.next();
      _cardsSeenCount++;
      _isFlipped = false;
      _flipCardKey.currentState?.resetFront();

      // Trigger scale/translate ease-in animation for the new front card
      _transitionController.forward(from: 0.0);
    });
  }

  void _previousCard() {
    if (_history.isEmpty) return;

    setState(() {
      _peekNextCard = _currentCard;
      _currentCard = _history.removeLast();
      if (_cardsSeenCount > 1) _cardsSeenCount--;
      _isFlipped = false;
      _flipCardKey.currentState?.resetFront();
      _transitionController.forward(from: 0.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (widget.repository.flashcards.isEmpty) {
      return const Center(child: Text('No flashcards available.'));
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            children: [
              // Clean minimalist header (counter only)
              _buildHeader(colorScheme),
              const SizedBox(height: 12),

              // Main Flashcard View with stacked next card easing in
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 500,
                      maxHeight: 600,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        // Stack Card 2 (Bottom decoration blank card)
                        _buildStackDecorationCard(
                          colorScheme: colorScheme,
                          offset: const Offset(0, 16),
                          angle: -0.03,
                          scale: 0.92,
                        ),

                        // Stack Card 1 (Middle - Actual Next Card pre-rendered)
                        _buildNextCardPeek(colorScheme),

                        // Active Interactive Card (Front Top Card with ease-in animation)
                        AnimatedBuilder(
                          animation: _transitionController,
                          builder: (context, child) {
                            return Transform.translate(
                              offset: _offsetAnimation.value,
                              child: Transform.scale(
                                scale: _scaleAnimation.value,
                                child: child,
                              ),
                            );
                          },
                          child: SwipeCard(
                            key: _swipeCardKey,
                            onSwiped: _nextCard,
                            child: FlipCard(
                              key: _flipCardKey,
                              isFlipped: _isFlipped,
                              onFlip: () {
                                setState(() {
                                  _isFlipped = !_isFlipped;
                                });
                              },
                              front: _CardContent(
                                isBack: false,
                                card: _currentCard,
                                repository: widget.repository,
                                topicTitle: _topicTitle(_currentCard),
                                colorScheme: colorScheme,
                              ),
                              back: _CardContent(
                                isBack: true,
                                card: _currentCard,
                                repository: widget.repository,
                                topicTitle: _topicTitle(_currentCard),
                                colorScheme: colorScheme,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Bottom control buttons
              _buildActionButtons(colorScheme),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  String _topicTitle(Flashcard card) =>
      widget.repository.topicById(card.topicId).title;

  Widget _buildHeader(ColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Flashcards Deck',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Card #$_cardsSeenCount',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onPrimaryContainer,
                ),
          ),
        ),
      ],
    );
  }

  /// Renders the next card waiting right beneath the active top card.
  Widget _buildNextCardPeek(ColorScheme colorScheme) {
    return Transform.translate(
      offset: const Offset(0, 8),
      child: Transform.scale(
        scale: 0.96,
        child: _CardContent(
          isBack: false,
          card: _peekNextCard,
          repository: widget.repository,
          topicTitle: _topicTitle(_peekNextCard),
          colorScheme: colorScheme,
        ),
      ),
    );
  }

  Widget _buildStackDecorationCard({
    required ColorScheme colorScheme,
    required Offset offset,
    required double angle,
    required double scale,
  }) {
    return Transform.translate(
      offset: offset,
      child: Transform.rotate(
        angle: angle,
        child: Transform.scale(
          scale: scale,
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            color: colorScheme.surfaceContainerLow,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(ColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Previous card button
        IconButton.filledTonal(
          onPressed: _history.isNotEmpty ? _previousCard : null,
          icon: const Icon(Icons.undo_rounded),
          tooltip: 'Previous Card',
          iconSize: 24,
        ),
        const SizedBox(width: 8),

        // Flip card button
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: FilledButton.icon(
              onPressed: () {
                _flipCardKey.currentState?.toggleFlip();
              },
              icon: Icon(
                _isFlipped
                    ? Icons.flip_to_front_rounded
                    : Icons.flip_to_back_rounded,
              ),
              label: Text(_isFlipped ? 'Show Front' : 'Flip Card'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ),

        // Next card button (Swipe left)
        IconButton.filled(
          onPressed: () {
            _swipeCardKey.currentState?.swipe(SwipeDirection.left);
          },
          icon: const Icon(Icons.arrow_forward_rounded),
          tooltip: 'Next Card',
          iconSize: 24,
        ),
      ],
    );
  }
}

class _CardContent extends StatelessWidget {
  const _CardContent({
    required this.isBack,
    required this.card,
    required this.repository,
    required this.topicTitle,
    required this.colorScheme,
  });

  final bool isBack;
  final Flashcard card;
  final StudyRepository repository;
  final String topicTitle;
  final ColorScheme colorScheme;

  void _onTermTap(BuildContext context, GlossaryTerm term) {
    showGlossarySpeechBubble(
      context: context,
      term: term,
      repository: repository,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStr = isBack ? card.back : card.front;
    final explanationStr = card.explanation;

    // Get glossary terms for the card's topic
    final topic = repository.topicById(card.topicId);
    final topicTerms = topic.glossary
        .map((entry) => repository.glossaryTerm(entry.term))
        .whereType<GlossaryTerm>()
        .toList();

    final textStyle = isBack
        ? theme.textTheme.bodyLarge?.copyWith(
            height: 1.5,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          )
        : theme.textTheme.titleLarge?.copyWith(
            height: 1.4,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          );

    return Card(
      elevation: 6,
      shadowColor: colorScheme.shadow.withValues(alpha: 0.25),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isBack
              ? colorScheme.secondary.withValues(alpha: 0.4)
              : colorScheme.primary.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      color: colorScheme.surface,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header badge: QUESTION / ANSWER, plus the topic for context
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: isBack
                        ? colorScheme.secondaryContainer
                        : colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isBack ? 'ANSWER' : 'QUESTION',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                      color: isBack
                          ? colorScheme.onSecondaryContainer
                          : colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    topicTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.outline,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            const Divider(height: 20, thickness: 1),

            // Card text body with interactive highlighted glossary terms
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: Text.rich(
                          GlossaryTextHighlighter.buildSpans(
                            text: textStr,
                            allTerms: topicTerms.isNotEmpty
                                ? topicTerms
                                : repository.glossary,
                            onTermTap: (term) => _onTermTap(context, term),
                            baseStyle: textStyle ?? const TextStyle(),
                            highlightColor: colorScheme.primary,
                          ),
                          textAlign:
                              isBack ? TextAlign.left : TextAlign.center,
                        ),
                      ),

                      // Explanation section (on back side)
                      if (isBack &&
                          explanationStr != null &&
                          explanationStr.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colorScheme.tertiary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border(
                              left: BorderSide(
                                color: colorScheme.tertiary,
                                width: 3,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.lightbulb_outline_rounded,
                                    size: 16,
                                    color: colorScheme.tertiary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Why',
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.tertiary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text.rich(
                                GlossaryTextHighlighter.buildSpans(
                                  text: explanationStr,
                                  allTerms: topicTerms.isNotEmpty
                                      ? topicTerms
                                      : repository.glossary,
                                  onTermTap: (term) =>
                                      _onTermTap(context, term),
                                  baseStyle: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                        height: 1.45,
                                        color: colorScheme.onSurface,
                                      ) ??
                                      const TextStyle(),
                                  highlightColor: colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            const Divider(height: 20, thickness: 1),

            // Footer hint
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isBack ? Icons.swipe_rounded : Icons.touch_app_rounded,
                  size: 16,
                  color: colorScheme.outline,
                ),
                const SizedBox(width: 6),
                Text(
                  isBack ? 'Swipe left or right for next' : 'Tap card to flip',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.outline,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
