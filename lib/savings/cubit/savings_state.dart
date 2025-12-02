import 'package:decimal/decimal.dart';
import 'package:finanalyzer/core/status.dart';
import 'package:finanalyzer/savings/model/savings.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uuid/uuid.dart';

part '../../_gen/savings/cubit/savings_state.freezed.dart';

@freezed
abstract class SavingsState with _$SavingsState {
  const factory SavingsState({
    @Default(Status.initial) Status status,
    @Default({}) Map<UuidValue, Savings> savingsById,
    @Default({}) Map<UuidValue, Decimal> balancesBySavingsId,
    String? errorMessage,
  }) = _SavingsState;
}
