import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/app/router/app_route_paths.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/student/application/student_attempt_answer_editor_controller.dart';
import 'package:testlabuz_client/features/student/application/student_attempt_answer_editor_state.dart';
import 'package:testlabuz_client/features/student/application/student_homework_attempt_controller.dart';
import 'package:testlabuz_client/features/student/application/student_homework_attempt_state.dart';
import 'package:testlabuz_client/features/student/application/student_homework_detail_controller.dart';
import 'package:testlabuz_client/features/student/application/student_homework_detail_state.dart';
import 'package:testlabuz_client/features/student/data/student_homework_attempt_repository_impl.dart';
import 'package:testlabuz_client/features/student/domain/student_answer_draft.dart';
import 'package:testlabuz_client/features/student/domain/student_answer_mutation.dart';
import 'package:testlabuz_client/features/student/domain/student_homework.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_attempt.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_attempt_repository.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_attempt_route_target.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_route_target.dart';
import 'package:testlabuz_client/features/student/domain/student_question.dart';
import 'package:testlabuz_client/features/student/presentation/student_attempt_answer_read_view.dart';
import 'package:testlabuz_client/features/student/presentation/student_homework_attempt_screen.dart';
import 'package:testlabuz_client/features/student/presentation/student_fill_blank_answer_editor.dart';
import 'package:testlabuz_client/features/student/presentation/student_matching_answer_editor.dart';
import 'package:testlabuz_client/features/student/presentation/student_ordering_answer_editor.dart';
import 'package:testlabuz_client/features/student/presentation/student_question_answer_editor.dart';

import 'student_test_support.dart';

const _homeworkId = '40000000-0000-0000-0000-000000000001';
const _attemptId = '60000000-0000-0000-0000-000000000001';
final _target = StudentHomeworkAttemptRouteTarget(
  topicId: studentTopicId,
  homeworkId: _homeworkId,
  attemptId: _attemptId,
);
final _parentTarget = StudentHomeworkRouteTarget(
  topicId: studentTopicId,
  homeworkId: _homeworkId,
);
String _id(int value) =>
    '70000000-0000-0000-0000-${value.toString().padLeft(12, '0')}';
String _questionId(int position) => _id(100 + position);
Finder _card(int position) =>
    find.byKey(ValueKey('studentAnswerEditor${_questionId(position)}'));
Finder _inside(int position, Finder matching) =>
    find.descendant(of: _card(position), matching: matching);
Finder _save(int position) =>
    find.byKey(ValueKey('studentSaveAnswer${_questionId(position)}'));

void main() {
  for (final surface in [AppDeviceSurface.desktop, AppDeviceSurface.mobile]) {
    testWidgets('${surface.name} renders exactly eight accessible editors', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        final harness = await _pump(tester, surface: surface);
        expect(find.byType(StudentQuestionAnswerEditor), findsNWidgets(8));
        expect(find.byType(StudentAttemptAnswerReadView), findsOneWidget);
        expect(find.text('Save answer'), findsNWidgets(8));
        expect(find.text('Clear answer'), findsNWidgets(6));
        expect(find.text('Select up to 2.'), findsOneWidget);
        expect(find.text('Selected: 0 / 2'), findsOneWidget);
        expect(find.text('Blank: first'), findsOneWidget);
        expect(find.text('Blank: second'), findsOneWidget);
        expect(find.text('Not matched'), findsNWidgets(2));
        expect(find.text('Unassigned'), findsNWidgets(2));
        expect(find.text('Match: Left A'), findsOneWidget);
        expect(find.text('Position: Item A'), findsOneWidget);
        expect(find.text('Question 4: Short answer'), findsOneWidget);
        _expectNoSaveEnabled(tester);
        for (final label in [
          'Upload file',
          'Download',
          'Submit',
          'Score',
          'Correct answer',
        ]) {
          expect(find.text(label), findsNothing);
        }
        await _tap(tester, _inside(1, find.text('Single A')));
        expect(harness.editorState.questions[_questionId(1)]!.isDirty, isTrue);
        expect(
          tester
              .getSemantics(
                _inside(1, find.byType(RadioListTile<String>)).first,
              )
              .label,
          contains('Single A'),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        expect(FocusManager.instance.primaryFocus, isNotNull);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    });

    testWidgets(
      '${surface.name} Single and True save selection without clear',
      (tester) async {
        final harness = await _pump(tester, surface: surface);
        await _tap(tester, _inside(1, find.text('Single B')));
        expect(_inside(1, find.text('Clear answer')), findsNothing);
        await _tap(tester, _save(1));
        expect(
          harness.repository.saves.single.mutation,
          isA<StudentSingleChoiceMutation>().having(
            (value) => value.selectedOptionId,
            'option',
            _id(2),
          ),
        );
        expect(_inside(1, find.text('Saving…')), findsOneWidget);
        expect(
          _inside(1, find.byType(LinearProgressIndicator)),
          findsOneWidget,
        );
        _expectNoSaveEnabled(tester);
        expect(
          tester
              .widget<RadioListTile<String>>(
                _inside(1, find.byType(RadioListTile<String>)).first,
              )
              .enabled,
          isFalse,
        );
        harness.repository.saves.single.complete(
          StudentChoiceAnswerValue(selectedOptionIds: [_id(2)]),
        );
        await tester.pumpAndSettle();
        expect(_inside(1, find.text('Saved')), findsOneWidget);
        expect(_inside(1, find.textContaining('Last saved:')), findsOneWidget);
        await _tap(tester, _inside(3, find.text('False')));
        expect(_inside(3, find.text('Clear answer')), findsNothing);
        await _tap(tester, _save(3));
        expect(
          harness.repository.saves.last.mutation,
          isA<StudentTrueFalseMutation>().having(
            (value) => value.value,
            'value',
            false,
          ),
        );
        harness.repository.saves.last.complete(
          const StudentBooleanAnswerValue(value: false),
        );
        await tester.pumpAndSettle();
        expect(_inside(3, find.text('Saved')), findsOneWidget);
        expect(harness.parent.refreshes, 2);
      },
    );

    testWidgets(
      '${surface.name} Multiple cap deselect and explicit Save clear',
      (tester) async {
        final harness = await _pump(tester, surface: surface);
        await _tap(tester, _inside(2, find.text('Multiple A')));
        await _tap(tester, _inside(2, find.text('Multiple B')));
        final optionC = _inside(
          2,
          find.byKey(ValueKey('studentOption${_id(5)}')),
        );
        expect(tester.widget<CheckboxListTile>(optionC).onChanged, isNull);
        expect(find.text('Selected: 2 / 2'), findsOneWidget);
        await _tap(tester, _inside(2, find.text('Multiple A')));
        expect(tester.widget<CheckboxListTile>(optionC).onChanged, isNotNull);
        await _tap(tester, _save(2));
        harness.repository.saves.single.complete(
          StudentChoiceAnswerValue(selectedOptionIds: [_id(4)]),
        );
        await tester.pumpAndSettle();
        await _tap(tester, _inside(2, find.text('Clear answer')));
        expect(harness.repository.saves, hasLength(1));
        expect(find.text('Selected: 0 / 2'), findsOneWidget);
        await _tap(tester, _save(2));
        expect(
          (harness.repository.saves.last.mutation
                  as StudentMultipleChoiceMutation)
              .selectedOptionIds,
          isEmpty,
        );
        harness.repository.saves.last.complete(null);
        await tester.pumpAndSettle();
        expect(harness.editorState.questions[_questionId(2)]!.isDirty, isFalse);
      },
    );

    testWidgets(
      '${surface.name} written exact text validation clear and discard',
      (tester) async {
        final harness = await _pump(tester, surface: surface);
        for (final position in [4, 5]) {
          final field = _inside(position, find.byType(TextField));
          await _enter(tester, field, '  Exact Student text\nnext line  ');
          await _tap(tester, _save(position));
          final mutation = harness.repository.saves.last.mutation;
          final sent = switch (mutation) {
            StudentShortWrittenMutation(:final text) => text,
            StudentOpenWrittenMutation(:final text) => text,
            _ => throw StateError('Expected a written mutation.'),
          };
          expect(sent, '  Exact Student text\nnext line  ');
          harness.repository.saves.last.complete(
            StudentTextAnswerValue(text: sent),
          );
          await tester.pumpAndSettle();
          await _enter(tester, field, 'changed');
          await _tap(tester, _inside(position, find.text('Discard changes')));
          expect(tester.widget<TextField>(field).controller!.text, sent);
          final maximum = position == 4 ? 1000 : 20000;
          await _enter(tester, field, 'x' * (maximum + 1));
          expect(
            tester.widget<TextField>(field).decoration!.errorText,
            isNotNull,
          );
          expect(
            tester.widget<FilledButton>(_save(position)).onPressed,
            isNull,
          );
          await _tap(tester, _inside(position, find.text('Clear answer')));
          expect(tester.widget<TextField>(field).controller!.text, '');
          expect(
            tester.widget<FilledButton>(_save(position)).onPressed,
            isNotNull,
          );
        }
      },
    );

    testWidgets(
      '${surface.name} Matching partial assignments prevent duplicate rights',
      (tester) async {
        final harness = await _pump(tester, surface: surface);
        final first = find.byKey(ValueKey('studentMatching${_id(6)}'));
        final second = find.byKey(ValueKey('studentMatching${_id(7)}'));
        await _tap(tester, first);
        await _tap(tester, find.text('Right B').last);
        final next = tester.widget<DropdownButton<String>>(second);
        expect(
          next.items!.singleWhere((item) => item.value == _id(9)).enabled,
          isFalse,
        );
        await _tap(tester, _save(7));
        expect(
          (harness.repository.saves.single.mutation as StudentMatchingMutation)
              .pairs,
          hasLength(1),
        );
        harness.repository.saves.single.complete(
          StudentMatchingAnswerValue(
            pairs: [
              StudentMatchingAnswerPair(
                leftItemId: _id(6),
                rightItemId: _id(9),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();
        await _tap(tester, _inside(7, find.text('Clear answer')));
        expect(tester.widget<DropdownButton<String>>(first).value, '');
        expect(harness.repository.saves, hasLength(1));
        expect(tester.widget<FilledButton>(_save(7)).onPressed, isNotNull);
      },
    );

    testWidgets(
      '${surface.name} Ordering partial assignments prevent duplicate positions',
      (tester) async {
        final harness = await _pump(tester, surface: surface);
        final first = find.byKey(ValueKey('studentOrdering${_id(10)}'));
        final second = find.byKey(ValueKey('studentOrdering${_id(11)}'));
        await _tap(tester, first);
        await _tap(tester, find.text('2').last);
        expect(
          tester
              .widget<DropdownButton<int>>(second)
              .items!
              .singleWhere((item) => item.value == 2)
              .enabled,
          isFalse,
        );
        await _tap(tester, _save(8));
        final mutation =
            harness.repository.saves.single.mutation as StudentOrderingMutation;
        expect(mutation.items, hasLength(1));
        expect(mutation.items.single.position, 2);
        harness.repository.saves.single.complete(
          StudentOrderingAnswerValue(items: mutation.items),
        );
        await tester.pumpAndSettle();
        await _tap(tester, _inside(8, find.text('Clear answer')));
        expect(tester.widget<DropdownButton<int>>(first).value, 0);
        expect(tester.widget<FilledButton>(_save(8)).onPressed, isNotNull);
        expect(harness.repository.saves, hasLength(1));
      },
    );

    testWidgets(
      '${surface.name} Fill fields preserve partial text and show long-value error',
      (tester) async {
        final harness = await _pump(tester, surface: surface);
        final fields = _inside(9, find.byType(TextField));
        expect(
          tester.widget<TextField>(fields.first).decoration!.labelText,
          'Blank: first',
        );
        await _enter(tester, fields.first, '  Exact blank  ');
        await _enter(tester, fields.last, '   ');
        await _tap(tester, _save(9));
        final mutation =
            harness.repository.saves.single.mutation
                as StudentFillBlankMutation;
        expect(mutation.values, hasLength(1));
        expect(mutation.values.single.text, '  Exact blank  ');
        harness.repository.saves.single.complete(
          StudentFillBlankAnswerValue(values: mutation.values),
        );
        await tester.pumpAndSettle();
        await _enter(tester, fields.first, 'x' * 1001);
        expect(
          tester.widget<TextField>(fields.first).decoration!.errorText,
          contains('1000'),
        );
        expect(tester.widget<FilledButton>(_save(9)).onPressed, isNull);
        await _tap(tester, _inside(9, find.text('Clear answer')));
        expect(tester.widget<TextField>(fields.first).controller!.text, '');
        expect(tester.widget<TextField>(fields.last).controller!.text, '');
        expect(harness.repository.saves, hasLength(1));
      },
    );
  }

  testWidgets(
    'deterministic failure keeps draft and accessible safe feedback',
    (tester) async {
      final harness = await _pump(tester);
      await _enter(tester, _inside(4, find.byType(TextField)), 'draft');
      await _tap(tester, _save(4));
      harness.repository.saves.single.completer.completeError(
        studentServerFailure(ApiErrorCodes.validationFailed, statusCode: 422),
      );
      await tester.pumpAndSettle();
      expect(_inside(4, find.text('Could not save answer')), findsOneWidget);
      expect(find.textContaining('Raw server failure'), findsNothing);
      expect(
        tester
            .widget<TextField>(_inside(4, find.byType(TextField)))
            .controller!
            .text,
        'draft',
      );
      expect(tester.widget<FilledButton>(_save(4)).onPressed, isNotNull);
    },
  );

  testWidgets(
    'uncertainty has one owned Reload recovery and retains other drafts',
    (tester) async {
      final harness = await _pump(tester);
      await _enter(tester, _inside(5, find.byType(TextField)), 'other draft');
      await _makeUncertain(tester, harness);
      expect(_inside(4, find.text('Save result unconfirmed')), findsOneWidget);
      expect(
        _inside(
          4,
          find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
        ),
        findsOneWidget,
      );
      expect(find.text('Reload attempt'), findsOneWidget);
      expect(find.text('Retry Save'), findsNothing);
      expect(
        tester.widget<TextField>(_inside(4, find.byType(TextField))).enabled,
        isFalse,
      );
      expect(
        tester.widget<TextField>(_inside(5, find.byType(TextField))).enabled,
        isTrue,
      );
      _expectNoSaveEnabled(tester);
      harness.parent.publish(_attempt());
      await tester.pumpAndSettle();
      expect(find.text('Save result unconfirmed'), findsOneWidget);
      harness.repository.nextFetch = Completer<StudentHomeworkAttempt>();
      await _tap(tester, find.text('Reload attempt'), settle: false);
      expect(harness.repository.fetches, [_attemptId]);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Reload attempt'),
            )
            .onPressed,
        isNull,
      );
      _expectNoSaveEnabled(tester);
      harness.repository.nextFetch!.complete(
        _attempt(answers: [_textAnswer('pending')]),
      );
      await tester.pumpAndSettle();
      expect(_inside(4, find.text('Saved')), findsOneWidget);
      expect(
        tester
            .widget<TextField>(_inside(5, find.byType(TextField)))
            .controller!
            .text,
        'other draft',
      );
      expect(harness.repository.saves, hasLength(1));
    },
  );

  testWidgets(
    'ordinary refresh removing the uncertain Question retains recovery controls',
    (tester) async {
      final harness = await _pump(tester);
      await _makeUncertain(tester, harness);
      harness.parent.publish(
        _attempt(
          questions: _questions()
              .where((question) => question.id != _questionId(4))
              .toList(),
        ),
      );
      await tester.pumpAndSettle();
      expect(_inside(4, find.text('Save result unconfirmed')), findsOneWidget);
      expect(find.text('Reload attempt'), findsOneWidget);
      expect(
        tester.widget<TextField>(_inside(4, find.byType(TextField))).enabled,
        isFalse,
      );
      expect(harness.repository.saves, hasLength(1));
    },
  );

  for (final status in StudentHomeworkAttemptLoadStatus.values.where(
    (status) => status != StudentHomeworkAttemptLoadStatus.data,
  )) {
    testWidgets('${status.name} retained parent cannot authorize Save', (
      tester,
    ) async {
      final harness = await _pump(tester);
      await _enter(
        tester,
        _inside(4, find.byType(TextField)),
        'retained draft',
      );
      harness.parent.publishState(
        StudentHomeworkAttemptState(
          status: status,
          attempt: _attempt(),
          failure: status == StudentHomeworkAttemptLoadStatus.error
              ? studentLocalFailure(ApiFailureKind.connection).failure
              : null,
        ),
      );
      await tester.pump();
      _expectNoSaveEnabled(tester);
      expect(harness.repository.saves, isEmpty);
      if (status == StudentHomeworkAttemptLoadStatus.error) {
        expect(harness.editorState.terminalAttempt, isNull);
        expect(find.text('Unable to load Attempt'), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);
        expect(find.byType(StudentQuestionAnswerEditor), findsNothing);
      }
      harness.parent.publish(_attempt());
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(_inside(4, find.byType(TextField)))
            .controller!
            .text,
        'retained draft',
      );
      expect(tester.widget<FilledButton>(_save(4)).onPressed, isNotNull);
    });
  }

  for (final invalidAttempt in [
    null,
    _attempt(id: _id(99)),
    _attempt(homeworkId: _id(99)),
  ]) {
    testWidgets(
      'null or mismatched route Attempt cannot expose Save ${invalidAttempt?.id}/${invalidAttempt?.assessmentId}',
      (tester) async {
        final harness = await _pump(tester);
        harness.parent.publishState(
          StudentHomeworkAttemptState(
            status: StudentHomeworkAttemptLoadStatus.data,
            attempt: invalidAttempt,
          ),
        );
        await tester.pump();
        _expectNoSaveEnabled(tester);
        expect(harness.repository.saves, isEmpty);
      },
    );
  }

  testWidgets('ineligible Student session removes editing authority', (
    tester,
  ) async {
    final harness = await _pump(tester);
    await _enter(tester, _inside(4, find.byType(TextField)), 'old draft');
    harness.auth.logOut();
    await tester.pump();
    _expectNoSaveEnabled(tester);
    expect(find.byType(StudentQuestionAnswerEditor), findsNothing);
    expect(harness.repository.saves, isEmpty);
  });

  testWidgets(
    'confirmed terminal Attempt survives refresh failure with stale in-progress data',
    (tester) async {
      final harness = await _pump(tester);
      final retainedAttempt = harness.container
          .read(studentHomeworkAttemptControllerProvider(_target))
          .attempt!;
      expect(retainedAttempt.status, StudentHomeworkAttemptStatus.inProgress);
      expect(find.byType(StudentQuestionAnswerEditor), findsNWidgets(8));
      await _enter(tester, _inside(4, find.byType(TextField)), 'unsaved draft');
      expect(harness.editorState.hasDirtyDrafts, isTrue);
      expect(tester.widget<FilledButton>(_save(4)).onPressed, isNotNull);

      final terminalAttempt = _attempt(
        status: StudentHomeworkAttemptStatus.submitted,
        answers: [_textAnswer('confirmed terminal server answer')],
      );
      harness.parent.publish(terminalAttempt);
      await tester.pumpAndSettle();

      void expectTerminalReadOnly() {
        expect(harness.editorState.terminalAttempt, same(terminalAttempt));
        expect(find.text('confirmed terminal server answer'), findsOneWidget);
        expect(
          tester
              .widget<Text>(
                find.byKey(const Key('studentHomeworkAttemptStatus')),
              )
              .data,
          'Submitted',
        );
        expect(find.byType(StudentAttemptAnswerReadView), findsNWidgets(9));
        expect(find.text('Unable to load Attempt'), findsNothing);
        expect(find.byType(StudentQuestionAnswerEditor), findsNothing);
        expect(find.text('Save answer'), findsNothing);
        expect(find.text('unsaved draft'), findsNothing);
        expect(harness.editorState.hasDirtyDrafts, isFalse);
        expect(harness.editorState.hasUncertainMutation, isFalse);
        expect(harness.editorState.canEdit(_questionId(4)), isFalse);
        expect(harness.editorState.canSave(_questionId(4)), isFalse);
        expect(harness.repository.saves, isEmpty);
      }

      expectTerminalReadOnly();
      for (final status in [
        StudentHomeworkAttemptLoadStatus.data,
        StudentHomeworkAttemptLoadStatus.refreshing,
        StudentHomeworkAttemptLoadStatus.error,
      ]) {
        harness.parent.publishState(
          StudentHomeworkAttemptState(
            status: status,
            attempt: retainedAttempt,
            failure: status == StudentHomeworkAttemptLoadStatus.error
                ? studentLocalFailure(ApiFailureKind.connection).failure
                : null,
          ),
        );
        await tester.pumpAndSettle();
        expectTerminalReadOnly();
      }
    },
  );

  for (final uncertain in [false, true]) {
    testWidgets(
      'terminal refresh removes ${uncertain ? 'uncertain GET' : 'active PUT'} and ignores late result',
      (tester) async {
        final harness = await _pump(tester);
        await _enter(
          tester,
          _inside(5, find.byType(TextField)),
          'other unsaved',
        );
        if (uncertain) {
          await _makeUncertain(tester, harness);
          harness.repository.nextFetch = Completer<StudentHomeworkAttempt>();
          await _tap(tester, find.text('Reload attempt'), settle: false);
        } else {
          await _enter(tester, _inside(4, find.byType(TextField)), 'pending');
          await _tap(tester, _save(4), settle: false);
        }
        harness.parent.publish(
          _attempt(
            status: StudentHomeworkAttemptStatus.submitted,
            answers: [_textAnswer('authoritative terminal answer')],
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(StudentQuestionAnswerEditor), findsNothing);
        expect(find.text('authoritative terminal answer'), findsOneWidget);
        expect(harness.editorState.hasDirtyDrafts, isFalse);
        expect(harness.editorState.hasUncertainMutation, isFalse);
        if (uncertain) {
          harness.repository.nextFetch!.complete(
            _attempt(answers: [_textAnswer('late answer')]),
          );
        } else {
          harness.repository.saves.single.complete(
            const StudentTextAnswerValue(text: 'late answer'),
          );
        }
        await tester.pumpAndSettle();
        expect(find.text('authoritative terminal answer'), findsOneWidget);
        expect(find.text('late answer'), findsNothing);
        expect(find.text('Score'), findsNothing);
        expect(harness.repository.saves, hasLength(1));
      },
    );
  }

  testWidgets('dirty Back Stay retains draft and Leave discards without Save', (
    tester,
  ) async {
    final harness = await _pump(tester, routed: true);
    await _enter(tester, _inside(4, find.byType(TextField)), 'keep me');
    await _tap(tester, find.byTooltip('Back to Homework'));
    expect(
      find.textContaining('You have unsaved answer changes.'),
      findsOneWidget,
    );
    await _tap(tester, find.text('Stay'));
    expect(
      tester
          .widget<TextField>(_inside(4, find.byType(TextField)))
          .controller!
          .text,
      'keep me',
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Leave Attempt?'), findsOneWidget);
    await _tap(tester, find.text('Leave'));
    expect(find.text('Homework destination'), findsOneWidget);
    expect(harness.repository.saves, isEmpty);
  });

  testWidgets('uncertain Back warns and Leave clears pending local operation', (
    tester,
  ) async {
    final harness = await _pump(tester, routed: true);
    final subscription = harness.container.listen(
      studentAttemptAnswerEditorControllerProvider(_target),
      (_, _) {},
    );
    addTearDown(subscription.close);
    await _makeUncertain(tester, harness);
    await _tap(tester, find.byTooltip('Back to Homework'));
    expect(
      find.textContaining('A save result is still unconfirmed.'),
      findsOneWidget,
    );
    await _tap(tester, find.text('Leave'));
    expect(find.text('Homework destination'), findsOneWidget);
    expect(subscription.read().pendingMutationSnapshot, isNull);
    expect(subscription.read().hasUncertainMutation, isFalse);
    expect(harness.repository.saves, hasLength(1));
  });

  testWidgets('clean Back returns directly without confirmation', (
    tester,
  ) async {
    final harness = await _pump(tester, routed: true);
    await _tap(tester, find.byTooltip('Back to Homework'));
    expect(find.text('Leave Attempt?'), findsNothing);
    expect(find.text('Homework destination'), findsOneWidget);
    expect(harness.repository.saves, isEmpty);
  });

  testWidgets('session replacement invalidates an open leave confirmation', (
    tester,
  ) async {
    final harness = await _pump(tester, routed: true);
    await _enter(tester, _inside(4, find.byType(TextField)), 'old student');
    await _tap(tester, find.byTooltip('Back to Homework'));
    harness.auth.replaceUser(studentUser('student-b'));
    await tester.pumpAndSettle();
    expect(find.text('Leave Attempt?'), findsNothing);
    expect(find.text('Homework destination'), findsNothing);
    expect(harness.repository.saves, isEmpty);
  });

  testWidgets(
    'narrow mobile enlarged text scrolls through every editor without overflow',
    (tester) async {
      await _pump(
        tester,
        surface: AppDeviceSurface.mobile,
        width: 320,
        textScale: 2,
      );
      for (final position in [1, 2, 3, 4, 5, 7, 8, 9]) {
        await tester.ensureVisible(_save(position));
        await tester.pumpAndSettle();
        expect(tester.getSize(_card(position)).width, lessThanOrEqualTo(320));
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'mixed-case saved controls and unavailable refreshed selections stay readable',
    (tester) async {
      const left = '7ABCDEF0-0000-0000-0000-000000000001';
      const right = '7ABCDEF0-0000-0000-0000-000000000002';
      const item = '7ABCDEF0-0000-0000-0000-000000000003';
      const blank = '7ABCDEF0-0000-0000-0000-000000000004';
      final semantics = tester.ensureSemantics();
      try {
        Widget controls(bool removed) => MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                StudentMatchingAnswerEditor(
                  answerUi: StudentMatchingAnswerUi(
                    leftItems: [
                      const StudentMatchingItem(
                        id: left,
                        text: 'Uppercase left',
                      ),
                    ],
                    rightItems: removed
                        ? []
                        : [
                            const StudentMatchingItem(
                              id: right,
                              text: 'Uppercase right',
                            ),
                          ],
                  ),
                  draft: StudentMatchingDraft(leftToRight: {left: right}),
                  enabled: true,
                  onChanged: (_) {},
                ),
                StudentOrderingAnswerEditor(
                  answerUi: StudentOrderingAnswerUi(
                    items: [
                      const StudentOrderingItem(
                        id: item,
                        text: 'Uppercase item',
                      ),
                      if (!removed)
                        StudentOrderingItem(id: _id(98), text: 'Second item'),
                    ],
                  ),
                  draft: StudentOrderingDraft(itemToPosition: {item: 2}),
                  enabled: true,
                  onChanged: (_) {},
                ),
                StudentFillBlankAnswerEditor(
                  answerUi: StudentFillBlankAnswerUi(
                    blanks: [
                      const StudentFillBlank(
                        id: blank,
                        key: 'uppercase',
                        position: 1,
                      ),
                    ],
                  ),
                  draft: StudentFillBlankDraft(
                    blankTextById: {blank: 'Exact saved text'},
                  ),
                  enabled: true,
                  onChanged: (_) {},
                ),
              ],
            ),
          ),
        );
        await tester.pumpWidget(controls(false));
        expect(
          tester
              .widget<DropdownButton<String>>(
                find.byKey(const ValueKey('studentMatching$left')),
              )
              .value,
          right.toLowerCase(),
        );
        expect(
          tester
              .widget<DropdownButton<int>>(
                find.byKey(const ValueKey('studentOrdering$item')),
              )
              .value,
          2,
        );
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'Exact saved text',
        );
        expect(
          find.bySemanticsLabel(RegExp('Match: Uppercase left')),
          findsWidgets,
        );
        expect(
          find.bySemanticsLabel(RegExp('Position: Uppercase item')),
          findsWidgets,
        );
        await tester.pumpWidget(controls(true));
        expect(find.text('Unavailable match'), findsOneWidget);
        expect(find.text('Unavailable position: 2'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );
}

Future<void> _tap(
  WidgetTester tester,
  Finder finder, {
  bool settle = true,
}) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump();
  if (settle && find.byType(LinearProgressIndicator).evaluate().isEmpty) {
    await tester.pumpAndSettle();
  }
}

Future<void> _enter(WidgetTester tester, Finder finder, String text) async {
  await tester.ensureVisible(finder);
  await tester.enterText(finder, text);
  await tester.pumpAndSettle();
}

void _expectNoSaveEnabled(WidgetTester tester) {
  for (final button in tester.widgetList<FilledButton>(
    find.widgetWithText(FilledButton, 'Save answer'),
  )) {
    expect(button.onPressed, isNull);
  }
}

Future<void> _makeUncertain(WidgetTester tester, _Harness harness) async {
  await _enter(tester, _inside(4, find.byType(TextField)), 'pending');
  await _tap(tester, _save(4), settle: false);
  harness.repository.saves.last.completer.completeError(
    studentLocalFailure(ApiFailureKind.timeout),
  );
  await tester.pumpAndSettle();
}

Future<_Harness> _pump(
  WidgetTester tester, {
  AppDeviceSurface surface = AppDeviceSurface.desktop,
  bool routed = false,
  double? width,
  double textScale = 1,
}) async {
  await tester.binding.setSurfaceSize(
    Size(width ?? (surface == AppDeviceSurface.mobile ? 390 : 1100), 900),
  );
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final harness = _Harness();
  final router = routed
      ? GoRouter(
          initialLocation: AppRoutePaths.studentHomeworkAttemptLocation(
            studentTopicId,
            _homeworkId,
            _attemptId,
          ),
          routes: [
            GoRoute(
              path: AppRoutePaths.studentHomeworkAttempt,
              builder: (_, _) => StudentHomeworkAttemptScreen(target: _target),
            ),
            GoRoute(
              path: AppRoutePaths.studentHomeworkDetail,
              builder: (_, _) =>
                  const Scaffold(body: Text('Homework destination')),
            ),
          ],
        )
      : null;
  if (router != null) addTearDown(router.dispose);
  Widget scale(BuildContext context, Widget? child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authSessionControllerProvider.overrideWith(() => harness.auth),
        appDeviceSurfaceProvider.overrideWithValue(surface),
        studentHomeworkAttemptRepositoryProvider.overrideWithValue(
          harness.repository,
        ),
        studentHomeworkAttemptControllerProvider(
          _target,
        ).overrideWith(() => harness.parent),
        studentHomeworkDetailControllerProvider(
          _parentTarget,
        ).overrideWith(_HomeworkController.new),
      ],
      child: router == null
          ? MaterialApp(
              builder: scale,
              home: StudentHomeworkAttemptScreen(target: _target),
            )
          : MaterialApp.router(builder: scale, routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  harness.container = ProviderScope.containerOf(
    tester.element(find.byType(StudentHomeworkAttemptScreen)),
  );
  return harness;
}

class _Harness {
  final repository = _Repository();
  final parent = _AttemptController();
  final auth = FakeStudentAuthSessionController.authenticated(
    studentUser('student-a'),
  );
  late ProviderContainer container;
  StudentAttemptAnswerEditorState get editorState =>
      container.read(studentAttemptAnswerEditorControllerProvider(_target));
}

class _AttemptController extends StudentHomeworkAttemptController {
  _AttemptController() : super(_target);
  var refreshes = 0;
  @override
  StudentHomeworkAttemptState build() => StudentHomeworkAttemptState(
    status: StudentHomeworkAttemptLoadStatus.data,
    attempt: _attempt(),
  );
  @override
  void refresh() {
    refreshes++;
  }

  void publish(StudentHomeworkAttempt attempt) => publishState(
    StudentHomeworkAttemptState(
      status: StudentHomeworkAttemptLoadStatus.data,
      attempt: attempt,
    ),
  );
  void publishState(StudentHomeworkAttemptState next) {
    state = next;
  }
}

class _HomeworkController extends StudentHomeworkDetailController {
  _HomeworkController() : super(_parentTarget);
  @override
  StudentHomeworkDetailState build() => StudentHomeworkDetailState(
    status: StudentHomeworkDetailStatus.data,
    homework: StudentHomeworkDetail(
      id: _homeworkId,
      topic: const StudentHomeworkTopicSummary(
        id: studentTopicId,
        title: 'Topic',
      ),
      title: 'Homework answer editors',
      description: null,
      studentInstructions: 'Read and answer each question.',
      status: StudentHomeworkStatus.active,
      deadlineAt: null,
      totalPossiblePoints: 9,
      attempts: const StudentHomeworkAttemptSummary(
        allowed: 3,
        used: 1,
        remaining: 2,
        officialScorePolicy: 'highest_valid_completed',
      ),
      myStatus: StudentHomeworkMyStatus.inProgress,
      scoreVisible: false,
      questions: _questions(),
    ),
  );
}

class _Repository implements StudentHomeworkAttemptRepository {
  final saves = <_PendingSave>[];
  final fetches = <String>[];
  Completer<StudentHomeworkAttempt>? nextFetch;
  @override
  Future<StudentHomeworkAttempt> fetchAttempt(String attemptId) {
    fetches.add(attemptId);
    return nextFetch?.future ?? Future.value(_attempt());
  }

  @override
  Future<StudentAttemptAnswerMutationResult> saveAnswer(
    String attemptId,
    StudentQuestion question,
    StudentAnswerMutation mutation,
  ) {
    expect(attemptId, _attemptId);
    final save = _PendingSave(question, mutation);
    saves.add(save);
    return save.completer.future;
  }

  @override
  Future<StudentHomeworkAttemptStartResult> startAttempt(
    String homeworkId,
    String idempotencyKey,
  ) => throw UnimplementedError();
}

class _PendingSave {
  _PendingSave(this.question, this.mutation);
  final StudentQuestion question;
  final StudentAnswerMutation mutation;
  final completer = Completer<StudentAttemptAnswerMutationResult>();
  void complete(StudentAttemptAnswerValue? answer) => completer.complete(
    StudentAttemptAnswerMutationResult(
      questionId: question.id,
      type: question.type,
      answer: answer,
      updatedAt: answer == null ? null : DateTime.utc(2026, 9, 10, 8),
    ),
  );
}

StudentAttemptAnswerState _textAnswer(String text) => StudentAttemptAnswerState(
  questionId: _questionId(4),
  type: StudentQuestionType.shortWritten,
  value: StudentTextAnswerValue(text: text),
  updatedAt: DateTime.utc(2026, 9, 10, 8),
);

StudentHomeworkAttempt _attempt({
  String id = _attemptId,
  String homeworkId = _homeworkId,
  StudentHomeworkAttemptStatus status = StudentHomeworkAttemptStatus.inProgress,
  List<StudentAttemptAnswerState> answers = const [],
  List<StudentQuestion>? questions,
}) => StudentHomeworkAttempt(
  id: id,
  assessmentId: homeworkId,
  attemptNumber: 1,
  status: status,
  startedAt: DateTime.utc(2026, 9, 10, 6),
  deadlineAt: null,
  submittedAt: status == StudentHomeworkAttemptStatus.inProgress
      ? null
      : DateTime.utc(2026, 9, 10, 9),
  finalizedAt: status == StudentHomeworkAttemptStatus.inProgress
      ? null
      : DateTime.utc(2026, 9, 10, 9),
  finalizationReason: status == StudentHomeworkAttemptStatus.inProgress
      ? null
      : StudentHomeworkAttemptFinalizationReason.studentSubmit,
  questions: questions ?? _questions(),
  answers: answers,
);

List<StudentQuestion> _questions() {
  final structures = <StudentAnswerUi>[
    StudentChoiceAnswerUi(
      options: [
        StudentChoiceOption(id: _id(1), text: 'Single A'),
        StudentChoiceOption(id: _id(2), text: 'Single B'),
      ],
    ),
    StudentChoiceAnswerUi(
      maxSelections: 2,
      options: [
        StudentChoiceOption(id: _id(3), text: 'Multiple A'),
        StudentChoiceOption(id: _id(4), text: 'Multiple B'),
        StudentChoiceOption(id: _id(5), text: 'Multiple C'),
      ],
    ),
    const StudentEmptyAnswerUi(),
    const StudentEmptyAnswerUi(),
    const StudentEmptyAnswerUi(),
    StudentFileAnswerUi(allowedExtensions: ['pdf'], maxSizeBytes: 2048),
    StudentMatchingAnswerUi(
      leftItems: [
        StudentMatchingItem(id: _id(6), text: 'Left A'),
        StudentMatchingItem(id: _id(7), text: 'Left B'),
      ],
      rightItems: [
        StudentMatchingItem(id: _id(8), text: 'Right A'),
        StudentMatchingItem(id: _id(9), text: 'Right B'),
      ],
    ),
    StudentOrderingAnswerUi(
      items: [
        StudentOrderingItem(id: _id(10), text: 'Item A'),
        StudentOrderingItem(id: _id(11), text: 'Item B'),
      ],
    ),
    StudentFillBlankAnswerUi(
      blanks: [
        StudentFillBlank(id: _id(13), key: 'second', position: 2),
        StudentFillBlank(id: _id(12), key: 'first', position: 1),
      ],
    ),
  ];
  return [
    for (var index = 0; index < structures.length; index++)
      StudentQuestion(
        id: _questionId(index + 1),
        type: StudentQuestionType.values[index],
        prompt: 'Question prompt ${index + 1}',
        instructions: 'Read the question and save your answer.',
        points: 1,
        position: index + 1,
        answerUi: structures[index],
      ),
  ];
}
