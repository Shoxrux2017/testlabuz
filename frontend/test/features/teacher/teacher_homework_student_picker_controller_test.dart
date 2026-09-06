import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_homework_student_picker_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_homework_student_picker_state.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_homework_student_picker_target.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_group_student_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_group_student.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_group_student_list.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_group_student_list_query.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_list_pagination.dart';

import 'teacher_test_support.dart';

const _groupId = '00000000-0000-0000-0000-000000000001';
const _studentA = '60000000-0000-0000-0000-000000000001';
const _studentB = '60000000-0000-0000-0000-000000000002';
const _studentC = '60000000-0000-0000-0000-000000000003';

void main() {
  test(
    'loads, searches, pages, and preserves selection across queries',
    () async {
      final repository = FakeTeacherGroupStudentRepository(
        onFetch: (_, query) async {
          final student = query.page == 1
              ? _student(_studentA, 'Ada Lovelace', 'ada')
              : _student(_studentB, 'Grace Hopper', 'grace');
          return _studentList(
            items: [student],
            page: query.page,
            total: 2,
            lastPage: 2,
          );
        },
      );
      final harness = _PickerHarness(repository: repository);
      addTearDown(harness.dispose);
      final provider = teacherHomeworkStudentPickerControllerProvider(
        TeacherHomeworkStudentPickerTarget(
          groupId: _groupId,
          initialSelectedIds: const {},
        ),
      );
      final subscription = harness.container.listen(
        provider,
        (_, _) {},
        fireImmediately: true,
      );
      final controller = harness.container.read(provider.notifier);

      await flushTeacherControllers();
      expect(repository.requests.single.groupId, _groupId);
      expect(repository.requests.single.query.page, 1);
      expect(repository.requests.single.query.perPage, 50);

      controller.setStudentSelected(_studentA, true);
      controller.nextPage();
      await flushTeacherControllers();
      expect(subscription.read().query.page, 2);
      expect(subscription.read().selectedIds, {_studentA});

      controller.setStudentSelected(_studentB, true);
      controller.previousPage();
      await flushTeacherControllers();
      controller.updateSearchDraft('  Ada  ');
      controller.submitSearch();
      await flushTeacherControllers();

      expect(repository.requests.last.query.search, 'Ada');
      expect(repository.requests.last.query.page, 1);
      expect(subscription.read().selectedIds, {_studentA, _studentB});

      controller.setStudentSelected(_studentA, false);
      expect(subscription.read().selectedIds, {_studentB});

      controller.updateSearchDraft(List.filled(101, '😀').join());
      controller.submitSearch();
      expect(
        subscription.read().searchErrorText,
        teacherHomeworkStudentSearchLengthError,
      );
    },
  );

  test(
    'unresolved initial selection resolves when a later page loads',
    () async {
      var calls = 0;
      final repository = FakeTeacherGroupStudentRepository(
        onFetch: (_, query) async {
          calls += 1;
          return _studentList(
            items: calls == 1
                ? const []
                : [_student(_studentC, 'Katherine Johnson', 'katherine')],
          );
        },
      );
      final harness = _PickerHarness(repository: repository);
      addTearDown(harness.dispose);
      final provider = teacherHomeworkStudentPickerControllerProvider(
        TeacherHomeworkStudentPickerTarget(
          groupId: _groupId,
          initialSelectedIds: const {_studentC},
        ),
      );
      final subscription = harness.container.listen(
        provider,
        (_, _) {},
        fireImmediately: true,
      );

      await flushTeacherControllers();
      expect(subscription.read().selectedIds, {_studentC});
      expect(subscription.read().resolvedStudent(_studentC), isNull);

      final controller = harness.container.read(provider.notifier);
      controller.updateSearchDraft('Katherine');
      controller.submitSearch();
      await flushTeacherControllers();

      expect(
        subscription.read().resolvedStudent(_studentC)?.fullName,
        'Katherine Johnson',
      );
      expect(subscription.read().selectedIds, {_studentC});
    },
  );

  test('roster error is safe and Retry loads the current query', () async {
    var calls = 0;
    final repository = FakeTeacherGroupStudentRepository(
      onFetch: (_, query) async {
        calls += 1;
        if (calls == 1) {
          throw teacherServerFailure(
            ApiErrorCodes.resourceNotFound,
            statusCode: 404,
          );
        }
        return _studentList(
          items: [_student(_studentA, 'Ada Lovelace', 'ada')],
        );
      },
    );
    final harness = _PickerHarness(repository: repository);
    addTearDown(harness.dispose);
    final provider = teacherHomeworkStudentPickerControllerProvider(
      TeacherHomeworkStudentPickerTarget(
        groupId: _groupId,
        initialSelectedIds: const {},
      ),
    );
    final subscription = harness.container.listen(
      provider,
      (_, _) {},
      fireImmediately: true,
    );

    await flushTeacherControllers();
    expect(
      subscription.read().status,
      TeacherHomeworkStudentPickerStatus.error,
    );
    expect(subscription.read().result, isNull);

    harness.container.read(provider.notifier).refresh();
    await flushTeacherControllers();
    expect(calls, 2);
    expect(subscription.read().status, TeacherHomeworkStudentPickerStatus.data);
  });

  test(
    'a stale older search result cannot replace the current query',
    () async {
      final alpha = Completer<TeacherGroupStudentList>();
      final beta = Completer<TeacherGroupStudentList>();
      final repository = FakeTeacherGroupStudentRepository(
        onFetch: (_, query) {
          return switch (query.search) {
            'Alpha' => alpha.future,
            'Beta' => beta.future,
            _ => Future.value(_studentList()),
          };
        },
      );
      final harness = _PickerHarness(repository: repository);
      addTearDown(harness.dispose);
      final provider = teacherHomeworkStudentPickerControllerProvider(
        TeacherHomeworkStudentPickerTarget(
          groupId: _groupId,
          initialSelectedIds: const {},
        ),
      );
      final subscription = harness.container.listen(
        provider,
        (_, _) {},
        fireImmediately: true,
      );
      await flushTeacherControllers();
      final controller = harness.container.read(provider.notifier);

      controller.updateSearchDraft('Alpha');
      controller.submitSearch();
      controller.updateSearchDraft('Beta');
      controller.submitSearch();
      beta.complete(
        _studentList(items: [_student(_studentB, 'Beta Student', 'beta')]),
      );
      await flushTeacherControllers();
      alpha.complete(
        _studentList(items: [_student(_studentA, 'Alpha Student', 'alpha')]),
      );
      await flushTeacherControllers();

      expect(subscription.read().query.search, 'Beta');
      expect(subscription.read().result!.items.single.id, _studentB);
      expect(subscription.read().resolvedStudent(_studentA), isNull);
    },
  );

  test(
    'session replacement and disposal reject a pending roster result',
    () async {
      final pending = Completer<TeacherGroupStudentList>();
      final auth = FakeTeacherAuthSessionController.authenticated(
        teacherUser('teacher-a'),
      );
      final harness = _PickerHarness(
        repository: FakeTeacherGroupStudentRepository(
          onFetch: (_, _) => pending.future,
        ),
        auth: auth,
      );
      final provider = teacherHomeworkStudentPickerControllerProvider(
        TeacherHomeworkStudentPickerTarget(
          groupId: _groupId,
          initialSelectedIds: const {},
        ),
      );
      final subscription = harness.container.listen(
        provider,
        (_, _) {},
        fireImmediately: true,
      );
      await flushTeacherControllers();

      auth.replaceUser(teacherUser('teacher-b'));
      await flushTeacherControllers();
      pending.complete(
        _studentList(items: [_student(_studentA, 'Old Student', 'old')]),
      );
      await flushTeacherControllers();

      expect(subscription.read().result, isNull);
      expect(subscription.read().resolvedStudentsById, isEmpty);
      harness.dispose();
    },
  );
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

class _PickerHarness {
  _PickerHarness({
    required FakeTeacherGroupStudentRepository repository,
    FakeTeacherAuthSessionController? auth,
  }) : container = ProviderContainer(
         overrides: [
           authSessionControllerProvider.overrideWith(
             () =>
                 auth ??
                 FakeTeacherAuthSessionController.authenticated(
                   teacherUser('teacher-a'),
                 ),
           ),
           appDeviceSurfaceProvider.overrideWithValue(AppDeviceSurface.desktop),
           teacherGroupStudentRepositoryProvider.overrideWithValue(repository),
         ],
       );

  final ProviderContainer container;
  var _disposed = false;

  void dispose() {
    if (!_disposed) {
      _disposed = true;
      container.dispose();
    }
  }
}
