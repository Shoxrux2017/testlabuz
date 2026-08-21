import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/features/institution_admin/data/dto/institution_group_detail_dto.dart';

import 'institution_group_test_support.dart';

void main() {
  test('accepts only exact data envelope with strict Group resource', () {
    final dto = InstitutionGroupDetailDto.fromJson({'data': groupResource()});
    expect(dto.group.id, testGroupId);

    for (final invalid in <Object?>[
      groupResource(),
      {'data': groupResource(), 'message': 'Unexpected.'},
      {
        'data': {...groupResource(), 'private': true},
      },
    ]) {
      expect(
        () => InstitutionGroupDetailDto.fromJson(invalid),
        throwsFormatException,
      );
    }
  });
}
