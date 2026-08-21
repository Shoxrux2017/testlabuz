import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_group_create.dart';

void main() {
  group('InstitutionGroupCreateFormValue', () {
    test(
      'preserves drafts and serializes one exact normalized four-key body',
      () {
        const form = InstitutionGroupCreateFormValue(
          name: '  Advanced  Mathematics  ',
          level: '',
          subjectDirection: '  STEM  ',
          description: '  First line\n  second line  ',
        );

        expect(form.validate(), isEmpty);
        expect(form.name, '  Advanced  Mathematics  ');
        expect(form.description, '  First line\n  second line  ');
        expect(form.toRequest().toJson(), {
          'name': 'Advanced  Mathematics',
          'level': null,
          'subject_direction': 'STEM',
          'description': 'First line\n  second line',
        });
      },
    );

    test('uses rune boundaries without truncating the draft', () {
      final valid = InstitutionGroupCreateFormValue(
        name: List.filled(160, '😀').join(),
        level: List.filled(100, '😀').join(),
        subjectDirection: List.filled(160, '😀').join(),
      );
      expect(valid.validate(), isEmpty);

      final invalid = InstitutionGroupCreateFormValue(
        name: '${valid.name}😀',
        level: '${valid.level}😀',
        subjectDirection: '${valid.subjectDirection}😀',
      );
      final errors = invalid.validate();
      expect(errors.keys, InstitutionGroupCreateField.values.take(3));
      expect(invalid.name.runes.length, 161);
    });

    test('rejects required and spaces-only optional values locally', () {
      const form = InstitutionGroupCreateFormValue(
        name: '   ',
        level: ' ',
        subjectDirection: '\t',
        description: '\n ',
      );

      expect(form.validate(), {
        InstitutionGroupCreateField.name: 'Group name is required.',
        InstitutionGroupCreateField.level:
            'Level must not contain only spaces.',
        InstitutionGroupCreateField.subjectDirection:
            'Subject direction must not contain only spaces.',
        InstitutionGroupCreateField.description:
            'Description must not contain only spaces.',
      });
    });

    test('does not perform duplicate-name validation', () {
      const first = InstitutionGroupCreateFormValue(name: 'Same name');
      const second = InstitutionGroupCreateFormValue(name: 'Same name');
      expect(first.validate(), isEmpty);
      expect(second.validate(), isEmpty);
    });
  });
}
