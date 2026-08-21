import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/features/institution_admin/data/dto/institution_group_mutation_dto.dart';

import 'institution_group_test_support.dart';

void main() {
  test('parses exact update envelope with strict Group DTO', () {
    final dto = InstitutionGroupMutationDto.fromJson({
      'data': groupResource(name: '10-B'),
      'message': 'Group updated successfully.',
    }, expectedMessage: 'Group updated successfully.');
    expect(dto.group.name, '10-B');
  });

  test('rejects missing, unknown, wrong message, and malformed Group data', () {
    for (final envelope in <Object?>[
      {'data': groupResource()},
      {
        'data': groupResource(),
        'message': 'Group updated successfully.',
        'extra': true,
      },
      {'data': groupResource(), 'message': 'Wrong message.'},
      {
        'data': {...groupResource(), 'unknown': true},
        'message': 'Group updated successfully.',
      },
    ]) {
      expect(
        () => InstitutionGroupMutationDto.fromJson(
          envelope,
          expectedMessage: 'Group updated successfully.',
        ),
        throwsFormatException,
      );
    }
  });
}
