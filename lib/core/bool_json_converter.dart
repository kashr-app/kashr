import 'package:freezed_annotation/freezed_annotation.dart';

class BoolNullableJsonConverter extends JsonConverter<bool?, dynamic> {
  const BoolNullableJsonConverter();

  @override
  bool? fromJson(dynamic json) {
    if (json == null) {
      return null;
    }
    if (json is bool) {
      return json;
    }
    if (json is int) {
      return json != 0;
    }
    if (json is String) {
      return json == '1' || json.toLowerCase() == 'true';
    }
    return null;
  }

  @override
  dynamic toJson(bool? object) {
    if (object == null) {
      return null;
    }
    return object ? 1 : 0;
  }
}

class BoolJsonConverter extends JsonConverter<bool, dynamic> {
  const BoolJsonConverter();

  @override
  bool fromJson(dynamic json) {
    if (json is bool) {
      return json;
    }
    if (json is int) {
      return json != 0;
    }
    if (json is String) {
      return json == '1' || json.toLowerCase() == 'true';
    }
    return false;
  }

  @override
  dynamic toJson(bool object) {
    return object ? 1 : 0;
  }
}
