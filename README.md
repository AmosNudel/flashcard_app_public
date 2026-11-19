# Flashcards

A Flutter study app with three ways to learn from the same deck:

- **Flashcards**: swipe through cards in random order and flip them for the answer.
- **Quiz**: multiple-choice questions with shuffled options and a score at the end.
- **Glossary**: a searchable list of terms, linked to each other. Terms that appear in card text can be tapped.

It ships with a small sample deck. Add your own decks from JSON files: no account, no internet connection and no server needed. Imported decks stay on your device.

## Running it

```sh
flutter pub get
flutter run
```

It runs on Android, iOS, Windows, macOS, Linux and the web. Folder import isn't available on the web, but you can still select files there.

## Release builds

```sh
flutter build apk --release --split-per-abi   # one APK per CPU type (~17 MB each)
flutter build apk --release                   # one APK for all phones (~48 MB)
```

`app-arm64-v8a-release.apk` runs on nearly every phone from the last several years.

Release builds are signed with the key described in `android/key.properties`:

```properties
storePassword=...
keyPassword=...
keyAlias=...
storeFile=../your-release-key.jks
```

That file and the keystore are gitignored. Without them, release builds are signed with the debug key, which is fine for trying the app but not for sharing it: Android only installs an update over an existing install when both are signed with the same key.

## Adding your own deck

In the app, tap **Add your own deck** (the icon in the top bar, or the first item in the deck list). From there you can:

- **Select JSON files**: one file holding a whole deck, or several topic files that become one deck.
- **Select a folder**: every `.json` file in the folder and its subfolders.
- **See the template**: copy it or save it as a file, fill it in, then import it.

Import is all-or-nothing. If a file has a mistake, nothing is imported, and the app lists every problem with the file name and the exact item, for example `biology.json › quiz[2]: "answerIndex" must be a whole number from 0 to 3`.

To remove an imported deck, open the deck list and tap the bin icon next to it. Your original files aren't touched.

## Deck format

### One file per deck (simplest)

```json
{
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
```

### Fields

**Deck**

| Field | Required | Notes |
|---|---|---|
| `course` | no | Deck name. You can also rename the deck when importing. |
| `sections` | no | Group names for topics, in display order. Sections used by topics but missing here are added automatically. |
| `topics` | yes | List of topics (see below). |

**Topic.** A topic needs at least one flashcard, quiz question or glossary term. The three lists are each optional.

| Field | Required | Notes |
|---|---|---|
| `title` | no | Defaults to `Topic 1`, `Topic 2`, … or to the file name for topic files. |
| `id` | no | Generated from the title. Duplicates get `-2`, `-3`, … appended. |
| `section` | no | Defaults to `General`. |
| `order` | no | Sort position. Without it, topics keep their file/list order. |
| `summary` | no | Short description. |
| `flashcards` | no | `front` and `back` required, `explanation` optional. |
| `quiz` | no | `question`, `options` (2 or more different answers) and `answerIndex` required. `answerIndex` is the position of the correct option, **counting from 0**. `explanation` is optional. Options are shuffled when shown. |
| `glossary` | no | `term` and `definition` required. `analogy`, `example`, `supplement` and `related` (a list of other term names) are optional. Links to terms that don't exist are dropped. |

### Large decks: one file per topic

For a big deck, put each topic in its own file. A topic file is just the topic object on its own:

```json
{
  "title": "Greetings",
  "flashcards": [{ "front": "hola", "back": "hello" }]
}
```

Select all the topic files together, or select their folder, and they become one deck. Without a manifest, topics are ordered by file name, so prefix them with numbers (`01_greetings.json`, `02_verbs.json`). The deck is named after the folder.

To set the deck name, sections and topic order explicitly, add a `manifest.json` to the folder:

```json
{
  "course": "Spanish Basics",
  "sections": ["Week 1", "Week 2"],
  "topics": ["topics/01_greetings.json", "topics/02_verbs.json"]
}
```

The bundled sample deck in [`assets/data/courses/sample/`](assets/data/courses/sample/) uses this layout. Copy that folder to your device and import it to see it in action.

## Bundling decks into your own build

To ship decks inside the app instead of importing them:

1. Add a folder under `assets/data/courses/<id>/` with a `manifest.json` and a `topics/` folder, like the sample.
2. Add the course to `assets/data/courses.json`.
3. List both folders under `flutter: assets:` in `pubspec.yaml`. Flutter asset folders aren't recursive.

`flutter test` checks every bundled course: quiz answers in range, unique terms, links that resolve, and so on.

## Project layout

```
lib/
  data/
    models.dart          Deck, topic, card, question and glossary models
    repository.dart      Loads bundled decks; the course catalog
    deck_importer.dart   Validates user JSON files and turns them into decks
    deck_store.dart      Saves, lists and deletes imported decks
    deck_template.dart   The template shown in the app
  platform/              File access (dart:io on devices, browser storage on web)
  ui/                    Screens: flashcards, quiz, glossary, add-deck, deck picker
android/app/src/main/kotlin/.../MainActivity.kt
                         Reads a folder picked through Android's system picker
```

## License

[MIT](LICENSE)
