import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:finanalyzer/account/model/account.dart';
import 'package:finanalyzer/ingest/ingest.dart';
import 'package:finanalyzer/turnover/model/turnover.dart';
import 'package:finanalyzer/turnover/services/turnover_matching_service.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:finanalyzer/account/cubit/account_cubit.dart';
import 'package:finanalyzer/turnover/cubit/turnover_cubit.dart';
import 'package:meta/meta.dart';
import 'package:uuid/uuid.dart';
import 'comdirect_api.dart';
import 'comdirect_model.dart';

final _apiDateFormat = DateFormat("yyyy-MM-dd");

class ComdirectService implements DataIngestor {
  final ComdirectAPI comdirectAPI;
  final log = Logger();
  final AccountCubit accountCubit;
  final TurnoverCubit turnoverCubit;
  final TurnoverMatchingService matchingService;

  ComdirectService({
    required this.comdirectAPI,
    required this.accountCubit,
    required this.turnoverCubit,
    required this.matchingService,
  });

  @override
  Future<DataIngestResult> ingest({
    required DateTime minBookingDate,
    required DateTime maxBookingDate,
  }) => _fetchAccountsAndTurnovers(
    minBookingDate: minBookingDate,
    maxBookingDate: maxBookingDate,
  );

  /// Fetches accounts and turnovers from the Comdirect API.
  /// Also automatically updates the balance for existing accounts.
  Future<DataIngestResult> _fetchAccountsAndTurnovers({
    required DateTime minBookingDate,
    required DateTime maxBookingDate,
  }) async {
    try {
      // Fetch account balances
      final accountsPage = await comdirectAPI.getBalances();
      log.i('Accounts fetched successfully');
      await accountCubit.loadAccounts();
      final allAccounts = accountCubit.state.accountById.values;

      final existingAccountsByApiId = {
        for (final a in allAccounts)
          if (a.apiId != null) a.apiId: a,
      };

      // Store API balances for later use
      final apiBalancesByApiId = <String, Decimal>{};
      for (final a in accountsPage.values) {
        apiBalancesByApiId[a.accountId] = a.balance.value;
      }

      final uuid = Uuid();

      for (final a in accountsPage.values) {
        final apiId = a.accountId;
        if (!existingAccountsByApiId.containsKey(apiId)) {
          log.d("Sotring new account");
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
            openingBalanceDate: DateTime.now(),
            isHidden: false,
          );
          await accountCubit.addAccount(account);
          log.i("New account stored");
        }
      }

      // Update balances for existing comdirect accounts
      if (existingAccountsByApiId.isNotEmpty) {
        var count = 0;
        for (final account in existingAccountsByApiId.values) {
          final apiId = account.apiId;
          if (apiId != null && apiBalancesByApiId.containsKey(apiId)) {
            final apiBalance = apiBalancesByApiId[apiId]!;
            log.i(
              'Updating balance for account ${account.name} to $apiBalance',
            );
            await accountCubit.updateBalanceFromReal(account, apiBalance);
            count++;
          }
        }
        log.i('$count account balance(s) updated successfully');
      }
      // For each account, fetch turnovers (transactions)
      final turnoversById = <UuidValue, Turnover>{};
      final accounts = accountCubit.state.accountById.values;

      for (final account in accounts) {
        final apiId = account.apiId;
        if (apiId == null) {
          continue;
        }
        var pageIndex = 0;
        var pageCount = 1;
        const pageSize = 50;

        while (pageIndex < pageCount) {
          // Fetch transactions for each account
          final transactionsResponse = await comdirectAPI.getTransactions(
            accountId: apiId,
            minBookingDate: _apiDateFormat.format(minBookingDate),
            maxBookingDate: _apiDateFormat.format(maxBookingDate),
            pageElementIndex: pageIndex * pageSize,
            pageSize: pageSize,
          );

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
              apiRaw: jsonEncode(transaction.toJson()),
              apiTurnoverType: transaction.transactionType.key,
            );
            turnoversById[turnover.id] = turnover;
          }

          pageCount = (transactionsResponse.paging.matches / pageSize).ceil();
          pageIndex++;
        }
      }

      // we upsert in case the data changed or that our data extraction changed
      final (newIds, existingIds) = await turnoverCubit.upsertTurnovers(
        turnoversById.values,
      );
      log.i(
        '${turnoversById.length} turnover(s) fetched and upserted successfully.',
      );

      // Auto-match turnovers with pending expenses
      var autoMatchedCount = 0;
      var unmatchedCount = 0;

      // newIds are always unmatched, for existingIds we need to check if they are unmatched
      final unmatchedTurnoverIds = [
        ...await turnoverCubit.filterUnmatched(turnoverIds: existingIds),
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
}
