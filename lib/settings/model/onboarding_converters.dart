import 'dart:convert';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kashr/settings/model/feature_tip.dart';

/// Converter for nullable DateTime values stored as ISO8601 strings
class NullableDateTimeConverter implements JsonConverter<DateTime?, String?> {
  const NullableDateTimeConverter();

  @override
  DateTime? fromJson(String? json) {
    if (json == null || json.isEmpty) return null;
    return DateTime.tryParse(json);
  }

  @override
  String? toJson(DateTime? object) {
    return object?.toIso8601String();
  }
}

/// Converter for `Map<FeatureTip, bool>` stored as JSON string
class FeatureTipMapConverter
    implements JsonConverter<Map<FeatureTip, bool>, String> {
  const FeatureTipMapConverter();

  @override
  Map<FeatureTip, bool> fromJson(String json) {
    if (json.isEmpty) return {};

    try {
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      final result = <FeatureTip, bool>{};

      for (final entry in decoded.entries) {
        final tip = FeatureTip.values.firstWhere(
          (e) => e.name == entry.key,
          orElse: () => FeatureTip.pendingTurnover,
        );
        result[tip] = entry.value as bool;
      }

      return result;
    } catch (e) {
      return {};
    }
  }

  @override
  String toJson(Map<FeatureTip, bool> object) {
    if (object.isEmpty) return '{}';

    final map = <String, bool>{};
    for (final entry in object.entries) {
      map[entry.key.name] = entry.value;
    }

    return jsonEncode(map);
  }
}
