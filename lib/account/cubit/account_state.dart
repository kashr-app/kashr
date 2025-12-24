import 'package:decimal/decimal.dart';
import 'package:kashr/account/model/account.dart';
import 'package:kashr/core/status.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uuid/uuid.dart';

part '../../_gen/account/cubit/account_state.freezed.dart';

@freezed
abstract class AccountState with _$AccountState {
  const factory AccountState({
    @Default(Status.initial) Status status,
    // all accounts
    @Default({}) Map<UuidValue, Account> accountById,
    @Default({}) Map<bool, List<Account>> accountsByIsHidden,
    // depending on showHiddenAccounts.
    @Default([]) List<Account> visibleAccounts,
    @Default({}) Map<UuidValue, Decimal> balances,
    @Default({}) Map<UuidValue, Decimal> projectedBalances,
    required DateTime projectionDate,
    @Default(false) bool showHiddenAccounts,
    String? errorMessage,
  }) = _AccountState;
}
