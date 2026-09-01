import 'package:decimal/decimal.dart';
import 'package:kashr/account/model/account.dart';
import 'package:kashr/account/model/account_repository.dart';
import 'package:kashr/account/services/balance_calculation_service.dart';
import 'package:kashr/logging/services/log_service.dart';
import 'package:kashr/turnover/model/tag.dart';
import 'package:kashr/turnover/model/tag_repository.dart';
import 'package:kashr/turnover/model/tag_turnover.dart';
import 'package:kashr/turnover/model/tag_turnover_repository.dart';
import 'package:kashr/turnover/model/transfer_repository.dart';
import 'package:kashr/turnover/model/turnover.dart';
import 'package:kashr/turnover/model/turnover_repository.dart';
import 'package:kashr/turnover/services/turnover_matching_service.dart';
import 'package:kashr/turnover/services/turnover_service.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

final _uuid = Uuid();

final _now = DateTime.now();

/// The month the cubits pick for themselves.
///
/// `AccountCubit` projects to the end of `DateTime.now()`'s month and
/// `DashboardCubit` opens on `Period.now(...)`. Neither takes a clock, so a
/// test that wants a booking on the last day of "this month" has to read the
/// same clock instead of a frozen literal.
final midThisMonth = DateTime(_now.year, _now.month, 15);
final lastDayOfThisMonth = DateTime(_now.year, _now.month + 1, 0);

/// The production object graph without the widgets, over whatever database
/// [DatabaseHelper] currently holds.
///
/// Mirrors `TurnoverModule` and `AccountModule`.
class TestApp {
  final Logger log = LogService.instance!.log;

  final accountRepository = AccountRepository();
  final turnoverRepository = TurnoverRepository();
  final transferRepository = TransferRepository();

  late final tagRepository = TagRepository(log);
  late final tagTurnoverRepository = TagTurnoverRepository(log);

  late final turnoverService = TurnoverService(
    turnoverRepository,
    tagTurnoverRepository,
    log,
  );
  late final balanceService = BalanceCalculationService(
    turnoverRepository,
    tagTurnoverRepository,
  );
  late final matchingService = TurnoverMatchingService(
    tagTurnoverRepository,
    turnoverRepository,
    log,
  );

  void dispose() {
    turnoverRepository.dispose();
    tagRepository.dispose();
    tagTurnoverRepository.dispose();
    transferRepository.dispose();
  }

  // Writes go through the repositories on purpose: the bug under test lives in
  // the gap between how a booking date is written and how it is queried, so a
  // fixture writing its own SQL could hide exactly that.

  Future<Account> givenAccount({String openingBalance = '0'}) async {
    final account = Account(
      id: _uuid.v4obj(),
      createdAt: DateTime(2020, 1, 1),
      name: 'Checking',
      accountType: AccountType.checking,
      currency: 'EUR',
      openingBalance: Decimal.parse(openingBalance),
      isHidden: false,
    );
    return accountRepository.createAccount(account);
  }

  Future<Tag> givenTag({String name = 'Groceries', TagSemantic? semantic}) async {
    final tag = Tag(id: _uuid.v4obj(), name: name, semantic: semantic);
    await tagRepository.createTag(tag);
    return tag;
  }

  Future<Turnover> givenTurnover(
    Account account, {
    required DateTime bookedOn,
    required String amount,
  }) async {
    final turnover = Turnover(
      id: _uuid.v4obj(),
      createdAt: DateTime(2020, 1, 1),
      accountId: account.id,
      bookingDate: bookedOn,
      amountValue: Decimal.parse(amount),
      amountUnit: 'EUR',
      purpose: 'Turnover',
    );
    await turnoverRepository.createTurnover(turnover);
    return turnover;
  }

  Future<TagTurnover> givenTagTurnover(
    Account account, {
    required Tag tag,
    required DateTime bookedOn,
    required String amount,
    Turnover? turnover,
  }) async {
    final tagTurnover = TagTurnover(
      id: _uuid.v4obj(),
      turnoverId: turnover?.id,
      tagId: tag.id,
      amountValue: Decimal.parse(amount),
      amountUnit: 'EUR',
      createdAt: DateTime(2020, 1, 1),
      bookingDate: bookedOn,
      accountId: account.id,
    );
    await tagTurnoverRepository.createTagTurnover(tagTurnover);
    return tagTurnover;
  }

  /// A planned expense that nothing has matched yet.
  Future<TagTurnover> givenPending(
    Account account, {
    required Tag tag,
    required DateTime bookedOn,
    required String amount,
  }) => givenTagTurnover(account, tag: tag, bookedOn: bookedOn, amount: amount);
}
