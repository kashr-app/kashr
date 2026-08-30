import 'package:kashr/comdirect/comdirect_login_page.dart';
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

/// Lists the banks Kashr can download transactions from.
class BanksPage extends StatelessWidget {
  const BanksPage({super.key, this.offerManualTracking = false});

  /// Whether to offer tracking a bank by hand instead.
  ///
  /// Taking that offer pops the page with `true`.
  final bool offerManualTracking;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Banks')),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                ListTile(
                  title: Text('Comdirect'),
                  // Pushed, so that coming back lands on this list as it was
                  // rather than rebuilding it from the route alone.
                  onTap: () => ComdirectLoginRoute().push(context),
                ),
                if (offerManualTracking) ...[
                  const Divider(),
                  ListTile(
                    title: const Text(
                      'Only comdirect is supported for now. '
                      'Track any other bank manually',
                    ),
                    trailing: const Icon(Icons.arrow_forward),
                    onTap: () => context.pop(true),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
