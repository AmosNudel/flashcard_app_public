import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../data/repository.dart';
import '../flashcards/swipe_card.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key, required this.repository});

  final StudyRepository repository;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<SwipeCardState> _swipeCardKey = GlobalKey<SwipeCardState>();

  List<QuizQuestion> _sessionQuestions = [];
  int _currentIndex = 0;
  int _correctCount = 0;
  int _wrongCount = 0;
  int _skippedCount = 0;

  // Track answers per question index
  final Map<int, String> _selectedAnswers = {};
  final Map<int, bool> _isCorrectAnswers = {};

  // Shuffled options cache per question index
  final Map<int, List<String>> _shuffledOptionsCache = {};

  bool _isCompleted = false;

  // Animation controller for easing in and unblurring the next card
  late final AnimationController _transitionController;
  late final Animation<double> _scaleAnimation;
  late final Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _transitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
      value: 1.0,
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

    _startNewSession();
  }

  @override
  void dispose() {
    _transitionController.dispose();
    super.dispose();
  }

  void _startNewSession() {
    final allQuiz = widget.repository.quiz;
    final random = Random();
    final shuffledAll = [...allQuiz]..shuffle(random);

    setState(() {
      _sessionQuestions = shuffledAll.take(50).toList();
      _currentIndex = 0;
      _correctCount = 0;
      _wrongCount = 0;
      _skippedCount = 0;
      _selectedAnswers.clear();
      _isCorrectAnswers.clear();
      _shuffledOptionsCache.clear();
      _isCompleted = false;
      _transitionController.value = 1.0;
    });
  }

  List<String> _getShuffledOptions(int index, QuizQuestion q) {
    if (_shuffledOptionsCache.containsKey(index)) {
      return _shuffledOptionsCache[index]!;
    }
    final shuffled = [...q.options]..shuffle();
    _shuffledOptionsCache[index] = shuffled;
    return shuffled;
  }

  void _answerQuestion(String optionText) {
    if (_selectedAnswers.containsKey(_currentIndex)) return;

    final q = _sessionQuestions[_currentIndex];
    final isCorrect = optionText == q.correctOption;

    setState(() {
      _selectedAnswers[_currentIndex] = optionText;
      _isCorrectAnswers[_currentIndex] = isCorrect;
      if (isCorrect) {
        _correctCount++;
      } else {
        _wrongCount++;
      }
    });
  }

  void _nextQuestion([SwipeDirection? direction]) {
    if (!_selectedAnswers.containsKey(_currentIndex)) {
      _skippedCount++;
    }

    if (_currentIndex < _sessionQuestions.length - 1) {
      setState(() {
        _currentIndex++;
        _transitionController.forward(from: 0.0);
      });
    } else {
      setState(() {
        _isCompleted = true;
      });
    }
  }

  void _previousQuestion() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _transitionController.forward(from: 0.0);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_sessionQuestions.isEmpty) {
      return const Center(child: Text('No quiz questions available.'));
    }

    if (_isCompleted) {
      return _buildSummaryView(colorScheme);
    }

    final q = _sessionQuestions[_currentIndex];
    final hasNext = _currentIndex < _sessionQuestions.length - 1;
    final peekQ = hasNext ? _sessionQuestions[_currentIndex + 1] : q;

    final selectedAnswer = _selectedAnswers[_currentIndex];
    final hasAnswered = selectedAnswer != null;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            children: [
              // Score & Progress Bar
              _buildScoreBar(colorScheme),
              const SizedBox(height: 12),

              // Active Question Card with Stacked Peek & Blur Animation
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 550,
                      maxHeight: 650,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        // Stack Card 2 (Bottom decoration blank card)
                        _buildStackDecorationCard(colorScheme),

                        // Stack Card 1 (Middle - Actual Next Question pre-rendered peek with blur)
                        if (hasNext)
                          _buildNextQuestionPeek(peekQ, colorScheme),

                        // Active Interactive Front Card (with ease-in & dynamic unblur animation)
                        AnimatedBuilder(
                          animation: _transitionController,
                          builder: (context, child) {
                            final blurSigma =
                                (1.0 - _transitionController.value) * 4.0;
                            return Transform.translate(
                              offset: _offsetAnimation.value,
                              child: Transform.scale(
                                scale: _scaleAnimation.value,
                                child: ImageFiltered(
                                  imageFilter: ImageFilter.blur(
                                    sigmaX: blurSigma,
                                    sigmaY: blurSigma,
                                  ),
                                  child: child,
                                ),
                              ),
                            );
                          },
                          child: SwipeCard(
                            key: _swipeCardKey,
                            onSwiped: _nextQuestion,
                            child: _buildQuestionCard(
                              context,
                              q,
                              _currentIndex,
                              colorScheme,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Bottom Action Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton.filledTonal(
                    onPressed: _currentIndex > 0 ? _previousQuestion : null,
                    icon: const Icon(Icons.arrow_back_rounded),
                    tooltip: 'Previous Question',
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: FilledButton.icon(
                        onPressed: () {
                          _swipeCardKey.currentState
                              ?.swipe(SwipeDirection.left);
                        },
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: Text(hasAnswered ? 'Next Question' : 'Skip & Next'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionCard(
    BuildContext context,
    QuizQuestion q,
    int index,
    ColorScheme colorScheme, {
    bool isPeek = false,
  }) {
    final theme = Theme.of(context);
    final shuffledOptions = _getShuffledOptions(index, q);
    final selectedAnswer = _selectedAnswers[index];
    final hasAnswered = selectedAnswer != null;

    return Card(
      elevation: isPeek ? 2 : 6,
      shadowColor: colorScheme.shadow.withAlpha(60),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isPeek
              ? colorScheme.outlineVariant.withAlpha(100)
              : colorScheme.primary.withAlpha(100),
          width: isPeek ? 1.0 : 1.5,
        ),
      ),
      color: isPeek ? colorScheme.surfaceContainerLow : colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Question badge & Topic ID
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'QUESTION ${index + 1} / ${_sessionQuestions.length}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.repository.topicById(q.topicId).title,
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

            // Question Text
            Text(
              q.question,
              style: theme.textTheme.titleMedium?.copyWith(
                height: 1.4,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),

            // Options List
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                children: [
                  for (final optionText in shuffledOptions)
                    _buildOptionButton(
                      context,
                      optionText,
                      q.correctOption,
                      selectedAnswer,
                      hasAnswered,
                      colorScheme,
                      enabled: !isPeek,
                    ),

                  // Explanation Box (shown after answering)
                  if (!isPeek && hasAnswered && q.explanation.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest
                            .withAlpha(150),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colorScheme.outlineVariant.withAlpha(120),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.lightbulb_rounded,
                                size: 18,
                                color: colorScheme.secondary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Explanation',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.secondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            q.explanation,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              height: 1.4,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Swipe hint
            if (!isPeek)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.swipe_rounded,
                        size: 16,
                        color: colorScheme.outline,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        hasAnswered
                            ? 'Swipe left or right to continue'
                            : 'Tap an option or swipe to skip',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.outline,
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

  Widget _buildNextQuestionPeek(QuizQuestion peekQ, ColorScheme colorScheme) {
    return Transform.translate(
      offset: const Offset(0, 8),
      child: Transform.scale(
        scale: 0.96,
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 4.0, sigmaY: 4.0),
          child: _buildQuestionCard(
            context,
            peekQ,
            _currentIndex + 1,
            colorScheme,
            isPeek: true,
          ),
        ),
      ),
    );
  }

  Widget _buildStackDecorationCard(ColorScheme colorScheme) {
    return Transform.translate(
      offset: const Offset(0, 16),
      child: Transform.scale(
        scale: 0.92,
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: colorScheme.outlineVariant.withAlpha(100),
            ),
          ),
          color: colorScheme.surfaceContainerLow,
          child: const SizedBox.expand(),
        ),
      ),
    );
  }

  Widget _buildScoreBar(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.outlineVariant.withAlpha(128),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Q ${_currentIndex + 1} / ${_sessionQuestions.length}',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
          ),
          Row(
            children: [
              _buildScoreBadge(
                '✓ $_correctCount',
                Colors.green.shade700,
                colorScheme,
              ),
              const SizedBox(width: 8),
              _buildScoreBadge(
                '✗ $_wrongCount',
                Colors.red.shade700,
                colorScheme,
              ),
              const SizedBox(width: 8),
              _buildScoreBadge(
                'Skipped $_skippedCount',
                colorScheme.outline,
                colorScheme,
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 20),
                tooltip: 'Restart Quiz Session',
                onPressed: _startNewSession,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScoreBadge(String label, Color color, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
      ),
    );
  }

  Widget _buildOptionButton(
    BuildContext context,
    String optionText,
    String correctOption,
    String? selectedAnswer,
    bool hasAnswered,
    ColorScheme colorScheme, {
    bool enabled = true,
  }) {
    final isSelected = selectedAnswer == optionText;
    final isCorrectOption = optionText == correctOption;

    Color borderColor = colorScheme.outlineVariant;
    Color bgColor = colorScheme.surfaceContainerLow;
    Color textColor = colorScheme.onSurface;
    FontWeight fontWeight = FontWeight.normal;

    if (hasAnswered) {
      if (isCorrectOption) {
        bgColor = Colors.green.shade50;
        borderColor = Colors.green;
        textColor = Colors.green.shade900;
        fontWeight = FontWeight.bold;
      } else if (isSelected) {
        bgColor = Colors.red.shade50;
        borderColor = Colors.red;
        textColor = Colors.red.shade900;
        fontWeight = FontWeight.bold;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10.0),
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: !enabled || hasAnswered ? null : () => _answerQuestion(optionText),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: borderColor,
                width: (hasAnswered && (isSelected || isCorrectOption)) ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    optionText,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: textColor,
                          fontWeight: fontWeight,
                        ),
                  ),
                ),
                if (hasAnswered && isCorrectOption)
                  const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20)
                else if (hasAnswered && isSelected && !isCorrectOption)
                  const Icon(Icons.cancel_rounded, color: Colors.red, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryView(ColorScheme colorScheme) {
    final theme = Theme.of(context);
    final answeredTotal = _correctCount + _wrongCount;
    final percentage = answeredTotal > 0
        ? ((_correctCount / answeredTotal) * 100).toStringAsFixed(1)
        : '0.0';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.emoji_events_rounded,
                        size: 64,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Quiz Session Complete!',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),

                      // Score percentage
                      Text(
                        '$percentage%',
                        style: theme.textTheme.displayMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                      Text(
                        'Correct out of answered questions',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.outline,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 24),

                      // Breakdown stats
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem('Correct', '$_correctCount', Colors.green),
                          _buildStatItem('Wrong', '$_wrongCount', Colors.red),
                          _buildStatItem('Skipped', '$_skippedCount', colorScheme.outline),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // Start new session button
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _startNewSession,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Start New Session'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );
  }
}
