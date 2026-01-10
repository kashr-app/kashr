import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kashr/settings/model/amazon_order_behavior.dart';

/// Result of the Amazon order action dialog.
class AmazonOrderActionResult {
  final AmazonOrderAction action;
  final AmazonTld? selectedTld;
  final bool setAsDefault;

  const AmazonOrderActionResult({
    required this.action,
    this.selectedTld,
    this.setAsDefault = false,
  });
}

/// Actions that can be taken on an Amazon order ID.
enum AmazonOrderAction {
  openOnDetectedTld,
  chooseOtherTld,
  copyOrderId,
}

/// Shows a dialog to select an action for an Amazon order ID.
///
/// Returns the selected action and whether to set it as default.
Future<AmazonOrderActionResult?> showAmazonOrderActionDialog({
  required BuildContext context,
  required String orderId,
  required AmazonTld detectedTld,
}) {
  return showDialog<AmazonOrderActionResult>(
    context: context,
    builder: (context) => _AmazonOrderActionDialog(
      orderId: orderId,
      detectedTld: detectedTld,
    ),
  );
}

class _AmazonOrderActionDialog extends StatefulWidget {
  final String orderId;
  final AmazonTld detectedTld;

  const _AmazonOrderActionDialog({
    required this.orderId,
    required this.detectedTld,
  });

  @override
  State<_AmazonOrderActionDialog> createState() =>
      _AmazonOrderActionDialogState();
}

class _AmazonOrderActionDialogState extends State<_AmazonOrderActionDialog> {
  bool _setAsDefault = false;
  AmazonTld? _selectedTld;

  @override
  void initState() {
    super.initState();
    _selectedTld = widget.detectedTld;
  }

  void _handleOpenOnDetectedTld() {
    Navigator.of(context).pop(
      AmazonOrderActionResult(
        action: AmazonOrderAction.openOnDetectedTld,
        selectedTld: widget.detectedTld,
        setAsDefault: _setAsDefault,
      ),
    );
  }

  Future<void> _handleChooseOtherTld() async {
    final tld = await showAmazonTldDialog(context, _selectedTld!);
    if (tld != null && mounted) {
      setState(() {
        _selectedTld = tld;
      });
      Navigator.of(context).pop(
        AmazonOrderActionResult(
          action: AmazonOrderAction.chooseOtherTld,
          selectedTld: tld,
          setAsDefault: _setAsDefault,
        ),
      );
    }
  }

  void _handleCopyOrderId() {
    Clipboard.setData(ClipboardData(text: widget.orderId));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Order ID copied to clipboard')),
    );
    Navigator.of(context).pop(
      AmazonOrderActionResult(
        action: AmazonOrderAction.copyOrderId,
        setAsDefault: _setAsDefault,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Amazon Order'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order ID: ${widget.orderId}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.open_in_browser),
            title: Text('Open on ${widget.detectedTld.domain}'),
            subtitle: Text(widget.detectedTld.country),
            onTap: _handleOpenOnDetectedTld,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.public),
            title: const Text('Choose other marketplace'),
            onTap: _handleChooseOtherTld,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.copy),
            title: const Text('Copy order ID'),
            onTap: _handleCopyOrderId,
          ),
          const Divider(),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _setAsDefault,
            onChanged: (value) {
              setState(() {
                _setAsDefault = value ?? false;
              });
            },
            title: const Text('Use this as default'),
            subtitle: const Text(
              'Skip this dialog in the future. You can change this in settings.',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
