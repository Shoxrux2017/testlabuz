import 'dart:convert';

import '../../domain/institution_understanding_categories.dart';

class InstitutionUnderstandingCategoriesDto {
  const InstitutionUnderstandingCategoriesDto({required this.configuration});

  factory InstitutionUnderstandingCategoriesDto.fromRawJson(String rawJson) {
    final Object? decoded;
    try {
      decoded = jsonDecode(rawJson);
    } on FormatException {
      throw const FormatException('Invalid understanding categories JSON.');
    }

    final envelope = _stringMap(
      decoded,
      context: 'understanding categories envelope',
    );
    final keys = envelope.keys.toSet();
    if (keys.length == 2 && keys.containsAll(const {'data', 'meta'})) {
      final data = envelope['data'];
      final meta = _exactStringMap(
        envelope['meta'],
        expectedKeys: const {'configured'},
        context: 'understanding categories meta',
      );
      if (data is! List || data.isNotEmpty || meta['configured'] != false) {
        throw const FormatException(
          'Invalid unconfigured understanding categories response.',
        );
      }
      return InstitutionUnderstandingCategoriesDto(
        configuration:
            InstitutionUnderstandingCategoryConfiguration.unconfigured(),
      );
    }

    if (keys.length != 1 || !keys.contains('data')) {
      throw const FormatException(
        'Unexpected understanding categories envelope keys.',
      );
    }
    final data = envelope['data'];
    if (data is! List ||
        data.length != UnderstandingCategoryDefinition.values.length) {
      throw const FormatException(
        'Configured understanding categories must contain five items.',
      );
    }

    final categories = <InstitutionUnderstandingCategory>[];
    for (var index = 0; index < data.length; index++) {
      final definition = UnderstandingCategoryDefinition.values[index];
      final item = _exactStringMap(
        data[index],
        expectedKeys: const {
          'code',
          'label',
          'min_score',
          'max_score',
          'sort_order',
        },
        context: 'understanding category item',
      );
      if (item['code'] != definition.code ||
          item['label'] != definition.label ||
          item['sort_order'] is! int ||
          item['sort_order'] != definition.sortOrder) {
        throw const FormatException(
          'Invalid fixed understanding category identity.',
        );
      }
      final minScore = item['min_score'];
      final maxScore = item['max_score'];
      if (definition.numeric) {
        if (minScore is! int || maxScore is! int) {
          throw const FormatException(
            'Numeric understanding category bounds must be integers.',
          );
        }
      } else if (minScore != null || maxScore != null) {
        throw const FormatException('Not completed must have null bounds.');
      }
      categories.add(
        InstitutionUnderstandingCategory(
          definition: definition,
          minScore: minScore as int?,
          maxScore: maxScore as int?,
        ),
      );
    }

    return InstitutionUnderstandingCategoriesDto(
      configuration: InstitutionUnderstandingCategoryConfiguration.configured(
        categories,
      ),
    );
  }

  final InstitutionUnderstandingCategoryConfiguration configuration;
}

Map<String, Object?> _exactStringMap(
  Object? value, {
  required Set<String> expectedKeys,
  required String context,
}) {
  final result = _stringMap(value, context: context);
  if (result.keys.length != expectedKeys.length ||
      !result.keys.toSet().containsAll(expectedKeys)) {
    throw FormatException('Unexpected keys in $context.');
  }
  return result;
}

Map<String, Object?> _stringMap(Object? value, {required String context}) {
  if (value is! Map) throw FormatException('Expected object for $context.');
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String) {
      throw FormatException('Invalid key in $context.');
    }
    result[entry.key as String] = entry.value;
  }
  return result;
}
