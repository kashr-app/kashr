import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kashr/account/cubit/account_cubit.dart';
import 'package:kashr/comdirect/comdirect_login_page.dart';
import 'package:kashr/comdirect/comdirect_service.dart';
import 'package:kashr/comdirect/cubit/comdirect_auth_cubit.dart';
import 'package:kashr/dashboard/cubit/dashboard_cubit.dart';
import 'package:kashr/ingest/cubit/download_cubit.dart';
import 'package:kashr/ingest/download_range.dart';
import 'package:kashr/ingest/ingest.dart';
import 'package:kashr/logging/services/log_service.dart';
import 'package:kashr/settings/extensions.dart';
import 'package:kashr/turnover/services/turnover_matching_service.dart';
import 'package:kashr/turnover/services/turnover_service.dart';

/// Shows what a download is doing, from connecting to the result.
///
/// The sheet is the whole conversation about a download: it is the only place
/// the user is asked anything, and the result arrives where they are already
/// looking.
class DownloadSheet extends StatefulWidget {
  const DownloadSheet({super.key});

  /// Opens the sheet and starts the download.
  static Future<void> show(BuildContext context) {
    final log = context.read<LogService>().log;
    final accountCubit = context.read<AccountCubit>();
    final turnoverService = context.read<TurnoverService>();
    final matchingService = context.read<TurnoverMatchingService>();

    final cubit = DownloadCubit(
      log,
      authCubit: context.read<ComdirectAuthCubit>(),
      accountCubit: accountCubit,
      dashboardCubit: context.read<DashboardCubit>(),
      createIngestor: (api) => ComdirectService(
        log,
        comdirectAPI: api,
        accountCubit: accountCubit,
        turnoverService: turnoverService,
        matchingService: matchingService,
      ),
    );

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          BlocProvider.value(value: cubit, child: const DownloadSheet()),
    ).whenComplete(cubit.close);
  }

  @override
  State<DownloadSheet> createState() => _DownloadSheetState();
}

class _DownloadSheetState extends State<DownloadSheet> {
  @override
  void initState() {
    super.initState();
    // After the first frame, so the state listener below sees every step.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<DownloadCubit>().start();
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<DownloadCubit, DownloadState>(
      listener: (context, state) {
        if (state is DownloadNeedsBank) _connectBank(context);
      },
      builder: (context, state) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _Grabber(),
              const SizedBox(height: 16),
              _view(state),
            ],
          ),
        ),
      ),
    );
  }

  Widget _view(DownloadState state) => switch (state) {
    DownloadStarting() ||
    DownloadNeedsBank() => const _BusyView(title: 'Getting ready…'),
    DownloadNoBankConnected() => const _NoBankView(),
    DownloadChoosingDepth() => const _DepthView(),
    DownloadConnecting() => _BusyView(
      title: state.message ?? 'Connecting to your bank…',
      range: state.range,
    ),
    DownloadWaitingForConfirmation() => _ConfirmationView(range: state.range),
    DownloadRunning() => _BusyView(
      title: 'Downloading transactions…',
      range: state.range,
    ),
    DownloadFinished() => _ResultView(result: state.result, range: state.range),
    DownloadFailed() => _FailureView(
      message: state.message,
      reason: state.reason,
    ),
  };

  /// Sends the user into the connect-a-bank flow and picks the download back
  /// up once they are connected.
  ///
  /// Both cubits are read before the push so that coming back never depends
  /// on this context still being mounted, and never on popping a route that
  /// may no longer be on top.
  Future<void> _connectBank(BuildContext context) async {
    final cubit = context.read<DownloadCubit>();
    final authCubit = context.read<ComdirectAuthCubit>();

    await const ComdirectLoginRoute().push<void>(context);

    await cubit.continueAfterConnect(
      isConnected: authCubit.state is AuthSuccess,
    );
  }
}

class _Grabber extends StatelessWidget {
  const _Grabber();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.outlineVariant,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;

  const _Title({required this.icon, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, color: color ?? theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// The one range the download covers, oldest start to today.
///
/// Per-account ranges are an internal detail, the user sees their union.
class _RangeLine extends StatelessWidget {
  final DownloadRange range;

  /// Offers widening the range. Only while no download is in flight.
  final bool canChange;

  const _RangeLine({required this.range, this.canChange = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final format = context.dateFormat;
    return Row(
      children: [
        Expanded(
          child: Text(
            '${format.format(range.min)} – ${format.format(range.max)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        if (canChange)
          TextButton(
            onPressed: () => _changeRange(context),
            child: const Text('Change range'),
          ),
      ],
    );
  }

  Future<void> _changeRange(BuildContext context) async {
    final cubit = context.read<DownloadCubit>();
    final today = DateTime.now();
    final startDate = await showDatePicker(
      context: context,
      initialDate: range.min,
      firstDate: DateTime(2000),
      lastDate: today,
      helpText: 'Download from',
    );
    if (startDate == null) return;
    await cubit.downloadFrom(startDate);
  }
}

class _BusyView extends StatelessWidget {
  final String title;
  final DownloadRange? range;

  const _BusyView({required this.title, this.range});

  @override
  Widget build(BuildContext context) {
    final range = this.range;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
        if (range != null) ...[
          const SizedBox(height: 8),
          _RangeLine(range: range),
        ],
      ],
    );
  }
}

/// The 2FA wait, which used to look like the app was doing nothing.
class _ConfirmationView extends StatelessWidget {
  final DownloadRange range;

  const _ConfirmationView({required this.range});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Title(
          icon: Icons.phonelink_lock_outlined,
          text: 'Confirm in your banking app',
        ),
        const SizedBox(height: 8),
        Text(
          'Your bank sent a confirmation request. Approve it there and the '
          'download continues on its own.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        const LinearProgressIndicator(),
        const SizedBox(height: 8),
        _RangeLine(range: range),
      ],
    );
  }
}

/// The only question the app ever asks up front, and only once.
class _DepthView extends StatelessWidget {
  const _DepthView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Title(icon: Icons.history, text: 'How far back should we go?'),
        const SizedBox(height: 8),
        Text(
          'This is the first download, so there is nothing to continue from. '
          'Later downloads pick up where this one ends.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        for (final depth in DownloadDepth.values)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(depth.label),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.read<DownloadCubit>().startWithDepth(depth),
          ),
      ],
    );
  }
}

/// Where the download lands: counts, the range it used, and a way out.
///
/// Built as a list of sections so another one - a note that arrives with the
/// data - can be slotted in without touching the rest.
class _ResultView extends StatelessWidget {
  final DataIngestResult result;
  final DownloadRange range;

  const _ResultView({required this.result, required this.range});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Title(
          icon: Icons.check_circle_outline,
          text: _summary(result),
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 8),
        _RangeLine(range: range, canChange: true),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ),
      ],
    );
  }

  String _summary(DataIngestResult result) {
    final parts = <String>[
      if (result.newCount > 0) '${result.newCount} new',
      if (result.updatedCount > 0) '${result.updatedCount} updated',
      if (result.autoMatchedCount > 0)
        '${result.autoMatchedCount} auto-matched',
      if (result.unmatchedCount > 0) '${result.unmatchedCount} need tagging',
    ];
    return parts.isEmpty
        ? 'Everything was already up to date'
        : parts.join(', ');
  }
}

/// The way out of a state that waits on the user.
///
/// Cancel is always the way back, so only the one thing worth doing next
/// changes between states.
class _Actions extends StatelessWidget {
  final String primaryLabel;
  final VoidCallback onPrimary;

  const _Actions({required this.primaryLabel, required this.onPrimary});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        const SizedBox(width: 8),
        FilledButton(onPressed: onPrimary, child: Text(primaryLabel)),
      ],
    );
  }
}

/// Where the download stops when the user backed out of the connect flow.
class _NoBankView extends StatelessWidget {
  const _NoBankView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Title(
          icon: Icons.account_balance_outlined,
          text: 'comdirect is not connected',
        ),
        const SizedBox(height: 8),
        Text(
          'Kashr needs your comdirect credentials before it can download '
          'anything.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        _Actions(
          primaryLabel: 'Connect comdirect',
          onPrimary: () => context.read<DownloadCubit>().start(),
        ),
      ],
    );
  }
}

/// Where the download stopped, and the one thing worth trying next.
///
/// The reason picks that action: offering 'Try again' for a rejected password
/// only sends the user around the same loop.
class _FailureView extends StatelessWidget {
  final String message;
  final DownloadFailureReason reason;

  const _FailureView({required this.message, required this.reason});

  bool get _isCredentialProblem =>
      reason == DownloadFailureReason.badCredentials;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Title(
          icon: Icons.error_outline,
          text: _isCredentialProblem
              ? 'comdirect could not sign you in'
              : 'The download stopped',
          color: theme.colorScheme.error,
        ),
        const SizedBox(height: 8),
        Text(
          message,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        if (_isCredentialProblem)
          _Actions(
            primaryLabel: 'Check credentials',
            onPrimary: () => _checkCredentials(context),
          )
        else
          _Actions(
            primaryLabel: 'Try again',
            onPrimary: () => context.read<DownloadCubit>().retry(),
          ),
      ],
    );
  }

  /// Opens the bank's credentials and picks the download back up, so a
  /// corrected password does not need a second tap.
  Future<void> _checkCredentials(BuildContext context) async {
    final cubit = context.read<DownloadCubit>();
    await const ComdirectLoginRoute().push<void>(context);
    await cubit.retry();
  }
}
