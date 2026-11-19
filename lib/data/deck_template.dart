/// The starter file shown on the "Add your own deck" screen.
///
/// It is a complete, importable deck in the single-file ("course file")
/// format. A test checks that it imports cleanly, so keep it valid JSON.
const deckTemplateFileName = 'my_deck.json';

const deckTemplate = r'''{
  "course": "My Deck",
  "sections": ["Chapter 1"],
  "topics": [
    {
      "title": "First topic",
      "section": "Chapter 1",
      "summary": "Optional: one or two sentences about this topic.",
      "flashcards": [
        {
          "front": "Question or prompt on the front of the card",
          "back": "Short answer on the back",
          "explanation": "Optional: why the answer is right, or an example."
        }
      ],
      "quiz": [
        {
          "question": "A multiple-choice question?",
          "options": ["Correct answer", "Wrong answer", "Wrong answer 2", "Wrong answer 3"],
          "answerIndex": 0,
          "explanation": "Optional: shown after answering."
        }
      ],
      "glossary": [
        {
          "term": "Key Term",
          "definition": "What the term means.",
          "analogy": "Optional: an everyday comparison.",
          "example": "Optional: the term used in a real situation.",
          "related": ["Other Term"]
        },
        {
          "term": "Other Term",
          "definition": "Terms listed in \"related\" become links between glossary entries."
        }
      ]
    }
  ]
}
''';

/// Short field-by-field notes shown under the template.
const deckTemplateNotes = <(String, String)>[
  ('course', 'The deck name shown in the app.'),
  ('sections', 'Optional. Group names for topics, in order.'),
  ('topics', 'A list of topics. Each needs a "title" and at least one '
      'flashcard, quiz question or glossary term.'),
  ('flashcards', '"front" and "back" are required; "explanation" is optional.'),
  ('quiz', '"options" needs 2 or more different answers. "answerIndex" is '
      'the position of the correct one, counting from 0. The app shuffles '
      'the options when it asks the question.'),
  ('glossary', '"term" and "definition" are required. "analogy", "example" '
      'and "related" are optional. Terms that appear in card text become '
      'tappable.'),
];
