import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_state.dart';
import 'package:testlabuz_client/features/auth/domain/user_role.dart';
import 'package:testlabuz_client/features/student/application/student_homework_detail_controller.dart';
import 'package:testlabuz_client/features/student/application/student_homework_detail_state.dart';
import 'package:testlabuz_client/features/student/application/student_homework_list_controller.dart';
import 'package:testlabuz_client/features/student/application/student_homework_list_state.dart';
import 'package:testlabuz_client/features/student/data/student_homework_repository_impl.dart';
import 'package:testlabuz_client/features/student/data/student_topic_repository_impl.dart';
import 'package:testlabuz_client/features/student/domain/student_homework.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_list.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_list_query.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_repository.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_route_target.dart';

import 'student_test_support.dart';

const _homeworkId = '40000000-0000-0000-0000-000000000001';
const _otherHomeworkId = '40000000-0000-0000-0000-000000000002';
const _otherTopicId = '10000000-0000-0000-0000-000000000002';

void main() {
  group('Student Homework list controller', () {
    for (final surface in [AppDeviceSurface.desktop, AppDeviceSurface.mobile]) {
      test('auto-loads the eligible Student on ${surface.name}', () async {
        final harness = _Harness(surface: surface);
        final subscription = harness.listenList();
        expect(subscription.read().status, StudentHomeworkListStatus.loading);
        await harness.flush();

        final request = harness.repository.lists.single;
        expect(
          request.query,
          StudentHomeworkListQuery(topicId: studentTopicId),
        );
        expect(request.query.sort, StudentHomeworkSort.createdAt);
        expect(request.query.direction, StudentHomeworkSortDirection.desc);
        request.complete(_page());
        await harness.flush();

        expect(subscription.read().status, StudentHomeworkListStatus.data);
        expect(subscription.read().page!.items.single.title, 'Homework 1');
      });
    }

    test('ineligible sessions and surfaces do not load', () async {
      final sessions = [
        const AuthSessionState.unauthenticated(),
        const AuthSessionState.bootstrapping(),
        AuthSessionState.authenticated(
          studentUser('teacher', role: UserRole.teacher),
        ),
        AuthSessionState.authenticated(
          studentUser('inactive', isActive: false),
        ),
        AuthSessionState.authenticated(
          studentUser('password', mustChangePassword: true),
        ),
        AuthSessionState.authenticated(
          studentUser('institution', institutionStatus: 'inactive'),
        ),
        AuthSessionState.authenticated(
          studentUser('mismatch', nestedInstitutionId: 'institution-2'),
        ),
      ];
      for (final session in sessions) {
        final harness = _Harness(
          auth: FakeStudentAuthSessionController(session),
        );
        final subscription = harness.listenList();
        final detail = harness.listenDetail();
        await harness.flush();
        expect(subscription.read().status, StudentHomeworkListStatus.initial);
        expect(detail.read().status, StudentHomeworkDetailStatus.initial);
        expect(harness.repository.lists, isEmpty);
        expect(harness.repository.details, isEmpty);
      }
      final unsupported = _Harness(surface: AppDeviceSurface.unsupported);
      unsupported.listenList();
      unsupported.listenDetail();
      await unsupported.flush();
      expect(unsupported.repository.lists, isEmpty);
      expect(unsupported.repository.details, isEmpty);
    });

    test(
      'backend metadata controls pagination and status resets page',
      () async {
        final harness = _Harness();
        final subscription = harness.listenList();
        await harness.flush();
        harness.repository.lists.single.complete(_page(total: 41, lastPage: 3));
        await harness.flush();
        final controller = harness.listController;
        expect(subscription.read().canGoPrevious, isFalse);
        expect(subscription.read().canGoNext, isTrue);

        controller.nextPage();
        controller.nextPage();
        expect(harness.repository.lists, hasLength(2));
        expect(harness.repository.lists.last.query.page, 2);
        harness.repository.lists.last.complete(
          _page(page: 2, total: 41, lastPage: 3),
        );
        await harness.flush();
        expect(subscription.read().canGoPrevious, isTrue);
        controller.previousPage();
        expect(harness.repository.lists.last.query.page, 1);
        harness.repository.lists.last.complete(_page(total: 41, lastPage: 3));
        await harness.flush();
        controller.nextPage();
        harness.repository.lists.last.complete(
          _page(page: 2, total: 41, lastPage: 3),
        );
        await harness.flush();

        controller.setStatus(StudentHomeworkStatus.closed);
        expect(subscription.read().query.page, 1);
        expect(subscription.read().query.status, StudentHomeworkStatus.closed);
        expect(subscription.read().page, isNull);
        final calls = harness.repository.lists.length;
        controller.setStatus(StudentHomeworkStatus.closed);
        controller.refresh();
        expect(harness.repository.lists, hasLength(calls));
        harness.repository.lists.last.complete(_page(items: [], total: 0));
        await harness.flush();
        expect(subscription.read().status, StudentHomeworkListStatus.empty);
        expect(subscription.read().canGoNext, isFalse);
        controller.setStatus(null);
        expect(harness.repository.lists.last.query.status, isNull);
      },
    );

    test('empty out-of-range page makes only one bounded correction', () async {
      final harness = _Harness();
      final subscription = harness.listenList();
      await harness.flush();
      harness.repository.lists.last.complete(_page(total: 60, lastPage: 3));
      await harness.flush();
      harness.listController.nextPage();
      harness.repository.lists.last.complete(
        _page(page: 2, total: 60, lastPage: 3),
      );
      await harness.flush();
      harness.listController.nextPage();
      harness.repository.lists.last.complete(
        _page(items: [], page: 3, total: 21, lastPage: 2),
      );
      await harness.flush();

      expect(harness.repository.lists.map((call) => call.query.page), [
        1,
        2,
        3,
        2,
      ]);
      expect(subscription.read().query.page, 2);
      expect(subscription.read().status, StudentHomeworkListStatus.loading);
      harness.listController.refresh();
      expect(harness.repository.lists, hasLength(4));
      harness.repository.lists.last.complete(
        _page(items: [], page: 2, total: 1),
      );
      await harness.flush();

      expect(harness.repository.lists, hasLength(4));
      expect(subscription.read().status, StudentHomeworkListStatus.empty);
      expect(subscription.read().page!.total, 1);
      expect(subscription.read().query.page, 2);
      expect(subscription.read().canGoPrevious, isTrue);
    });

    test('a now-empty collection corrects directly to page one', () async {
      final harness = _Harness();
      final subscription = harness.listenList();
      await harness.flush();
      harness.repository.lists.last.complete(_page(total: 21, lastPage: 2));
      await harness.flush();
      harness.listController.nextPage();
      harness.repository.lists.last.complete(
        _page(items: [], page: 2, total: 0),
      );
      await harness.flush();
      expect(harness.repository.lists.last.query.page, 1);
      harness.repository.lists.last.complete(_page(items: [], total: 0));
      await harness.flush();
      expect(subscription.read().status, StudentHomeworkListStatus.empty);
      expect(subscription.read().page!.total, 0);
    });

    test('stale correction cannot publish over a changed filter', () async {
      final harness = _Harness();
      final subscription = harness.listenList();
      await harness.flush();
      harness.repository.lists.last.complete(_page(total: 21, lastPage: 2));
      await harness.flush();
      harness.listController.nextPage();
      harness.repository.lists.last.complete(
        _page(items: [], page: 2, total: 1),
      );
      await harness.flush();
      final correction = harness.repository.lists.last;
      harness.listController.setStatus(StudentHomeworkStatus.archived);
      final filtered = harness.repository.lists.last;
      filtered.complete(_page(title: 'Current filter Homework'));
      await harness.flush();
      correction.complete(_page(title: 'Stale corrected page'));
      await harness.flush();

      expect(harness.repository.lists, hasLength(4));
      expect(subscription.read().query.status, StudentHomeworkStatus.archived);
      expect(
        subscription.read().page!.items.single.title,
        'Current filter Homework',
      );
    });

    test('late previous page and filter responses never publish', () async {
      final harness = _Harness();
      final subscription = harness.listenList();
      await harness.flush();
      final initial = harness.repository.lists.single;
      harness.listController.setStatus(StudentHomeworkStatus.active);
      final active = harness.repository.lists.last;
      harness.listController.setStatus(StudentHomeworkStatus.closed);
      harness.repository.lists.last.complete(
        _page(title: 'Closed', total: 21, lastPage: 2),
      );
      await harness.flush();
      initial.complete(_page(title: 'Old initial'));
      active.fail(studentLocalFailure(ApiFailureKind.timeout));
      await harness.flush();
      expect(subscription.read().page!.items.single.title, 'Closed');
      expect(subscription.read().failure, isNull);

      harness.listController.nextPage();
      final oldPage = harness.repository.lists.last;
      harness.listController.setStatus(StudentHomeworkStatus.archived);
      harness.repository.lists.last.complete(_page(title: 'Archived'));
      await harness.flush();
      oldPage.complete(_page(items: [], page: 2, total: 0));
      await harness.flush();
      expect(harness.repository.lists, hasLength(5));
      expect(subscription.read().page!.items.single.title, 'Archived');
      expect(subscription.read().query.page, 1);
    });

    test('refresh retains rows and failed refresh marks them stale', () async {
      final harness = _Harness();
      final subscription = harness.listenList();
      await harness.flush();
      harness.repository.lists.last.complete(_page());
      await harness.flush();
      harness.listController.refresh();
      expect(subscription.read().status, StudentHomeworkListStatus.refreshing);
      expect(subscription.read().page!.items, isNotEmpty);
      harness.listController.refresh();
      expect(harness.repository.lists, hasLength(2));
      harness.repository.lists.last.fail(
        studentLocalFailure(ApiFailureKind.timeout),
      );
      await harness.flush();
      expect(subscription.read().status, StudentHomeworkListStatus.error);
      expect(subscription.read().isStale, isTrue);
      expect(subscription.read().failure!.kind, ApiFailureKind.timeout);
      expect(subscription.read().page!.items.single.title, 'Homework 1');
      expect(subscription.read().canGoNext, isFalse);
      harness.listController.retry();
      harness.listController.retry();
      expect(harness.repository.lists, hasLength(3));
      expect(subscription.read().isStale, isTrue);
      harness.repository.lists.last.complete(_page(title: 'Refreshed'));
      await harness.flush();
      expect(subscription.read().isStale, isFalse);
      expect(subscription.read().failure, isNull);
      expect(subscription.read().page!.items.single.title, 'Refreshed');
    });

    test('initial failure has no retained rows and supports retry', () async {
      final harness = _Harness();
      final subscription = harness.listenList();
      await harness.flush();
      harness.repository.lists.single.fail(
        studentLocalFailure(ApiFailureKind.connection),
      );
      await harness.flush();
      expect(subscription.read().status, StudentHomeworkListStatus.error);
      expect(subscription.read().page, isNull);
      expect(subscription.read().isStale, isFalse);
      harness.listController.retry();
      harness.repository.lists.last.complete(_page());
      await harness.flush();
      expect(subscription.read().status, StudentHomeworkListStatus.data);
    });

    test(
      'new Student owns fresh state and rejects old success and failure',
      () async {
        final harness = _Harness();
        final subscription = harness.listenList();
        await harness.flush();
        final first = harness.repository.lists.last;
        harness.listController.setStatus(StudentHomeworkStatus.closed);
        final oldFilter = harness.repository.lists.last;
        harness.auth.replaceUser(studentUser('student-b'));
        await harness.flush();
        expect(subscription.read().query.status, isNull);
        expect(subscription.read().page, isNull);
        harness.repository.lists.last.complete(_page(title: 'New Student'));
        await harness.flush();
        first.complete(_page(title: 'Old Student'));
        oldFilter.fail(studentServerFailure(ApiErrorCodes.userInactive));
        await harness.flush();
        expect(subscription.read().page!.items.single.title, 'New Student');
        expect(harness.auth.bootstrapCalls, 0);
      },
    );

    test('logout clears owned rows and rejects pending refresh', () async {
      final harness = _Harness();
      final subscription = harness.listenList();
      await harness.flush();
      harness.repository.lists.last.complete(_page());
      await harness.flush();
      harness.listController.refresh();
      final oldRefresh = harness.repository.lists.last;
      harness.auth.logOut();
      await harness.flush();
      expect(subscription.read().status, StudentHomeworkListStatus.initial);
      expect(subscription.read().page, isNull);
      oldRefresh.complete(_page(title: 'After logout'));
      await harness.flush();
      expect(subscription.read().page, isNull);
    });

    test('separate Topic targets never share rows or queries', () async {
      final harness = _Harness();
      final first = harness.listenList();
      final second = harness.listenList(topicId: _otherTopicId);
      await harness.flush();
      final requests = harness.repository.lists;
      requests
          .firstWhere((call) => call.query.topicId == _otherTopicId)
          .complete(_page(topicId: _otherTopicId, title: 'Second Topic'));
      requests
          .firstWhere((call) => call.query.topicId == studentTopicId)
          .complete(_page(title: 'First Topic'));
      await harness.flush();
      expect(first.read().page!.items.single.title, 'First Topic');
      expect(second.read().page!.items.single.title, 'Second Topic');
    });

    test('disposed list ignores an asynchronous failure', () async {
      final harness = _Harness();
      harness.listenList();
      await harness.flush();
      final pending = harness.repository.lists.single;
      harness.close();
      pending.fail(studentServerFailure(ApiErrorCodes.userInactive));
      await Future<void>.value();
      expect(harness.auth.bootstrapCalls, 0);
    });
  });

  group('Student Homework detail controller', () {
    test(
      'loading, data, retained refresh and retry remain read-only',
      () async {
        final harness = _Harness();
        final subscription = harness.listenDetail();
        expect(subscription.read().status, StudentHomeworkDetailStatus.loading);
        await harness.flush();
        expect(harness.repository.details.single.id, _homeworkId);
        harness.repository.details.last.complete(_detail());
        await harness.flush();
        expect(subscription.read().status, StudentHomeworkDetailStatus.data);
        harness.detailController.refresh();
        harness.detailController.refresh();
        expect(harness.repository.details, hasLength(2));
        expect(
          subscription.read().status,
          StudentHomeworkDetailStatus.refreshing,
        );
        expect(subscription.read().homework!.title, 'Homework 1');
        harness.repository.details.last.fail(
          studentLocalFailure(ApiFailureKind.timeout),
        );
        await harness.flush();
        expect(subscription.read().status, StudentHomeworkDetailStatus.error);
        expect(subscription.read().homework!.title, 'Homework 1');
        harness.detailController.retry();
        harness.detailController.retry();
        expect(harness.repository.details, hasLength(3));
        harness.repository.details.last.complete(
          _detail(title: 'Refreshed detail'),
        );
        await harness.flush();
        expect(subscription.read().homework!.title, 'Refreshed detail');
        expect(subscription.read().failure, isNull);
        expect(harness.repository.lists, isEmpty);
      },
    );

    test('authoritative 404 clears detail and marks its list stale', () async {
      final harness = _Harness();
      final list = harness.listenList();
      final otherList = harness.listenList(topicId: _otherTopicId);
      final detail = harness.listenDetail();
      await harness.flush();
      for (final request in harness.repository.lists) {
        request.complete(_page(topicId: request.query.topicId));
      }
      harness.repository.details.last.complete(_detail());
      await harness.flush();
      harness.listController.setStatus(StudentHomeworkStatus.closed);
      harness.repository.lists.last.complete(_page());
      await harness.flush();
      harness.detailController.refresh();
      harness.repository.details.last.fail(
        studentServerFailure(ApiErrorCodes.resourceNotFound, statusCode: 404),
      );
      await harness.flush();

      expect(detail.read().status, StudentHomeworkDetailStatus.notFound);
      expect(detail.read().homework, isNull);
      expect(list.read().status, StudentHomeworkListStatus.refreshing);
      expect(list.read().isStale, isTrue);
      expect(list.read().query.status, StudentHomeworkStatus.closed);
      expect(otherList.read().status, StudentHomeworkListStatus.data);
      expect(otherList.read().isStale, isFalse);
      expect(harness.repository.lists, hasLength(4));
      harness.repository.lists.last.complete(_page(items: [], total: 0));
      await harness.flush();
      expect(list.read().status, StudentHomeworkListStatus.empty);
      expect(list.read().isStale, isFalse);
    });

    test(
      'successful detail refresh does not invalidate the Homework list',
      () async {
        final harness = _Harness();
        final list = harness.listenList();
        harness.listenDetail();
        await harness.flush();
        harness.repository.lists.last.complete(_page());
        harness.repository.details.last.complete(_detail());
        await harness.flush();
        harness.detailController.refresh();
        harness.repository.details.last.complete(_detail(title: 'Updated'));
        await harness.flush();
        expect(harness.repository.lists, hasLength(1));
        expect(list.read().isStale, isFalse);
      },
    );

    test('authoritative 404 rejects an already pending list refresh', () async {
      final harness = _Harness();
      final list = harness.listenList();
      final detail = harness.listenDetail();
      await harness.flush();
      harness.repository.lists.last.complete(_page());
      await harness.flush();
      harness.listController.refresh();
      final staleRefresh = harness.repository.lists.last;
      harness.repository.details.last.fail(
        studentServerFailure(ApiErrorCodes.resourceNotFound, statusCode: 404),
      );
      await harness.flush();
      expect(detail.read().status, StudentHomeworkDetailStatus.notFound);
      expect(list.read().isStale, isTrue);
      expect(harness.repository.lists, hasLength(3));
      harness.repository.lists.last.complete(_page(items: [], total: 0));
      await harness.flush();
      staleRefresh.complete(_page(title: 'Inaccessible old row'));
      await harness.flush();
      expect(list.read().status, StudentHomeworkListStatus.empty);
      expect(list.read().page!.items, isEmpty);
      expect(list.read().isStale, isFalse);
    });

    test(
      'canonical UUID comparisons accept uppercase returned identities',
      () async {
        const topicId = 'a0000000-abcd-0000-0000-000000000001';
        const homeworkId = 'b0000000-abcd-0000-0000-000000000001';
        final harness = _Harness();
        final target = StudentHomeworkRouteTarget(
          topicId: topicId.toUpperCase(),
          homeworkId: homeworkId.toUpperCase(),
        );
        final detail = harness.container.listen(
          studentHomeworkDetailControllerProvider(target),
          (_, _) {},
          fireImmediately: true,
        );
        await harness.flush();
        expect(harness.repository.details.single.id, homeworkId);
        harness.repository.details.single.complete(
          _detail(id: homeworkId.toUpperCase(), topicId: topicId.toUpperCase()),
        );
        await harness.flush();
        expect(detail.read().status, StudentHomeworkDetailStatus.data);
        expect(
          target,
          StudentHomeworkRouteTarget(topicId: topicId, homeworkId: homeworkId),
        );
      },
    );

    test('wrong returned Topic or Homework identity is unavailable', () async {
      for (final returned in [
        _detail(topicId: _otherTopicId),
        _detail(id: _otherHomeworkId),
      ]) {
        final harness = _Harness();
        final subscription = harness.listenDetail();
        await harness.flush();
        harness.repository.details.last.complete(returned);
        await harness.flush();
        expect(
          subscription.read().status,
          StudentHomeworkDetailStatus.notFound,
        );
        expect(subscription.read().homework, isNull);
        expect(harness.repository.lists, isEmpty);
      }
    });

    test(
      'frozen assignment loads while the parent Topic read is 404',
      () async {
        final topicRepository = FakeStudentTopicRepository(
          onFetchTopic: (_) async => throw studentServerFailure(
            ApiErrorCodes.resourceNotFound,
            statusCode: 404,
          ),
        );
        final harness = _Harness(topicRepository: topicRepository);
        final subscription = harness.listenDetail();
        await harness.flush();
        harness.repository.details.last.complete(
          _detail(title: 'Historical assignment'),
        );
        await harness.flush();
        expect(topicRepository.detailIds, isEmpty);
        expect(topicRepository.listQueries, isEmpty);
        expect(subscription.read().status, StudentHomeworkDetailStatus.data);
        expect(subscription.read().homework!.title, 'Historical assignment');
        await expectLater(
          topicRepository.fetchTopic(studentTopicId),
          throwsA(isA<Exception>()),
        );
        expect(subscription.read().status, StudentHomeworkDetailStatus.data);
      },
    );

    test(
      'initial typed failure does not become notFound without its exact code',
      () async {
        final harness = _Harness();
        final subscription = harness.listenDetail();
        await harness.flush();
        harness.repository.details.last.fail(
          studentServerFailure('other_failure', statusCode: 404),
        );
        await harness.flush();
        expect(subscription.read().status, StudentHomeworkDetailStatus.error);
        expect(subscription.read().homework, isNull);
        expect(harness.repository.lists, isEmpty);
      },
    );

    test(
      'old target completion cannot publish to the new route target',
      () async {
        final harness = _Harness();
        final old = harness.listenDetail();
        await harness.flush();
        final oldRequest = harness.repository.details.single;
        old.close();
        final current = harness.listenDetail(homeworkId: _otherHomeworkId);
        await harness.flush();
        harness.repository.details.last.complete(
          _detail(id: _otherHomeworkId, title: 'Current target'),
        );
        await harness.flush();
        oldRequest.fail(
          studentServerFailure(ApiErrorCodes.resourceNotFound, statusCode: 404),
        );
        await harness.flush();
        expect(current.read().homework!.title, 'Current target');
        expect(current.read().status, StudentHomeworkDetailStatus.data);
        expect(harness.repository.lists, isEmpty);
      },
    );

    test(
      'old-session refresh cannot replace current detail or invalidate its list',
      () async {
        final harness = _Harness();
        final detail = harness.listenDetail();
        await harness.flush();
        harness.repository.details.last.complete(_detail());
        await harness.flush();
        harness.detailController.refresh();
        final oldRefresh = harness.repository.details.last;
        harness.auth.replaceUser(studentUser('student-b'));
        await harness.flush();
        expect(detail.read().homework, isNull);
        harness.repository.details.last.complete(_detail(title: 'New session'));
        await harness.flush();
        final list = harness.listenList();
        await harness.flush();
        harness.repository.lists.last.complete(_page());
        await harness.flush();
        oldRefresh.fail(
          studentServerFailure(ApiErrorCodes.resourceNotFound, statusCode: 404),
        );
        await harness.flush();
        expect(detail.read().homework!.title, 'New session');
        expect(list.read().isStale, isFalse);
        expect(harness.repository.lists, hasLength(1));
      },
    );

    test('disposed detail ignores success completion', () async {
      final harness = _Harness();
      harness.listenDetail();
      await harness.flush();
      final pending = harness.repository.details.single;
      harness.close();
      pending.complete(_detail());
      await Future<void>.value();
      expect(harness.auth.bootstrapCalls, 0);
    });
  });

  group('Homework session ownership', () {
    for (final code in [
      ApiErrorCodes.authenticationRequired,
      ApiErrorCodes.passwordChangeRequired,
      ApiErrorCodes.userInactive,
      ApiErrorCodes.institutionInactive,
    ]) {
      test(
        '$code clears retained list/detail and reconciles bootstrap',
        () async {
          for (final isDetail in [false, true]) {
            final harness = _Harness();
            final list = isDetail ? null : harness.listenList();
            final detail = isDetail ? harness.listenDetail() : null;
            await harness.flush();
            if (isDetail) {
              harness.repository.details.last.complete(_detail());
            } else {
              harness.repository.lists.last.complete(_page());
            }
            await harness.flush();
            if (isDetail) {
              harness.detailController.refresh();
              harness.repository.details.last.fail(studentServerFailure(code));
            } else {
              harness.listController.refresh();
              harness.repository.lists.last.fail(studentServerFailure(code));
            }
            await harness.flush();
            expect(
              harness.auth.bootstrapCalls,
              code == ApiErrorCodes.authenticationRequired ? 0 : 1,
            );
            if (isDetail) {
              expect(
                detail!.read().status,
                StudentHomeworkDetailStatus.initial,
              );
              expect(detail.read().homework, isNull);
            } else {
              expect(list!.read().status, StudentHomeworkListStatus.initial);
              expect(list.read().page, isNull);
            }
          }
        },
      );
    }

    test(
      'bootstrap, Institution and surface changes reject stale requests',
      () async {
        final harness = _Harness();
        final list = harness.listenList();
        final detail = harness.listenDetail();
        await harness.flush();
        final firstList = harness.repository.lists.last;
        final firstDetail = harness.repository.details.last;
        harness.auth.onBootstrap = () => const AuthSessionState.bootstrapping();
        await harness.auth.bootstrap();
        await harness.flush();
        expect(list.read().status, StudentHomeworkListStatus.initial);
        expect(detail.read().status, StudentHomeworkDetailStatus.initial);
        firstList.complete(_page(title: 'Pre-bootstrap'));
        firstDetail.complete(_detail(title: 'Pre-bootstrap'));
        await harness.flush();
        expect(list.read().page, isNull);
        expect(detail.read().homework, isNull);

        harness.auth.replaceUser(
          studentUser(
            'student-a',
            institutionId: 'institution-2',
            nestedInstitutionId: 'institution-2',
          ),
        );
        await harness.flush();
        final institutionList = harness.repository.lists.last;
        final institutionDetail = harness.repository.details.last;
        harness.container
            .read(_surfaceProvider.notifier)
            .setSurface(AppDeviceSurface.mobile);
        await harness.flush();
        harness.repository.lists.last.complete(_page(title: 'Mobile'));
        harness.repository.details.last.complete(_detail(title: 'Mobile'));
        await harness.flush();
        institutionList.complete(_page(title: 'Prior surface'));
        institutionDetail.fail(
          studentServerFailure(ApiErrorCodes.userInactive),
        );
        await harness.flush();
        expect(list.read().page!.items.single.title, 'Mobile');
        expect(detail.read().homework!.title, 'Mobile');
        expect(harness.auth.bootstrapCalls, 1);
        harness.auth.replaceUser(
          studentUser(
            'student-a',
            institutionId: 'institution-3',
            nestedInstitutionId: 'institution-3',
          ),
        );
        await harness.flush();
        expect(list.read().page, isNull);
        expect(detail.read().homework, isNull);
        expect(harness.repository.details, hasLength(4));
      },
    );

    test('equivalent session rebuild preserves in-flight ownership', () async {
      final user = studentUser('student-a');
      final harness = _Harness(
        auth: FakeStudentAuthSessionController.authenticated(user),
      );
      final list = harness.listenList();
      final detail = harness.listenDetail();
      await harness.flush();
      harness.auth.replaceUser(user);
      await harness.flush();
      expect(harness.repository.lists, hasLength(1));
      expect(harness.repository.details, hasLength(1));
      harness.repository.lists.last.complete(_page());
      harness.repository.details.last.complete(_detail());
      await harness.flush();
      expect(list.read().status, StudentHomeworkListStatus.data);
      expect(detail.read().status, StudentHomeworkDetailStatus.data);
    });

    test('disposal before scheduled loading issues no request', () async {
      final harness = _Harness();
      harness.listenList();
      harness.listenDetail();
      harness.close();
      await Future<void>.value();
      expect(harness.repository.lists, isEmpty);
      expect(harness.repository.details, isEmpty);
    });
  });
}

class _Harness {
  _Harness({
    FakeStudentAuthSessionController? auth,
    AppDeviceSurface surface = AppDeviceSurface.desktop,
    FakeStudentTopicRepository? topicRepository,
  }) : auth =
           auth ??
           FakeStudentAuthSessionController.authenticated(
             studentUser('student-a'),
           ) {
    container = ProviderContainer(
      overrides: [
        authSessionControllerProvider.overrideWith(() => this.auth),
        _surfaceProvider.overrideWith(() => _Surface(surface)),
        appDeviceSurfaceProvider.overrideWith(
          (ref) => ref.watch(_surfaceProvider),
        ),
        studentHomeworkRepositoryProvider.overrideWithValue(repository),
        studentTopicRepositoryProvider.overrideWithValue(
          topicRepository ?? FakeStudentTopicRepository(),
        ),
      ],
    );
    addTearDown(close);
  }

  final FakeStudentAuthSessionController auth;
  final repository = _ControlledHomeworkRepository();
  late final ProviderContainer container;
  var _closed = false;

  StudentHomeworkListController get listController => container.read(
    studentHomeworkListControllerProvider(studentTopicId).notifier,
  );

  StudentHomeworkDetailController get detailController => container.read(
    studentHomeworkDetailControllerProvider(_target()).notifier,
  );

  ProviderSubscription<StudentHomeworkListState> listenList({
    String topicId = studentTopicId,
  }) => container.listen(
    studentHomeworkListControllerProvider(topicId),
    (_, _) {},
    fireImmediately: true,
  );

  ProviderSubscription<StudentHomeworkDetailState> listenDetail({
    String homeworkId = _homeworkId,
  }) => container.listen(
    studentHomeworkDetailControllerProvider(_target(homeworkId: homeworkId)),
    (_, _) {},
    fireImmediately: true,
  );

  Future<void> flush() async {
    await Future<void>.value();
    await container.pump();
    await Future<void>.value();
    await container.pump();
  }

  void close() {
    if (!_closed) {
      _closed = true;
      container.dispose();
    }
  }
}

final _surfaceProvider = NotifierProvider<_Surface, AppDeviceSurface>(
  () => _Surface(AppDeviceSurface.desktop),
);

class _Surface extends Notifier<AppDeviceSurface> {
  _Surface(this.initial);
  final AppDeviceSurface initial;

  @override
  AppDeviceSurface build() => initial;

  void setSurface(AppDeviceSurface value) => state = value;
}

class _ControlledHomeworkRepository implements StudentHomeworkRepository {
  final lists = <_ListRequest>[];
  final details = <_DetailRequest>[];

  @override
  Future<StudentHomeworkList> fetchHomework(StudentHomeworkListQuery query) {
    final request = _ListRequest(query);
    lists.add(request);
    return request.completer.future;
  }

  @override
  Future<StudentHomeworkDetail> fetchHomeworkDetail(String homeworkId) {
    final request = _DetailRequest(homeworkId);
    details.add(request);
    return request.completer.future;
  }
}

class _ListRequest {
  _ListRequest(this.query);
  final StudentHomeworkListQuery query;
  final completer = Completer<StudentHomeworkList>();
  void complete(StudentHomeworkList page) => completer.complete(page);
  void fail(Object failure) => completer.completeError(failure);
}

class _DetailRequest {
  _DetailRequest(this.id);
  final String id;
  final completer = Completer<StudentHomeworkDetail>();
  void complete(StudentHomeworkDetail homework) => completer.complete(homework);
  void fail(Object failure) => completer.completeError(failure);
}

StudentHomeworkRouteTarget _target({String homeworkId = _homeworkId}) =>
    StudentHomeworkRouteTarget(topicId: studentTopicId, homeworkId: homeworkId);

StudentHomeworkList _page({
  List<StudentHomeworkSummary>? items,
  String topicId = studentTopicId,
  String title = 'Homework 1',
  int page = 1,
  int total = 1,
  int lastPage = 1,
}) => StudentHomeworkList(
  items:
      items ??
      [
        StudentHomeworkSummary(
          id: _homeworkId,
          topic: StudentHomeworkTopicSummary(
            id: topicId,
            title: 'Internet Basics',
          ),
          title: title,
          status: StudentHomeworkStatus.active,
          deadlineAt: null,
          attempts: _attempts,
          myStatus: StudentHomeworkMyStatus.notStarted,
          scoreVisible: false,
        ),
      ],
  page: page,
  perPage: 20,
  total: total,
  lastPage: lastPage,
);

StudentHomeworkDetail _detail({
  String id = _homeworkId,
  String topicId = studentTopicId,
  String title = 'Homework 1',
}) => StudentHomeworkDetail(
  id: id,
  topic: StudentHomeworkTopicSummary(id: topicId, title: 'Internet Basics'),
  title: title,
  description: null,
  studentInstructions: 'Read each question.',
  status: StudentHomeworkStatus.active,
  deadlineAt: null,
  totalPossiblePoints: 0,
  attempts: _attempts,
  myStatus: StudentHomeworkMyStatus.notStarted,
  scoreVisible: false,
  questions: [],
);

const _attempts = StudentHomeworkAttemptSummary(
  allowed: 3,
  used: 0,
  remaining: 3,
  officialScorePolicy: 'highest_valid_completed',
);
