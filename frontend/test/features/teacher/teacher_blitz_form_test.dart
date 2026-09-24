import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_blitz.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_blitz_form.dart';

import 'teacher_test_support.dart';

const _studentA = '60000000-0000-0000-0000-00000000000a';
const _studentB = '60000000-0000-0000-0000-00000000000b';

void main() {
  group('TeacherBlitzFormField', () {
    test('maps exactly the six editable request keys', () {
      expect(
        {for (final field in TeacherBlitzFormField.values) field.requestKey},
        {
          'title',
          'description',
          'student_instructions',
          'assignment_mode',
          'student_ids',
          'duration_seconds',
        },
      );
      for (final field in TeacherBlitzFormField.values) {
        expect(TeacherBlitzFormField.fromRequestKey(field.requestKey), field);
      }
      for (final key in ['scheduled_at', 'questions', 'status', 'timer']) {
        expect(TeacherBlitzFormField.fromRequestKey(key), isNull);
      }
    });
  });

  group('TeacherBlitzFormValue', () {
    test('Create defaults are empty group assignment without a duration', () {
      final form = TeacherBlitzFormValue();

      expect(form.title, '');
      expect(form.description, '');
      expect(form.studentInstructions, '');
      expect(form.assignmentMode, TeacherBlitzAssignmentMode.group);
      expect(form.selectedStudentIds, isEmpty);
      expect(form.durationSecondsText, '');
      expect(form.durationSeconds, isNull);
    });

    test('title is trimmed, required, and limited to 255 characters', () {
      expect(_errors(title: '   '), contains(TeacherBlitzFormField.title));
      expect(
        _errors(title: '${'😀' * 255} '),
        isNot(contains(TeacherBlitzFormField.title)),
      );
      expect(_errors(title: '😀' * 256), contains(TeacherBlitzFormField.title));
      expect(_valid(title: '  Blitz  ').normalizedTitle, 'Blitz');
    });

    test('description keeps non-empty input and maps empty to null', () {
      expect(_valid().normalizedDescription, isNull);
      expect(_valid(description: '  ').normalizedDescription, '  ');
      expect(_valid(description: ' Keep ').normalizedDescription, ' Keep ');
      expect(
        _errors(description: 'd' * 10001),
        contains(TeacherBlitzFormField.description),
      );
      expect(
        _errors(description: 'd' * 10000),
        isNot(contains(TeacherBlitzFormField.description)),
      );
    });

    test('student instructions are trimmed, required, and bounded', () {
      expect(
        _errors(studentInstructions: ' \n '),
        contains(TeacherBlitzFormField.studentInstructions),
      );
      expect(
        _errors(studentInstructions: 'i' * 10001),
        contains(TeacherBlitzFormField.studentInstructions),
      );
      expect(
        _valid(studentInstructions: '  Go  ').normalizedStudentInstructions,
        'Go',
      );
    });

    test('selected assignment requires Students; group requires none', () {
      expect(
        _errors(mode: TeacherBlitzAssignmentMode.selectedStudents),
        contains(TeacherBlitzFormField.studentIds),
      );
      expect(
        _errors(
          mode: TeacherBlitzAssignmentMode.group,
          students: const {_studentA},
        ),
        contains(TeacherBlitzFormField.studentIds),
      );
      expect(
        _errors(
          mode: TeacherBlitzAssignmentMode.selectedStudents,
          students: const {_studentA},
        ),
        isEmpty,
      );
    });

    test('Student IDs are canonical, lowercased, and deduplicated', () {
      final form = TeacherBlitzFormValue(
        assignmentMode: TeacherBlitzAssignmentMode.selectedStudents,
        selectedStudentIds: {_studentB.toUpperCase(), _studentA, _studentB},
      );

      expect(form.selectedStudentIds, {_studentA, _studentB});
      expect(
        () => TeacherBlitzFormValue(selectedStudentIds: const {'not-a-uuid'}),
        throwsArgumentError,
      );
    });

    test('duration accepts only whole ASCII seconds within 1..2147483647', () {
      for (final (text, seconds) in [
        ('1', 1),
        (' 600 ', 600),
        ('0600', 600),
        ('2147483647', 2147483647),
      ]) {
        final form = _valid(duration: text);
        expect(form.durationSeconds, seconds, reason: text);
        expect(form.validate(), isEmpty, reason: text);
      }
      for (final text in [
        '',
        '   ',
        '0',
        '-1',
        '+5',
        '-',
        '1.5',
        '60.0',
        '1e3',
        '1,000',
        '1 000',
        '٣',
        '2147483648',
        '99999999999999999999',
      ]) {
        final form = _valid(duration: text);
        expect(form.durationSeconds, isNull, reason: text);
        expect(
          form.validate(),
          contains(TeacherBlitzFormField.durationSeconds),
          reason: text,
        );
      }
    });

    test('Edit form starts from the authoritative Blitz', () {
      final blitz = teacherBlitz(
        description: null,
        assignmentMode: TeacherBlitzAssignmentMode.selectedStudents,
        studentIds: const [_studentB, _studentA],
        durationSeconds: 90,
      );

      final form = TeacherBlitzFormValue.fromBlitz(blitz);

      expect(form.title, blitz.title);
      expect(form.description, '');
      expect(form.studentInstructions, blitz.studentInstructions);
      expect(form.assignmentMode, TeacherBlitzAssignmentMode.selectedStudents);
      expect(form.selectedStudentIds, {_studentA, _studentB});
      expect(form.durationSecondsText, '90');
    });

    test('uses semantic value equality', () {
      expect(
        TeacherBlitzFormValue(
          title: 'A',
          selectedStudentIds: const {_studentA},
        ),
        TeacherBlitzFormValue(
          title: 'A',
          selectedStudentIds: {_studentA.toUpperCase()},
        ),
      );
      expect(TeacherBlitzFormValue() == _valid(), isFalse);
    });
  });

  test('authoring is available only for draft and scheduled Blitz', () {
    expect(TeacherBlitzStatus.values.where(isTeacherBlitzAuthoringStatus), [
      TeacherBlitzStatus.draft,
      TeacherBlitzStatus.scheduled,
    ]);
  });
}

TeacherBlitzFormValue _valid({
  String title = 'Equation Blitz',
  String description = '',
  String studentInstructions = 'Answer quickly.',
  TeacherBlitzAssignmentMode mode = TeacherBlitzAssignmentMode.group,
  Set<String> students = const {},
  String duration = '600',
}) {
  return TeacherBlitzFormValue(
    title: title,
    description: description,
    studentInstructions: studentInstructions,
    assignmentMode: mode,
    selectedStudentIds: students,
    durationSecondsText: duration,
  );
}

Set<TeacherBlitzFormField> _errors({
  String title = 'Equation Blitz',
  String description = '',
  String studentInstructions = 'Answer quickly.',
  TeacherBlitzAssignmentMode mode = TeacherBlitzAssignmentMode.group,
  Set<String> students = const {},
}) {
  return _valid(
    title: title,
    description: description,
    studentInstructions: studentInstructions,
    mode: mode,
    students: students,
  ).validate().keys.toSet();
}
