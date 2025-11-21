import 'package:flutter/material.dart';

/// A widget for displaying a note.
class NoteDisplay extends StatelessWidget {
  const NoteDisplay({
    super.key,
    required this.note,
  });

  final String? note;

  @override
  Widget build(BuildContext context) {
    return Container(
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
              note!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}