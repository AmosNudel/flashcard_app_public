import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/deck_importer.dart';
import '../data/deck_store.dart';
import '../data/deck_template.dart';
import '../platform/device.dart';

/// Lets the user import their own decks from JSON files or a folder, and
/// shows the template for writing one.
///
/// Pops with the id of the first deck imported, or null if nothing was.
class AddDeckScreen extends StatefulWidget {
  const AddDeckScreen({super.key, required this.deckStore});

  final DeckStore deckStore;

  @override
  State<AddDeckScreen> createState() => _AddDeckScreenState();
}

class _AddDeckScreenState extends State<AddDeckScreen> {
  bool _busy = false;

  Future<void> _pickFiles() async {
    final picked = await _guard(() => FilePicker.pickFiles(
          dialogTitle: 'Select deck JSON files',
        ));
    if (picked == null || picked.isEmpty) return;

    final skipped = picked.where((f) => !_isJson(f.name)).map((f) => f.name);
    final files = await _guard(() async => <SourceFile>[
          for (final f in picked)
            if (_isJson(f.name))
              SourceFile(
                f.name,
                utf8.decode(await f.readAsBytes(), allowMalformed: true),
              ),
        ]);
    if (files == null) return;
    if (files.isEmpty) {
      _showProblems(['Only .json files can be imported.', ...skipped]);
      return;
    }
    await _import(files, fallbackTitle: null, skipped: skipped.toList());
  }

  Future<void> _pickFolder() async {
    final folder = await _guard(() => FilePicker.pickDirectory(
          dialogTitle: 'Select a folder of deck JSON files',
        ));
    if (folder == null) return;
    final files = await _guard(() => readJsonFolder(folder));
    if (files == null) return;
    if (files.isEmpty) {
      _showProblems(['That folder has no .json files.']);
      return;
    }
    final segments = folder.pathSegments.where((s) => s.isNotEmpty);
    // Android tree URIs end in e.g. "primary:Documents/Biology".
    final folderName = segments.isEmpty
        ? null
        : Uri.decodeComponent(segments.last).split(RegExp(r'[:/]')).last;
    await _import(files, fallbackTitle: folderName, skipped: const []);
  }

  bool _isJson(String name) => name.toLowerCase().endsWith('.json');

  /// Runs a picker/IO call with the busy indicator on, reporting failures.
  Future<T?> _guard<T>(Future<T> Function() action) async {
    setState(() => _busy = true);
    try {
      return await action();
    } on Object catch (e) {
      _showProblems(['Could not read the selection: $e']);
      return null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import(
    List<SourceFile> files, {
    required String? fallbackTitle,
    required List<String> skipped,
  }) async {
    final List<DeckDraft> drafts;
    try {
      drafts = DeckImporter.parse(files, fallbackTitle: fallbackTitle);
    } on DeckImportException catch (e) {
      _showProblems(e.problems);
      return;
    }
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _ConfirmImportDialog(drafts: drafts, skipped: skipped),
    );
    if (confirmed != true) return;

    final ids = await _guard(() async => [
          for (final d in drafts) await widget.deckStore.save(d),
        ]);
    if (ids == null || !mounted) return;
    Navigator.of(context).pop(ids.first);
  }

  void _showProblems(List<String> problems) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.error_outline_rounded),
        title: const Text('Nothing was imported'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final p in problems)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text('• $p'),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _copyTemplate() async {
    await Clipboard.setData(const ClipboardData(text: deckTemplate));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Template copied to the clipboard')),
    );
  }

  Future<void> _saveTemplate() async {
    final saved = await _guard(() => FilePicker.saveFile(
          dialogTitle: 'Save the deck template',
          fileName: deckTemplateFileName,
          bytes: utf8.encode(deckTemplate),
          mimeType: 'application/json',
        ));
    if (saved == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Template saved')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add your own deck'),
        bottom: _busy
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator(),
              )
            : null,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Import', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Pick one file that holds a whole deck, several topic files, '
              'or a folder of them. Files you pick together become one deck.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy ? null : _pickFiles,
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text('Select JSON files'),
            ),
            if (canPickFolder) ...[
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                onPressed: _busy ? null : _pickFolder,
                icon: const Icon(Icons.folder_open_rounded),
                label: const Text('Select a folder'),
              ),
            ],
            const SizedBox(height: 32),
            Text('Template', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Start from this file: fill it in with any text editor, save '
              'it as a .json file, then import it above.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _copyTemplate,
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text('Copy'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _saveTemplate,
                    icon: const Icon(Icons.save_alt_rounded),
                    label: const Text('Save file'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SelectableText(
                  deckTemplate,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    height: 1.4,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            for (final (field, note) in deckTemplateNotes)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(
                      text: '$field  ',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                    TextSpan(text: note),
                  ]),
                ),
              ),
            const SizedBox(height: 8),
            Text(
              'Long decks can also be split into one file per topic, with an '
              'optional manifest.json for the deck name and topic order. '
              'See the project README for details.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows what was found and lets the user rename a single deck before saving.
class _ConfirmImportDialog extends StatefulWidget {
  const _ConfirmImportDialog({required this.drafts, required this.skipped});

  final List<DeckDraft> drafts;
  final List<String> skipped;

  @override
  State<_ConfirmImportDialog> createState() => _ConfirmImportDialogState();
}

class _ConfirmImportDialogState extends State<_ConfirmImportDialog> {
  late final _name = TextEditingController(text: widget.drafts.first.title);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _confirm() {
    if (widget.drafts.length == 1) {
      final name = _name.text.trim();
      if (name.isEmpty) return;
      widget.drafts.first.title = name;
    }
    Navigator.of(context).pop(true);
  }

  String _counts(DeckDraft d) => '${d.topics.length} topics · '
      '${d.flashcardCount} cards · ${d.quizCount} questions · '
      '${d.glossaryCount} terms';

  @override
  Widget build(BuildContext context) {
    final single = widget.drafts.length == 1;
    return AlertDialog(
      title: Text(single ? 'Import deck' : 'Import ${widget.drafts.length} decks'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: [
            if (single) ...[
              TextField(
                controller: _name,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Deck name'),
                onSubmitted: (_) => _confirm(),
              ),
              const SizedBox(height: 12),
              Text(_counts(widget.drafts.first)),
            ] else
              for (final d in widget.drafts)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(d.title),
                  subtitle: Text(_counts(d)),
                ),
            if (widget.skipped.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Skipped (not .json): ${widget.skipped.join(', ')}'),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _confirm, child: const Text('Import')),
      ],
    );
  }
}
