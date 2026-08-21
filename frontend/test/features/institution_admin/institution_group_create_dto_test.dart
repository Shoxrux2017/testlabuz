import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/features/institution_admin/data/dto/institution_group_create_dto.dart';

import 'institution_group_test_support.dart';

void main() {
  test('accepts only exact data and create message envelope', () {
    final dto = InstitutionGroupCreateDto.fromJson({
      'data': groupResource(),
      'message': InstitutionGroupCreateDto.successMessage,
    });
    expect(dto.group.id, testGroupId);

    for (final invalid in <Object?>[
      {'data': groupResource()},
      {'data': groupResource(), 'message': 'Wrong message.'},
      {
        'data': groupResource(),
        'message': InstitutionGroupCreateDto.successMessage,
        'extra': true,
      },
    ]) {
      expect(
        () => InstitutionGroupCreateDto.fromJson(invalid),
        throwsFormatException,
      );
    }
  });

  test('reuses strict Institution Group resource parsing', () {
    expect(
      () => InstitutionGroupCreateDto.fromJson({
        'data': {...groupResource(), 'institution_id': 'private'},
        'message': InstitutionGroupCreateDto.successMessage,
      }),
      throwsFormatException,
    );
  });
}
