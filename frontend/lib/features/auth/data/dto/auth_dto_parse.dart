Map<Object?, Object?> readRequiredMap(Object? value, String context) {
  if (value is Map<Object?, Object?>) {
    return value;
  }

  if (value is Map) {
    return Map<Object?, Object?>.from(value);
  }

  throw FormatException('Expected object for $context.');
}

String readRequiredString(Map<Object?, Object?> json, String key) {
  final value = json[key];

  if (value is String && value.trim().isNotEmpty) {
    return value;
  }

  throw FormatException('Missing required string field: $key.');
}

String? readNullableString(Map<Object?, Object?> json, String key) {
  final value = json[key];

  if (value == null) {
    return null;
  }

  if (value is String && value.trim().isNotEmpty) {
    return value;
  }

  throw FormatException('Invalid nullable string field: $key.');
}

bool readRequiredBool(Map<Object?, Object?> json, String key) {
  final value = json[key];

  if (value is bool) {
    return value;
  }

  throw FormatException('Missing required boolean field: $key.');
}
