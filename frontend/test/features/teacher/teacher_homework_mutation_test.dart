import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/time/institution_timezone.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_homework.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_homework_form.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_homework_mutation.dart';

import 'teacher_test_support.dart';

const _studentA = '60000000-0000-0000-0000-000000000001';
const _studentB = '60000000-0000-0000-0000-000000000002';

void main() {
  group('Teacher Homework form', () {
    test('defaults to an immutable pristine group draft value', () {
      final sourceIds = <String>{
        _studentB.toUpperCase(),
        _studentA,
        _studentA.toUpperCase(),
      };
      final selected = TeacherHomeworkFormValue(
        assignmentMode: TeacherHomeworkAssignmentMode.selectedStudents,
        selectedStudentIds: sourceIds,
      );
      sourceIds.clear();

      expect(
        TeacherHomeworkFormValue().assignmentMode,
        TeacherHomeworkAssignmentMode.group,
      );
      expect(TeacherHomeworkFormValue().selectedStudentIds, isEmpty);
      expect(selected.selectedStudentIds, [_studentA, _studentB]);
      expect(
        () => selected.selectedStudentIds.add(
          '60000000-0000-0000-0000-000000000003',
        ),
        throwsUnsupportedError,
      );
      expect(
        selected,
        TeacherHomeworkFormValue(
          assignmentMode: TeacherHomeworkAssignmentMode.selectedStudents,
          selectedStudentIds: const {_studentA, _studentB},
        ),
      );
      expect(
        selected.hashCode,
        TeacherHomeworkFormValue(
          assignmentMode: TeacherHomeworkAssignmentMode.selectedStudents,
          selectedStudentIds: const {_studentB, _studentA},
        ).hashCode,
      );
    });

    test(
      'counts Unicode scalar values and preserves description semantics',
      () {
        final emoji = String.fromCharCode(0x1f600);
        final valid = TeacherHomeworkFormValue(
          title: List.filled(255, emoji).join(),
          description: '   ',
          studentInstructions: List.filled(10000, emoji).join(),
        );
        final invalid = valid.copyWith(
          title: '${valid.title}$emoji',
          description: '${valid.studentInstructions}x',
          studentInstructions: '${valid.studentInstructions}$emoji',
        );

        expect(valid.validate(institutionTimezone: 'Asia/Tashkent'), isEmpty);
        expect(valid.normalizedDescription, '   ');
        expect(
          TeacherHomeworkFormValue(description: '').normalizedDescription,
          isNull,
        );
        expect(
          invalid.validate(institutionTimezone: 'Asia/Tashkent').keys,
          containsAll([
            TeacherHomeworkFormField.title,
            TeacherHomeworkFormField.description,
            TeacherHomeworkFormField.studentInstructions,
          ]),
        );
      },
    );

    test('validates assignment and real Institution wall-clock deadline', () {
      final missingSelection = TeacherHomeworkFormValue(
        title: 'Homework',
        studentInstructions: 'Complete it.',
        assignmentMode: TeacherHomeworkAssignmentMode.selectedStudents,
      );
      final nonexistentDeadline = TeacherHomeworkFormValue(
        title: 'Homework',
        studentInstructions: 'Complete it.',
        deadlineWallClock: const InstitutionWallClock(
          year: 2026,
          month: 3,
          day: 29,
          hour: 2,
          minute: 30,
        ),
      );

      expect(
        missingSelection.validate(institutionTimezone: 'Asia/Tashkent'),
        contains(TeacherHomeworkFormField.studentIds),
      );
      expect(
        nonexistentDeadline.validate(institutionTimezone: 'Europe/Berlin'),
        contains(TeacherHomeworkFormField.deadlineAt),
      );
      expect(
        TeacherHomeworkFormValue(
          title: 'Homework',
          studentInstructions: 'Complete it.',
          deadlineWallClock: const InstitutionWallClock(
            year: 2000,
            month: 1,
            day: 1,
            hour: 0,
            minute: 0,
          ),
        ).validate(institutionTimezone: 'Asia/Tashkent'),
        isEmpty,
      );
      expect(
        () => TeacherHomeworkFormValue(selectedStudentIds: const {'invalid'}),
        throwsArgumentError,
      );
      expect(
        () => TeacherHomeworkFormValue.fromHomework(
          teacherHomework(hasDeadline: false),
          'Invalid/Timezone',
        ),
        throwsA(isA<InstitutionTimezoneException>()),
      );
    });
  });

  group('TeacherHomeworkCreateRequest', () {
    test('serializes exact seven-key group payload with null optionals', () {
      final request = TeacherHomeworkCreateRequest.fromForm(
        TeacherHomeworkFormValue(
          title: '  Algebra practice  ',
          description: '',
          studentInstructions: '  Complete every exercise.  ',
        ),
        'Asia/Tashkent',
      );

      expect(request.toJson(), {
        'title': 'Algebra practice',
        'description': null,
        'student_instructions': 'Complete every exercise.',
        'assignment_mode': 'group',
        'student_ids': <String>[],
        'deadline_at': null,
        'questions': <Object?>[],
      });
      expect(request.toJson().length, 7);
      expect(
        request.toJson().keys,
        isNot(
          containsAll([
            'attempt_limit',
            'status',
            'total_possible_points',
            'institution_id',
            'teacher_id',
            'topic_id',
          ]),
        ),
      );
    });

    test('sorts selected IDs and preserves non-empty description verbatim', () {
      final request = TeacherHomeworkCreateRequest.fromForm(
        TeacherHomeworkFormValue(
          title: 'Homework',
          description: '  Keep this spacing.  ',
          studentInstructions: 'Instructions',
          assignmentMode: TeacherHomeworkAssignmentMode.selectedStudents,
          selectedStudentIds: const {_studentB, _studentA},
          deadlineWallClock: const InstitutionWallClock(
            year: 2026,
            month: 9,
            day: 10,
            hour: 17,
            minute: 30,
          ),
        ),
        'Asia/Tashkent',
      );

      expect(request.toJson(), {
        'title': 'Homework',
        'description': '  Keep this spacing.  ',
        'student_instructions': 'Instructions',
        'assignment_mode': 'selected_students',
        'student_ids': [_studentA, _studentB],
        'deadline_at': '2026-09-10T17:30:00+05:00',
        'questions': <Object?>[],
      });
    });
  });

  group('TeacherHomeworkEditRequest', () {
    test('serializes each common field only when semantically changed', () {
      final homework = teacherHomework();
      final initial = TeacherHomeworkEditSnapshot.fromHomework(homework);
      final form = TeacherHomeworkFormValue.fromHomework(
        homework,
        'Asia/Tashkent',
      );

      expect(_edit(form.copyWith(title: '  New title  '), initial).toJson(), {
        'title': 'New title',
      });
      expect(_edit(form.copyWith(description: ''), initial).toJson(), {
        'description': null,
      });
      expect(
        _edit(
          form.copyWith(studentInstructions: '  New instructions  '),
          initial,
        ).toJson(),
        {'student_instructions': 'New instructions'},
      );
      expect(
        _edit(
          form.copyWith(
            deadlineWallClock: const InstitutionWallClock(
              year: 2026,
              month: 9,
              day: 11,
              hour: 18,
              minute: 0,
            ),
          ),
          initial,
        ).toJson(),
        {'deadline_at': '2026-09-11T18:00:00+05:00'},
      );
    });

    test('serializes all changed fields without Questions', () {
      final homework = teacherHomework();
      final initial = TeacherHomeworkEditSnapshot.fromHomework(homework);
      final request = _edit(
        TeacherHomeworkFormValue.fromHomework(
          homework,
          'Asia/Tashkent',
        ).copyWith(
          title: 'Updated',
          description: 'Updated description',
          studentInstructions: 'Updated instructions',
          assignmentMode: TeacherHomeworkAssignmentMode.selectedStudents,
          selectedStudentIds: const {_studentB, _studentA},
          deadlineWallClock: null,
        ),
        initial,
      );

      expect(request.toJson(), {
        'title': 'Updated',
        'description': 'Updated description',
        'student_instructions': 'Updated instructions',
        'assignment_mode': 'selected_students',
        'student_ids': [_studentA, _studentB],
        'deadline_at': null,
      });
      expect(request.toJson(), isNot(contains('questions')));
    });

    test('no-op and an equivalent UTC deadline produce an empty PATCH', () {
      final homework = teacherHomework(
        deadlineAt: DateTime.utc(2026, 9, 10, 12),
      );
      final initial = TeacherHomeworkEditSnapshot.fromHomework(homework);
      final form = TeacherHomeworkFormValue.fromHomework(
        homework,
        'Asia/Tashkent',
      );

      expect(_edit(form, initial).isEmpty, isTrue);
      expect(_edit(form, initial).toJson(), isEmpty);
    });

    test('selected set reorder alone is a no-op', () {
      final homework = teacherHomework(
        assignmentMode: TeacherHomeworkAssignmentMode.selectedStudents,
        studentIds: const [_studentA, _studentB],
      );
      final initial = TeacherHomeworkEditSnapshot.fromHomework(homework);
      final reordered = TeacherHomeworkFormValue.fromHomework(
        homework,
        'Asia/Tashkent',
      ).copyWith(selectedStudentIds: const {_studentB, _studentA});

      expect(_edit(reordered, initial).isEmpty, isTrue);
    });

    test('assignment transitions include the required resulting IDs', () {
      final groupHomework = teacherHomework();
      final groupToSelected = _edit(
        TeacherHomeworkFormValue.fromHomework(
          groupHomework,
          'Asia/Tashkent',
        ).copyWith(
          assignmentMode: TeacherHomeworkAssignmentMode.selectedStudents,
          selectedStudentIds: const {_studentB, _studentA},
        ),
        TeacherHomeworkEditSnapshot.fromHomework(groupHomework),
      );
      final selectedHomework = teacherHomework(
        assignmentMode: TeacherHomeworkAssignmentMode.selectedStudents,
        studentIds: const [_studentA, _studentB],
      );
      final selectedToGroup = _edit(
        TeacherHomeworkFormValue.fromHomework(
          selectedHomework,
          'Asia/Tashkent',
        ).copyWith(
          assignmentMode: TeacherHomeworkAssignmentMode.group,
          selectedStudentIds: const {},
        ),
        TeacherHomeworkEditSnapshot.fromHomework(selectedHomework),
      );
      final selectedSetChange = _edit(
        TeacherHomeworkFormValue.fromHomework(
          selectedHomework,
          'Asia/Tashkent',
        ).copyWith(selectedStudentIds: const {_studentB}),
        TeacherHomeworkEditSnapshot.fromHomework(selectedHomework),
      );

      expect(groupToSelected.toJson(), {
        'assignment_mode': 'selected_students',
        'student_ids': [_studentA, _studentB],
      });
      expect(selectedToGroup.toJson(), {
        'assignment_mode': 'group',
        'student_ids': <String>[],
      });
      expect(selectedSetChange.toJson(), {
        'student_ids': [_studentB],
      });
    });

    test(
      'matches compares only intended fields using set and UTC equality',
      () {
        final initialHomework = teacherHomework(
          assignmentMode: TeacherHomeworkAssignmentMode.selectedStudents,
          studentIds: const [_studentA],
          deadlineAt: DateTime.utc(2026, 9, 10, 12),
        );
        final request = _edit(
          TeacherHomeworkFormValue.fromHomework(
            initialHomework,
            'Asia/Tashkent',
          ).copyWith(
            title: 'Updated',
            selectedStudentIds: const {_studentB, _studentA},
          ),
          TeacherHomeworkEditSnapshot.fromHomework(initialHomework),
        );
        final matching = teacherHomework(
          title: 'Updated',
          assignmentMode: TeacherHomeworkAssignmentMode.selectedStudents,
          studentIds: const [_studentB, _studentA],
          deadlineAt: DateTime.parse('2026-09-10T17:00:00+05:00'),
          status: TeacherHomeworkStatus.active,
          totalPossiblePoints: 999,
        );

        expect(request.matches(matching), isTrue);
        expect(request.matches(teacherHomework(title: 'Different')), isFalse);
        expect(TeacherHomeworkEditRequest.empty().matches(matching), isTrue);

        final deadlineRequest = _edit(
          TeacherHomeworkFormValue.fromHomework(
            initialHomework,
            'Asia/Tashkent',
          ).copyWith(
            deadlineWallClock: const InstitutionWallClock(
              year: 2026,
              month: 9,
              day: 11,
              hour: 18,
              minute: 0,
            ),
          ),
          TeacherHomeworkEditSnapshot.fromHomework(initialHomework),
        );
        expect(
          deadlineRequest.matches(
            teacherHomework(
              assignmentMode: TeacherHomeworkAssignmentMode.selectedStudents,
              studentIds: const [_studentA],
              deadlineAt: DateTime.parse('2026-09-11T18:00:00+05:00'),
            ),
          ),
          isTrue,
        );
        expect(
          deadlineRequest.matches(
            teacherHomework(
              assignmentMode: TeacherHomeworkAssignmentMode.selectedStudents,
              studentIds: const [_studentA],
              deadlineAt: DateTime.utc(2026, 9, 11, 14),
            ),
          ),
          isFalse,
        );
      },
    );
  });
}

TeacherHomeworkEditRequest _edit(
  TeacherHomeworkFormValue form,
  TeacherHomeworkEditSnapshot initial,
) {
  return TeacherHomeworkEditRequest.fromForm(
    form: form,
    initial: initial,
    institutionTimezone: 'Asia/Tashkent',
  );
}
