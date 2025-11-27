import 'package:decimal/decimal.dart';
import 'package:finanalyzer/account/model/account.dart';
import 'package:finanalyzer/core/status.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part '../../_gen/account/cubit/account_state.freezed.dart';

@freezed
abstract class AccountState with _$AccountState {
  const factory AccountState({
    @Default(Status.initial) Status status,
    @Default([]) List<Account> accounts,
    @Default([]) List<Account> hiddenAccounts,
    @Default({}) Map<String, Decimal> balances,
    @Default({}) Map<String, Decimal> projectedBalances,
    required DateTime projectionDate,
    @Default(false) bool showHiddenAccounts,
    String? errorMessage,
  }) = _AccountState;
}
