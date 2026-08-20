import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/features/institution_admin/data/dto/institution_understanding_categories_dto.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_understanding_categories.dart';

void main() {
  group('understanding category response contract', () {
    test('accepts only the exact configured and unconfigured envelopes', () {
      final configured = InstitutionUnderstandingCategoriesDto.fromRawJson(
        jsonEncode({'data': _categoryItems()}),
      ).configuration;
      final unconfigured = InstitutionUnderstandingCategoriesDto.fromRawJson(
        '{"data":[],"meta":{"configured":false}}',
      ).configuration;

      expect(configured.configured, isTrue);
      expect(configured.categories, hasLength(5));
      expect(configured.categories.first.minScore, 86);
      expect(configured.categories.last.minScore, isNull);
      expect(unconfigured.configured, isFalse);
      expect(unconfigured.categories, isEmpty);
    });

    test(
      'object key order is irrelevant but array order and identities are exact',
      () {
        final items = _categoryItems();
        final first = Map<String, Object?>.from(items.first);
        items[0] = {
          'sort_order': first['sort_order'],
          'max_score': first['max_score'],
          'label': first['label'],
          'code': first['code'],
          'min_score': first['min_score'],
        };
        expect(
          InstitutionUnderstandingCategoriesDto.fromRawJson(
            jsonEncode({'data': items}),
          ).configuration.configured,
          isTrue,
        );

        final reversed = _categoryItems().reversed.toList();
        expect(
          () => InstitutionUnderstandingCategoriesDto.fromRawJson(
            jsonEncode({'data': reversed}),
          ),
          throwsFormatException,
        );
        for (final mutation in <void Function(List<Map<String, Object?>>)>[
          (values) => values[0]['code'] = 'other',
          (values) => values[0]['label'] = 'Other',
          (values) => values[0]['sort_order'] = 2,
          (values) => values[4]['min_score'] = 0,
        ]) {
          final values = _categoryItems();
          mutation(values);
          expect(
            () => InstitutionUnderstandingCategoriesDto.fromRawJson(
              jsonEncode({'data': values}),
            ),
            throwsFormatException,
          );
        }
      },
    );

    test('fails closed for envelope, item, type and partition drift', () {
      final fixtures = <Object?>[
        {},
        {'data': null},
        {'data': <Object?>[]},
        {'data': <Object?>[], 'message': 'ok'},
        {'data': <Object?>[], 'meta': <String, Object?>{}},
        {
          'data': _categoryItems(),
          'meta': {'configured': true},
        },
        {'data': _categoryItems(), 'message': 'ok'},
        {'data': _categoryItems(), 'links': <Object?>[]},
        {
          'data': <Object?>[],
          'meta': {'configured': true},
        },
        {
          'data': <Object?>[],
          'meta': {'configured': false, 'extra': 1},
        },
        {'data': _categoryItems().take(4).toList()},
      ];
      for (final fixture in fixtures) {
        expect(
          () => InstitutionUnderstandingCategoriesDto.fromRawJson(
            jsonEncode(fixture),
          ),
          throwsFormatException,
          reason: jsonEncode(fixture),
        );
      }

      for (final invalid in <Object?>[86.0, '86', true, null]) {
        final items = _categoryItems()..[0]['min_score'] = invalid;
        expect(
          () => InstitutionUnderstandingCategoriesDto.fromRawJson(
            jsonEncode({'data': items}),
          ),
          throwsFormatException,
          reason: '$invalid',
        );
      }
      final extraKey = _categoryItems()..[0]['private'] = 'value';
      final missingKey = _categoryItems()..[0].remove('label');
      final gap = _categoryItems()..[1]['max_score'] = 84;
      for (final items in [extraKey, missingKey, gap]) {
        expect(
          () => InstitutionUnderstandingCategoriesDto.fromRawJson(
            jsonEncode({'data': items}),
          ),
          throwsFormatException,
        );
      }
    });

    test('rejects every item-key, identity and strict scalar drift', () {
      for (final key in const [
        'code',
        'label',
        'min_score',
        'max_score',
        'sort_order',
      ]) {
        final items = _categoryItems()..[2].remove(key);
        _expectInvalidItems(items, reason: 'missing $key');
      }
      for (final mutation in <void Function(List<Map<String, Object?>>)>[
        (items) => items[0]['code'] = items[1]['code'],
        (items) => items[3]['code'] = 'unknown',
        (items) => items[1]['label'] = null,
        (items) => items[1]['code'] = true,
        (items) => items[1]['sort_order'] = 2.0,
        (items) => items[1]['sort_order'] = '2',
        (items) => items[1]['sort_order'] = true,
        (items) => items[1]['max_score'] = 85.0,
        (items) => items[1]['max_score'] = '85',
        (items) => items[1]['max_score'] = true,
        (items) => items[1]['max_score'] = null,
        (items) => items[4]['max_score'] = 0,
      ]) {
        final items = _categoryItems();
        mutation(items);
        _expectInvalidItems(items);
      }
    });

    test(
      'accepts boundary, single-point and arbitrary complete partitions',
      () {
        for (final ranges in <List<(int, int)>>[
          [(100, 100), (99, 99), (98, 98), (0, 97)],
          [(76, 100), (51, 75), (1, 50), (0, 0)],
          [(91, 100), (81, 90), (41, 80), (0, 40)],
        ]) {
          final items = _categoryItems();
          for (var index = 0; index < 4; index++) {
            items[index]['min_score'] = ranges[index].$1;
            items[index]['max_score'] = ranges[index].$2;
          }
          expect(
            InstitutionUnderstandingCategoriesDto.fromRawJson(
              jsonEncode({'data': items}),
            ).configuration.configured,
            isTrue,
          );
        }
      },
    );

    test('rejects every endpoint, range, gap, overlap and bound violation', () {
      for (final mutation in <void Function(List<Map<String, Object?>>)>[
        (items) => items[0]['max_score'] = 99,
        (items) => items[3]['min_score'] = 1,
        (items) => items[1]['min_score'] = 90,
        (items) => items[1]['max_score'] = 84,
        (items) => items[1]['max_score'] = 86,
        (items) => items[0]['min_score'] = 101,
        (items) => items[3]['min_score'] = -1,
      ]) {
        final items = _categoryItems();
        mutation(items);
        _expectInvalidItems(items);
      }
    });
  });

  group('understanding category draft', () {
    test(
      'accepts one exact descending partition and emits canonical request',
      () {
        final validation =
            InstitutionUnderstandingCategoryDraft.fromConfiguration(
              _configuration(),
            ).validate();

        expect(validation.isValid, isTrue);
        expect(validation.fieldErrors, isEmpty);
        expect(validation.request!.toJson(), {
          'categories': _categoryItems()
              .map(
                (item) => <String, Object?>{
                  'code': item['code'],
                  'min_score': item['min_score'],
                  'max_score': item['max_score'],
                  'sort_order': item['sort_order'],
                },
              )
              .toList(),
        });
        expect(validation.request!.toJson().keys, ['categories']);
      },
    );

    test(
      'unconfigured state stays blank and receives no invented defaults',
      () {
        final draft = InstitutionUnderstandingCategoryDraft.fromConfiguration(
          InstitutionUnderstandingCategoryConfiguration.unconfigured(),
        );

        for (final field in InstitutionUnderstandingCategoryField.values) {
          expect(draft.valueFor(field), isEmpty);
        }
        expect(draft.validate().isValid, isFalse);
      },
    );

    test('request construction rejects non-canonical order and partitions', () {
      final valid = InstitutionUnderstandingCategoryDraft.fromConfiguration(
        _configuration(),
      ).validate().request!;
      expect(
        () => InstitutionUnderstandingCategoryUpdateRequest([
          valid.categories[1],
          valid.categories[0],
          ...valid.categories.skip(2),
        ]),
        throwsArgumentError,
      );
      expect(
        () => InstitutionUnderstandingCategoryUpdateRequest([
          InstitutionUnderstandingCategoryUpdateEntry(
            definition: valid.categories[0].definition,
            minScore: 85,
            maxScore: 100,
          ),
          ...valid.categories.skip(1),
        ]),
        throwsArgumentError,
      );
    });

    test(
      'rejects grammar, bounds, reversed ranges, gaps and overlaps locally',
      () {
        for (final value in [
          '',
          '01',
          '+1',
          '-1',
          '1.0',
          '1,0',
          '1e2',
          ' 1',
          '1 ',
          '٨٦',
          '101',
        ]) {
          final validation =
              InstitutionUnderstandingCategoryDraft.fromConfiguration(
                    _configuration(),
                  )
                  .withField(
                    InstitutionUnderstandingCategoryField.understoodWellMin,
                    value,
                  )
                  .validate();
          expect(validation.isValid, isFalse, reason: value);
          expect(
            validation.fieldErrors,
            contains(InstitutionUnderstandingCategoryField.understoodWellMin),
          );
        }

        final reversed =
            InstitutionUnderstandingCategoryDraft.fromConfiguration(
                  _configuration(),
                )
                .withField(
                  InstitutionUnderstandingCategoryField.partiallyUnderstoodMin,
                  '90',
                )
                .validate();
        final gap =
            InstitutionUnderstandingCategoryDraft.fromConfiguration(
                  _configuration(),
                )
                .withField(
                  InstitutionUnderstandingCategoryField.needsRevisionMax,
                  '69',
                )
                .validate();
        final wrongEndpoint =
            InstitutionUnderstandingCategoryDraft.fromConfiguration(
                  _configuration(),
                )
                .withField(
                  InstitutionUnderstandingCategoryField.needsTeacherSupportMin,
                  '1',
                )
                .validate();

        expect(reversed.isValid, isFalse);
        expect(gap.isValid, isFalse);
        expect(wrongEndpoint.isValid, isFalse);
        expect(gap.setError, contains('0 through 100 exactly once'));
      },
    );
  });
}

void _expectInvalidItems(List<Map<String, Object?>> items, {String? reason}) {
  expect(
    () => InstitutionUnderstandingCategoriesDto.fromRawJson(
      jsonEncode({'data': items}),
    ),
    throwsFormatException,
    reason: reason,
  );
}

List<Map<String, Object?>> _categoryItems() => [
  {
    'code': 'understood_well',
    'label': 'Understood well',
    'min_score': 86,
    'max_score': 100,
    'sort_order': 1,
  },
  {
    'code': 'partially_understood',
    'label': 'Partially understood',
    'min_score': 71,
    'max_score': 85,
    'sort_order': 2,
  },
  {
    'code': 'needs_revision',
    'label': 'Needs revision',
    'min_score': 51,
    'max_score': 70,
    'sort_order': 3,
  },
  {
    'code': 'needs_teacher_support',
    'label': 'Needs teacher support',
    'min_score': 0,
    'max_score': 50,
    'sort_order': 4,
  },
  {
    'code': 'not_completed',
    'label': 'Not completed',
    'min_score': null,
    'max_score': null,
    'sort_order': 5,
  },
];

InstitutionUnderstandingCategoryConfiguration _configuration() =>
    InstitutionUnderstandingCategoryConfiguration.configured(const [
      InstitutionUnderstandingCategory(
        definition: UnderstandingCategoryDefinition.understoodWell,
        minScore: 86,
        maxScore: 100,
      ),
      InstitutionUnderstandingCategory(
        definition: UnderstandingCategoryDefinition.partiallyUnderstood,
        minScore: 71,
        maxScore: 85,
      ),
      InstitutionUnderstandingCategory(
        definition: UnderstandingCategoryDefinition.needsRevision,
        minScore: 51,
        maxScore: 70,
      ),
      InstitutionUnderstandingCategory(
        definition: UnderstandingCategoryDefinition.needsTeacherSupport,
        minScore: 0,
        maxScore: 50,
      ),
      InstitutionUnderstandingCategory(
        definition: UnderstandingCategoryDefinition.notCompleted,
        minScore: null,
        maxScore: null,
      ),
    ]);
