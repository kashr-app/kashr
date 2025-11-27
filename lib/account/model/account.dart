import 'package:decimal/decimal.dart';
import 'package:finanalyzer/core/decimal_json_converter.dart';
import 'package:finanalyzer/core/uuid_json_converter.dart';
import 'package:finanalyzer/core/bool_json_converter.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uuid/uuid.dart';

part '../../_gen/account/model/account.freezed.dart';
part '../../_gen/account/model/account.g.dart';

enum AccountType {
  checking,
  savings,
  cash,
  investment,
  creditCard;

  String label() {
    switch (this) {
      case AccountType.checking:
        return 'Checking Account';
      case AccountType.savings:
        return 'Savings Account';
      case AccountType.cash:
        return 'Cash';
      case AccountType.investment:
        return 'Investment Account';
      case AccountType.creditCard:
        return 'Credit Card';
    }
  }

  IconData get icon {
    switch (this) {
      case AccountType.checking:
        return Icons.account_balance;
      case AccountType.savings:
        return Icons.savings;
      case AccountType.cash:
        return Icons.payments;
      case AccountType.investment:
        return Icons.trending_up;
      case AccountType.creditCard:
        return Icons.credit_card;
    }
  }
}

enum SyncSource {
  comdirect,
  manual;

  String label() {
    switch (this) {
      case SyncSource.comdirect:
        return 'Comdirect';
      case SyncSource.manual:
        return 'Manual';
    }
  }

  IconData get icon {
    switch (this) {
      case SyncSource.comdirect:
        return Icons.sync;
      case SyncSource.manual:
        return Icons.sync_disabled;
    }
  }
}

@freezed
abstract class Account with _$Account {
  const factory Account({
    @UUIDNullableJsonConverter() UuidValue? id,
    required DateTime createdAt,
    required String name,
    String? identifier, // IBAN or account number
    String? apiId,
    @JsonKey(name: 'account_type') required AccountType accountType,
    @JsonKey(name: 'sync_source') SyncSource? syncSource,
    required String currency,
    @JsonKey(name: 'opening_balance')
    @DecimalJsonConverter()
    required Decimal openingBalance,
    @JsonKey(name: 'opening_balance_date') required DateTime openingBalanceDate,
    @BoolNullableJsonConverter() @JsonKey(name: 'is_hidden') bool? isHidden,
  }) = _Account;

  factory Account.fromJson(Map<String, dynamic> json) =>
      _$AccountFromJson(json);
}

@freezed
abstract class AccountIdAndApiId with _$AccountIdAndApiId {
  const factory AccountIdAndApiId({
    @UUIDJsonConverter() required UuidValue id,
    required String apiId,
  }) = _AccountIdAndApiId;

  factory AccountIdAndApiId.fromJson(Map<String, dynamic> json) =>
      _$AccountIdAndApiIdFromJson(json);
}
