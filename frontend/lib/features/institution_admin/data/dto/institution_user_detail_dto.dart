import 'institution_user_dto.dart';

class InstitutionUserDetailDto {
  const InstitutionUserDetailDto({required this.user});

  factory InstitutionUserDetailDto.fromJson(Object? json) {
    final envelope = _readExactMap(
      json,
      context: 'Institution User detail envelope',
      keys: const {'data'},
    );

    return InstitutionUserDetailDto(
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
