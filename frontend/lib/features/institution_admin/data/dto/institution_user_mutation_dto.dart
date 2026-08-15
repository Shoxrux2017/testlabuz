import 'institution_user_dto.dart';

class InstitutionUserMutationDto {
  const InstitutionUserMutationDto({required this.user});

  factory InstitutionUserMutationDto.fromJson(
    Object? json, {
    required String expectedMessage,
  }) {
    final envelope = _readExactMap(
      json,
      context: 'Institution User mutation envelope',
      keys: const {'data', 'message'},
    );
    if (envelope['message'] != expectedMessage) {
      throw const FormatException(
        'Institution User mutation message did not match the endpoint.',
      );
    }
    return InstitutionUserMutationDto(
      user: InstitutionUserDto.fromJson(envelope['data']),
    );
  }

  final InstitutionUserDto user;
}

Map<String, Object?> _readExactMap(
  Object? value, {
  required String context,
  required Set<String> keys,
}) {
  if (value is! Map) {
    throw FormatException('$context must be an object.');
  }
  final map = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String) {
      throw FormatException('$context contains a non-string key.');
    }
    map[entry.key as String] = entry.value;
  }
  if (map.length != keys.length || !map.keys.toSet().containsAll(keys)) {
    throw FormatException('$context has missing or unknown keys.');
  }
  return map;
}
