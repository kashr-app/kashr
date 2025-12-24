import 'package:kashr/turnover/model/tag_semantic_converter.dart';
import 'package:kashr/core/uuid_json_converter.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uuid/uuid.dart';

part '../../_gen/turnover/model/tag.freezed.dart';
part '../../_gen/turnover/model/tag.g.dart';

@freezed
abstract class Tag with _$Tag {
  const Tag._();

  const factory Tag({
    @UUIDJsonConverter() required UuidValue id,
    required String name,
    String? color,
    @TagSemanticConverter() TagSemantic? semantic,
  }) = _Tag;

  bool get isTransfer => semantic == TagSemantic.transfer;
  bool get isNormal => semantic == null;

  factory Tag.fromJson(Map<String, dynamic> json) => _$TagFromJson(json);
}

enum TagSemantic {
  transfer;

  String toJson() => name;

  static TagSemantic? fromJson(String? value) {
    if (value == null) return null;
    return TagSemantic.values.firstWhere(
      (e) => e.name == value,
      orElse: () => throw ArgumentError('Invalid TagSemantic value: $value'),
    );
  }
}
