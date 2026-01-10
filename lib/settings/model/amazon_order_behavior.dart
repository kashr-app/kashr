import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

/// Defines the behavior when clicking on an Amazon order ID.
enum AmazonOrderBehavior {
  /// Show a dialog to choose the action.
  askOnTap,

  /// Directly open the order on a specific Amazon TLD.
  openOnTld,

  /// Copy the order ID to clipboard.
  copyOrderId;

  String get displayName {
    switch (this) {
      case AmazonOrderBehavior.askOnTap:
        return 'Ask on tap';
      case AmazonOrderBehavior.openOnTld:
        return 'Open on Amazon';
      case AmazonOrderBehavior.copyOrderId:
        return 'Copy order ID';
    }
  }

  String get description {
    switch (this) {
      case AmazonOrderBehavior.askOnTap:
        return 'Show dialog with options';
      case AmazonOrderBehavior.openOnTld:
        return 'Directly open order on Amazon';
      case AmazonOrderBehavior.copyOrderId:
        return 'Copy order ID to clipboard';
    }
  }
}

/// Converter for [AmazonOrderBehavior] to/from JSON.
class AmazonOrderBehaviorConverter
    implements JsonConverter<AmazonOrderBehavior, String> {
  const AmazonOrderBehaviorConverter();

  @override
  AmazonOrderBehavior fromJson(String json) {
    return AmazonOrderBehavior.values.firstWhere(
      (e) => e.name == json,
      orElse: () => AmazonOrderBehavior.askOnTap,
    );
  }

  @override
  String toJson(AmazonOrderBehavior object) => object.name;
}

/// Available Amazon top-level domains.
enum AmazonTld {
  de('amazon.de', 'Germany'),
  com('amazon.com', 'United States'),
  coUk('amazon.co.uk', 'United Kingdom'),
  fr('amazon.fr', 'France'),
  it('amazon.it', 'Italy'),
  es('amazon.es', 'Spain'),
  ca('amazon.ca', 'Canada'),
  coJp('amazon.co.jp', 'Japan'),
  comAu('amazon.com.au', 'Australia'),
  inTld('amazon.in', 'India'),
  comBr('amazon.com.br', 'Brazil'),
  comMx('amazon.com.mx', 'Mexico'),
  nl('amazon.nl', 'Netherlands'),
  se('amazon.se', 'Sweden'),
  pl('amazon.pl', 'Poland'),
  sg('amazon.sg', 'Singapore');

  const AmazonTld(this.domain, this.country);

  final String domain;
  final String country;

  String get displayName => '$country ($domain)';
}

/// Converter for [AmazonTld] to/from JSON.
class AmazonTldConverter implements JsonConverter<AmazonTld, String> {
  const AmazonTldConverter();

  @override
  AmazonTld fromJson(String json) {
    return AmazonTld.values.firstWhere(
      (e) => e.name == json,
      orElse: () => AmazonTld.de,
    );
  }

  @override
  String toJson(AmazonTld object) => object.name;
}

/// Shows a dialog to select the Amazon order behavior.
Future<AmazonOrderBehavior?> showAmazonOrderBehaviorDialog(
  BuildContext context,
  AmazonOrderBehavior current,
) {
  return showModalBottomSheet<AmazonOrderBehavior>(
    context: context,
    builder: (context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Amazon Order ID Behavior',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ...AmazonOrderBehavior.values.map((option) {
              return ListTile(
                title: Text(option.displayName),
                subtitle: Text(option.description),
                trailing: option == current ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(context, option),
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

/// Shows a dialog to select the Amazon TLD.
Future<AmazonTld?> showAmazonTldDialog(
  BuildContext context,
  AmazonTld current,
) {
  return showModalBottomSheet<AmazonTld>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Select Amazon Marketplace',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: AmazonTld.values.map((tld) {
                    return ListTile(
                      title: Text(tld.country),
                      subtitle: Text(tld.domain),
                      trailing: tld == current ? const Icon(Icons.check) : null,
                      onTap: () => Navigator.pop(context, tld),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
