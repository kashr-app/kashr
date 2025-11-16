import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uuid/uuid_value.dart';

class UUIDNullableJsonConverter extends JsonConverter<UuidValue?, String?> {
  const UUIDNullableJsonConverter();
  
  @override
  UuidValue? fromJson(String? json) {
    if (json == null) {
      return null;
    }
    return UuidValue.fromString(json);
  }

  @override
  String? toJson(UuidValue? object) {
    if (object == null) {
      return null;
    }
    return object.uuid;
  }
}


class UUIDJsonConverter extends JsonConverter<UuidValue, String> {
  const UUIDJsonConverter();
  
  @override
  UuidValue fromJson(String json) {
    return UuidValue.fromString(json);
  }

  @override
  String toJson(UuidValue object) {
    return object.uuid;
  }
}
