import 'dart:convert';

import 'package:kashr/core/secure_storage.dart';
import 'package:kashr/logging/services/log_service.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:decimal/decimal.dart';
import 'package:local_auth/local_auth.dart';

part '../_gen/comdirect/comdirect_model.g.dart';
part '../_gen/comdirect/comdirect_model.freezed.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class Credentials {
  final String clientId;
  final String clientSecret;
  final String username;
  final String password;

  Credentials({
    required this.clientId,
    required this.clientSecret,
    required this.username,
    required this.password,
  });

  static Future<bool> _authenticate() async {
    try {
      return await LocalAuthentication().authenticate(
        localizedReason: 'Access credentials',
        persistAcrossBackgrounding: true,
      );
    } catch (e, s) {
      final log = LogService.instance?.log;
      log?.i('Authentication failed', error: e, stackTrace: s);
      return false;
    }
  }

  static Future<Credentials?> load() async {
    bool authenticated = await _authenticate();
    if (!authenticated) {
      return null;
    }
    final storage = secureStorage();
    final clientId = await storage.read(key: 'comdirectClientId') ?? '';
    final clientSecret = await storage.read(key: 'comdirectClientSecret') ?? '';
    final username = await storage.read(key: 'comdirectUsername') ?? '';
    final password = await storage.read(key: 'comdirectPasssword') ?? '';
    return Credentials(
      clientId: clientId,
      clientSecret: clientSecret,
      username: username,
      password: password,
    );
  }

  Future<bool> store() async {
    bool authenticated = await _authenticate();
    if (!authenticated) {
      return false;
    }
    final storage = secureStorage();
    await storage.write(key: 'comdirectClientId', value: clientId);
    await storage.write(key: 'comdirectClientSecret', value: clientSecret);
    await storage.write(key: 'comdirectUsername', value: username);
    await storage.write(key: 'comdirectPasssword', value: password);
    return true;
  }

  Future<bool> delete() async {
    bool authenticated = await _authenticate();
    if (!authenticated) {
      return false;
    }
    final storage = secureStorage();
    await storage.delete(key: 'comdirectClientId');
    await storage.delete(key: 'comdirectClientSecret');
    await storage.delete(key: 'comdirectUsername');
    await storage.delete(key: 'comdirectPasssword');
    return true;
  }

  factory Credentials.fromJson(Map<String, dynamic> json) =>
      _$CredentialsFromJson(json);
  Map<String, dynamic> toJson() => _$CredentialsToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class CreateLoginAuthTokenReqDTO {
  final String clientId;
  final String clientSecret;
  final String grantType;
  final String username;
  final String password;

  CreateLoginAuthTokenReqDTO({
    required this.clientId,
    required this.clientSecret,
    required this.grantType,
    required this.username,
    required this.password,
  });

  factory CreateLoginAuthTokenReqDTO.fromJson(Map<String, dynamic> json) =>
      _$CreateLoginAuthTokenReqDTOFromJson(json);
  Map<String, dynamic> toJson() => _$CreateLoginAuthTokenReqDTOToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class TokenDTO {
  final String accessToken;
  final String tokenType;
  final String refreshToken;
  final int expiresIn;
  final String scope;
  final String kdnr;
  final int bpid;
  @JsonKey(name: 'kontaktId')
  final int kontaktId;

  TokenDTO({
    required this.accessToken,
    required this.tokenType,
    required this.refreshToken,
    required this.expiresIn,
    required this.scope,
    required this.kdnr,
    required this.bpid,
    required this.kontaktId,
  });

  /// Checks if the token is close to expiring.
  /// Does not guarantee that the token is still valid.
  Future<bool> needsRefresh() async {
    final storage = secureStorage();
    final tokenTimestampStr = await storage.read(
      key: 'comdirectTokenTimestamp',
    );

    if (tokenTimestampStr == null) {
      return false;
    }

    final tokenTimestamp = int.tryParse(tokenTimestampStr);
    if (tokenTimestamp == null) {
      return false;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final tokenAgeMs = now - tokenTimestamp;
    final expiresInMs = expiresIn * 1000;

    // start refreshing ~1min before expiration
    return tokenAgeMs >= expiresInMs - 60_000;
  }

  Future<void> store(int timestampMs) async {
    final storage = secureStorage();
    final tokenJson = jsonEncode(toJson());

    await storage.write(key: 'comdirectToken', value: tokenJson);
    await storage.write(
      key: 'comdirectTokenTimestamp',
      value: timestampMs.toString(),
    );
  }

  static Future<TokenDTO?> load() async {
    final storage = secureStorage();
    final tokenJson = await storage.read(key: 'comdirectToken');

    if (tokenJson == null) {
      return null;
    }

    try {
      return TokenDTO.fromJson(
        Map<String, dynamic>.from(jsonDecode(tokenJson) as Map),
      );
    } catch (e, s) {
      final log = LogService.instance?.log;
      log?.e('Bad comdirect token format. Deleting the token.', stackTrace: s);
      await delete();
      return null;
    }
  }

  static Future<void> delete() async {
    final storage = secureStorage();
    await storage.delete(key: 'comdirectToken');
    await storage.delete(key: 'comdirectTokenTimestamp');
  }

  factory TokenDTO.fromJson(Map<String, dynamic> json) =>
      _$TokenDTOFromJson(json);
  Map<String, dynamic> toJson() => _$TokenDTOToJson(this);
}

@JsonSerializable()
class ClientRequestInfoDTO {
  final ClientRequestId clientRequestId;

  ClientRequestInfoDTO({required this.clientRequestId});

  factory ClientRequestInfoDTO.fromJson(Map<String, dynamic> json) =>
      _$ClientRequestInfoDTOFromJson(json);
  Map<String, dynamic> toJson() => _$ClientRequestInfoDTOToJson(this);
}

@JsonSerializable()
class ClientRequestId {
  final String sessionId;
  final String requestId;

  ClientRequestId({required this.sessionId, required this.requestId});

  factory ClientRequestId.fromJson(Map<String, dynamic> json) =>
      _$ClientRequestIdFromJson(json);
  Map<String, dynamic> toJson() => _$ClientRequestIdToJson(this);
}

@freezed
abstract class SessionDTO with _$SessionDTO {
  const factory SessionDTO({
    required String identifier,
    required bool sessionTanActive,
    required bool activated2FA,
  }) = _SessionDTO;

  factory SessionDTO.fromJson(Map<String, dynamic> json) =>
      _$SessionDTOFromJson(json);
}

@JsonSerializable()
class TanChallengeLink {
  final String href;

  TanChallengeLink({required this.href});

  factory TanChallengeLink.fromJson(Map<String, dynamic> json) =>
      _$TanChallengeLinkFromJson(json);
  Map<String, dynamic> toJson() => _$TanChallengeLinkToJson(this);
}

@JsonSerializable()
class TanChallenge {
  final String id;
  final String typ;
  final String? challenge;
  final TanChallengeLink? link;
  final List<String> availableTypes;

  TanChallenge({
    required this.id,
    required this.typ,
    this.challenge,
    this.link,
    required this.availableTypes,
  });

  factory TanChallenge.fromJson(Map<String, dynamic> json) =>
      _$TanChallengeFromJson(json);
  Map<String, dynamic> toJson() => _$TanChallengeToJson(this);
}

@JsonSerializable()
class TanChallengeIdWrapper {
  final String id;

  TanChallengeIdWrapper({required this.id});

  factory TanChallengeIdWrapper.fromJson(Map<String, dynamic> json) =>
      _$TanChallengeIdWrapperFromJson(json);
  Map<String, dynamic> toJson() => _$TanChallengeIdWrapperToJson(this);
}

@JsonSerializable()
class AuthStatus {
  final String authenticationId;
  final String status;

  AuthStatus({required this.authenticationId, required this.status});

  factory AuthStatus.fromJson(Map<String, dynamic> json) =>
      _$AuthStatusFromJson(json);
  Map<String, dynamic> toJson() => _$AuthStatusToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class ApiAccessTokenReqDTO {
  final String clientId;
  final String clientSecret;
  final String grantType;
  final String token;

  ApiAccessTokenReqDTO({
    required this.clientId,
    required this.clientSecret,
    required this.grantType,
    required this.token,
  });

  factory ApiAccessTokenReqDTO.fromJson(Map<String, dynamic> json) =>
      _$ApiAccessTokenReqDTOFromJson(json);
  Map<String, dynamic> toJson() => _$ApiAccessTokenReqDTOToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class RefreshTokenReqDTO {
  final String clientId;
  final String clientSecret;
  final String grantType;
  final String refreshToken;

  RefreshTokenReqDTO({
    required this.clientId,
    required this.clientSecret,
    required this.grantType,
    required this.refreshToken,
  });

  factory RefreshTokenReqDTO.fromJson(Map<String, dynamic> json) =>
      _$RefreshTokenReqDTOFromJson(json);
  Map<String, dynamic> toJson() => _$RefreshTokenReqDTOToJson(this);
}

@JsonSerializable()
class Amount {
  final Decimal value;
  final String unit;

  Amount({required this.value, required this.unit});

  factory Amount.fromJson(Map<String, dynamic> json) => _$AmountFromJson(json);
  Map<String, dynamic> toJson() => _$AmountToJson(this);
}

@JsonSerializable()
class EnumText {
  final String key;
  final String text;

  EnumText({required this.key, required this.text});

  factory EnumText.fromJson(Map<String, dynamic> json) =>
      _$EnumTextFromJson(json);
  Map<String, dynamic> toJson() => _$EnumTextToJson(this);
}

@JsonSerializable()
class PageIndex {
  final int index;
  final int matches;

  PageIndex({required this.index, required this.matches});

  factory PageIndex.fromJson(Map<String, dynamic> json) =>
      _$PageIndexFromJson(json);
  Map<String, dynamic> toJson() => _$PageIndexToJson(this);
}

@JsonSerializable()
class AccountsPage {
  final PageIndex paging;
  final List<AccountBalance> values;

  AccountsPage({required this.paging, required this.values});

  factory AccountsPage.fromJson(Map<String, dynamic> json) =>
      _$AccountsPageFromJson(json);
  Map<String, dynamic> toJson() => _$AccountsPageToJson(this);
}

@JsonSerializable()
class AccountBalance {
  final ComdirectAccount account;
  final String accountId;
  final Amount balance;
  final Amount balanceEUR;
  final Amount availableCashAmount;
  final Amount availableCashAmountEUR;

  AccountBalance({
    required this.account,
    required this.accountId,
    required this.balance,
    required this.balanceEUR,
    required this.availableCashAmount,
    required this.availableCashAmountEUR,
  });

  factory AccountBalance.fromJson(Map<String, dynamic> json) =>
      _$AccountBalanceFromJson(json);
  Map<String, dynamic> toJson() => _$AccountBalanceToJson(this);
}

@JsonSerializable()
class ComdirectAccount {
  final String accountId;
  final String accountDisplayId;
  final String currency;
  final String clientId;
  final EnumText accountType;
  final String? iban;
  final String bic;
  final Amount? creditLimit;

  ComdirectAccount({
    required this.accountId,
    required this.accountDisplayId,
    required this.currency,
    required this.clientId,
    required this.accountType,
    this.iban,
    required this.bic,
    this.creditLimit,
  });

  factory ComdirectAccount.fromJson(Map<String, dynamic> json) =>
      _$ComdirectAccountFromJson(json);
  Map<String, dynamic> toJson() => _$ComdirectAccountToJson(this);
}

@JsonSerializable()
class TransactionsPage {
  final PageIndex paging;
  final AccountTransactionAggregate aggregated;
  final List<AccountTransaction> values;

  TransactionsPage({
    required this.paging,
    required this.aggregated,
    required this.values,
  });

  factory TransactionsPage.fromJson(Map<String, dynamic> json) =>
      _$TransactionsPageFromJson(json);
  Map<String, dynamic> toJson() => _$TransactionsPageToJson(this);
}

@JsonSerializable()
class AccountTransactionAggregate {
  final String accountId;
  final String? bookingDateLatestTransaction;
  final String? referenceLatestTransaction;
  final bool latestTransactionIncluded;
  final DateTime pagingTimestamp;

  AccountTransactionAggregate({
    required this.accountId,
    required this.bookingDateLatestTransaction,
    required this.referenceLatestTransaction,
    required this.latestTransactionIncluded,
    required this.pagingTimestamp,
  });

  factory AccountTransactionAggregate.fromJson(Map<String, dynamic> json) =>
      _$AccountTransactionAggregateFromJson(json);
  Map<String, dynamic> toJson() => _$AccountTransactionAggregateToJson(this);
}

@freezed
abstract class AccountTransaction with _$AccountTransaction {
  const factory AccountTransaction({
    required String bookingStatus,
    DateTime? bookingDate,
    required Amount amount,
    AccountInformation? remitter,

    // yes, the API uses "deptor" instead of "debtor" even if the docs say "debtor"
    // ignore: invalid_annotation_target
    @JsonKey(name: 'deptor') AccountInformation? debtor,

    AccountInformation? creditor,
    required String reference,
    String? endToEndReference,

    // might be a non-valid date, e.g. 20.02.2019
    required String valutaDate,

    String? directDebitCreditorId,
    String? directDebitMandateId,
    required EnumText transactionType,

    // purpose / booking text
    required String remittanceInfo,

    // false if seen by user in web
    required bool newTransaction,
  }) = _AccountTransaction;

  factory AccountTransaction.fromJson(Map<String, dynamic> json) =>
      _$AccountTransactionFromJson(json);
}

@JsonSerializable()
class AccountInformation {
  final String holderName;
  final String? iban;
  final String? bic;

  AccountInformation({required this.holderName, this.iban, this.bic});

  factory AccountInformation.fromJson(Map<String, dynamic> json) =>
      _$AccountInformationFromJson(json);
  Map<String, dynamic> toJson() => _$AccountInformationToJson(this);
}
