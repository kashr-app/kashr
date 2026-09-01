import 'package:kashr/comdirect/comdirect_login_page.dart';
import 'package:kashr/comdirect/comdirect_model.dart';
import 'package:kashr/ingest/widgets/bank_download_explainer.dart';
import 'package:kashr/app_gate.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Value for [BanksRoute.from] that marks the bank list as being part of
/// creating an account.
const banksFromAccountCreation = 'account-creation';

/// Route to the list of banks Kashr can download transactions from.
///
/// Pass [from] as [banksFromAccountCreation] and push it to let the user fall
/// back to tracking their bank by hand:
///
/// ```dart
/// final trackManually = await const BanksRoute(
///   from: banksFromAccountCreation,
/// ).push<bool>(context);
/// ```
class BanksRoute extends GoRouteData with $BanksRoute {
  const BanksRoute({this.from});
  final String? from;
  @override
  Widget build(BuildContext context, GoRouterState state) {
    return BanksPage(offerManualTracking: from == banksFromAccountCreation);
  }
}

/// A bank Kashr can download turnovers from.
class _Bank {
  const _Bank({required this.name, required this.isConnected});

  final String name;

  /// Whether the user already signed in to this bank.
  final bool isConnected;
}

/// Lists the banks Kashr can download transactions from.
class BanksPage extends StatefulWidget {
  const BanksPage({super.key, this.offerManualTracking = false});

  /// Whether to offer tracking a bank by hand instead.
  ///
  /// Taking that offer pops the page with `true`.
  final bool offerManualTracking;

  @override
  State<BanksPage> createState() => _BanksPageState();
}

class _BanksPageState extends State<BanksPage> {
  bool _comdirectConnected = false;

  @override
  void initState() {
    super.initState();
    _loadConnectionState();
  }

  /// Reads whether comdirect has been set up. Does not prompt for biometrics.
  Future<void> _loadConnectionState() async {
    final connected = await Credentials.hasStored();
    if (mounted) {
      setState(() => _comdirectConnected = connected);
    }
  }

  Future<void> _openComdirectLogin() async {
    await ComdirectLoginRoute().push(context);
    await _loadConnectionState();
  }

  @override
  Widget build(BuildContext context) {
    final banks = [_Bank(name: 'comdirect', isConnected: _comdirectConnected)];
    final connected = banks.where((it) => it.isConnected).toList();
    final notConnected = banks.where((it) => !it.isConnected).toList();

    // A heading only earns its place once it separates two groups.
    final showHeadings = connected.isNotEmpty && notConnected.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Banks')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _PrivacyNote(),
            const SizedBox(height: 24),
            if (showHeadings) const _Heading('Connected'),
            for (final bank in connected)
              _BankCard(bank: bank, onTap: _openComdirectLogin),
            if (showHeadings) ...[
              const SizedBox(height: 16),
              const _Heading('Not connected'),
            ],
            for (final bank in notConnected)
              _BankCard(bank: bank, onTap: _openComdirectLogin),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 8),
            _MissingBankNote(
              onTrackManually: widget.offerManualTracking
                  ? () => context.pop(true)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Explains what a bank download does, for whoever wants to read it.
///
/// Collapsed, because the answer is long and most visits here are to connect
/// a bank rather than to be convinced. The same words the download sheet
/// shows before it asks for anything.
class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: ExpansionTile(
        leading: Icon(Icons.shield_outlined),
        title: Text('How bank download works'),
        subtitle: Text('And what happens to your data'),
        childrenPadding: EdgeInsets.fromLTRB(16, 0, 16, 8),
        children: [BankDownloadExplainer()],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _BankCard extends StatelessWidget {
  const _BankCard({required this.bank, required this.onTap});

  final _Bank bank;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.account_balance_outlined),
        title: Text(bank.name),
        subtitle: bank.isConnected
            ? const _ConnectedLabel()
            : const Text('Connect'),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

/// Status line of a bank the user already signed in to.
///
/// The dot only reinforces the word next to it, so it stays readable without
/// telling the colours apart.
class _ConnectedLabel extends StatelessWidget {
  const _ConnectedLabel();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        const Text('Connected'),
      ],
    );
  }
}

/// Says why the list above is this short, and what to do about it.
class _MissingBankNote extends StatelessWidget {
  const _MissingBankNote({required this.onTrackManually});

  /// Switches to tracking the bank by hand. When null, the way there is only
  /// described, because there is no account being created to switch over.
  final VoidCallback? onTrackManually;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Column(
      children: [
        Text(
          'Only comdirect is supported for now.',
          textAlign: TextAlign.center,
          style: style,
        ),
        if (onTrackManually == null)
          Text(
            'Any other bank can be tracked as a manual account.',
            textAlign: TextAlign.center,
            style: style,
          )
        else
          TextButton.icon(
            onPressed: onTrackManually,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Track another bank manually'),
          ),
      ],
    );
  }
}
