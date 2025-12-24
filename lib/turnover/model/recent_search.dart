import 'package:kashr/core/uuid_json_converter.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uuid/uuid.dart';

part '../../_gen/turnover/model/recent_search.freezed.dart';
part '../../_gen/turnover/model/recent_search.g.dart';

/// Represents a recent search query
@freezed
abstract class RecentSearch with _$RecentSearch {
  // ignore: invalid_annotation_target
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory RecentSearch({
    @UUIDJsonConverter() required UuidValue id,
    required String query,
    required DateTime createdAt,
  }) = _RecentSearch;

  factory RecentSearch.fromJson(Map<String, dynamic> json) =>
      _$RecentSearchFromJson(json);
}
