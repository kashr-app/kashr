import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kashr/settings/model/amazon_order_behavior.dart';
import 'package:kashr/settings/settings_cubit.dart';
import 'package:kashr/turnover/dialogs/amazon_order_action_dialog.dart';
import 'package:kashr/turnover/widgets/purpose_renderer.dart';
import 'package:url_launcher/url_launcher.dart';

/// Renderer that detects Amazon order IDs and makes them clickable.
class AmazonOrderRenderer implements PurposeRenderer {
  const AmazonOrderRenderer();

  /// Regex pattern to match Amazon order IDs (e.g., D02-1234567-1234567).
  static final _orderIdRegex = RegExp(r'\w\d{2}-\d{7}-\d{7}');

  /// Regex pattern to extract country code from Amazon transactions.
  /// Matches patterns like "AMZN Mktp DE", "AMZNPrime DE", "Amazon.de".
  static final _countryCodeRegex = RegExp(
    r'(?:AMZN(?:\s+Mktp|\s*Prime)?\s+([A-Z]{2})|Amazon\.([a-z]{2,3}(?:\.[a-z]{2})?))',
    caseSensitive: false,
  );

  /// Maps country codes to Amazon TLDs.
  static const _countryToTldMap = <String, AmazonTld>{
    'DE': AmazonTld.de,
    'UK': AmazonTld.coUk,
    'US': AmazonTld.com,
    'FR': AmazonTld.fr,
    'IT': AmazonTld.it,
    'ES': AmazonTld.es,
    'CA': AmazonTld.ca,
    'JP': AmazonTld.coJp,
    'AU': AmazonTld.comAu,
    'IN': AmazonTld.inTld,
    'BR': AmazonTld.comBr,
    'MX': AmazonTld.comMx,
    'NL': AmazonTld.nl,
    'SE': AmazonTld.se,
    'PL': AmazonTld.pl,
    'SG': AmazonTld.sg,
  };

  /// Maps domain extensions to Amazon TLDs.
  static const _domainToTldMap = <String, AmazonTld>{
    'de': AmazonTld.de,
    'co.uk': AmazonTld.coUk,
    'com': AmazonTld.com,
    'fr': AmazonTld.fr,
    'it': AmazonTld.it,
    'es': AmazonTld.es,
    'ca': AmazonTld.ca,
    'co.jp': AmazonTld.coJp,
    'com.au': AmazonTld.comAu,
    'in': AmazonTld.inTld,
    'com.br': AmazonTld.comBr,
    'com.mx': AmazonTld.comMx,
    'nl': AmazonTld.nl,
    'se': AmazonTld.se,
    'pl': AmazonTld.pl,
    'sg': AmazonTld.sg,
  };

  @override
  Widget? tryRender(
    BuildContext context,
    String purposeText, {
    TextStyle? style,
    int? maxLines,
    TextOverflow? overflow,
  }) {
    final matches = _orderIdRegex.allMatches(purposeText);

    if (matches.isEmpty) {
      return null;
    }

    final spans = <InlineSpan>[];
    int lastMatchEnd = 0;

    for (final match in matches) {
      if (match.start > lastMatchEnd) {
        spans.add(
          TextSpan(text: purposeText.substring(lastMatchEnd, match.start)),
        );
      }

      final orderId = match.group(0)!;
      spans.add(
        TextSpan(
          text: orderId,
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            decoration: TextDecoration.underline,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () async {
              await _handleOrderIdTap(context, orderId, purposeText);
            },
        ),
      );

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < purposeText.length) {
      spans.add(TextSpan(text: purposeText.substring(lastMatchEnd)));
    }

    return RichText(
      text: TextSpan(style: style, children: spans),
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
    );
  }

  /// Detects the Amazon TLD from the transaction purpose text.
  ///
  /// Returns the appropriate Amazon TLD based on heuristics,
  /// or the provided fallback if no country code is detected.
  static AmazonTld detectTld(String purposeText, AmazonTld fallback) {
    final match = _countryCodeRegex.firstMatch(purposeText);
    if (match == null) return fallback;

    // Check if we matched a country code (group 1: "AMZN Mktp DE")
    final countryCode = match.group(1)?.toUpperCase();
    if (countryCode != null && _countryToTldMap.containsKey(countryCode)) {
      return _countryToTldMap[countryCode]!;
    }

    // Check if we matched a domain (group 2: "Amazon.de")
    final domain = match.group(2)?.toLowerCase();
    if (domain != null && _domainToTldMap.containsKey(domain)) {
      return _domainToTldMap[domain]!;
    }

    return fallback;
  }

  /// Handles a tap on an Amazon order ID.
  static Future<void> _handleOrderIdTap(
    BuildContext context,
    String orderId,
    String purposeText,
  ) async {
    final settingsCubit = context.read<SettingsCubit>();
    final settings = settingsCubit.state;
    final detectedTld = detectTld(purposeText, settings.amazonTld);

    switch (settings.amazonOrderBehavior) {
      case AmazonOrderBehavior.askOnTap:
        final result = await showAmazonOrderActionDialog(
          context: context,
          orderId: orderId,
          detectedTld: detectedTld,
        );

        if (result != null && context.mounted) {
          // Handle the "set as default" checkbox
          if (result.setAsDefault) {
            switch (result.action) {
              case AmazonOrderAction.openOnDetectedTld:
              case AmazonOrderAction.chooseOtherTld:
                await settingsCubit.setAmazonOrderBehavior(
                  AmazonOrderBehavior.openOnTld,
                );
                if (result.selectedTld != null) {
                  await settingsCubit.setAmazonTld(result.selectedTld!);
                }
                break;
              case AmazonOrderAction.copyOrderId:
                await settingsCubit.setAmazonOrderBehavior(
                  AmazonOrderBehavior.copyOrderId,
                );
                break;
            }
          }

          // Perform the action
          switch (result.action) {
            case AmazonOrderAction.openOnDetectedTld:
            case AmazonOrderAction.chooseOtherTld:
              if (result.selectedTld != null && context.mounted) {
                await _openOrder(context, orderId, result.selectedTld!);
              }
              break;
            case AmazonOrderAction.copyOrderId:
              // Already handled in the dialog
              break;
          }
        }
        break;

      case AmazonOrderBehavior.openOnTld:
        await _openOrder(context, orderId, settings.amazonTld);
        break;

      case AmazonOrderBehavior.copyOrderId:
        await Clipboard.setData(ClipboardData(text: orderId));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Order ID copied to clipboard')),
          );
        }
        break;
    }
  }

  /// Opens an Amazon order URL.
  static Future<void> _openOrder(
    BuildContext context,
    String orderId,
    AmazonTld tld,
  ) async {
    final urlString =
        'https://www.${tld.domain}/gp/css/summary/edit.html?orderID=$orderId';
    final url = Uri.parse(urlString);
    try {
      final launched = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        _showCopyLinkSnackBar(context, urlString);
      }
    } catch (e) {
      if (context.mounted) {
        _showCopyLinkSnackBar(context, urlString);
      }
    }
  }

  /// Shows a SnackBar with an option to copy the URL to clipboard.
  static void _showCopyLinkSnackBar(BuildContext context, String url) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Could not open link'),
        action: SnackBarAction(
          label: 'Copy Link',
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: url));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Link copied to clipboard')),
              );
            }
          },
        ),
      ),
    );
  }
}
