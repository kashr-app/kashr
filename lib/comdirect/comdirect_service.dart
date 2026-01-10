import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:jiffy/jiffy.dart';
import 'package:kashr/account/model/account.dart';
import 'package:kashr/core/associate_by.dart';
import 'package:kashr/core/model/period.dart';
import 'package:kashr/ingest/ingest.dart';
import 'package:kashr/turnover/model/turnover.dart';
import 'package:kashr/turnover/services/turnover_matching_service.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:kashr/account/cubit/account_cubit.dart';
import 'package:kashr/turnover/services/turnover_service.dart';
import 'package:meta/meta.dart';
import 'package:uuid/uuid.dart';
import 'comdirect_api.dart';
import 'comdirect_model.dart';

final _apiDateFormat = DateFormat("yyyy-MM-dd");

class ComdirectService implements DataIngestor {
  final ComdirectAPI comdirectAPI;
  final Logger log;
  final AccountCubit accountCubit;
  final TurnoverService turnoverService;
  final TurnoverMatchingService matchingService;

  ComdirectService(
    this.log, {
    required this.comdirectAPI,
    required this.accountCubit,
    required this.turnoverService,
    required this.matchingService,
  });

  @override
  Future<DataIngestResult> ingest(Period period) =>
      _fetchAccountsAndTurnovers(period);

  /// Fetches accounts and turnovers from the Comdirect API.
  /// Also automatically updates the balance for existing accounts.
  Future<DataIngestResult> _fetchAccountsAndTurnovers(Period period) async {
    try {
      final (accounts, realBalanceByAccountId) =
          await _fetchAccountsAndStoreNew(period);

      // For each api account, fetch turnovers (transactions)

      final (newIds, existingIds, turnoversById) =
          await _fetchAndUpsertTurnovers(accounts, period);

      // Assuming the real balance did not change between fetching accounts
      // and fetching the turnovers, we now can reconcile the balance based
      // on the sum of all stored turnovers to match the real balance.
      await _reconcileBalances(accounts, realBalanceByAccountId);

      final (autoMatchedCount, unmatchedCount) = await _autoMatch(
        newIds: newIds,
        existingIds: existingIds,
        turnoversById: turnoversById,
      );

      return DataIngestResult.success(
        newCount: newIds.length,
        updatedCount: existingIds.length,
        autoMatchedCount: autoMatchedCount,
        unmatchedCount: unmatchedCount,
      );
    } catch (e, s) {
      if (e is DioException) {
        if (e.response?.statusCode == 401) {
          return DataIngestResult.error(ResultStatus.unauthed);
        }
      }
      log.e('Error fetching turnovers: $e', error: e, stackTrace: s);
      return DataIngestResult.error(
        ResultStatus.otherError,
        errorMessage: 'unknown error: $e',
      );
    }
  }

  Future<
    (List<Account> accounts, Map<UuidValue, Decimal?> realBalanceByAccountId)
  >
  _fetchAccountsAndStoreNew(Period period) async {
    final uuid = Uuid();

    final accounts = <Account>[];
    final realBalanceByAccountId = <UuidValue, Decimal?>{};

    var countNew = 0;

    await accountCubit.loadAccounts();
    final existingAccountsByApiId = accountCubit.state.accountById.values
        .where((it) => it.apiId != null)
        .associateBy((it) => it.apiId);

    var index = 0;
    var total = 1;
    while (index < total) {
      // Fetch account balances
      final accountsPage = await comdirectAPI.getBalances(index: index);
      total = accountsPage.paging.matches;
      index += accountsPage.values.length;

      // Store API balances for later use
      final apiBalancesByApiId = <String, Decimal>{};
      for (final a in accountsPage.values) {
        apiBalancesByApiId[a.accountId] = a.balance.value;
      }

      for (final a in accountsPage.values) {
        final apiId = a.accountId;
        if (!existingAccountsByApiId.containsKey(apiId)) {
          final account = Account(
            id: uuid.v4obj(),
            createdAt: DateTime.now(),
            name: a.account.accountType.text,
            identifier: a.account.iban,
            apiId: apiId,
            accountType: AccountType.checking,
            syncSource: SyncSource.comdirect,
            currency: a.balance.unit,
            openingBalance: a.balance.value,
            lastSyncDate: DateTime.now(),
            isHidden: false,
          );
          await accountCubit.addAccount(account);
          accounts.add(account);
          countNew++;
          realBalanceByAccountId[account.id] = a.balance.value;
          log.i("New account stored");
        }
      }

      // Update balances for existing comdirect accounts
      if (existingAccountsByApiId.isNotEmpty) {
        for (final account in existingAccountsByApiId.values) {
          final apiId = account.apiId;
          realBalanceByAccountId[account.id] = apiBalancesByApiId[apiId];
          accounts.add(account);
        }
      }
    }
    log.i('$countNew new accounts stored successfully');
    return (accounts, realBalanceByAccountId);
  }

  Future<
    (
      Iterable<UuidValue> newIds,
      Iterable<UuidValue> existingIds,
      Map<UuidValue, Turnover> turnoversById,
    )
  >
  _fetchAndUpsertTurnovers(Iterable<Account> accounts, Period period) async {
    final uuid = Uuid();
    final turnoversById = <UuidValue, Turnover>{};
    for (final account in accounts) {
      final apiId = account.apiId;
      if (apiId == null) {
        continue;
      }

      var index = 0;
      var total = 1;
      while (index < total) {
        // Fetch transactions for each account
        final transactionsResponse = await comdirectAPI.getTransactions(
          accountId: apiId,
          minBookingDate: _apiDateFormat.format(period.startInclusive),
          maxBookingDate: _apiDateFormat.format(
            Jiffy.parseFromDateTime(
              period.endExclusive,
            ).subtract(days: 1).dateTime,
          ),
          index: index,
          pageSize: 50,
        );

        total = transactionsResponse.paging.matches;
        index += transactionsResponse.values.length;

        // Collect turnovers for this account
        for (final transaction in transactionsResponse.values) {
          final counterPartInfo = _extractCounterPart(transaction);
          final turnover = Turnover(
            id: uuid.v4obj(),
            createdAt: DateTime.now(),
            accountId: account.id,
            bookingDate: transaction.bookingDate,
            amountValue: transaction.amount.value,
            amountUnit: transaction.amount.unit,
            counterPart: counterPartInfo.name,
            counterIban: counterPartInfo.iban,
            purpose: cleanPurpose(transaction.remittanceInfo),
            apiId: transaction.reference,
            apiRaw: jsonEncode(
              // we mark all transactions as non-new here to prevent
              // future syncs from telling the user that turnovers
              // would have been updated just because the user visited
              // their bank account and saw the transaction there.
              transaction.copyWith(newTransaction: false).toJson(),
            ),
            apiTurnoverType: transaction.transactionType.key,
          );
          turnoversById[turnover.id] = turnover;
        }
      }
    }

    // we upsert in case the data changed or that our data extraction changed
    final (newIds, existingIds) = await turnoverService.upsertTurnovers(
      turnoversById.values,
    );
    log.i(
      '${turnoversById.length} turnover(s) fetched and upserted successfully.',
    );
    return (newIds, existingIds, turnoversById);
  }

  /// Extracts the counterpart name and IBAN from a transaction.
  ///
  /// First attempts to use the structured fields (remitter, creditor, debtor).
  /// If all are null (e.g., for debit card transactions), parses the remittanceInfo
  /// field to extract the merchant name from the first line (01).
  ({String? name, String? iban}) _extractCounterPart(
    AccountTransaction transaction,
  ) {
    // Try standard fields first
    final counterPart =
        transaction.remitter ?? transaction.creditor ?? transaction.debtor;

    if (counterPart != null) {
      return (name: counterPart.holderName, iban: counterPart.iban);
    }

    // Fallback: Parse remittanceInfo for card transactions
    final remittanceInfo = transaction.remittanceInfo;
    if (remittanceInfo.isEmpty || !remittanceInfo.startsWith("01")) {
      return (name: null, iban: null);
    }

    // Extract first line (01) which typically contains the merchant name
    // Format: "01<35 chars>02<35 chars>..."
    final firstLine = remittanceInfo.substring(
      2,
      37.clamp(0, remittanceInfo.length),
    );
    final merchantName = firstLine.trim();

    return (name: merchantName.isEmpty ? null : merchantName, iban: null);
  }

  /// Cleans the `purpose` field from comdirect transaction data.
  ///
  /// Each line in the original booking text is exactly 35 characters long
  /// and starts with a 2-character line number. This function removes the
  /// line numbers and normalizes the text.
  @visibleForTesting
  String cleanPurpose(String raw) {
    if (raw.isEmpty) return raw;
    if (!raw.startsWith("01")) {
      return raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    }

    final buffer = StringBuffer();

    for (int i = 0; i < raw.length; i += 37) {
      // Get the current line without line number
      final line = raw.substring(i + 2, (i + 37).clamp(0, raw.length));
      // normalize whitespace, it is intended to keep one space at start and end of the line
      var normalized = line.replaceAll(RegExp(r'\s+'), ' ');
      buffer.write(normalized);
    }

    // Combine lines and final trim
    return buffer.toString().trim();
  }

  Future<void> _reconcileBalances(
    List<Account> accounts,
    Map<UuidValue, Decimal?> realBalanceByAccountId,
  ) async {
    for (final account in accounts) {
      final apiBalance = realBalanceByAccountId[account.id];
      if (apiBalance != null) {
        log.i('Reconciling balance for account ${account.name} to $apiBalance');
        await accountCubit.syncBalanceFromReal(account, apiBalance);
      }
    }
  }

  Future<(int autoMatchedCount, int unmatchedCount)> _autoMatch({
    required final Iterable<UuidValue> newIds,
    required final Iterable<UuidValue> existingIds,
    required final Map<UuidValue, Turnover> turnoversById,
  }) async {
    // Auto-match turnovers with pending expenses
    var autoMatchedCount = 0;
    var unmatchedCount = 0;

    // newIds are always unmatched, for existingIds we need to check if they are unmatched
    final unmatchedTurnoverIds = [
      ...await turnoverService.filterUnmatched(turnoverIds: existingIds),
      ...newIds,
    ];

    for (final id in unmatchedTurnoverIds) {
      final turnover = turnoversById[id];
      if (turnover == null) {
        log.e(
          'Unexpected to not find a turnover that has been selected for matching.',
        );
        continue;
      }
      final match = await matchingService.autoMatchPerfectTagTurnover(
        turnover,
        isGuaranteedToBeUnmatched:
            true, // because we filtered in batch which are unmatched
      );
      final matched = null != match;
      if (matched) {
        autoMatchedCount++;
      } else {
        unmatchedCount++;
      }
    }
    log.i(
      'Auto-matched $autoMatchedCount turnovers, $unmatchedCount remain unmatched',
    );
    return (autoMatchedCount, unmatchedCount);
  }
}
