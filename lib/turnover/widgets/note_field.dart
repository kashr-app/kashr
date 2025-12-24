import 'package:kashr/turnover/widgets/note_display.dart';
import 'package:flutter/material.dart';

/// A widget for displaying and editing a note.
///
/// Shows a button to add a note when empty, displays the note text when
/// present, and opens a dialog for editing when tapped.
class NoteField extends StatelessWidget {
  final String? note;
  final void Function(String?) onNoteChanged;

  const NoteField({required this.note, required this.onNoteChanged, super.key});

  Future<void> _showNoteDialog(BuildContext context) async {
    final controller = TextEditingController(text: note ?? '');

    final result = await showDialog<String>(
      context: context,
      builder: (context) => _NoteDialog(controller: controller),
    );

    if (result != null) {
      final trimmedNote = result.trim();
      onNoteChanged(trimmedNote.isEmpty ? null : trimmedNote);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasNote = note != null && note!.isNotEmpty;

    if (!hasNote) {
      return TextButton.icon(
        onPressed: () => _showNoteDialog(context),
        icon: const Icon(Icons.note_add, size: 16),
        label: const Text('Add note'),
      );
    }

    return InkWell(
      onTap: () => _showNoteDialog(context),
      child: NoteDisplay(note: note),
    );
  }
}

class _NoteDialog extends StatelessWidget {
  final TextEditingController controller;

  const _NoteDialog({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Note'),
      content: TextField(
        controller: controller,
        decoration: const InputDecoration(
          labelText: 'Note',
          border: OutlineInputBorder(),
        ),
        maxLines: 5,
        minLines: 3,
        textCapitalization: TextCapitalization.sentences,
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
