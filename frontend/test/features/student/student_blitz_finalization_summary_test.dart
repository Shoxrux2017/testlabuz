import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/features/student/domain/student_attempt_answer.dart';
import 'package:testlabuz_client/features/student/domain/student_blitz_attempt.dart';
import 'package:testlabuz_client/features/student/domain/student_question.dart';
import 'package:testlabuz_client/features/student/presentation/student_blitz_finalization_summary.dart';

import 'student_blitz_execution_test_support.dart';
import 'student_blitz_test_support.dart';

void main() {
  for (final (name, attempt, confirmedBySubmit, heading, lines, note) in [
    (
      'a fresh Student Submit',
      _attempt(StudentBlitzAttemptStatus.submitted),
      true,
      'Submitted',
      ['Your Blitz attempt has been submitted.'],
      'Blitz submitted successfully.',
    ),
    (
      'a Student Submit found by a replay',
      _attempt(StudentBlitzAttemptStatus.submitted),
      false,
      'Submitted',
      ['Your Blitz attempt has been submitted.'],
      'This Blitz attempt is already submitted.',
    ),
    (
      'a timeout',
      _attempt(
        StudentBlitzAttemptStatus.timedOutFinalized,
        reason: StudentBlitzAttemptFinalizationReason.timeout,
      ),
      false,
      'Time expired',
      [
        'The server finalized the answers that were saved before the deadline.',
        'Unanswered Questions remain unanswered.',
      ],
      null,
    ),
    (
      'a Teacher close',
      _attempt(
        StudentBlitzAttemptStatus.submitted,
        reason: StudentBlitzAttemptFinalizationReason.taskClosed,
      ),
      false,
      'Blitz closed',
      [
        'The Teacher closed the Blitz.',
        'The answers saved before finalization were preserved.',
      ],
      null,
    ),
    (
      'a waiting Attempt',
      _attempt(StudentBlitzAttemptStatus.waitingForReview),
      true,
      'Finalized',
      ['Some answers may require Teacher review.'],
      'Blitz submission confirmed.',
    ),
    (
      'a checked Attempt',
      _attempt(StudentBlitzAttemptStatus.checked),
      false,
      'Finalized',
      <String>[],
      'This Blitz attempt is already submitted.',
    ),
  ]) {
    testWidgets('$name has its own copy and no score', (tester) async {
      await _pump(tester, attempt, confirmedBySubmit: confirmedBySubmit);
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('studentBlitzFinalizationHeading')),
            )
            .data,
        heading,
      );
      for (final line in lines) {
        expect(find.text(line), findsOneWidget);
      }
      if (note == null) {
        expect(
          find.byKey(const Key('studentBlitzSubmitOutcome')),
          findsNothing,
        );
      } else {
        expect(find.text(note), findsOneWidget);
      }
      for (final forbidden in [
        'score',
        'Score',
        'points',
        'Points',
        'correct',
        'Correct',
        'Checking',
        'marked wrong',
        'Waiting for Teacher review',
      ]) {
        expect(find.textContaining(forbidden), findsNothing);
      }
    });
  }

  testWidgets('counts only persisted answers for Attempt #1', (tester) async {
    await _pump(
      tester,
      _attempt(
        StudentBlitzAttemptStatus.submitted,
        answers: [
          blitzSavedAnswer(
            1,
            StudentQuestionType.trueFalse,
            const StudentBooleanAnswerValue(value: true),
          ),
          blitzSavedAnswer(
            3,
            StudentQuestionType.fileBased,
            StudentFileAnswerValue(file: blitzServerFile()),
          ),
        ],
      ),
    );
    expect(find.text('Attempt 1'), findsOneWidget);
    expect(find.text('2 of 3'), findsOneWidget);
    expect(find.text('Unanswered'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('Submitted by you'), findsOneWidget);
    expect(find.text('Finalized at'), findsOneWidget);
  });

  testWidgets('labels the approved additional Attempt #2', (tester) async {
    await _pump(
      tester,
      studentBlitzAttempt(
        id: studentBlitzReplacementAttemptId,
        attemptNumber: 2,
        status: StudentBlitzAttemptStatus.timedOutFinalized,
        finalizationReason: StudentBlitzAttemptFinalizationReason.timeout,
      ),
    );
    expect(find.text('Additional attempt (Attempt 2)'), findsOneWidget);
    expect(find.text('0 of 2'), findsOneWidget);
    expect(find.text('Time expired'), findsWidgets);
  });

  testWidgets('the reason is a semantic heading', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, _attempt(StudentBlitzAttemptStatus.submitted));
    final heading = tester.widget<Semantics>(
      find
          .ancestor(
            of: find.byKey(const Key('studentBlitzFinalizationHeading')),
            matching: find.byType(Semantics),
          )
          .first,
    );
    expect(heading.properties.header, isTrue);
    semantics.dispose();
  });
}

StudentBlitzAttempt _attempt(
  StudentBlitzAttemptStatus status, {
  StudentBlitzAttemptFinalizationReason reason =
      StudentBlitzAttemptFinalizationReason.studentSubmit,
  List<StudentAttemptAnswerState> answers = const [],
}) => blitzExecutionAttempt(
  status: status,
  finalizationReason: reason,
  answers: answers,
);

Future<void> _pump(
  WidgetTester tester,
  StudentBlitzAttempt attempt, {
  bool confirmedBySubmit = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: StudentBlitzFinalizationSummary(
            attempt: attempt,
            timezone: 'Asia/Tashkent',
            confirmedBySubmit: confirmedBySubmit,
          ),
        ),
      ),
    ),
  );
}
