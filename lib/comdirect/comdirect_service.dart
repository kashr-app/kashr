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
import 'package:uuid/uuid.dart';
import 'comdirect_api.dart';

final _apiDateFormat = DateFormat("yyyy-MM-dd");

class ComdirectService implements DataIngestor {
  final ComdirectAPI comdirectAPI;
  final log = Logger();
  final AccountCubit accountCubit;
  final TurnoverCubit turnoverCubit;
  final TurnoverMatchingService? matchingService;

  ComdirectService({
    required this.comdirectAPI,
    required this.accountCubit,
    required this.turnoverCubit,
    this.matchingService,
  });

  @override
  Future<DataIngestResult> ingest({
    required DateTime minBookingDate,
    required DateTime maxBookingDate,
  }) async {
    return _fetchAccountsAndTurnovers(
      minBookingDate: minBookingDate,
      maxBookingDate: maxBookingDate,
    );
  }

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
          log.i("New account ... storing");
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
        log.i('Account displayId: ${a.account.accountDisplayId}');
        log.i("Type: ${a.account.accountType.toJson()}");
        log.i("IBAN ${a.account.iban}");
        log.i('Balance: ${a.balance.value} ${a.balance.unit}');
      }

      // For each account, fetch turnovers (transactions)
      final turnovers = <Turnover>[];
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
            final counterPart =
                transaction.remitter ??
                transaction.creditor ??
                transaction.debtor;
            final turnover = Turnover(
              id: uuid.v4obj(),
              createdAt: DateTime.now(),
              accountId: account.id,
              bookingDate: transaction.bookingDate,
              amountValue: transaction.amount.value,
              amountUnit: transaction.amount.unit,
              counterPart: counterPart?.holderName,
              counterIban: counterPart?.iban,
              purpose: _cleanPurpose(transaction.remittanceInfo),
              apiId: transaction.reference,
              apiRaw: jsonEncode(transaction.toJson()),
              apiTurnoverType: transaction.transactionType.key,
            );
            turnovers.add(turnover);
          }

          pageCount = (transactionsResponse.paging.matches / pageSize).ceil();
          pageIndex++;
        }
      }

      await turnoverCubit.upsertTurnovers(turnovers);
      log.i('Turnovers fetched and upserted successfully');

      // Auto-match turnovers with pending expenses
      var autoMatchedCount = 0;
      final unmatchedTurnovers = <Turnover>[];
      if (matchingService != null) {
        for (final turnover in turnovers) {
          final matches = await matchingService!.findMatchesForTurnover(
            turnover,
          );
          final matched = await matchingService!.autoConfirmPerfectMatch(
            matches,
          );
          if (matched) {
            autoMatchedCount++;
            log.i('Auto-matched turnover: ${turnover.purpose}');
          } else {
            if (matches.isNotEmpty) {
              unmatchedTurnovers.add(turnover);
            }
          }
        }
        log.i('Auto-matched $autoMatchedCount turnovers');
      }

      // Update balances for existing comdirect accounts
      for (final account in existingAccountsByApiId.values) {
        final apiId = account.apiId;
        if (apiId != null && apiBalancesByApiId.containsKey(apiId)) {
          final apiBalance = apiBalancesByApiId[apiId]!;
          log.i('Updating balance for account ${account.name} to $apiBalance');
          await accountCubit.updateBalanceFromReal(account, apiBalance);
        }
      }
      log.i('Account balances updated successfully');

      return DataIngestResult(
        status: ResultStatus.success,
        autoMatchedCount: autoMatchedCount,
        unmatchedTurnovers: unmatchedTurnovers,
      );
    } catch (e) {
      if (e is DioException) {
        if (e.response?.statusCode == 401) {
          return DataIngestResult(status: ResultStatus.unauthed);
        }
      }
      log.e('Error fetching turnovers: $e', error: e);
      return DataIngestResult(
        status: ResultStatus.otherError,
        errorMessage: 'unknown error: $e',
      );
    }
  }

  /// Cleans the `purpose` field from comdirect transaction data.
  ///
  /// Since the upstream data format is ambiguous by design, this
  /// implementation is best-effort and may (in rare cases) remove or alter
  /// numeric content that resembles segment markers.
  ///
  /// comdirect embeds MT940/SEPA-style segment numbers (01, 02, 03, …) directly
  /// into the reference text. These appear even in the middle of words and are
  /// not part of the actual remittance information.
  ///
  /// This function scans the string, detects true segment numbers based on the
  /// expected sequential order (01 → 02 → 03 …), and removes them while keeping
  /// all real numeric content intact (dates, amounts, IDs, article numbers, etc.).
  String _cleanPurpose(String raw) {
    final buffer = StringBuffer();
    int i = 0;
    int expectedSegment = 1;

    while (i < raw.length) {
      if (i + 2 <= raw.length) {
        final maybe = raw.substring(i, i + 2);

        final num = int.tryParse(maybe);

        if (num != null && num >= 1 && num <= 99) {
          if (num == expectedSegment) {
            // skip sequence number
            expectedSegment++;
            i += 2;
            continue;
          }
        }
      }

      // not a sequence number
      buffer.write(raw[i]);
      i++;
    }

    // Whitespace normalisieren
    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
