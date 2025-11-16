import 'package:flutter/material.dart';

/// A widget for displaying and editing a note.
///
/// Shows a button to add a note when empty, displays the note text when
/// present, and provides an inline editor when editing.
class NoteField extends StatefulWidget {
  final String? note;
  final void Function(String?) onNoteChanged;

  const NoteField({
    required this.note,
    required this.onNoteChanged,
    super.key,
  });

  @override
  State<NoteField> createState() => _NoteFieldState();
}

class _NoteFieldState extends State<NoteField> {
  bool _isEditing = false;
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.note ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasNote = widget.note != null && widget.note!.isNotEmpty;

    if (!_isEditing && !hasNote) {
      return TextButton.icon(
        onPressed: () => setState(() => _isEditing = true),
        icon: const Icon(Icons.note_add, size: 16),
        label: const Text('Add note'),
      );
    }

    if (!_isEditing && hasNote) {
      return InkWell(
        onTap: () => setState(() => _isEditing = true),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.note, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.note!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            decoration: const InputDecoration(
              labelText: 'Note',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.check),
          onPressed: () {
            final note = _controller.text.trim();
            widget.onNoteChanged(note.isEmpty ? null : note);
            setState(() => _isEditing = false);
          },
        ),
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            _controller.text = widget.note ?? '';
            setState(() => _isEditing = false);
          },
        ),
      ],
    );
  }
}
