import 'institution_group_dto.dart';

class InstitutionGroupCreateDto {
  const InstitutionGroupCreateDto({required this.group});

  factory InstitutionGroupCreateDto.fromJson(Object? json) {
    final envelope = _readExactMap(
      json,
      context: 'Institution Group create envelope',
      keys: const {'data', 'message'},
    );
    if (envelope['message'] != successMessage) {
      throw const FormatException(
        'Institution Group create message does not match the contract.',
      );
    }

    return InstitutionGroupCreateDto(
      group: InstitutionGroupDto.fromJson(envelope['data']),
    );
  }

  static const successMessage = 'Group created successfully.';

  final InstitutionGroupDto group;
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
