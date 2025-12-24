import 'package:kashr/turnover/model/tag.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

class TagSemanticConverter extends JsonConverter<TagSemantic?, String?> {
  const TagSemanticConverter();

  @override
  TagSemantic? fromJson(String? json) {
    return TagSemantic.fromJson(json);
  }

  @override
  String? toJson(TagSemantic? object) {
    return object?.name;
  }
}
