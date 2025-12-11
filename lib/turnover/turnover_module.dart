import 'package:finanalyzer/core/module.dart';
import 'package:finanalyzer/turnover/cubit/tag_cubit.dart';
import 'package:finanalyzer/turnover/cubit/turnover_cubit.dart';
import 'package:finanalyzer/turnover/model/recent_search_repository.dart';
import 'package:finanalyzer/turnover/model/tag.dart';
import 'package:finanalyzer/turnover/model/tag_repository.dart';
import 'package:finanalyzer/turnover/model/tag_turnover_repository.dart';
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
  final recentSearchRepository = RecentSearchRepository();

  late final TurnoverMatchingService turnoverMatchingService;

  @override
  late final List<SingleChildWidget> providers;

  final List<TagListener> tagListeners = [
    // TODO add TagTurnoverTagListener
  ];

  TurnoverModule() {
    turnoverMatchingService = TurnoverMatchingService(
      tagTurnoverRepository,
      turnoverRepository,
    );

    providers = [
      Provider<TurnoverRepository>.value(value: turnoverRepository),
      Provider<TagRepository>.value(value: tagRepository),
      Provider<TagTurnoverRepository>.value(value: tagTurnoverRepository),
      Provider<RecentSearchRepository>.value(value: recentSearchRepository),
      Provider<TurnoverMatchingService>.value(value: turnoverMatchingService),
      BlocProvider(create: (_) => TurnoverCubit(turnoverRepository)),
      BlocProvider(
        lazy: false,
        create: (_) => TagCubit(tagRepository)..loadTags(),
      ),
    ];
  }

  void registerTagListener(TagListener listener) {
    tagListeners.add(listener);
  }
}

abstract class TagListener {
  Future<BeforeTagDeleteResult> onBeforeTagDelete(Tag tag);
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
