import 'package:finanalyzer/core/uuid_json_converter.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uuid/uuid.dart';

part '../_gen/model/account.freezed.dart';
part '../_gen/model/account.g.dart';

@freezed
abstract class Account with _$Account {
  const factory Account({
    @UUIDNullableJsonConverter() UuidValue? id,
    required DateTime createdAt,
    required String name,
    String? identifier, // IBAN or account number
    String? apiId,
  }) = _Account;

  factory Account.fromJson(Map<String, dynamic> json) => _$AccountFromJson(json);
}

@freezed
abstract class AccountIdAndApiId with _$AccountIdAndApiId {
  const factory AccountIdAndApiId({
    @UUIDJsonConverter() required UuidValue id,
    required String apiId,
  }) = _AccountIdAndApiId;

  factory AccountIdAndApiId.fromJson(Map<String, dynamic> json) => _$AccountIdAndApiIdFromJson(json);
}
