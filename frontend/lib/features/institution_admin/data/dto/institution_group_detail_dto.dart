import 'institution_group_dto.dart';

class InstitutionGroupDetailDto {
  const InstitutionGroupDetailDto({required this.group});

  factory InstitutionGroupDetailDto.fromJson(Object? json) {
    final envelope = _readExactMap(json);

    return InstitutionGroupDetailDto(
      group: InstitutionGroupDto.fromJson(envelope['data']),
    );
  }

  final InstitutionGroupDto group;
}

Map<String, Object?> _readExactMap(Object? value) {
  if (value is! Map) {
    throw const FormatException(
      'Institution Group detail envelope must be an object.',
    );
  }

  final map = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String) {
      throw const FormatException(
        'Institution Group detail envelope contains a non-string key.',
      );
    }
    map[entry.key as String] = entry.value;
  }

  if (map.length != 1 || !map.containsKey('data')) {
    throw const FormatException(
      'Institution Group detail envelope has missing or unknown keys.',
    );
  }

  return map;
}
