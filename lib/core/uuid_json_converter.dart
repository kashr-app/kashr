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

class UUIDListJsonConverter extends JsonConverter<List<UuidValue>, List<String>> {
  const UUIDListJsonConverter();

  @override
  List<UuidValue> fromJson(List<String> json) {
    return json.map((id) => UuidValue.fromString(id)).toList();
  }

  @override
  List<String> toJson(List<UuidValue> object) {
    return object.map((uuid) => uuid.uuid).toList();
  }
}

class UUIDListNullableJsonConverter extends JsonConverter<List<UuidValue>?, List<String>?> {
  const UUIDListNullableJsonConverter();

  @override
  List<UuidValue>? fromJson(List<String>? json) {
    if (json == null) return null;
    return json.map((id) => UuidValue.fromString(id)).toList();
  }

  @override
  List<String>? toJson(List<UuidValue>? object) {
    if (object == null) return null;
    return object.map((uuid) => uuid.uuid).toList();
  }
}
