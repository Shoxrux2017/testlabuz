import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_blitz.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_blitz_form.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_blitz_mutation.dart';

import 'teacher_test_support.dart';

const _studentA = '60000000-0000-0000-0000-00000000000a';
const _studentB = '60000000-0000-0000-0000-00000000000b';

void main() {
  group('TeacherBlitzCreateRequest', () {
    test(
      'serializes exactly the eight create keys with fixed schedule and Questions',
      () {
        final request = TeacherBlitzCreateRequest.fromForm(
          TeacherBlitzFormValue(
            title: '  Topic Blitz  ',
            description: '',
            studentInstructions: '  Answer quickly.  ',
            durationSecondsText: ' 600 ',
          ),
        );

        expect(request.toJson(), {
          'title': 'Topic Blitz',
          'description': null,
          'student_instructions': 'Answer quickly.',
          'assignment_mode': 'group',
          'student_ids': <String>[],
          'duration_seconds': 600,
          'scheduled_at': null,
          'questions': <Object?>[],
        });
      },
    );

    test(
      'sends sorted canonical selected Students and verbatim description',
      () {
        final request = TeacherBlitzCreateRequest.fromForm(
          TeacherBlitzFormValue(
            title: 'Blitz',
            description: ' keep spacing ',
            studentInstructions: 'Go',
            assignmentMode: TeacherBlitzAssignmentMode.selectedStudents,
            selectedStudentIds: {_studentB.toUpperCase(), _studentA},
            durationSecondsText: '90',
          ),
        );

        final json = request.toJson();
        expect(json['assignment_mode'], 'selected_students');
        expect(json['student_ids'], [_studentA, _studentB]);
        expect(json['description'], ' keep spacing ');
        expect(json['duration_seconds'], 90);
        expect(
          json.keys,
          isNot(
            anyOf(
              contains('status'),
              contains('attempt_limit'),
              contains('normal_attempts'),
              contains('timer_start_mode'),
              contains('total_possible_points'),
            ),
          ),
        );
      },
    );

    test('refuses an invalid form instead of sending a partial request', () {
      for (final form in [
        TeacherBlitzFormValue(title: 'Blitz', studentInstructions: 'Go'),
        TeacherBlitzFormValue(
          title: 'Blitz',
          studentInstructions: 'Go',
          durationSecondsText: '600',
          assignmentMode: TeacherBlitzAssignmentMode.selectedStudents,
        ),
      ]) {
        expect(
          () => TeacherBlitzCreateRequest.fromForm(form),
          throwsArgumentError,
        );
      }
    });
  });

  group('TeacherBlitzEditRequest', () {
    test('an unchanged form is a no-op request', () {
      final blitz = teacherBlitz(description: null, durationSeconds: 600);
      final request = _edit(blitz, TeacherBlitzFormValue.fromBlitz(blitz));

      expect(request.isEmpty, isTrue);
      expect(request.toJson(), isEmpty);
    });

    test('includes only fields whose normalized values changed', () {
      final blitz = teacherBlitz(
        title: 'Old title',
        description: 'Old',
        studentInstructions: 'Old instructions',
        durationSeconds: 600,
      );
      final form = TeacherBlitzFormValue.fromBlitz(blitz).copyWith(
        title: '  Old title  ',
        description: '',
        studentInstructions: 'New instructions',
        durationSecondsText: '90',
      );

      expect(_edit(blitz, form).toJson(), {
        'description': null,
        'student_instructions': 'New instructions',
        'duration_seconds': 90,
      });
    });

    test('never sends schedule, Questions, status, or timer fields', () {
      final blitz = teacherBlitz(
        status: TeacherBlitzStatus.scheduled,
        scheduledAt: DateTime.utc(2026, 9, 18, 4),
      );
      final json = _edit(
        blitz,
        TeacherBlitzFormValue.fromBlitz(blitz).copyWith(title: 'Renamed'),
      ).toJson();

      expect(json, {'title': 'Renamed'});
    });

    test('a mode change sends both assignment mode and resulting Students', () {
      final group = teacherBlitz();
      final toSelected = TeacherBlitzFormValue.fromBlitz(group).copyWith(
        assignmentMode: TeacherBlitzAssignmentMode.selectedStudents,
        selectedStudentIds: const {_studentB, _studentA},
      );
      expect(_edit(group, toSelected).toJson(), {
        'assignment_mode': 'selected_students',
        'student_ids': [_studentA, _studentB],
      });

      final selected = teacherBlitz(
        assignmentMode: TeacherBlitzAssignmentMode.selectedStudents,
        studentIds: const [_studentA],
      );
      final toGroup = TeacherBlitzFormValue.fromBlitz(selected).copyWith(
        assignmentMode: TeacherBlitzAssignmentMode.group,
        selectedStudentIds: const {},
      );
      expect(_edit(selected, toGroup).toJson(), {
        'assignment_mode': 'group',
        'student_ids': <String>[],
      });
    });

    test(
      'a changed selected set sends only student_ids case-insensitively',
      () {
        final blitz = teacherBlitz(
          assignmentMode: TeacherBlitzAssignmentMode.selectedStudents,
          studentIds: [_studentA.toUpperCase()],
        );
        final sameSet = TeacherBlitzFormValue.fromBlitz(
          blitz,
        ).copyWith(selectedStudentIds: const {_studentA});
        expect(_edit(blitz, sameSet).isEmpty, isTrue);

        final changed = TeacherBlitzFormValue.fromBlitz(
          blitz,
        ).copyWith(selectedStudentIds: const {_studentA, _studentB});
        expect(_edit(blitz, changed).toJson(), {
          'student_ids': [_studentA, _studentB],
        });
      },
    );

    test('matches only when every changed field is now authoritative', () {
      final blitz = teacherBlitz(durationSeconds: 600);
      final request = _edit(
        blitz,
        TeacherBlitzFormValue.fromBlitz(blitz).copyWith(
          title: 'Renamed',
          durationSecondsText: '90',
          assignmentMode: TeacherBlitzAssignmentMode.selectedStudents,
          selectedStudentIds: const {_studentA},
        ),
      );

      expect(
        request.matches(
          teacherBlitz(
            title: 'Renamed',
            durationSeconds: 90,
            assignmentMode: TeacherBlitzAssignmentMode.selectedStudents,
            studentIds: [_studentA.toUpperCase()],
          ),
        ),
        isTrue,
      );
      expect(
        request.matches(
          teacherBlitz(
            title: 'Renamed',
            durationSeconds: 600,
            assignmentMode: TeacherBlitzAssignmentMode.selectedStudents,
            studentIds: const [_studentA],
          ),
        ),
        isFalse,
      );
      expect(request.matches(teacherBlitz(title: 'Renamed')), isFalse);
    });

    test('refuses an invalid form', () {
      final blitz = teacherBlitz();
      expect(
        () => _edit(
          blitz,
          TeacherBlitzFormValue.fromBlitz(
            blitz,
          ).copyWith(durationSecondsText: '0'),
        ),
        throwsArgumentError,
      );
    });
  });
}

TeacherBlitzEditRequest _edit(TeacherBlitz blitz, TeacherBlitzFormValue form) {
  return TeacherBlitzEditRequest.fromForm(
    form: form,
    initial: TeacherBlitzEditSnapshot.fromBlitz(blitz),
  );
}
