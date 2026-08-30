import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kashr/account/cubit/account_cubit.dart';
import 'package:kashr/account/cubit/account_state.dart';
import 'package:kashr/ingest/download_range.dart';
import 'package:kashr/ingest/widgets/download_sheet.dart';

/// Starts a bank data download with one tap.
///
/// Small on purpose: downloading is a periodic action, unlike logging a
/// transaction. The dot marks that the downloaded data is behind, and nothing
/// else.
class DownloadFab extends StatelessWidget {
  const DownloadFab({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AccountCubit, AccountState>(
      builder: (context, state) {
        final isStale = isDownloadStale(state.accountById.values);
        return Badge(
          isLabelVisible: isStale,
          smallSize: 10,
          backgroundColor: Theme.of(context).colorScheme.tertiary,
          child: FloatingActionButton.small(
            heroTag: null,
            onPressed: () => DownloadSheet.show(context),
            tooltip: isStale
                ? 'Download bank data, last download is a few days old'
                : 'Download bank data',
            child: const Icon(Icons.move_to_inbox_outlined),
          ),
        );
      },
    );
  }
}
