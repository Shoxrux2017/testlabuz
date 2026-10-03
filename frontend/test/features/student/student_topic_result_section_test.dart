import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/student/data/student_topic_repository_impl.dart';
import 'package:testlabuz_client/features/student/domain/student_topic_result.dart';
import 'package:testlabuz_client/features/student/presentation/student_topic_result_section.dart';

import 'student_test_support.dart';

const _notCompleted = StudentTopicResultCategory(
  code: StudentTopicResultCategoryCode.notCompleted,
  label: 'Not completed',
);

void main() {
  group('Student Topic result section', () {
    testWidgets('shows every value of a released calculated result', (
      tester,
    ) async {
      await _pump(tester, studentTopicResult());

      expect(_text(tester), [
        'Topic result',
        'Status: Calculated',
        'Homework score',
        '88.0',
        'Blitz score',
        '84.0',
        'Final score',
        '86.0',
        'The final score is the average of the Homework and Blitz scores.',
        'Category',
        'Understood well',
        "Teacher's comment",
        'Revise question 4.',
        'Refresh result',
      ]);
    });

    testWidgets('a Blitz-method result says so in one neutral line', (
      tester,
    ) async {
      await _pump(
        tester,
        studentTopicResult(
          homeworkScore: 100,
          blitzScore: 80.25,
          finalScore: 80.25,
          method: StudentTopicResultMethod.blitz,
          teacherComment: null,
        ),
      );

      expect(find.text('80.3'), findsNWidgets(2));
      expect(find.text('The final score is the Blitz score.'), findsOneWidget);
      expect(find.text("Teacher's comment"), findsNothing);
      for (final word in ['nconsistent', 'ifference', 'hreshold', 'ccuracy']) {
        expect(find.textContaining(word), findsNothing);
      }
    });

    testWidgets(
      'a hidden outcome is not open yet and is never called incomplete',
      (tester) async {
        for (final (result, status) in [
          (_hidden(StudentTopicResultStatus.calculated), 'Status: Calculated'),
          (
            _hidden(
              StudentTopicResultStatus.closed,
              outcome: StudentTopicResultOutcome.calculated,
            ),
            'Status: Final',
          ),
        ]) {
          await _pump(tester, result);

          expect(find.text(status), findsOneWidget);
          expect(find.text('The result is not open yet.'), findsOneWidget);
          expect(find.textContaining('score'), findsNothing);
          expect(find.textContaining('Not completed'), findsNothing);
        }
      },
    );

    testWidgets('a waiting result shows its status and when scores appear', (
      tester,
    ) async {
      for (final (status, label) in [
        (StudentTopicResultStatus.waitingForHomework, 'Waiting for Homework'),
        (StudentTopicResultStatus.waitingForBlitz, 'Waiting for Blitz'),
        (
          StudentTopicResultStatus.waitingForTeacherReview,
          'Waiting for Teacher review',
        ),
        (StudentTopicResultStatus.waitingForSettings, 'Being prepared'),
      ]) {
        await _pump(tester, _hidden(status));

        expect(find.text('Status: $label'), findsOneWidget);
        expect(
          find.text('Scores appear when the result is ready.'),
          findsOneWidget,
        );
      }
    });

    testWidgets(
      'a Not completed result shows the missing part and the ready side',
      (tester) async {
        await _pump(
          tester,
          studentTopicResult(
            status: StudentTopicResultStatus.notCompleted,
            missingComponent: StudentTopicResultMissingComponent.blitz,
            blitzScore: null,
            finalScore: null,
            method: null,
            category: _notCompleted,
            teacherComment: null,
          ),
        );

        expect(_text(tester), [
          'Topic result',
          'Status: Not completed',
          'Missing: Blitz',
          'Homework score',
          '88.0',
          'Category',
          'Not completed',
          'Refresh result',
        ]);

        await _pump(
          tester,
          studentTopicResult(
            status: StudentTopicResultStatus.closed,
            closedOutcome: StudentTopicResultOutcome.notCompleted,
            missingComponent: StudentTopicResultMissingComponent.both,
            homeworkScore: null,
            blitzScore: null,
            finalScore: null,
            method: null,
            category: _notCompleted,
          ),
        );

        expect(find.text('Status: Not completed (final)'), findsOneWidget);
        expect(find.text('Missing: Homework and Blitz'), findsOneWidget);
        expect(find.text('Revise question 4.'), findsOneWidget);
      },
    );

    testWidgets('a Student without a result is told so', (tester) async {
      await _pump(tester, null);

      expect(find.text('No Topic result is available yet.'), findsOneWidget);
    });

    testWidgets('a failed load offers a retry that loads again', (
      tester,
    ) async {
      var fetches = 0;
      await _pumpWith(
        tester,
        FakeStudentTopicRepository(
          onFetchTopicResult: (_) async {
            fetches += 1;
            if (fetches == 1) {
              throw studentServerFailure(
                ApiErrorCodes.serverError,
                statusCode: 500,
              );
            }
            return studentTopicResult();
          },
        ),
      );

      expect(
        find.text('The Topic result could not be loaded.'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('studentTopicResultRetry')));
      await tester.pump();
      await tester.pump();

      expect(find.text('86.0'), findsOneWidget);
      expect(fetches, 2);
    });

    testWidgets(
      'a retry after a failed first load shows progress, never "no result"',
      (tester) async {
        final retry = Completer<StudentTopicResult?>();
        var fetches = 0;
        await _pumpWith(
          tester,
          FakeStudentTopicRepository(
            onFetchTopicResult: (_) {
              fetches += 1;
              return fetches == 1
                  ? Future.error(
                      studentServerFailure(
                        ApiErrorCodes.serverError,
                        statusCode: 500,
                      ),
                    )
                  : retry.future;
            },
          ),
        );
        await tester.tap(find.byKey(const Key('studentTopicResultRetry')));
        await tester.pump();

        expect(
          find.byKey(const Key('studentTopicResultLoading')),
          findsOneWidget,
        );
        expect(find.text('No Topic result is available yet.'), findsNothing);

        retry.complete(studentTopicResult());
        await tester.pump();
        expect(find.text('86.0'), findsOneWidget);
      },
    );

    testWidgets('a failed refresh keeps a confirmed "no result"', (
      tester,
    ) async {
      var fetches = 0;
      await _pumpWith(
        tester,
        FakeStudentTopicRepository(
          onFetchTopicResult: (_) async {
            fetches += 1;
            if (fetches == 2) {
              throw studentServerFailure(
                ApiErrorCodes.serverError,
                statusCode: 500,
              );
            }
            return null;
          },
        ),
      );
      await tester.tap(find.byKey(const Key('studentTopicResultRefresh')));
      await tester.pump();
      await tester.pump();

      expect(find.text('No Topic result is available yet.'), findsOneWidget);
      expect(
        find.text('The Topic result could not be refreshed.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('studentTopicResultRetry')), findsNothing);
    });

    testWidgets(
      'a Not completed result without Homework shows the Blitz side only',
      (tester) async {
        await _pump(
          tester,
          studentTopicResult(
            status: StudentTopicResultStatus.notCompleted,
            missingComponent: StudentTopicResultMissingComponent.homework,
            homeworkScore: null,
            blitzScore: 70,
            finalScore: null,
            method: null,
            category: _notCompleted,
            teacherComment: null,
          ),
        );

        expect(find.text('Missing: Homework'), findsOneWidget);
        expect(find.text('Homework score'), findsNothing);
        expect(find.text('Blitz score'), findsOneWidget);
        expect(find.text('70.0'), findsOneWidget);
      },
    );

    testWidgets(
      'a hidden Not completed result keeps its status and missing part',
      (tester) async {
        await _pump(
          tester,
          studentTopicResult(
            status: StudentTopicResultStatus.notCompleted,
            missingComponent: StudentTopicResultMissingComponent.blitz,
            visible: false,
            homeworkScore: null,
            blitzScore: null,
            finalScore: null,
            method: null,
            category: null,
            teacherComment: null,
          ),
        );

        expect(_text(tester), [
          'Topic result',
          'Status: Not completed',
          'Missing: Blitz',
          'The result is not open yet.',
          'Refresh result',
        ]);
      },
    );

    testWidgets('Refresh reloads the result', (tester) async {
      var fetches = 0;
      await _pumpWith(
        tester,
        FakeStudentTopicRepository(
          onFetchTopicResult: (_) async {
            fetches += 1;
            return studentTopicResult(finalScore: fetches == 1 ? 86 : 90);
          },
        ),
      );

      await tester.tap(find.byKey(const Key('studentTopicResultRefresh')));
      await tester.pump();
      await tester.pump();

      expect(find.text('90.0'), findsOneWidget);
    });

    testWidgets('fits a narrow phone with large text', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await _pump(tester, studentTopicResult(), textScale: 2);

      expect(tester.takeException(), isNull);
      expect(find.text('Understood well'), findsOneWidget);
    });
  });
}

StudentTopicResult _hidden(
  StudentTopicResultStatus status, {
  StudentTopicResultOutcome? outcome,
}) {
  return studentTopicResult(
    status: status,
    closedOutcome: outcome,
    visible: false,
    homeworkScore: null,
    blitzScore: null,
    finalScore: null,
    method: null,
    category: null,
    teacherComment: null,
  );
}

List<String> _text(WidgetTester tester) {
  return tester
      .widgetList<Text>(
        find.descendant(
          of: find.byKey(const Key('studentTopicResultSection')),
          matching: find.byType(Text),
        ),
      )
      .map((text) => text.data ?? text.textSpan?.toPlainText() ?? '')
      .toList();
}

Future<void> _pump(
  WidgetTester tester,
  StudentTopicResult? result, {
  double textScale = 1,
}) {
  return _pumpWith(
    tester,
    FakeStudentTopicRepository(onFetchTopicResult: (_) async => result),
    textScale: textScale,
  );
}

Future<void> _pumpWith(
  WidgetTester tester,
  FakeStudentTopicRepository repository, {
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        authSessionControllerProvider.overrideWith(
          () => FakeStudentAuthSessionController.authenticated(
            studentUser('student-a'),
          ),
        ),
        appDeviceSurfaceProvider.overrideWithValue(AppDeviceSurface.mobile),
        studentTopicRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: const Scaffold(
            body: SingleChildScrollView(
              child: StudentTopicResultSection(topicId: studentTopicId),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}
