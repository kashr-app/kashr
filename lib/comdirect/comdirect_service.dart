import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:kashr/account/model/account.dart';
import 'package:kashr/core/associate_by.dart';
import 'package:kashr/core/model/booking_date.dart';
import 'package:kashr/ingest/download_progress.dart';
import 'package:kashr/ingest/download_range.dart';
import 'package:kashr/ingest/ingest.dart';
import 'package:kashr/turnover/model/turnover.dart';
import 'package:kashr/turnover/services/turnover_matching_service.dart';
import 'package:logger/logger.dart';
import 'package:kashr/account/cubit/account_cubit.dart';
import 'package:kashr/turnover/services/turnover_service.dart';
import 'package:meta/meta.dart';
import 'package:uuid/uuid.dart';
import 'comdirect_api.dart';
import 'comdirect_model.dart';

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
  Future<DataIngestResult> ingest(
    DownloadRequest request,
    DownloadCancellation cancellation,
    DownloadProgressSink progress,
  ) => _fetchAccountsAndTurnovers(request, cancellation, progress);

  /// Fetches accounts and turnovers from the Comdirect API.
  /// Also automatically updates the balance for existing accounts.
  ///
  /// [cancellation] is checked while fetching only. Once the turnovers are
  /// being written, the run finishes: the balance reconciliation that
  /// follows is what makes them consistent.
  Future<DataIngestResult> _fetchAccountsAndTurnovers(
    DownloadRequest request,
    DownloadCancellation cancellation,
    DownloadProgressSink progress,
  ) async {
    try {
      // Said before the first database read, so the sheet has a sentence to
      // show without waiting on anything.
      progress.report(const DownloadProgress.findingAccounts());

      final (accounts, realBalanceByAccountId) =
          await _fetchAccountsAndStoreNew(cancellation, progress);

      // Accounts that have never been downloaded - including the ones just
      // discovered - start where the oldest known account already is, so they
      // land with comparable history without asking the user again.
      final startInclusiveWithoutCursor = oldestDownloadCursor(
        accountCubit.state.accountById.values,
      );

      // For each api account, fetch turnovers (transactions)

      final (
        newIds,
        existingIds,
        turnoversById,
      ) = await _fetchAndUpsertTurnovers(
        accounts,
        request,
        startInclusiveWithoutCursor,
        cancellation,
        progress,
      );

      // Assuming the real balance did not change between fetching accounts
      // and fetching the turnovers, we now can reconcile the balance based
      // on the sum of all stored turnovers to match the real balance.
      await _reconcileBalances(accounts, realBalanceByAccountId, progress);

      final (autoMatchedCount, unmatchedCount) = await _autoMatch(
        newIds: newIds,
        existingIds: existingIds,
        turnoversById: turnoversById,
        progress: progress,
      );

      return DataIngestResult.success(
        newCount: newIds.length,
        updatedCount: existingIds.length,
        autoMatchedCount: autoMatchedCount,
        unmatchedCount: unmatchedCount,
        downloadedAccountIds: [
          for (final account in accounts)
            if (account.apiId != null) account.id,
        ],
      );
    } on DownloadCancelledException {
      log.i('Download stopped before any turnover was written.');
      rethrow;
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
  _fetchAccountsAndStoreNew(
    DownloadCancellation cancellation,
    DownloadProgressSink progress,
  ) async {
    final uuid = Uuid();

    final accounts = <Account>[];
    final realBalanceByAccountId = <UuidValue, Decimal?>{};

    var countNew = 0;

    await accountCubit.loadAccounts();
    final existingAccountsByApiId = accountCubit.state.accountById.values
        .where((it) => it.apiId != null)
        .associateBy((it) => it.apiId);

    // Collected across every page, because the balances of the accounts the
    // app already knows are only read once the last page has been seen.
    final apiBalancesByApiId = <String, Decimal>{};

    var index = 0;
    var total = 1;
    while (index < total) {
      // Stopping here can leave accounts from earlier pages stored. They are
      // matched by apiId next time, so the run simply picks them up again.
      cancellation.throwIfCancelled();

      // Fetch account balances
      final accountsPage = await comdirectAPI.getBalances(index: index);
      total = accountsPage.paging.matches;
      index += accountsPage.values.length;

      // A page with nothing on it does not move `index`, so without this the
      // loop would keep asking the bank for it.
      if (accountsPage.values.isEmpty) break;

      // Reported after the response, never before: `total` starts at the
      // sentinel 1, and saying '1 of 1' up front would be a number the run
      // has not learned yet.
      progress.report(
        DownloadProgress.findingAccounts(done: index, total: total),
      );

      // Store API balances for later use
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
            isHidden: false,
          );
          await accountCubit.addAccount(account);
          accounts.add(account);
          countNew++;
          realBalanceByAccountId[account.id] = a.balance.value;
          log.i("New account stored");
        }
      }
    }

    // After the loop rather than inside it. An account the app already knows
    // belongs to the run once, however many pages the bank needed to list
    // them, and its balance is only complete once every page has been seen -
    // in here it was overwritten with null on every page that left it out.
    for (final account in existingAccountsByApiId.values) {
      realBalanceByAccountId[account.id] = apiBalancesByApiId[account.apiId];
      accounts.add(account);
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
  _fetchAndUpsertTurnovers(
    Iterable<Account> accounts,
    DownloadRequest request,
    BookingDate? startInclusiveWithoutCursor,
    DownloadCancellation cancellation,
    DownloadProgressSink progress,
  ) async {
    final uuid = Uuid();
    final turnoversById = <UuidValue, Turnover>{};

    // Settled up front so that 'account 2 of 3' counts the accounts that are
    // actually going to be fetched. Skipping them inside the loop instead
    // would stall the number wherever manual and synced accounts are mixed.
    final fetchable = [
      for (final account in accounts)
        if (account.apiId case final apiId?) (account: account, apiId: apiId),
    ];

    for (var subject = 0; subject < fetchable.length; subject++) {
      final (:account, :apiId) = fetchable[subject];

      final startInclusive = startInclusiveFor(
        account,
        request: request,
        startInclusiveWithoutCursor: startInclusiveWithoutCursor,
      );

      // Built once per account rather than once per page, so that two
      // reports of the same window compare equal and the sink can drop the
      // repeat.
      final window = DownloadRange(
        startInclusive: startInclusive,
        endInclusive: request.endInclusive,
      );
      DownloadProgress progressAt(int done, int? total) =>
          DownloadProgress.fetching(
            subject: account.name,
            subjectIndex: subject + 1,
            subjectCount: fetchable.length,
            window: window,
            done: done,
            total: total,
          );

      var index = 0;
      // Null until the bank says, rather than a sentinel of 1: the sheet
      // shows the total, and a made-up one would be on screen for the whole
      // first page.
      int? total;
      while (total == null || index < total) {
        // Everything fetched so far is still only in memory, so stopping
        // here writes nothing at all.
        cancellation.throwIfCancelled();

        // Reported before the request as well as after it, so the wait for a
        // page is attributed to the account it belongs to.
        progress.report(progressAt(index, total));

        // Fetch transactions for each account
        final transactionsResponse = await comdirectAPI.getTransactions(
          accountId: apiId,
          minBookingDate: startInclusive.iso,
          maxBookingDate: request.endInclusive.iso,
          index: index,
          pageSize: 50,
        );

        total = transactionsResponse.paging.matches;
        index += transactionsResponse.values.length;

        // A page with nothing on it does not move `index`, so without this
        // the loop would keep asking the bank for it.
        if (transactionsResponse.values.isEmpty) break;

        // Without this the last page of each account never reaches the
        // screen: the next thing reported is already the next account.
        progress.report(progressAt(index, total));

        // Collect turnovers for this account
        for (final transaction in transactionsResponse.values) {
          final counterPartInfo = _extractCounterPart(transaction);
          final turnover = Turnover(
            id: uuid.v4obj(),
            createdAt: DateTime.now(),
            accountId: account.id,
            bookingDate: switch (transaction.bookingDate) {
              final it? => BookingDate.on(it),
              null => null,
            },
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

    // Thousands of rows through the upsert is seconds in which the sheet
    // would otherwise still be claiming to download.
    progress.report(DownloadProgress.saving(total: turnoversById.length));

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
    DownloadProgressSink progress,
  ) async {
    for (final account in accounts) {
      final apiBalance = realBalanceByAccountId[account.id];
      if (apiBalance != null) {
        // Still saving as far as the user is concerned; a phase of its own
        // would name a step only this app cares about.
        progress.report(DownloadProgress.saving(subject: account.name));
        log.i('Reconciling balance for account ${account.name} to $apiBalance');
        await accountCubit.syncBalanceFromReal(
          account,
          apiBalance,
          // A download is not a manual balance check, and the download
          // cursor - not a wall clock stamp - records how current the data is.
          recordManualCheck: false,
        );
      }
    }
  }

  Future<(int autoMatchedCount, int unmatchedCount)> _autoMatch({
    required final Iterable<UuidValue> newIds,
    required final Iterable<UuidValue> existingIds,
    required final Map<UuidValue, Turnover> turnoversById,
    required final DownloadProgressSink progress,
  }) async {
    // Auto-match turnovers with pending expenses
    var autoMatchedCount = 0;
    var unmatchedCount = 0;

    // A change of phase, so it is never held back: it is what stops the
    // sheet saying 'saving' while the batch query below runs.
    progress.report(const DownloadProgress.matching());

    // newIds are always unmatched, for existingIds we need to check if they are unmatched
    final unmatchedTurnoverIds = [
      ...await turnoverService.filterUnmatched(turnoverIds: existingIds),
      ...newIds,
    ];

    var handled = 0;
    for (final id in unmatchedTurnoverIds) {
      // Fires once per turnover, thousands of times on a first download.
      // The sink is what turns that into a few repaints a second.
      progress.report(
        DownloadProgress.matching(
          done: handled++,
          total: unmatchedTurnoverIds.length,
        ),
      );

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
