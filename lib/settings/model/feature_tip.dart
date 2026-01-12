import 'package:freezed_annotation/freezed_annotation.dart';

/// Feature tips that can be shown to users for progressive disclosure
enum FeatureTip {
  /// Tip shown when user first sees a pending turnover
  pendingTurnover,

  /// Tip shown when user navigates to transfers for the first time
  transfers,

  /// Tip shown when user creates their first synced account
  syncedAccount,

  /// Tip shown when user first encounters transaction matching
  turnoverMatching,

  /// Tip shown when user navigates to savings goals for the first time
  savingsGoals;

  String get displayName {
    switch (this) {
      case FeatureTip.pendingTurnover:
        return 'Pending Transactions';
      case FeatureTip.transfers:
        return 'Transfers';
      case FeatureTip.savingsGoals:
        return 'Savings Goals';
      case FeatureTip.turnoverMatching:
        return 'Transaction Matching';
      case FeatureTip.syncedAccount:
        return 'Synced Accounts';
    }
  }
}

class FeatureTipConverter implements JsonConverter<FeatureTip, String> {
  const FeatureTipConverter();

  @override
  FeatureTip fromJson(String json) {
    return FeatureTip.values.firstWhere(
      (e) => e.name == json,
      orElse: () => FeatureTip.pendingTurnover,
    );
  }

  @override
  String toJson(FeatureTip object) => object.name;
}
