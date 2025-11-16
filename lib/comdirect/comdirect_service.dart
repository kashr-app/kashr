import 'package:finanalyzer/model/account.dart';
import 'package:finanalyzer/model/turnover.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:finanalyzer/model/account_cubit.dart';
import 'package:finanalyzer/turnover/cubit/turnover_cubit.dart';
import 'package:uuid/uuid.dart';
import 'comdirect_api.dart';

const uuid = Uuid();
final apiDateFormat = DateFormat("yyyy-MM-dd");

class ComdirectService {
  final ComdirectAPI comdirectAPI;
  final log = Logger();
  final AccountCubit accountCubit;
  final TurnoverCubit turnoverCubit;

  ComdirectService({
    required this.comdirectAPI,
    required this.accountCubit,
    required this.turnoverCubit,
  });

  /// Fetches accounts and turnovers from the Comdirect API.
  Future<void> fetchAccountsAndTurnovers({
    required DateTime minBookingDate,
    required DateTime maxBookingDate,
  }) async {
    try {
      // Fetch account balances
      final accountsPage = await comdirectAPI.getBalances();
      log.i('Accounts fetched successfully');
      final existingAccounts = (await accountCubit.loadAccounts());
      final existingAccountsByApiId = {
        for (final a in existingAccounts)
          if (a.apiId != null) a.apiId: a,
      };

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
          );
          await accountCubit.addAccount(account);
          log.i("New account stored");
        }
        log.i('Account displayId: ${a.account.accountDisplayId}');
        log.i("Type: ${a.account.accountType}");
        log.i("IBAN ${a.account.iban}");
        log.i('Balance: ${a.balance.value} ${a.balance.unit}');
      }

      // For each account, fetch turnovers (transactions)
      final turnovers = <Turnover>[];
      final accounts = accountCubit.state;
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

      await turnoverCubit.storeNonExisting(turnovers);
      log.i('Turnovers fetched and stored successfully');
    } catch (e) {
      log.e('Error fetching turnovers: $e', error: e);
      throw Exception('Failed to fetch turnovers');
    }
  }
}
