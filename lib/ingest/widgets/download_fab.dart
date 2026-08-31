import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kashr/account/cubit/account_cubit.dart';
import 'package:kashr/account/cubit/account_state.dart';
import 'package:kashr/ingest/cubit/download_cubit.dart';
import 'package:kashr/ingest/download_range.dart';
import 'package:kashr/ingest/widgets/download_sheet.dart';

/// Starts a bank data download with one tap, and shows one that is going on.
///
/// Small on purpose: downloading is a periodic action, unlike logging a
/// transaction. The dot marks that the downloaded data is behind; the spinner
/// marks a download in flight, which outlives the sheet, so this is the only
/// place left that can still show it.
class DownloadFab extends StatelessWidget {
  const DownloadFab({super.key});

  @override
  Widget build(BuildContext context) {
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
                onPressed: () => DownloadSheet.show(context),
                tooltip: _tooltip(isWorking: isWorking, isStale: isStale),
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

  String _tooltip({required bool isWorking, required bool isStale}) {
    if (isWorking) return 'Downloading bank data, tap to see the progress';
    if (isStale) return 'Download bank data, last download is a few days old';
    return 'Download bank data';
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
