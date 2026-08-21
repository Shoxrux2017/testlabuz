import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_group_mutation.dart';

import 'institution_group_test_support.dart';

void main() {
  group('InstitutionGroupEditFormValue', () {
    test('initializes from exact selected group', () {
      final group = testGroup();
      final form = InstitutionGroupEditFormValue.fromGroup(group);

      expect(form.name, group.name);
      expect(form.level, group.level);
      expect(form.subjectDirection, group.subjectDirection);
      expect(form.description, group.description);
    });

    test('validates name with trim and Unicode rune boundary', () {
      final valid = InstitutionGroupEditFormValue(
        name: '  ${List.filled(160, '\u{1F600}').join()}  ',
        level: '',
        subjectDirection: '',
        description: '',
      );
      expect(valid.validate(), isEmpty);
      expect(valid.normalizedName.runes.length, 160);

      final tooLong = valid.copyWith(
        name: List.filled(161, '\u{1F600}').join(),
      );
      expect(
        tooLong.validate()[InstitutionGroupEditField.name],
        'Group name must be 160 characters or fewer.',
      );
      expect(
        valid.copyWith(name: '   ').validate()[InstitutionGroupEditField.name],
        'Group name is required.',
      );
    });

    test('normalizes nullable fields and rejects spaces-only drafts', () {
      const empty = InstitutionGroupEditFormValue(
        name: 'Group',
        level: '',
        subjectDirection: '',
        description: '',
      );
      expect(empty.normalizedLevel, isNull);
      expect(empty.normalizedSubjectDirection, isNull);
      expect(empty.normalizedDescription, isNull);

      const spaces = InstitutionGroupEditFormValue(
        name: 'Group',
        level: '  ',
        subjectDirection: '\t',
        description: '\n ',
      );
      expect(
        spaces.validate(),
        containsPair(
          InstitutionGroupEditField.level,
          'Level must not contain only spaces.',
        ),
      );
      expect(
        spaces.validate(),
        containsPair(
          InstitutionGroupEditField.subjectDirection,
          'Subject direction must not contain only spaces.',
        ),
      );
      expect(
        spaces.validate(),
        containsPair(
          InstitutionGroupEditField.description,
          'Description must not contain only spaces.',
        ),
      );
    });

    test('uses rune limits for level and subject direction', () {
      final form = InstitutionGroupEditFormValue(
        name: 'Group',
        level: List.filled(101, '\u{1F600}').join(),
        subjectDirection: List.filled(161, '\u{1F600}').join(),
        description: '',
      );
      expect(
        form.validate()[InstitutionGroupEditField.level],
        'Level must be 100 characters or fewer.',
      );
      expect(
        form.validate()[InstitutionGroupEditField.subjectDirection],
        'Subject direction must be 160 characters or fewer.',
      );
    });

    test('preserves internal multiline description and trims only outside', () {
      const form = InstitutionGroupEditFormValue(
        name: 'Group',
        level: '',
        subjectDirection: '',
        description: '  First line\n  second line  ',
      );
      expect(form.normalizedDescription, 'First line\n  second line');
    });

    test('creates exact changed map, null clear, and normalized no-op', () {
      final group = testGroup();
      final noOp = InstitutionGroupEditFormValue.fromGroup(
        group,
      ).copyWith(name: '  ${group.name}  ', level: '  ${group.level}  ');
      expect(noOp.changedFieldsComparedTo(group).isEmpty, isTrue);

      final changed = noOp.copyWith(name: '10-B', description: '');
      expect(changed.changedFieldsComparedTo(group).toJson(), {
        'name': '10-B',
        'description': null,
      });
    });
  });

  group('InstitutionGroupEditRequest', () {
    test(
      'freezes fields, rejects unsupported values, and matches submitted fields',
      () {
        final source = <String, Object?>{'name': '10-B'};
        final request = InstitutionGroupEditRequest(source);
        source['name'] = 'changed later';
        expect(request.toJson(), {'name': '10-B'});
        expect(request.matches(testGroup(name: '10-B')), isTrue);
        expect(request.matches(testGroup(name: '10-C')), isFalse);
        expect(
          () => request.changedFields['name'] = 'mutated',
          throwsUnsupportedError,
        );
        expect(
          () => InstitutionGroupEditRequest({'status': 'archived'}),
          throwsArgumentError,
        );
        expect(
          () => InstitutionGroupEditRequest({'level': 10}),
          throwsArgumentError,
        );
      },
    );
  });
}
