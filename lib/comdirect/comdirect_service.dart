import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:finanalyzer/account/model/account.dart';
import 'package:finanalyzer/turnover/model/turnover.dart';
import 'package:finanalyzer/turnover/services/turnover_matching_service.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:finanalyzer/account/cubit/account_cubit.dart';
import 'package:finanalyzer/turnover/cubit/turnover_cubit.dart';
import 'package:uuid/uuid.dart';
import 'comdirect_api.dart';

const uuid = Uuid();
final apiDateFormat = DateFormat("yyyy-MM-dd");

enum ResultStatus { success, unauthed, otherError }

class FetchComdirectDataResult {
  ResultStatus status;
  String? errorMessage;
  int autoMatchedCount;
  List<Turnover> unmatchedTurnovers;
  FetchComdirectDataResult({
    required this.status,
    this.errorMessage,
    this.autoMatchedCount = 0,
    this.unmatchedTurnovers = const [],
  });
}

class ComdirectService {
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

  /// Fetches accounts and turnovers from the Comdirect API.
  /// Also automatically updates the balance for existing accounts.
  Future<FetchComdirectDataResult> fetchAccountsAndTurnovers({
    required DateTime minBookingDate,
    required DateTime maxBookingDate,
  }) async {
    try {
      // Fetch account balances
      final accountsPage = await comdirectAPI.getBalances();
      log.i('Accounts fetched successfully');
      await accountCubit.loadAccounts();
      final allAccounts = [
        ...accountCubit.state.accounts,
        ...accountCubit.state.hiddenAccounts,
      ];
      final existingAccountsByApiId = {
        for (final a in allAccounts)
          if (a.apiId != null) a.apiId: a,
      };

      // Store API balances for later use
      final apiBalancesByApiId = <String, Decimal>{};
      for (final a in accountsPage.values) {
        apiBalancesByApiId[a.accountId] = a.balance.value;
      }

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
      final accounts = [
        ...accountCubit.state.accounts,
        ...accountCubit.state.hiddenAccounts,
      ];
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
            minBookingDate: apiDateFormat.format(minBookingDate),
            maxBookingDate: apiDateFormat.format(maxBookingDate),
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
              accountId: account.id!,
              bookingDate: transaction.bookingDate,
              amountValue: transaction.amount.value,
              amountUnit: transaction.amount.unit,
              counterPart: counterPart?.holderName,
              purpose: transaction.remittanceInfo,
              apiId: transaction.reference,
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
          final matched = await matchingService!.autoMatchPerfect(turnover);
          if (matched) {
            autoMatchedCount++;
            log.i('Auto-matched turnover: ${turnover.purpose}');
          } else {
            // Check if there are any pending matches for this turnover
            final matches = await matchingService!.findMatches(turnover);
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
          log.i(
            'Updating balance for account ${account.name} to $apiBalance',
          );
          await accountCubit.updateBalanceFromReal(account, apiBalance);
        }
      }
      log.i('Account balances updated successfully');

      return FetchComdirectDataResult(
        status: ResultStatus.success,
        autoMatchedCount: autoMatchedCount,
        unmatchedTurnovers: unmatchedTurnovers,
      );
    } catch (e) {
      if (e is DioException) {
        if (e.response?.statusCode == 401) {
          return FetchComdirectDataResult(status: ResultStatus.unauthed);
        }
      }
      log.e('Error fetching turnovers: $e', error: e);
      return FetchComdirectDataResult(
        status: ResultStatus.otherError,
        errorMessage: 'unknown error',
      );
    }
  }
}
