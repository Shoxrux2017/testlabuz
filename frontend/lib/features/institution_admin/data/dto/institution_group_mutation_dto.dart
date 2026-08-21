import 'institution_group_dto.dart';

class InstitutionGroupMutationDto {
  const InstitutionGroupMutationDto({required this.group});

  factory InstitutionGroupMutationDto.fromJson(
    Object? json, {
    required String expectedMessage,
  }) {
    final envelope = _readExactMap(
      json,
      context: 'Institution Group mutation envelope',
      keys: const {'data', 'message'},
    );
    if (envelope['message'] != expectedMessage) {
      throw const FormatException(
        'Institution Group mutation message did not match the endpoint.',
      );
    }
    return InstitutionGroupMutationDto(
      group: InstitutionGroupDto.fromJson(envelope['data']),
    );
  }

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
