import 'package:kashr/core/module.dart';
import 'package:kashr/turnover/cubit/tag_cubit.dart';
import 'package:kashr/turnover/services/transfer_service.dart';
import 'package:kashr/turnover/services/turnover_service.dart';
import 'package:kashr/turnover/listeners/tag_turnover_tag_listener.dart';
import 'package:kashr/turnover/model/recent_search_repository.dart';
import 'package:kashr/turnover/model/tag.dart';
import 'package:kashr/turnover/model/tag_repository.dart';
import 'package:kashr/turnover/model/tag_turnover_repository.dart';
import 'package:kashr/turnover/model/transfer_repository.dart';
import 'package:kashr/turnover/model/turnover_repository.dart';
import 'package:kashr/turnover/services/turnover_matching_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

class TurnoverModule implements Module {
  final turnoverRepository = TurnoverRepository();
  final tagTurnoverRepository = TagTurnoverRepository();
  final transferRepository = TransferRepository();
  final recentSearchRepository = RecentSearchRepository();

  late final TurnoverService turnoverService;
  late final TransferService transferService;
  late final TurnoverMatchingService turnoverMatchingService;
  late TagRepository tagRepository;

  @override
  late final List<SingleChildWidget> providers;

  late final List<TagListener> tagListeners = [];

  TurnoverModule(Logger log) {
    tagRepository = TagRepository(log);
    turnoverService = TurnoverService(
      turnoverRepository,
      tagTurnoverRepository,
      log,
    );
    transferService = TransferService(
      log,
      transferRepository: transferRepository,
      tagTurnoverRepository: tagTurnoverRepository,
      tagRepository: tagRepository,
    );
    turnoverMatchingService = TurnoverMatchingService(
      tagTurnoverRepository,
      turnoverRepository,
      log,
    );

    final tagCubit = TagCubit(tagRepository, log);
    // Starts loading tags asynchronously (no await)
    // Note that we use the tagCubit instead of the repository in order to set the cubits loading state
    tagCubit.loadTags();

    providers = [
      Provider.value(value: this),
      Provider.value(value: turnoverRepository),
      Provider.value(value: tagRepository),
      Provider.value(value: tagTurnoverRepository),
      Provider.value(value: transferRepository),
      Provider.value(value: recentSearchRepository),
      Provider.value(value: turnoverService),
      Provider.value(value: transferService),
      Provider.value(value: turnoverMatchingService),
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
