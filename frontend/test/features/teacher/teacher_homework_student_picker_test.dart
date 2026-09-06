import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_homework_student_picker_target.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_group_student_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_group_student.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_group_student_list.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_group_student_list_query.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_list_pagination.dart';
import 'package:testlabuz_client/features/teacher/presentation/teacher_homework_student_picker_dialog.dart';

import 'teacher_test_support.dart';

const _groupId = '00000000-0000-0000-0000-000000000001';
const _studentA = '60000000-0000-0000-0000-000000000001';
const _studentB = '60000000-0000-0000-0000-000000000002';
const _unresolvedStudent = '60000000-0000-0000-0000-000000000003';

void main() {
  testWidgets(
    'unresolved selection is safe, then resolves without displaying its UUID',
    (tester) async {
      final pending = Completer<TeacherGroupStudentList>();
      await _pumpPicker(
        tester,
        repository: FakeTeacherGroupStudentRepository(
          onFetch: (_, _) => pending.future,
        ),
        initialSelectedIds: const {_unresolvedStudent},
      );

      await tester.tap(find.byKey(const Key('openStudentPicker')));
      await tester.pump();

      expect(
        find.byKey(const Key('teacherHomeworkStudentPickerDialog')),
        findsOneWidget,
      );
      expect(find.text('Selected student 1'), findsOneWidget);
      expect(
        find.text('Name not loaded in the current eligible roster view.'),
        findsOneWidget,
      );
      expect(find.textContaining(_unresolvedStudent), findsNothing);
      final searchField = tester.widget<TextField>(
        find.byKey(const Key('teacherHomeworkStudentPickerSearchField')),
      );
      expect(searchField.decoration?.labelText, 'Search eligible Students');
      final semanticLabels = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .map((widget) => widget.properties.label);
      expect(semanticLabels, contains('Current selected Students'));

      pending.complete(
        _studentList(
          items: [
            _student(_unresolvedStudent, 'Katherine Johnson', 'katherine'),
          ],
          total: 1,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Katherine Johnson'), findsWidgets);
      expect(find.text('katherine'), findsWidgets);
      expect(find.textContaining(_unresolvedStudent), findsNothing);

      await tester.tap(
        find.byKey(const Key('teacherHomeworkStudentPickerCancelButton')),
      );
      await tester.pumpAndSettle();
      expect(find.text('No selection applied'), findsOneWidget);
    },
  );

  testWidgets('Apply returns the complete selected set', (tester) async {
    await _pumpPicker(
      tester,
      surfaceSize: const Size(700, 900),
      repository: FakeTeacherGroupStudentRepository(
        onFetch: (_, _) async => _studentList(
          items: [
            _student(_studentA, 'Ada Lovelace', 'ada'),
            _student(_studentB, 'Grace Hopper', 'grace'),
          ],
          total: 2,
        ),
      ),
      initialSelectedIds: const {_studentA},
    );

    await tester.tap(find.byKey(const Key('openStudentPicker')));
    await tester.pumpAndSettle();
    expect(find.text('1 Student selected'), findsOneWidget);

    await tester.tap(
      find.byKey(ValueKey('teacherHomeworkPickerStudent$_studentB')),
    );
    await tester.pump();
    expect(find.text('2 Students selected'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('teacherHomeworkStudentPickerApplyButton')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Applied 2 Students'), findsOneWidget);
  });

  testWidgets('search commits from the keyboard and pagination is operable', (
    tester,
  ) async {
    final repository = FakeTeacherGroupStudentRepository(
      onFetch: (_, query) async => _studentList(
        items: [
          query.page == 1
              ? _student(_studentA, 'Ada Lovelace', 'ada')
              : _student(_studentB, 'Grace Hopper', 'grace'),
        ],
        page: query.page,
        total: 2,
        lastPage: 2,
      ),
    );
    await _pumpPicker(tester, repository: repository);
    await tester.tap(find.byKey(const Key('openStudentPicker')));
    await tester.pumpAndSettle();

    final search = find.byKey(
      const Key('teacherHomeworkStudentPickerSearchField'),
    );
    expect(
      tester.widget<TextField>(search).textInputAction,
      TextInputAction.search,
    );
    await tester.enterText(search, '  Ada  ');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(repository.requests.last.query.search, 'Ada');
    expect(repository.requests.last.query.page, 1);

    await tester.tap(
      find.byKey(const Key('teacherHomeworkStudentPickerNextButton')),
    );
    await tester.pumpAndSettle();
    expect(repository.requests.last.query.page, 2);
    expect(find.text('Page 2 of 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('roster error exposes a local Retry action', (tester) async {
    var calls = 0;
    await _pumpPicker(
      tester,
      repository: FakeTeacherGroupStudentRepository(
        onFetch: (_, _) async {
          calls += 1;
          if (calls == 1) {
            throw teacherServerFailure(
              ApiErrorCodes.resourceNotFound,
              statusCode: 404,
            );
          }
          return _studentList();
        },
      ),
    );
    await tester.tap(find.byKey(const Key('openStudentPicker')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('teacherHomeworkStudentPickerError')),
      findsOneWidget,
    );
    expect(find.textContaining('Raw server failure'), findsNothing);

    await tester.tap(
      find.byKey(const Key('teacherHomeworkStudentPickerRetryButton')),
    );
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(
      find.byKey(const Key('teacherHomeworkStudentPickerEmpty')),
      findsOneWidget,
    );
  });

  testWidgets('picker has no overflow on a narrow supported desktop', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _pumpPicker(
      tester,
      repository: FakeTeacherGroupStudentRepository(
        onFetch: (_, _) async => _studentList(
          items: [_student(_studentA, 'A very long Student name', 'student')],
          total: 1,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('openStudentPicker')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpPicker(
  WidgetTester tester, {
  required FakeTeacherGroupStudentRepository repository,
  Set<String> initialSelectedIds = const {},
  Size surfaceSize = const Size(1100, 800),
}) async {
  await tester.binding.setSurfaceSize(surfaceSize);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authSessionControllerProvider.overrideWith(
          () => FakeTeacherAuthSessionController.authenticated(
            teacherUser('teacher-a'),
          ),
        ),
        appDeviceSurfaceProvider.overrideWithValue(AppDeviceSurface.desktop),
        teacherGroupStudentRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        home: _PickerLauncher(initialSelectedIds: initialSelectedIds),
      ),
    ),
  );
  await tester.pump();
}

class _PickerLauncher extends StatefulWidget {
  const _PickerLauncher({required this.initialSelectedIds});

  final Set<String> initialSelectedIds;

  @override
  State<_PickerLauncher> createState() => _PickerLauncherState();
}

class _PickerLauncherState extends State<_PickerLauncher> {
  Set<String>? _selection;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _selection == null
                  ? 'No selection applied'
                  : 'Applied ${_selection!.length} Students',
            ),
            FilledButton(
              key: const Key('openStudentPicker'),
              onPressed: () async {
                final selection = await showTeacherHomeworkStudentPicker(
                  context: context,
                  target: TeacherHomeworkStudentPickerTarget(
                    groupId: _groupId,
                    initialSelectedIds: widget.initialSelectedIds,
                  ),
                );
                if (selection != null && mounted) {
                  setState(() => _selection = selection);
                }
              },
              child: const Text('Open picker'),
            ),
          ],
        ),
      ),
    );
  }
}

TeacherGroupStudent _student(String id, String name, String login) {
  return TeacherGroupStudent(id: id, fullName: name, loginName: login);
}

TeacherGroupStudentList _studentList({
  List<TeacherGroupStudent> items = const [],
  int page = 1,
  int total = 0,
  int lastPage = 1,
}) {
  return TeacherGroupStudentList(
    items: items,
    pagination: TeacherListPagination(
      page: page,
      perPage: TeacherGroupStudentListQuery.defaultPerPage,
      total: total,
      lastPage: lastPage,
    ),
  );
}
