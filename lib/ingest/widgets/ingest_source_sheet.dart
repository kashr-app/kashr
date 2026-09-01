import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kashr/core/widgets/sheet_grabber.dart';
import 'package:kashr/ingest/ingest_source.dart';
import 'package:kashr/ingest/widgets/ingest_source_tile.dart';
import 'package:kashr/settings/settings_cubit.dart';

/// Asks how the user wants to get transactions into Kashr.
///
/// Returns what they picked, or null when they dismissed the sheet. Storing
/// the answer as the default happens here, because that is the sheet's own
/// promise; acting on it does not, because only the caller knows what each
/// source does.
class IngestSourceSheet extends StatefulWidget {
  const IngestSourceSheet({super.key});

  static Future<IngestSource?> show(BuildContext context) {
    return showModalBottomSheet<IngestSource>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const IngestSourceSheet(),
    );
  }

  @override
  State<IngestSourceSheet> createState() => _IngestSourceSheetState();
}

class _IngestSourceSheetState extends State<IngestSourceSheet> {
  /// The offered sources, in the order they cost the user effort.
  static const _offered = [
    IngestSource.manual,
    IngestSource.csv,
    IngestSource.bank,
  ];

  bool _remember = false;

  Future<void> _pick(IngestSource source) async {
    if (_remember && source.canBeDefault) {
      await context.read<SettingsCubit>().setDefaultIngestSource(source);
    }
    if (!mounted) return;
    Navigator.of(context).pop(source);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetGrabber(),
            const SizedBox(height: 16),
            Text(
              'Add transactions',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            for (final source in _offered) ...[
              IngestSourceTile(
                source: source,
                onTap: () => _pick(source),
                // While the switch is on, the pin says which taps will stick.
                trailing: _remember && source.canBeDefault
                    ? const Icon(Icons.push_pin_outlined)
                    : null,
              ),
              const SizedBox(height: 8),
            ],
            const Divider(),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _remember,
              onChanged: (value) => setState(() => _remember = value),
              title: const Text('Remember my choice'),
              subtitle: const Text(
                'The next option you pick becomes the default. Change it any '
                'time in Settings.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
