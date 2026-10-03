import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/features/student/data/dto/student_topic_result_dto.dart';
import 'package:testlabuz_client/features/student/domain/student_topic_result.dart';

import 'student_test_support.dart';

void main() {
  StudentTopicResult parse(Map<String, Object?> json) =>
      StudentTopicResultDto.fromJson(json).toDomain();

  group('Student Topic result DTO', () {
    test('parses a visible calculated result with every value', () {
      final result = parse(studentTopicResultJson());

      expect(result.topicId, studentTopicId);
      expect(result.status, StudentTopicResultStatus.calculated);
      expect(result.visible, isTrue);
      expect(
        [result.homeworkScore, result.blitzScore, result.finalScore],
        [88.0, 84.0, 86.0],
      );
      expect(result.method, StudentTopicResultMethod.average);
      expect(
        result.category?.code,
        StudentTopicResultCategoryCode.understoodWell,
      );
      expect(result.category?.label, 'Understood well');
      expect(result.teacherComment, 'Revise question 4.');
      expect(result.closedOutcome, isNull);
      expect(result.missingComponent, isNull);
    });

    test('parses hidden results of every status', () {
      for (final (status, outcome, missing) in [
        ('waiting_for_homework', null, null),
        ('waiting_for_blitz', null, null),
        ('waiting_for_teacher_review', null, null),
        ('waiting_for_settings', null, null),
        ('calculated', null, null),
        ('not_completed', null, 'both'),
        ('closed', 'calculated', null),
        ('closed', 'not_completed', 'homework'),
      ]) {
        final result = parse(
          hiddenStudentTopicResultJson(
            status: status,
            closedOutcome: outcome,
            missingComponent: missing,
          ),
        );

        expect(result.visible, isFalse, reason: status);
        expect(result.status.value, status);
        expect(
          [
            result.homeworkScore,
            result.blitzScore,
            result.finalScore,
            result.method,
            result.category,
            result.teacherComment,
          ],
          everyElement(isNull),
          reason: status,
        );
      }
    });

    test('parses visible Not completed results with only the ready side', () {
      final blitzMissing = parse(
        studentTopicResultJson(
          status: 'not_completed',
          missingComponent: 'blitz',
          blitzScore: null,
          finalScore: null,
          method: null,
          category: const {'code': 'not_completed', 'label': 'Not completed'},
          teacherComment: null,
        ),
      );
      expect(
        blitzMissing.missingComponent,
        StudentTopicResultMissingComponent.blitz,
      );
      expect(
        [blitzMissing.homeworkScore, blitzMissing.blitzScore],
        [88.0, null],
      );
      expect(
        blitzMissing.category?.code,
        StudentTopicResultCategoryCode.notCompleted,
      );

      final closedBoth = parse(
        studentTopicResultJson(
          status: 'closed',
          closedOutcome: 'not_completed',
          missingComponent: 'both',
          homeworkScore: null,
          blitzScore: null,
          finalScore: null,
          method: null,
          category: const {'code': 'not_completed', 'label': 'Not completed'},
        ),
      );
      expect(closedBoth.closedOutcome, StudentTopicResultOutcome.notCompleted);
      expect(closedBoth.teacherComment, 'Revise question 4.');
    });

    test('accepts a Not completed result whose other side still waits', () {
      final result = parse(
        studentTopicResultJson(
          status: 'not_completed',
          missingComponent: 'blitz',
          homeworkScore: null,
          blitzScore: null,
          finalScore: null,
          method: null,
          category: const {'code': 'not_completed', 'label': 'Not completed'},
        ),
      );

      expect([result.homeworkScore, result.blitzScore], [null, null]);
      expect(
        result.category?.code,
        StudentTopicResultCategoryCode.notCompleted,
      );
    });

    test('parses a visible closed calculated result with the Blitz method', () {
      final result = parse(
        studentTopicResultJson(
          status: 'closed',
          closedOutcome: 'calculated',
          homeworkScore: 100,
          blitzScore: 80.5,
          finalScore: 80.5,
          method: 'blitz',
          category: const {
            'code': 'partially_understood',
            'label': 'Partially understood',
          },
        ),
      );

      expect(result.closedOutcome, StudentTopicResultOutcome.calculated);
      expect(result.method, StudentTopicResultMethod.blitz);
      expect(result.finalScore, 80.5);
    });

    test('rejects responses that break the result invariants', () {
      final invalid = <String, Map<String, Object?>>{
        'unknown key': studentTopicResultJson()..['score_difference'] = 4,
        'missing key': studentTopicResultJson()..remove('teacher_comment'),
        'bad topic id': studentTopicResultJson(topicId: 'topic-1'),
        'unknown status': studentTopicResultJson(status: 'released'),
        'outcome on an open result': studentTopicResultJson(
          closedOutcome: 'calculated',
        ),
        'closed without outcome': studentTopicResultJson(status: 'closed'),
        'unknown outcome': studentTopicResultJson(
          status: 'closed',
          closedOutcome: 'inconsistent',
        ),
        'missing component on a calculated result': studentTopicResultJson(
          missingComponent: 'blitz',
        ),
        'Not completed without missing component': hiddenStudentTopicResultJson(
          status: 'not_completed',
        ),
        'visible while waiting': studentTopicResultJson(
          status: 'waiting_for_blitz',
        ),
        'visible not a bool': studentTopicResultJson()..['visible'] = 'true',
        'hidden with a score': hiddenStudentTopicResultJson()
          ..['homework_score'] = 88,
        'hidden with a comment': hiddenStudentTopicResultJson()
          ..['teacher_comment'] = 'Hidden.',
        'calculated without a final score': studentTopicResultJson(
          finalScore: null,
        ),
        'calculated without a method': studentTopicResultJson(method: null),
        'calculated without a side score': studentTopicResultJson(
          blitzScore: null,
        ),
        'calculated with the Not completed category': studentTopicResultJson(
          category: const {'code': 'not_completed', 'label': 'Not completed'},
        ),
        'calculated without a category': studentTopicResultJson(category: null),
        'Not completed with a final score': studentTopicResultJson(
          status: 'not_completed',
          missingComponent: 'blitz',
          blitzScore: null,
          method: null,
          category: const {'code': 'not_completed', 'label': 'Not completed'},
        ),
        'Not completed with a numeric category': studentTopicResultJson(
          status: 'not_completed',
          missingComponent: 'blitz',
          blitzScore: null,
          finalScore: null,
          method: null,
        ),
        'Not completed with the missing side scored': studentTopicResultJson(
          status: 'not_completed',
          missingComponent: 'blitz',
          finalScore: null,
          method: null,
          category: const {'code': 'not_completed', 'label': 'Not completed'},
        ),
        'Not completed without Homework but with a Homework score':
            studentTopicResultJson(
              status: 'not_completed',
              missingComponent: 'homework',
              blitzScore: null,
              finalScore: null,
              method: null,
              category: const {
                'code': 'not_completed',
                'label': 'Not completed',
              },
            ),
        'Not completed without both sides but with a Blitz score':
            studentTopicResultJson(
              status: 'not_completed',
              missingComponent: 'both',
              homeworkScore: null,
              finalScore: null,
              method: null,
              category: const {
                'code': 'not_completed',
                'label': 'Not completed',
              },
            ),
        'unknown missing component': hiddenStudentTopicResultJson(
          status: 'not_completed',
          missingComponent: 'quiz',
        ),
        'score above 100': studentTopicResultJson(homeworkScore: 100.5),
        'negative score': studentTopicResultJson(blitzScore: -1),
        'score as text': studentTopicResultJson(finalScore: '86'),
        'unknown method': studentTopicResultJson(method: 'mixed'),
        'category with an extra key': studentTopicResultJson(
          category: const {
            'code': 'understood_well',
            'label': 'Understood well',
            'category_score': 86,
          },
        ),
        'category with a blank label': studentTopicResultJson(
          category: const {'code': 'understood_well', 'label': '  '},
        ),
        'unknown category': studentTopicResultJson(
          category: const {'code': 'excellent', 'label': 'Excellent'},
        ),
        'blank comment': studentTopicResultJson(teacherComment: '   '),
      };

      for (final entry in invalid.entries) {
        expect(
          () => StudentTopicResultDto.fromJson(entry.value),
          throwsFormatException,
          reason: entry.key,
        );
      }
    });
  });
}
