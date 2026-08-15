import 'institution_user_dto.dart';

class InstitutionUserCreateDto {
  const InstitutionUserCreateDto({required this.user});

  factory InstitutionUserCreateDto.fromJson(Object? json) {
    final envelope = _readExactMap(json);
    if (envelope['message'] != successMessage) {
      throw const FormatException(
        'Institution User create message does not match the contract.',
      );
    }

    return InstitutionUserCreateDto(
      user: InstitutionUserDto.fromJson(envelope['data']),
    );
  }

  static const successMessage = 'Institution user created successfully.';

  final InstitutionUserDto user;
}

Map<String, Object?> _readExactMap(Object? value) {
  if (value is! Map) {
    throw const FormatException(
      'Institution User create envelope must be an object.',
    );
  }

  final map = <String, Object?>{};
  for (final entry in value.entries) {
    final key = entry.key;
    if (key is! String) {
      throw const FormatException(
        'Institution User create envelope contains a non-string key.',
      );
    }
    map[key] = entry.value;
  }

  const keys = {'data', 'message'};
  if (map.length != keys.length || !map.keys.toSet().containsAll(keys)) {
    throw const FormatException(
      'Institution User create envelope has missing or unknown keys.',
    );
  }

  return map;
}
