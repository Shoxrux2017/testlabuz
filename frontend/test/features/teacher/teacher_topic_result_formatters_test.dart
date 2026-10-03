import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_topic_result.dart';
import 'package:testlabuz_client/features/teacher/presentation/teacher_topic_result_formatters.dart';

import 'teacher_topic_result_test_support.dart';

void main() {
  test('every status has its Teacher label', () {
    expect(TeacherTopicResultStatus.values.map(teacherTopicResultStatusLabel), [
      'Waiting for Homework',
      'Waiting for Blitz',
      'Waiting for review',
      'Waiting for result settings',
      'Calculated',
      'Not completed',
      'Closed',
    ]);
  });

  test('every side state has its label', () {
    expect(
      TeacherTopicResultSideState.values.map(teacherTopicResultSideStateLabel),
      [
        'Ready',
        'Waiting for review',
        'Checking',
        'Not activated',
        'Open',
        'Missing',
        'No official Blitz',
      ],
    );
  });

  test('missing components, methods and closure reasons are named', () {
    expect(
      TeacherTopicResultMissingComponent.values.map(
        teacherTopicResultMissingLabel,
      ),
      ['Missing: Homework', 'Missing: Blitz', 'Missing: Homework and Blitz'],
    );
    expect(TeacherTopicResultMethod.values.map(teacherTopicResultMethodLabel), [
      'Average of both scores',
      'Blitz score',
    ]);
    expect(
      TeacherTopicResultClosureReason.values.map(
        teacherTopicResultClosureReasonLabel,
      ),
      ['Closed by the Teacher', 'Closed when the Topic was archived'],
    );
  });

  test('release modes include the unconfigured state', () {
    expect(
      [
        ...TeacherStudentResultReleaseMode.values,
        null,
      ].map(teacherStudentReleaseModeLabel),
      ['Automatic', 'Manual by the Teacher', 'Not configured'],
    );
    expect(
      [
        ...TeacherParentResultReleaseMode.values,
        null,
      ].map(teacherParentReleaseModeLabel),
      [
        'With the Student',
        'Manual by the Teacher',
        'Hidden from Parents',
        'Not configured',
      ],
    );
  });

  test('the category filter labels match the server labels', () {
    expect(
      TeacherTopicResultCategoryCode.values.map(
        teacherTopicResultCategoryFilterLabel,
      ),
      [
        'Understood well',
        'Partially understood',
        'Needs revision',
        'Needs teacher support',
        'Not completed',
      ],
    );
  });

  test('the scores line rounds each present score to one decimal', () {
    final result = teacherTopicResult(
      teacherTopicResultJson(
        homework: teacherResultSideJson(score: 86.15),
        blitz: teacherResultBlitzSideJson(score: 84.04999999),
        scoreDifference: 2.10000001,
        finalScore: 85.09999999,
        categoryScore: 85,
      ),
    );

    expect(
      teacherTopicResultScoresLine(result),
      'Homework 86.2 · Blitz 84.0 · Final 85.1',
    );
    expect(
      teacherTopicResultScoresLine(
        teacherTopicResult(
          waitingTeacherTopicResultJson(
            homeworkState: 'open',
            blitzState: 'not_activated',
            status: 'waiting_for_homework',
          ),
        ),
      ),
      isNull,
    );
  });
}
