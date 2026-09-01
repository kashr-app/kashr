import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kashr/account/cubit/account_cubit.dart';
import 'package:kashr/account/cubit/account_state.dart';
import 'package:kashr/core/model/period.dart';
import 'package:kashr/ingest/cubit/download_cubit.dart';
import 'package:kashr/ingest/download_range.dart';
import 'package:kashr/ingest/ingest_source.dart';
import 'package:kashr/ingest/widgets/csv_import_dialog.dart';
import 'package:kashr/ingest/widgets/download_sheet.dart';
import 'package:kashr/ingest/widgets/ingest_source_sheet.dart';
import 'package:kashr/ingest/widgets/manual_entry_explainer.dart';
import 'package:kashr/settings/extensions.dart';

/// Opens the way of adding transactions the user asked for, and shows a
/// download that is going on.
///
/// Small on purpose: downloading is a periodic action, unlike logging a
/// transaction. The dot marks that the downloaded data is behind; the spinner
/// marks a download in flight, which outlives the sheet, so this is the only
/// place left that can still show it.
class DownloadFab extends StatelessWidget {
  const DownloadFab({
    super.key,
    required this.onLogTransaction,
    required this.onLogTransfer,
    this.selectedPeriod,
  });

  /// The period on screen, which the download can be narrowed to.
  final Period? selectedPeriod;

  /// Logs a transaction by hand, which this button only points at.
  final VoidCallback onLogTransaction;

  /// Logs a transfer by hand, which this button only points at.
  final VoidCallback onLogTransfer;

  @override
  Widget build(BuildContext context) {
    final defaultSource = context.defaultIngestSource;
    return BlocBuilder<DownloadCubit, DownloadState>(
      builder: (context, download) {
        final isWorking = download.activity == DownloadActivity.working;
        return BlocBuilder<AccountCubit, AccountState>(
          builder: (context, state) {
            // A download in flight already answers what the dot would say.
            final isStale =
                !isWorking && isDownloadStale(state.accountById.values);
            return Badge(
              isLabelVisible: isStale,
              smallSize: 10,
              backgroundColor: Theme.of(context).colorScheme.tertiary,
              child: FloatingActionButton.small(
                heroTag: null,
                onPressed: () => _onTap(
                  context,
                  isWorking: isWorking,
                  defaultSource: defaultSource,
                ),
                tooltip: _tooltip(
                  isWorking: isWorking,
                  isStale: isStale,
                  defaultSource: defaultSource,
                ),
                child: isWorking
                    ? const _RunningIndicator()
                    : const Icon(Icons.move_to_inbox_outlined),
              ),
            );
          },
        );
      },
    );
  }

  /// A download that is already running owns the button: showing what it is
  /// doing beats offering to start something else.
  Future<void> _onTap(
    BuildContext context, {
    required bool isWorking,
    required IngestSource defaultSource,
  }) {
    if (isWorking) return _showDownloadSheet(context);
    return _open(context, defaultSource);
  }

  Future<void> _open(BuildContext context, IngestSource source) =>
      switch (source) {
        IngestSource.ask => _chooseThenOpen(context),
        IngestSource.manual => showManualEntryExplainer(
          context,
          onLogTransaction: onLogTransaction,
          onLogTransfer: onLogTransfer,
        ),
        IngestSource.csv => showCsvImportDialog(context),
        IngestSource.bank => _showDownloadSheet(context),
      };

  Future<void> _chooseThenOpen(BuildContext context) async {
    final picked = await IngestSourceSheet.show(context);
    // Guarding against [IngestSource.ask] keeps this from recursing on an
    // answer the sheet does not offer today but could tomorrow.
    if (picked == null || picked == IngestSource.ask) return;
    if (!context.mounted) return;
    await _open(context, picked);
  }

  Future<void> _showDownloadSheet(BuildContext context) =>
      DownloadSheet.show(context, selectedPeriod: selectedPeriod);

  String _tooltip({
    required bool isWorking,
    required bool isStale,
    required IngestSource defaultSource,
  }) {
    if (isWorking) return 'Downloading bank data, tap to see the progress';
    final what = defaultSource == IngestSource.bank
        ? 'Download bank data'
        : 'Add transactions';
    if (isStale) return '$what, last download is a few days old';
    return what;
  }
}

class _RunningIndicator extends StatelessWidget {
  const _RunningIndicator();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: Theme.of(context).colorScheme.onPrimaryContainer,
      ),
    );
  }
}
