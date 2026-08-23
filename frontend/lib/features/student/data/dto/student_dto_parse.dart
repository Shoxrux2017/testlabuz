final canonicalStudentUuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

Map<String, Object?> readExactStudentMap(
  Object? value, {
  required String context,
  required Set<String> keys,
}) {
  if (value is! Map) {
    throw FormatException('$context must be an object.');
  }

  final map = <String, Object?>{};
  for (final entry in value.entries) {
    final key = entry.key;
    if (key is! String) {
      throw FormatException('$context contains a non-string key.');
    }
    map[key] = entry.value;
  }
  if (map.length != keys.length || !map.keys.toSet().containsAll(keys)) {
    throw FormatException('$context has missing or unknown keys.');
  }

  return map;
}

String readStudentNonBlankString(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is String && value.trim().isNotEmpty) {
    return value;
  }

  throw FormatException('$key must be a non-blank string.');
}

String readStudentCanonicalUuid(Map<String, Object?> map, String key) {
  final value = readStudentNonBlankString(map, key);
  if (!canonicalStudentUuidPattern.hasMatch(value)) {
    throw FormatException('$key must be a canonical UUID.');
  }

  return value;
}

String? readStudentNullableString(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value == null || value is String) {
    return value as String?;
  }

  throw FormatException('$key must be a nullable string.');
}

int readStudentInt(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is int) {
    return value;
  }

  throw FormatException('$key must be a JSON integer.');
}

DateTime? readStudentNullableUtcTimestamp(
  Map<String, Object?> map,
  String key,
) {
  final value = map[key];
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw FormatException('$key must be a nullable UTC timestamp.');
  }

  final match = _utcTimestampPattern.firstMatch(value);
  if (match == null) {
    throw FormatException('$key must be an ISO-8601 timestamp ending in Z.');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null ||
      !parsed.isUtc ||
      parsed.year != int.parse(match.group(1)!) ||
      parsed.month != int.parse(match.group(2)!) ||
      parsed.day != int.parse(match.group(3)!) ||
      parsed.hour != int.parse(match.group(4)!) ||
      parsed.minute != int.parse(match.group(5)!) ||
      parsed.second != int.parse(match.group(6) ?? '0')) {
    throw FormatException('$key must be a valid UTC timestamp.');
  }

  return parsed;
}

final _utcTimestampPattern = RegExp(
  r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})(?::(\d{2})(?:[.,]\d+)?)?Z$',
);
