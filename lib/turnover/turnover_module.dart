import 'package:finanalyzer/core/module.dart';
import 'package:finanalyzer/turnover/cubit/tag_cubit.dart';
import 'package:finanalyzer/turnover/services/transfer_service.dart';
import 'package:finanalyzer/turnover/services/turnover_service.dart';
import 'package:finanalyzer/turnover/listeners/tag_turnover_tag_listener.dart';
import 'package:finanalyzer/turnover/model/recent_search_repository.dart';
import 'package:finanalyzer/turnover/model/tag.dart';
import 'package:finanalyzer/turnover/model/tag_repository.dart';
import 'package:finanalyzer/turnover/model/tag_turnover_repository.dart';
import 'package:finanalyzer/turnover/model/transfer_repository.dart';
import 'package:finanalyzer/turnover/model/turnover_repository.dart';
import 'package:finanalyzer/turnover/services/turnover_matching_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

class TurnoverModule implements Module {
  final turnoverRepository = TurnoverRepository();
  final tagRepository = TagRepository();
  final tagTurnoverRepository = TagTurnoverRepository();
  final transferRepository = TransferRepository();
  final recentSearchRepository = RecentSearchRepository();

  late final TurnoverService turnoverService;
  late final TransferService transferService;
  late final TurnoverMatchingService turnoverMatchingService;

  @override
  late final List<SingleChildWidget> providers;

  late final List<TagListener> tagListeners = [];

  TurnoverModule() {
    turnoverService = TurnoverService(
      turnoverRepository,
      tagTurnoverRepository,
    );
    transferService = TransferService(
      transferRepository: transferRepository,
      tagTurnoverRepository: tagTurnoverRepository,
      tagRepository: tagRepository,
    );
    turnoverMatchingService = TurnoverMatchingService(
      tagTurnoverRepository,
      turnoverRepository,
    );

    final tagCubit = TagCubit(tagRepository);
    // Starts loading tags asynchronously (no await)
    // Note that we use the tagCubit instead of the repository in order to set the cubits loading state
    tagCubit.loadTags();

    providers = [
      Provider<TurnoverRepository>.value(value: turnoverRepository),
      Provider<TagRepository>.value(value: tagRepository),
      Provider<TagTurnoverRepository>.value(value: tagTurnoverRepository),
      Provider<TransferRepository>.value(value: transferRepository),
      Provider<RecentSearchRepository>.value(value: recentSearchRepository),
      Provider<TurnoverService>.value(value: turnoverService),
      Provider<TransferService>.value(value: transferService),
      Provider<TurnoverMatchingService>.value(value: turnoverMatchingService),
      BlocProvider.value(value: tagCubit),
    ];

    registerTagListener(
      TagTurnoverTagListener(tagTurnoverRepository: tagTurnoverRepository),
    );
  }

  void registerTagListener(TagListener listener) {
    tagListeners.add(listener);
  }

  @override
  void dispose() {
    turnoverRepository.dispose();
    tagRepository.dispose();
    tagTurnoverRepository.dispose();
    transferRepository.dispose();
  }
}

abstract class TagListener {
  Future<BeforeTagDeleteResult> onBeforeTagDelete(
    Tag tag, {
    required VoidCallback recheckStatus,
  });
}

class BeforeTagDeleteResult {
  final bool canProceed;
  final String? blockingReason;
  final List<Widget> Function(BuildContext context)? buildSuggestedActions;

  BeforeTagDeleteResult({
    required this.canProceed,
    required this.blockingReason,
    required this.buildSuggestedActions,
  });
}
