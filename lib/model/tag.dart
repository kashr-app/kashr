import 'package:finanalyzer/core/uuid_json_converter.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uuid/uuid.dart';

part '../_gen/model/tag.freezed.dart';
part '../_gen/model/tag.g.dart';

@freezed
abstract class Tag with _$Tag {
  const Tag._();

  const factory Tag({
    @UUIDNullableJsonConverter() UuidValue? id,
    required String name,
    String? color,
  }) = _Tag;

  factory Tag.fromJson(Map<String, dynamic> json) => _$TagFromJson(json);
}
