import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kashr/comdirect/comdirect_login_page.dart';
import 'package:kashr/comdirect/cubit/comdirect_auth_cubit.dart';
import 'package:kashr/core/model/booking_date.dart';
import 'package:kashr/core/widgets/sheet_grabber.dart';
import 'package:kashr/ingest/cubit/download_cubit.dart';
import 'package:kashr/ingest/download_range.dart';
import 'package:kashr/ingest/ingest.dart';
import 'package:kashr/settings/extensions.dart';

/// Shows what a download is doing, from connecting to the result.
///
/// The sheet is the whole conversation about a download: it is the only place
/// the user is asked anything, and the result arrives where they are already
/// looking. Dismissing it only closes the window on a download that keeps
/// going; reopening shows the same one again.
class DownloadSheet extends StatefulWidget {
  const DownloadSheet({super.key});

  /// Opens the sheet on the app's download.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const DownloadSheet(),
    );
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
      if (mounted) context.read<DownloadCubit>().startIfIdle();
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
              const SheetGrabber(),
              const SizedBox(height: 16),
              _view(state),
            ],
          ),
        ),
      ),
    );
  }

  Widget _view(DownloadState state) => switch (state) {
    DownloadIdle() ||
    DownloadStarting() ||
    DownloadNeedsBank() => const _BusyView(title: 'Getting ready…'),
    DownloadNoBankConnected() => const _NoBankView(),
    DownloadChoosingDepth() => const _DepthView(),
    DownloadConnecting() => _BusyView(
      title: state.message ?? 'Connecting to your bank…',
      range: state.range,
      canCancel: true,
    ),
    DownloadWaitingForConfirmation() => _ConfirmationView(range: state.range),
    DownloadRunning() => _BusyView(
      title: 'Downloading transactions…',
      range: state.range,
      canCancel: true,
    ),
    DownloadStopping() => const _BusyView(title: 'Stopping…'),
    DownloadFinished() => _ResultView(
      result: state.result,
      range: state.range,
      isCustomRange: state.request.ignoreCursors,
    ),
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

/// The one range the download covers, oldest start to newest booking date.
///
/// Per-account ranges are an internal detail, the user sees their union.
class _RangeLine extends StatelessWidget {
  final DownloadRange range;

  /// Offers changing the range. Only while no download is in flight.
  final bool canChange;

  /// Whether [range] is one the user picked by hand.
  ///
  /// Only then is there a default to go back to.
  final bool isCustom;

  const _RangeLine({
    required this.range,
    this.canChange = false,
    this.isCustom = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final format = context.dateFormat;
    return Row(
      children: [
        Expanded(
          child: Text(
            '${range.startInclusive.format(format)} – '
            '${range.endInclusive.format(format)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        if (canChange && isCustom)
          TextButton(
            onPressed: () => context.read<DownloadCubit>().start(),
            child: const Text('Use default'),
          ),
        if (canChange)
          TextButton(
            onPressed: () => _changeRange(context),
            child: const Text('Change range'),
          ),
      ],
    );
  }

  /// Lets the user pick both ends, so a gap in the history can be filled
  /// without re-fetching everything since.
  Future<void> _changeRange(BuildContext context) async {
    final cubit = context.read<DownloadCubit>();
    final today = BookingDate.today();
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(
        start: range.startInclusive.atMidnight,
        end: range.endInclusive.atMidnight,
      ),
      firstDate: DateTime(2000),
      lastDate: today.atMidnight,
      helpText: 'Download range',
      saveText: 'Download',
    );
    if (picked == null) return;
    await cubit.downloadBetween(
      startInclusive: BookingDate.on(picked.start),
      endInclusive: BookingDate.on(picked.end),
    );
  }
}

class _BusyView extends StatelessWidget {
  final String title;
  final DownloadRange? range;

  /// Whether there is work worth stopping. Adds the way to stop it.
  final bool canCancel;

  const _BusyView({required this.title, this.range, this.canCancel = false});

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
        if (canCancel) const _CancelAction(),
      ],
    );
  }
}

/// Stops the download and closes the sheet.
///
/// The stop is cooperative, so the download ends at its next safe point
/// rather than the instant this is tapped.
class _CancelAction extends StatelessWidget {
  const _CancelAction();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: () {
          context.read<DownloadCubit>().cancel();
          Navigator.of(context).pop();
        },
        child: const Text('Cancel'),
      ),
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
        const _CancelAction(),
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
        const _CancelAction(),
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

  /// Whether the run used a range the user picked rather than the default.
  final bool isCustomRange;

  const _ResultView({
    required this.result,
    required this.range,
    required this.isCustomRange,
  });

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
        _RangeLine(range: range, canChange: true, isCustom: isCustomRange),
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
