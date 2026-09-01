import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kashr/account/cubit/account_cubit.dart';
import 'package:kashr/account/model/account.dart';
import 'package:kashr/comdirect/comdirect_api.dart';
import 'package:kashr/comdirect/comdirect_model.dart';
import 'package:kashr/comdirect/comdirect_service.dart';
import 'package:kashr/core/model/booking_date.dart';
import 'package:kashr/ingest/download_progress.dart';
import 'package:kashr/ingest/download_range.dart';
import 'package:kashr/ingest/ingest.dart';
import 'package:uuid/uuid.dart';

import '../helpers/test_app.dart';
import '../helpers/test_database.dart';

final _uuid = Uuid();

Amount _amount(String value) =>
    Amount(value: Decimal.parse(value), unit: 'EUR');

/// One page of the bank's account list.
AccountsPage _balancesPage({
  required int matches,
  required List<({String apiId, String balance})> accounts,
}) => AccountsPage(
  paging: PageIndex(index: 0, matches: matches),
  values: [
    for (final it in accounts)
      AccountBalance(
        account: ComdirectAccount(
          accountId: it.apiId,
          accountDisplayId: it.apiId,
          currency: 'EUR',
          clientId: 'client',
          accountType: EnumText(key: 'CHECKING', text: 'Girokonto'),
          iban: 'DE00${it.apiId}',
          bic: 'BIC',
        ),
        accountId: it.apiId,
        balance: _amount(it.balance),
        balanceEUR: _amount(it.balance),
        availableCashAmount: _amount(it.balance),
        availableCashAmountEUR: _amount(it.balance),
      ),
  ],
);

/// A page of transactions carrying none, however many the bank claims.
TransactionsPage _emptyTransactionsPage(String apiId, {required int matches}) =>
    TransactionsPage(
      paging: PageIndex(index: 0, matches: matches),
      aggregated: AccountTransactionAggregate(
        accountId: apiId,
        bookingDateLatestTransaction: null,
        referenceLatestTransaction: null,
        latestTransactionIncluded: true,
        pagingTimestamp: DateTime(2026, 1, 1),
      ),
      values: const [],
    );

/// A bank that hands out prepared pages and counts what was asked of it.
///
/// Both endpoints give up rather than answer forever: a loop that stops
/// advancing should fail the test that provoked it, not hang the suite.
class _FakeComdirectAPI implements ComdirectAPI {
  final List<AccountsPage> balancePages;
  final int transactionMatches;

  int balanceCalls = 0;
  final Map<String, int> transactionCallsByApiId = {};

  _FakeComdirectAPI(this.balancePages, {this.transactionMatches = 0});

  @override
  Future<AccountsPage> getBalances({int index = 0, int pageSize = 20}) async {
    balanceCalls++;
    if (balanceCalls > balancePages.length + 2) {
      throw StateError('getBalances asked $balanceCalls times, it is looping');
    }
    return balancePages[(balanceCalls - 1).clamp(0, balancePages.length - 1)];
  }

  @override
  Future<TransactionsPage> getTransactions({
    required String accountId,
    required String minBookingDate,
    required String maxBookingDate,
    String transactionState = 'BOOKED',
    int index = 0,
    int pageSize = 20,
  }) async {
    final calls = (transactionCallsByApiId[accountId] ?? 0) + 1;
    transactionCallsByApiId[accountId] = calls;
    if (calls > 3) {
      throw StateError('getTransactions for $accountId is looping');
    }
    return _emptyTransactionsPage(accountId, matches: transactionMatches);
  }
}

void main() {
  useInMemoryDatabase();

  late TestApp app;
  late AccountCubit accountCubit;

  setUp(() {
    app = TestApp();
    addTearDown(app.dispose);
    accountCubit = AccountCubit(
      app.accountRepository,
      app.balanceService,
      app.turnoverRepository,
      app.log,
    );
    addTearDown(accountCubit.close);
  });

  Future<Account> givenSyncedAccount(String apiId, {String opening = '0'}) =>
      app.accountRepository.createAccount(
        Account(
          id: _uuid.v4obj(),
          createdAt: DateTime(2020, 1, 1),
          name: 'Girokonto',
          apiId: apiId,
          accountType: AccountType.checking,
          syncSource: SyncSource.comdirect,
          currency: 'EUR',
          openingBalance: Decimal.parse(opening),
          isHidden: false,
        ),
      );

  Future<DataIngestResult> ingest(_FakeComdirectAPI api) {
    final service = ComdirectService(
      app.log,
      comdirectAPI: api,
      accountCubit: accountCubit,
      turnoverService: app.turnoverService,
      matchingService: app.matchingService,
    );
    final today = BookingDate.today();
    return service.ingest(
      DownloadRequest.upTo(
        endInclusive: today,
        startInclusive: today.addDays(-30),
      ),
      DownloadCancellation(),
      DownloadProgressSink.discard(),
    );
  }

  test('fetches a known account once however many pages list it', () async {
    final existing = await givenSyncedAccount('A1');
    final api = _FakeComdirectAPI([
      _balancesPage(matches: 2, accounts: [(apiId: 'A1', balance: '500')]),
      _balancesPage(matches: 2, accounts: [(apiId: 'A2', balance: '20')]),
    ]);

    final result = await ingest(api);

    expect(api.balanceCalls, 2);
    expect(api.transactionCallsByApiId['A1'], 1);
    expect(
      result.downloadedAccountIds,
      hasLength(result.downloadedAccountIds.toSet().length),
    );
    expect(result.downloadedAccountIds, contains(existing.id));
  });

  test('keeps a balance that only the first page carried', () async {
    final existing = await givenSyncedAccount('A1');
    final api = _FakeComdirectAPI([
      _balancesPage(matches: 2, accounts: [(apiId: 'A1', balance: '500')]),
      _balancesPage(matches: 2, accounts: [(apiId: 'A2', balance: '20')]),
    ]);

    await ingest(api);

    // With no turnovers the reconciliation moves the opening balance to
    // whatever the bank said. A balance the later page dropped would leave
    // it where it started.
    final reconciled = await app.accountRepository.getAccountById(existing.id);
    expect(reconciled?.openingBalance, Decimal.parse('500'));
  });

  test('stops asking for accounts when a page comes back empty', () async {
    final api = _FakeComdirectAPI([
      _balancesPage(matches: 5, accounts: const []),
    ]);

    await ingest(api);

    expect(api.balanceCalls, 1);
  });

  test('stops asking for transactions when a page comes back empty', () async {
    await givenSyncedAccount('A1');
    final api = _FakeComdirectAPI([
      _balancesPage(matches: 1, accounts: [(apiId: 'A1', balance: '500')]),
    ], transactionMatches: 5);

    await ingest(api);

    expect(api.transactionCallsByApiId['A1'], 1);
  });
}
