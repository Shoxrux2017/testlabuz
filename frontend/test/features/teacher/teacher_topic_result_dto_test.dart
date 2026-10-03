import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/features/teacher/data/dto/teacher_topic_result_dto.dart';
import 'package:testlabuz_client/features/teacher/data/dto/teacher_topic_result_list_dto.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_topic_result.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_topic_result_list.dart';

import 'teacher_topic_result_test_support.dart';

void main() {
  TeacherTopicResult parse(Map<String, Object?> json) =>
      TeacherTopicResultDto.fromJson(json).toDomain();

  Map<String, Object?> withKey(
    Map<String, Object?> json,
    String key,
    Object? value,
  ) => {...json, key: value};

  group('Teacher Topic result item DTO', () {
    test('parses a calculated result with every value', () {
      final result = parse(
        teacherTopicResultJson(
          teacherComment: 'Revise question 4.',
          visibility: teacherResultVisibilityJson(
            studentMode: 'automatic',
            studentVisible: true,
            studentReleasedAt: '2026-10-04T08:00:00Z',
            canReleaseToStudent: false,
            parentMode: 'manual_teacher',
            canReleaseToParent: true,
          ),
        ),
      );

      expect(result.studentId, teacherResultStudentId);
      expect(result.studentName, 'Aziza Karimova');
      expect(result.status, TeacherTopicResultStatus.calculated);
      expect(result.closedOutcome, isNull);
      expect(result.closedAt, isNull);
      expect(result.missingComponent, isNull);
      expect(result.homework.assessmentId, teacherResultHomeworkId);
      expect(result.homework.state, TeacherTopicResultSideState.ready);
      expect(result.homework.officialAttemptId, teacherResultHomeworkAttemptId);
      expect(result.homework.attemptNumber, 1);
      expect(result.homework.score, 88.0);
      expect(result.blitz.assessmentId, teacherResultBlitzId);
      expect(result.blitz.score, 84.0);
      expect(result.scoreDifference, 4.0);
      expect(result.acceptableDifference, 10.0);
      expect(result.consistency, TeacherTopicResultConsistency.consistent);
      expect(result.method, TeacherTopicResultMethod.average);
      expect(result.finalScore, 86.0);
      expect(result.categoryScore, 86);
      expect(
        result.category?.code,
        TeacherTopicResultCategoryCode.understoodWell,
      );
      expect(result.category?.label, 'Understood well');
      expect(result.teacherComment, 'Revise question 4.');
      expect(result.canClose, isTrue);

      final visibility = result.visibility;
      expect(
        visibility.studentReleaseMode,
        TeacherStudentResultReleaseMode.automatic,
      );
      expect(visibility.studentVisible, isTrue);
      expect(visibility.studentReleasedAt, DateTime.utc(2026, 10, 4, 8));
      expect(visibility.canReleaseToStudent, isFalse);
      expect(
        visibility.parentReleaseMode,
        TeacherParentResultReleaseMode.manualTeacher,
      );
      expect(visibility.parentVisible, isFalse);
      expect(visibility.parentReleasedAt, isNull);
      expect(visibility.canReleaseToParent, isTrue);
    });

    test('parses unconfigured release modes and fractional scores', () {
      final result = parse(
        teacherTopicResultJson(
          homework: teacherResultSideJson(score: 86.12345679),
          scoreDifference: 2.12345679,
          acceptableDifference: 2.5,
          finalScore: 85.06172840,
          categoryScore: 85,
          visibility: teacherResultVisibilityJson(
            studentMode: null,
            canReleaseToStudent: false,
            parentMode: null,
          ),
        ),
      );

      expect(result.homework.score, 86.12345679);
      expect(result.finalScore, 85.0617284);
      expect(result.visibility.studentReleaseMode, isNull);
      expect(result.visibility.parentReleaseMode, isNull);
    });

    test('parses an inconsistent result that uses the Blitz score', () {
      final result = parse(inconsistentTeacherTopicResultJson());

      expect(result.consistency, TeacherTopicResultConsistency.inconsistent);
      expect(result.method, TeacherTopicResultMethod.blitz);
      expect(result.finalScore, 60.0);
      expect(
        result.category?.code,
        TeacherTopicResultCategoryCode.needsRevision,
      );
    });

    test('parses waiting results without comparison values', () {
      for (final (status, homeworkState, blitzState) in [
        ('waiting_for_homework', 'open', 'not_activated'),
        ('waiting_for_homework', 'not_activated', 'not_designated'),
        ('waiting_for_homework', 'checking', 'open'),
        ('waiting_for_blitz', 'ready', 'not_designated'),
        ('waiting_for_blitz', 'waiting_for_teacher_review', 'checking'),
        ('waiting_for_teacher_review', 'ready', 'waiting_for_teacher_review'),
        ('waiting_for_settings', 'ready', 'ready'),
      ]) {
        final result = parse(
          waitingTeacherTopicResultJson(
            status: status,
            homeworkState: homeworkState,
            blitzState: blitzState,
          ),
        );

        expect(result.status.value, status);
        expect(result.homework.state.value, homeworkState);
        expect(result.blitz.state.value, blitzState);
        expect(
          [
            result.scoreDifference,
            result.acceptableDifference,
            result.consistency,
            result.method,
            result.finalScore,
            result.categoryScore,
            result.category,
          ],
          everyElement(isNull),
          reason: status,
        );
      }
    });

    test('a not designated Blitz has no assessment', () {
      final result = parse(
        waitingTeacherTopicResultJson(blitzState: 'not_designated'),
      );

      expect(result.blitz.state, TeacherTopicResultSideState.notDesignated);
      expect(result.blitz.assessmentId, isNull);
    });

    test('parses open and closed Not completed results per missing side', () {
      for (final closed in [false, true]) {
        for (final missing in ['homework', 'blitz', 'both']) {
          final result = parse(
            notCompletedTeacherTopicResultJson(
              missing: missing,
              closed: closed,
            ),
          );

          expect(result.missingComponent?.value, missing);
          expect(
            result.status,
            closed
                ? TeacherTopicResultStatus.closed
                : TeacherTopicResultStatus.notCompleted,
          );
          expect(
            result.closedOutcome,
            closed ? TeacherTopicResultOutcome.notCompleted : null,
          );
          expect(result.closedAt, closed ? DateTime.utc(2026, 10, 5, 9) : null);
          expect(
            result.category?.code,
            TeacherTopicResultCategoryCode.notCompleted,
          );
          expect(result.finalScore, isNull);
          expect(result.isNotCompleted, isTrue);
        }
      }
    });

    test('parses a closed calculated result', () {
      final result = parse(closedCalculatedTeacherTopicResultJson());

      expect(result.status, TeacherTopicResultStatus.closed);
      expect(result.closedOutcome, TeacherTopicResultOutcome.calculated);
      expect(result.closedAt, DateTime.utc(2026, 10, 5, 9));
      expect(result.isCalculated, isTrue);
      expect(result.finalScore, 86.0);
      expect(result.canClose, isFalse);
      expect(result.visibility.studentVisible, isTrue);
    });

    test('rejects malformed items', () {
      final calculated = teacherTopicResultJson();
      final waiting = waitingTeacherTopicResultJson();
      final notCompleted = notCompletedTeacherTopicResultJson();
      final cases = <String, Map<String, Object?>>{
        'an unknown key': withKey(calculated, 'extra', 1),
        'a missing key': Map.of(calculated)..remove('can_close'),
        'an unknown status': withKey(calculated, 'result_status', 'done'),
        'a student with an extra key': withKey(calculated, 'student', {
          'id': teacherResultStudentId,
          'full_name': 'Aziza',
          'login': 'aziza',
        }),
        'a non-canonical Student id': teacherTopicResultJson(
          studentId: 'student-1',
        ),
        'a blank Student name': teacherTopicResultJson(fullName: ' '),
        'an outcome on an open result': teacherTopicResultJson(
          closedOutcome: 'calculated',
        ),
        'a closed result without an outcome': teacherTopicResultJson(
          status: 'closed',
          closedAt: '2026-10-05T09:00:00Z',
        ),
        'a closed result without a closing time': teacherTopicResultJson(
          status: 'closed',
          closedOutcome: 'calculated',
          canClose: false,
        ),
        'a closing time on an open result': teacherTopicResultJson(
          closedAt: '2026-10-05T09:00:00Z',
        ),
        'an invalid closing time': withKey(
          notCompletedTeacherTopicResultJson(closed: true),
          'closed_at',
          '2026-10-05 09:00',
        ),
        'a missing component on a calculated result': teacherTopicResultJson(
          missingComponent: 'blitz',
        ),
        'a Not completed result without its component': withKey(
          notCompleted,
          'missing_component',
          null,
        ),
        'a missing component that is not the missing side': withKey(
          notCompleted,
          'missing_component',
          'homework',
        ),
        'a missing component that leaves out a missing side': withKey(
          notCompletedTeacherTopicResultJson(missing: 'both'),
          'missing_component',
          'blitz',
        ),
        'a not designated Homework': teacherTopicResultJson(
          status: 'waiting_for_homework',
          homework: teacherResultSideJson(state: 'not_designated'),
        ),
        'a Homework without its assessment': teacherTopicResultJson(
          homework: teacherResultSideJson(assessmentId: null),
        ),
        'a designated Blitz without its assessment': teacherTopicResultJson(
          blitz: teacherResultSideJson(assessmentId: null, score: 84),
        ),
        'a not designated Blitz with an assessment': withKey(
          waiting,
          'blitz',
          teacherResultSideJson(
            assessmentId: teacherResultBlitzId,
            state: 'not_designated',
          ),
        ),
        'an unknown side state': withKey(
          waiting,
          'blitz',
          teacherResultSideJson(
            assessmentId: teacherResultBlitzId,
            state: 'started',
          ),
        ),
        'a side with an extra key': withKey(calculated, 'homework', {
          ...teacherResultSideJson(),
          'extra': 1,
        }),
        'a ready side without its Attempt': withKey(calculated, 'homework', {
          ...teacherResultSideJson(),
          'official_attempt_id': null,
        }),
        'a waiting side with a score': withKey(waiting, 'blitz', {
          ...teacherResultBlitzSideJson(state: 'open'),
          'score': 40,
        }),
        'a Homework Attempt number above three': teacherTopicResultJson(
          homework: teacherResultSideJson(attemptNumber: 4),
        ),
        'a Blitz Attempt number above two': teacherTopicResultJson(
          blitz: teacherResultBlitzSideJson(attemptNumber: 3),
        ),
        'an Attempt number below one': teacherTopicResultJson(
          homework: teacherResultSideJson(attemptNumber: 0),
        ),
        'a calculated result with a waiting side': teacherTopicResultJson(
          blitz: teacherResultBlitzSideJson(state: 'open'),
        ),
        'a calculated result without D': teacherTopicResultJson(
          scoreDifference: null,
        ),
        'a calculated result without a final score': teacherTopicResultJson(
          finalScore: null,
        ),
        'a calculated result without a category score': teacherTopicResultJson(
          categoryScore: null,
        ),
        'an average for inconsistent scores': teacherTopicResultJson(
          consistency: 'inconsistent',
        ),
        'the Blitz score for consistent scores': teacherTopicResultJson(
          method: 'blitz',
        ),
        'a calculated result in the Not completed category':
            teacherTopicResultJson(
              category: const {
                'code': 'not_completed',
                'label': 'Not completed',
              },
            ),
        'a waiting result with a final score': withKey(
          waiting,
          'final_score',
          70,
        ),
        'a waiting result with a category': withKey(waiting, 'category', {
          'code': 'understood_well',
          'label': 'Understood well',
        }),
        'a Not completed result with a method': withKey(
          notCompleted,
          'calculation_method',
          'average',
        ),
        'a Not completed result in a numeric category': withKey(
          notCompleted,
          'category',
          {'code': 'needs_revision', 'label': 'Needs revision'},
        ),
        'a score above 100': teacherTopicResultJson(
          homework: teacherResultSideJson(score: 100.5),
        ),
        'a negative score': teacherTopicResultJson(finalScore: -1),
        'a string score': teacherTopicResultJson(finalScore: '86'),
        'a negative difference': teacherTopicResultJson(scoreDifference: -4),
        'an allowed difference above 100': teacherTopicResultJson(
          acceptableDifference: 101,
        ),
        'a fractional category score': teacherTopicResultJson(
          categoryScore: 86.5,
        ),
        'a category score above 100': teacherTopicResultJson(
          categoryScore: 101,
        ),
        'an unknown category': teacherTopicResultJson(
          category: const {'code': 'excellent', 'label': 'Excellent'},
        ),
        'a blank category label': teacherTopicResultJson(
          category: const {'code': 'understood_well', 'label': ' '},
        ),
        'a category with an extra key': teacherTopicResultJson(
          category: const {
            'code': 'understood_well',
            'label': 'Understood well',
            'range': '85-100',
          },
        ),
        'a blank comment': teacherTopicResultJson(teacherComment: '  '),
        'visibility with an extra key': teacherTopicResultJson(
          visibility: {...teacherResultVisibilityJson(), 'extra': true},
        ),
        'an unknown Student release mode': teacherTopicResultJson(
          visibility: teacherResultVisibilityJson(studentMode: 'with_parent'),
        ),
        'an unknown Parent release mode': teacherTopicResultJson(
          visibility: teacherResultVisibilityJson(parentMode: 'automatic'),
        ),
        'a non-boolean visibility': teacherTopicResultJson(
          visibility: {
            ...teacherResultVisibilityJson(),
            'student_visible': 'false',
          },
        ),
        'an invalid release time': teacherTopicResultJson(
          visibility: teacherResultVisibilityJson(
            studentReleasedAt: '2026-10-04T08:00:00+05:00',
          ),
        ),
        'a waiting result visible to the Student': withKey(
          waiting,
          'visibility',
          teacherResultVisibilityJson(studentVisible: true),
        ),
        'a waiting result visible to Parents': withKey(
          waiting,
          'visibility',
          teacherResultVisibilityJson(parentVisible: true),
        ),
        'a closable waiting result': withKey(waiting, 'can_close', true),
        'a closable closed result': withKey(
          closedCalculatedTeacherTopicResultJson(),
          'can_close',
          true,
        ),
        'a non-boolean closable flag': teacherTopicResultJson(canClose: 1),
      };

      for (final MapEntry(key: name, value: json) in cases.entries) {
        expect(
          () => parse(json),
          throwsA(isA<FormatException>()),
          reason: name,
        );
      }
    });
  });

  group('Teacher Topic result detail DTO', () {
    TeacherTopicResultDetail parseDetail(Map<String, Object?> json) =>
        TeacherTopicResultDetailDto.fromJson(json).toDomain();

    test('parses a closed result with its actors and reason', () {
      final detail = parseDetail(
        teacherTopicResultDetailJson(
          item: closedCalculatedTeacherTopicResultJson(),
          commentUpdatedAt: '2026-10-03T07:30:00Z',
          commentUpdatedBy: teacherResultActorJson(),
          studentReleasedBy: teacherResultActorJson(fullName: 'Second Teacher'),
          closedBy: teacherResultActorJson(),
          closureReason: 'teacher',
        ),
      );

      expect(detail.result.status, TeacherTopicResultStatus.closed);
      expect(detail.commentUpdatedAt, DateTime.utc(2026, 10, 3, 7, 30));
      expect(detail.commentUpdatedBy?.id, teacherResultActorId);
      expect(detail.commentUpdatedBy?.fullName, 'Dilnoza Teacher');
      expect(detail.studentReleasedBy?.fullName, 'Second Teacher');
      expect(detail.parentReleasedBy, isNull);
      expect(detail.closedBy?.fullName, 'Dilnoza Teacher');
      expect(detail.closureReason, TeacherTopicResultClosureReason.teacher);
    });

    test('parses an open result without actors', () {
      final detail = parseDetail(teacherTopicResultDetailJson());

      expect(detail.result.status, TeacherTopicResultStatus.calculated);
      expect(detail.closedBy, isNull);
      expect(detail.closureReason, isNull);
      expect(detail.commentUpdatedAt, isNull);
    });

    test('a closed result at Topic archive may have no closing actor', () {
      final detail = parseDetail(
        teacherTopicResultDetailJson(
          item: notCompletedTeacherTopicResultJson(closed: true),
          closureReason: 'topic_archived',
        ),
      );

      expect(
        detail.closureReason,
        TeacherTopicResultClosureReason.topicArchived,
      );
      expect(detail.closedBy, isNull);
    });

    test('rejects malformed details', () {
      final closed = closedCalculatedTeacherTopicResultJson();
      final cases = <String, Map<String, Object?>>{
        'a missing detail key': Map.of(teacherTopicResultDetailJson())
          ..remove('closure_reason'),
        'an unknown detail key': {
          ...teacherTopicResultDetailJson(),
          'extra': null,
        },
        'a closure reason on an open result': teacherTopicResultDetailJson(
          closureReason: 'teacher',
        ),
        'a closing actor on an open result': teacherTopicResultDetailJson(
          closedBy: teacherResultActorJson(),
        ),
        'a closed result without a reason': teacherTopicResultDetailJson(
          item: closed,
        ),
        'an unknown closure reason': teacherTopicResultDetailJson(
          item: closed,
          closureReason: 'admin',
        ),
        'an actor with an extra key': teacherTopicResultDetailJson(
          commentUpdatedBy: {...teacherResultActorJson(), 'role': 'teacher'},
        ),
        'an actor with a blank name': teacherTopicResultDetailJson(
          studentReleasedBy: teacherResultActorJson(fullName: ''),
        ),
        'a non-canonical actor id': teacherTopicResultDetailJson(
          parentReleasedBy: teacherResultActorJson(id: 'teacher-1'),
        ),
        'an invalid comment time': teacherTopicResultDetailJson(
          commentUpdatedAt: 'yesterday',
        ),
      };

      for (final MapEntry(key: name, value: json) in cases.entries) {
        expect(
          () => parseDetail(json),
          throwsA(isA<FormatException>()),
          reason: name,
        );
      }
    });
  });

  group('Teacher Topic result list DTO', () {
    TeacherTopicResultList parseList(
      Map<String, Object?> json, {
      TeacherTopicResultListQuery query = const TeacherTopicResultListQuery(),
    }) => TeacherTopicResultListDto.fromJson(json, query: query).toDomain();

    const secondStudentId = '60000000-0000-0000-0000-000000000002';

    test('parses rows, pagination and the cohort counts', () {
      final list = parseList(
        teacherTopicResultListJson(
          items: [
            teacherTopicResultJson(),
            waitingTeacherTopicResultJson(studentId: secondStudentId),
          ],
          total: 28,
          counts: teacherResultCountsJson(
            waitingForBlitz: 4,
            waitingForTeacherReview: 2,
            calculated: 18,
            notCompleted: 1,
            closed: 3,
          ),
        ),
      );

      expect(list.items.map((item) => item.studentId), [
        teacherResultStudentId,
        secondStudentId,
      ]);
      expect(list.pagination.total, 28);
      expect(list.pagination.lastPage, 2);
      expect(list.counts.total, 28);
      expect(list.counts.of(TeacherTopicResultStatus.calculated), 18);
      expect(list.counts.of(TeacherTopicResultStatus.waitingForHomework), 0);
      expect(list.counts.of(TeacherTopicResultStatus.closed), 3);
    });

    test('parses an empty cohort', () {
      final list = parseList(
        teacherTopicResultListJson(
          items: const [],
          counts: teacherResultCountsJson(),
        ),
      );

      expect(list.items, isEmpty);
      expect(list.counts.total, 0);
    });

    test('parses filtered pages whose rows match the filters', () {
      final byStatus = parseList(
        teacherTopicResultListJson(
          items: [notCompletedTeacherTopicResultJson()],
          counts: teacherResultCountsJson(calculated: 5, notCompleted: 1),
        ),
        query: const TeacherTopicResultListQuery(
          status: TeacherTopicResultStatus.notCompleted,
        ),
      );
      expect(byStatus.items.single.isNotCompleted, isTrue);

      final byCategory = parseList(
        teacherTopicResultListJson(
          items: [notCompletedTeacherTopicResultJson(closed: true)],
          counts: teacherResultCountsJson(calculated: 5, closed: 1),
        ),
        query: const TeacherTopicResultListQuery(
          category: TeacherTopicResultCategoryCode.notCompleted,
        ),
      );
      expect(byCategory.items.single.status, TeacherTopicResultStatus.closed);
    });

    test('rejects malformed lists', () {
      final valid = teacherTopicResultListJson();
      Map<String, Object?> withMeta(Map<String, Object?> meta) => {
        'data': valid['data'],
        'meta': meta,
      };
      final validMeta = valid['meta']! as Map<String, Object?>;
      final cases =
          <String, (Map<String, Object?>, TeacherTopicResultListQuery)>{
            'meta without counts': (
              withMeta({'pagination': validMeta['pagination']}),
              const TeacherTopicResultListQuery(),
            ),
            'meta with links': (
              withMeta({...validMeta, 'links': const <String, Object?>{}}),
              const TeacherTopicResultListQuery(),
            ),
            'counts without a status': (
              withMeta({
                ...validMeta,
                'counts': Map.of(teacherResultCountsJson(calculated: 1))
                  ..remove('closed'),
              }),
              const TeacherTopicResultListQuery(),
            ),
            'a negative count': (
              teacherTopicResultListJson(
                counts: teacherResultCountsJson(calculated: 2, closed: -1),
              ),
              const TeacherTopicResultListQuery(),
            ),
            'a fractional count': (
              withMeta({
                ...validMeta,
                'counts': {...teacherResultCountsJson(), 'calculated': 1.5},
              }),
              const TeacherTopicResultListQuery(),
            ),
            'a total that is not the sum of the counts': (
              teacherTopicResultListJson(
                counts: teacherResultCountsJson(calculated: 2),
              ),
              const TeacherTopicResultListQuery(),
            ),
            'a status total that is not its count': (
              teacherTopicResultListJson(
                counts: teacherResultCountsJson(calculated: 3),
              ),
              const TeacherTopicResultListQuery(
                status: TeacherTopicResultStatus.calculated,
              ),
            ),
            'a category total above every count': (
              teacherTopicResultListJson(
                total: 3,
                counts: teacherResultCountsJson(calculated: 2),
              ),
              const TeacherTopicResultListQuery(
                category: TeacherTopicResultCategoryCode.understoodWell,
              ),
            ),
            'a row outside the status filter': (
              teacherTopicResultListJson(
                counts: teacherResultCountsJson(closed: 1, calculated: 4),
              ),
              const TeacherTopicResultListQuery(
                status: TeacherTopicResultStatus.closed,
              ),
            ),
            'a row outside the category filter': (
              valid,
              const TeacherTopicResultListQuery(
                category: TeacherTopicResultCategoryCode.needsRevision,
              ),
            ),
            'a duplicate Student': (
              teacherTopicResultListJson(
                items: [teacherTopicResultJson(), teacherTopicResultJson()],
              ),
              const TeacherTopicResultListQuery(),
            ),
            'another page than requested': (
              teacherTopicResultListJson(page: 2, total: 26),
              const TeacherTopicResultListQuery(),
            ),
            'a malformed row': (
              teacherTopicResultListJson(
                items: [
                  {...teacherTopicResultJson(), 'extra': 1},
                ],
              ),
              const TeacherTopicResultListQuery(),
            ),
          };

      for (final MapEntry(key: name, value: (json, query)) in cases.entries) {
        expect(
          () => parseList(json, query: query),
          throwsA(isA<FormatException>()),
          reason: name,
        );
      }
    });
  });
}
