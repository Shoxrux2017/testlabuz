import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_topic_create_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_topic_create_state.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_topic_detail_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_topic_detail_state.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_topic_edit_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_topic_edit_state.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_topic_group_picker_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_topic_group_picker_state.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_topic_lifecycle_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_topic_lifecycle_state.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_topic_list_controller.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_group_list_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_topic_list_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_topic_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_group.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_group_list.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_group_list_query.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_topic.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_topic_mutation.dart';

import 'teacher_test_support.dart';

const _topicId = '10000000-0000-0000-0000-000000000001';

void main() {
  group('TeacherTopicGroupPickerController', () {
    test('loads/searches/pages and preserves an active selection', () async {
      final groups = FakeTeacherGroupListRepository(
        onFetch: (query) async => teacherGroupPage(
          groups: [
            teacherGroup(
              id: query.page == 1
                  ? '00000000-0000-0000-0000-000000000001'
                  : '00000000-0000-0000-0000-000000000002',
              name: query.page == 1 ? 'Alpha' : 'Beta',
            ),
          ],
          page: query.page,
          total: 40,
          lastPage: 2,
        ),
      );
      final harness = _Harness(groups: groups);
      final subscription = harness.container.listen(
        teacherTopicGroupPickerControllerProvider,
        (_, _) {},
        fireImmediately: true,
      );
      await flushTeacherControllers();
      final controller = harness.container.read(
        teacherTopicGroupPickerControllerProvider.notifier,
      );

      controller.selectGroup(subscription.read().result!.groups.single);
      controller.nextPage();
      await flushTeacherControllers();
      expect(subscription.read().query.page, 2);
      expect(subscription.read().selectedGroup!.name, 'Alpha');

      controller.updateSearchDraft('  Beta  ');
      controller.commitSearchNow();
      await flushTeacherControllers();
      expect(groups.queries.last.search, 'Beta');
      expect(groups.queries.last.toQueryParameters(), {
        'page': 1,
        'per_page': 20,
        'sort': 'name',
        'direction': 'asc',
        'search': 'Beta',
      });
      expect(subscription.read().selectedGroup!.name, 'Alpha');

      controller.updateSearchDraft(List.filled(255, '😀').join());
      controller.commitSearchNow();
      expect(subscription.read().searchErrorText, isNotNull);
      expect(TeacherGroupListQuery.searchDebounceDuration.inMilliseconds, 300);
    });

    test('stale session response cannot publish', () async {
      final first = Completer<TeacherGroupListPage>();
      final second = Completer<TeacherGroupListPage>();
      var calls = 0;
      final groups = FakeTeacherGroupListRepository(
        onFetch: (_) {
          calls += 1;
          return calls == 1 ? first.future : second.future;
        },
      );
      final auth = FakeTeacherAuthSessionController.authenticated(
        teacherUser('teacher-a'),
      );
      final harness = _Harness(groups: groups, auth: auth);
      final subscription = harness.container.listen(
        teacherTopicGroupPickerControllerProvider,
        (_, _) {},
        fireImmediately: true,
      );
      await flushTeacherControllers();

      auth.replaceUser(teacherUser('teacher-b'));
      await flushTeacherControllers();
      first.complete(teacherGroupPage());
      await flushTeacherControllers();

      expect(subscription.read().status, TeacherTopicGroupPickerStatus.loading);
      second.complete(teacherGroupPage());
      await flushTeacherControllers();
      expect(subscription.read().status, TeacherTopicGroupPickerStatus.data);
    });

    test(
      'rejects an inactive Group returned by the picker repository',
      () async {
        final harness = _Harness(
          groups: FakeTeacherGroupListRepository(
            onFetch: (_) async => teacherGroupPage(
              groups: [teacherGroup(status: TeacherGroupStatus.archived)],
            ),
          ),
        );
        final subscription = harness.container.listen(
          teacherTopicGroupPickerControllerProvider,
          (_, _) {},
          fireImmediately: true,
        );
        await flushTeacherControllers();

        expect(subscription.read().status, TeacherTopicGroupPickerStatus.error);
        expect(subscription.read().result, isNull);
      },
    );
  });

  group('TeacherTopicCreateController', () {
    test(
      'confirmed create invalidates list authority and returns Topic ID',
      () async {
        final topics = FakeTeacherTopicRepository(
          onCreate: (request) async => teacherTopic(
            id: _topicId,
            title: request.title,
            description: request.description,
            subject: request.subject,
            studentInstructions: request.studentInstructions,
            lessonAt: request.lessonAtInstant,
          ),
        );
        final harness = _Harness(topics: topics);
        final subscription = harness.container.listen(
          teacherTopicCreateControllerProvider,
          (_, _) {},
          fireImmediately: true,
        );
        final controller = harness.container.read(
          teacherTopicCreateControllerProvider.notifier,
        )..enterRoute();
        _fillCreate(controller);

        await controller.submit();

        expect(subscription.read().confirmedTopicId, _topicId);
        expect(topics.createRequests, hasLength(1));
        expect(topics.createRequests.single.toJson().keys, {
          'group_id',
          'title',
          'description',
          'subject',
          'student_instructions',
          'lesson_at',
        });
        expect(
          harness.container.read(teacherTopicListRetainedQueryProvider).value,
          isNotNull,
        );
        expect(
          harness.container
              .read(teacherTopicListRetainedQueryProvider)
              .value!
              .authoritativeRowsStale,
          isTrue,
        );
      },
    );

    test(
      'unknown create is never repeated and prepares exact recovery query',
      () async {
        final topics = FakeTeacherTopicRepository(
          onCreate: (_) async =>
              throw const TeacherTopicMutationOutcomeUnknownException(),
        );
        final harness = _Harness(topics: topics);
        final subscription = harness.container.listen(
          teacherTopicCreateControllerProvider,
          (_, _) {},
          fireImmediately: true,
        );
        final controller = harness.container.read(
          teacherTopicCreateControllerProvider.notifier,
        )..enterRoute();
        _fillCreate(controller);

        await controller.submit();
        expect(subscription.read().status, TeacherTopicCreateStatus.unknown);
        expect(topics.createRequests, hasLength(1));
        expect(controller.reviewTopics(), isTrue);
        final retained = harness.container
            .read(teacherTopicListRetainedQueryProvider)
            .value!;
        expect(retained.query.toQueryParameters(), {
          'page': 1,
          'per_page': 20,
          'sort': 'created_at',
          'direction': 'desc',
          'group_id': '00000000-0000-0000-0000-000000000001',
          'status': 'draft',
        });
        expect(retained.recoveryNoticePending, isTrue);
      },
    );

    test(
      'selected Group 404 clears selection without retrying create',
      () async {
        final topics = FakeTeacherTopicRepository(
          onCreate: (_) async => throw teacherServerFailure(
            ApiErrorCodes.resourceNotFound,
            statusCode: 404,
          ),
        );
        final harness = _Harness(topics: topics);
        final subscription = harness.container.listen(
          teacherTopicCreateControllerProvider,
          (_, _) {},
          fireImmediately: true,
        );
        final controller = harness.container.read(
          teacherTopicCreateControllerProvider.notifier,
        )..enterRoute();
        _fillCreate(controller);

        await controller.submit();

        expect(topics.createRequests, hasLength(1));
        expect(subscription.read().form.selectedGroup, isNull);
        expect(
          subscription.read().formError,
          'Selected group is no longer available.',
        );
      },
    );

    test(
      'stale create completion cannot publish to replacement session',
      () async {
        final completer = Completer<TeacherTopic>();
        final auth = FakeTeacherAuthSessionController.authenticated(
          teacherUser('teacher-a'),
        );
        final harness = _Harness(
          auth: auth,
          topics: FakeTeacherTopicRepository(onCreate: (_) => completer.future),
        );
        final subscription = harness.container.listen(
          teacherTopicCreateControllerProvider,
          (_, _) {},
          fireImmediately: true,
        );
        final controller = harness.container.read(
          teacherTopicCreateControllerProvider.notifier,
        )..enterRoute();
        _fillCreate(controller);
        final submission = controller.submit();

        auth.replaceUser(teacherUser('teacher-b'));
        completer.complete(teacherTopic());
        await submission;
        await flushTeacherControllers();

        expect(subscription.read().confirmedTopicId, isNull);
      },
    );

    test('server validation maps known fields without raw messages', () async {
      final topics = FakeTeacherTopicRepository(
        onCreate: (_) async => throw ApiRequestException(
          ApiFailure(
            kind: ApiFailureKind.validation,
            statusCode: 422,
            serverCode: ApiErrorCodes.validationFailed,
            message: 'Raw validation response.',
            fieldErrors: const {
              'title': ['Raw Laravel title message.'],
              'unknown': ['Raw unknown message.'],
            },
          ),
        ),
      );
      final harness = _Harness(topics: topics);
      final subscription = harness.container.listen(
        teacherTopicCreateControllerProvider,
        (_, _) {},
        fireImmediately: true,
      );
      final controller = harness.container.read(
        teacherTopicCreateControllerProvider.notifier,
      )..enterRoute();
      _fillCreate(controller);

      await controller.submit();

      expect(
        subscription.read().fieldErrors[TeacherTopicFormField.title],
        'Review the Topic title.',
      );
      expect(subscription.read().formError, 'The Topic could not be created.');
      expect(subscription.read().formError, isNot(contains('Laravel')));
    });
  });

  group('TeacherTopicDetailController', () {
    test(
      'loads desktop/mobile, refreshes with retained data, and rejects invalid ID',
      () async {
        for (final surface in [
          AppDeviceSurface.desktop,
          AppDeviceSurface.mobile,
        ]) {
          final pendingRefresh = Completer<TeacherTopic>();
          var calls = 0;
          final repository = FakeTeacherTopicRepository(
            onFetch: (id) {
              calls += 1;
              return calls == 1
                  ? Future.value(teacherTopic(id: id))
                  : pendingRefresh.future;
            },
          );
          final harness = _Harness(topics: repository, surface: surface);
          final provider = teacherTopicDetailControllerProvider(_topicId);
          final subscription = harness.container.listen(
            provider,
            (_, _) {},
            fireImmediately: true,
          );
          await flushTeacherControllers();
          expect(subscription.read().status, TeacherTopicDetailStatus.data);

          harness.container.read(provider.notifier).refresh();
          expect(
            subscription.read().status,
            TeacherTopicDetailStatus.refreshing,
          );
          expect(subscription.read().topic, isNotNull);
          pendingRefresh.complete(teacherTopic(id: _topicId, title: 'Fresh'));
          await flushTeacherControllers();
          expect(subscription.read().topic!.title, 'Fresh');
        }

        final invalidRepository = FakeTeacherTopicRepository();
        final invalidHarness = _Harness(topics: invalidRepository);
        final invalidSubscription = invalidHarness.container.listen(
          teacherTopicDetailControllerProvider('new'),
          (_, _) {},
          fireImmediately: true,
        );
        await flushTeacherControllers();
        expect(invalidRepository.fetchIds, isEmpty);
        expect(
          invalidSubscription.read().status,
          TeacherTopicDetailStatus.initial,
        );
      },
    );

    test('maps resource_not_found to generic unavailable state', () async {
      final harness = _Harness(
        topics: FakeTeacherTopicRepository(
          onFetch: (_) async => throw teacherServerFailure(
            ApiErrorCodes.resourceNotFound,
            statusCode: 404,
          ),
        ),
      );
      final subscription = harness.container.listen(
        teacherTopicDetailControllerProvider(_topicId),
        (_, _) {},
        fireImmediately: true,
      );
      await flushTeacherControllers();

      expect(subscription.read().status, TeacherTopicDetailStatus.notFound);
    });
  });

  group('TeacherTopicEditController', () {
    test(
      'no-op sends no PATCH; changed update is authoritative and list-stale',
      () async {
        final repository = FakeTeacherTopicRepository(
          onFetch: (id) async => teacherTopic(id: id),
          onUpdate: (id, request) async =>
              teacherTopic(id: id, title: request.toJson()['title']! as String),
        );
        final harness = _Harness(topics: repository);
        final provider = teacherTopicEditControllerProvider(_topicId);
        final subscription = harness.container.listen(
          provider,
          (_, _) {},
          fireImmediately: true,
        );
        final controller = harness.container.read(provider.notifier)
          ..enterRoute();
        await flushTeacherControllers();

        await controller.submit();
        expect(repository.updateRequests, isEmpty);
        expect(subscription.read().formError, 'No changes to save.');

        controller.updateTitle('  Updated  ');
        expect(subscription.read().isDirty, isTrue);
        await controller.submit();
        expect(repository.updateRequests.single.request.toJson(), {
          'title': 'Updated',
        });
        expect(
          subscription.read().status,
          TeacherTopicEditStatus.confirmedSuccess,
        );
        expect(
          harness.container
              .read(teacherTopicDetailControllerProvider(_topicId))
              .topic!
              .title,
          'Updated',
        );
        expect(
          harness.container
              .read(teacherTopicListRetainedQueryProvider)
              .value!
              .authoritativeRowsStale,
          isTrue,
        );
      },
    );

    test(
      'topic_not_editable refreshes state and preserves attempted draft',
      () async {
        var fetches = 0;
        final repository = FakeTeacherTopicRepository(
          onFetch: (id) async {
            fetches += 1;
            return teacherTopic(
              id: id,
              title: fetches == 1 ? 'Original' : 'Server current',
              status: fetches == 1
                  ? TeacherTopicStatus.draft
                  : TeacherTopicStatus.closed,
            );
          },
          onUpdate: (_, _) async => throw teacherServerFailure(
            ApiErrorCodes.topicNotEditable,
            statusCode: 409,
          ),
        );
        final harness = _Harness(topics: repository);
        final provider = teacherTopicEditControllerProvider(_topicId);
        final subscription = harness.container.listen(
          provider,
          (_, _) {},
          fireImmediately: true,
        );
        final controller = harness.container.read(provider.notifier)
          ..enterRoute();
        await flushTeacherControllers();
        controller.updateTitle('Attempted draft');

        await controller.submit();

        expect(
          subscription.read().status,
          TeacherTopicEditStatus.topicNotEditable,
        );
        expect(subscription.read().attemptedDraft!.title, 'Attempted draft');
        expect(subscription.read().topic!.title, 'Server current');
        expect(subscription.read().canSave, isFalse);
      },
    );

    test(
      'ambiguous PATCH reconciles match/mismatch and never repeats PATCH',
      () async {
        for (final matches in [true, false]) {
          var fetches = 0;
          final repository = FakeTeacherTopicRepository(
            onFetch: (id) async {
              fetches += 1;
              return teacherTopic(
                id: id,
                title: fetches == 1 || !matches ? 'Original' : 'Updated',
              );
            },
            onUpdate: (_, _) async =>
                throw const TeacherTopicMutationOutcomeUnknownException(),
          );
          final harness = _Harness(topics: repository);
          final provider = teacherTopicEditControllerProvider(_topicId);
          final subscription = harness.container.listen(
            provider,
            (_, _) {},
            fireImmediately: true,
          );
          final controller = harness.container.read(provider.notifier)
            ..enterRoute();
          await flushTeacherControllers();
          controller.updateTitle('Updated');
          await controller.submit();

          expect(repository.updateRequests, hasLength(1));
          expect(repository.fetchIds, hasLength(2));
          expect(
            subscription.read().status,
            matches
                ? TeacherTopicEditStatus.confirmedSuccess
                : TeacherTopicEditStatus.unconfirmedCurrentState,
          );
        }
      },
    );

    test('edit server validation maps fields and never sends Group', () async {
      final repository = FakeTeacherTopicRepository(
        onFetch: (id) async => teacherTopic(id: id),
        onUpdate: (_, _) async => throw ApiRequestException(
          ApiFailure(
            kind: ApiFailureKind.validation,
            statusCode: 422,
            serverCode: ApiErrorCodes.validationFailed,
            message: 'Raw validation response.',
            fieldErrors: const {
              'subject': ['Raw Laravel subject message.'],
            },
          ),
        ),
      );
      final harness = _Harness(topics: repository);
      final provider = teacherTopicEditControllerProvider(_topicId);
      final subscription = harness.container.listen(
        provider,
        (_, _) {},
        fireImmediately: true,
      );
      final controller = harness.container.read(provider.notifier)
        ..enterRoute();
      await flushTeacherControllers();
      controller.updateSubject('Changed subject');

      await controller.submit();

      expect(repository.updateRequests.single.request.toJson(), {
        'subject': 'Changed subject',
      });
      expect(
        subscription.read().fieldErrors[TeacherTopicFormField.subject],
        'Review the subject.',
      );
    });

    test(
      'failed reconciliation exposes GET-only Check current Topic',
      () async {
        var fetches = 0;
        final repository = FakeTeacherTopicRepository(
          onFetch: (id) async {
            fetches += 1;
            if (fetches == 2) {
              throw teacherLocalFailure(ApiFailureKind.connection);
            }
            return teacherTopic(
              id: id,
              title: fetches == 3 ? 'Updated' : 'Original',
            );
          },
          onUpdate: (_, _) async =>
              throw const TeacherTopicMutationOutcomeUnknownException(),
        );
        final harness = _Harness(topics: repository);
        final provider = teacherTopicEditControllerProvider(_topicId);
        final subscription = harness.container.listen(
          provider,
          (_, _) {},
          fireImmediately: true,
        );
        final controller = harness.container.read(provider.notifier)
          ..enterRoute();
        await flushTeacherControllers();
        controller.updateTitle('Updated');
        await controller.submit();
        expect(
          subscription.read().status,
          TeacherTopicEditStatus.outcomeUnknown,
        );

        await controller.checkCurrentTopic();
        expect(repository.updateRequests, hasLength(1));
        expect(repository.fetchIds, hasLength(3));
        expect(
          subscription.read().status,
          TeacherTopicEditStatus.confirmedSuccess,
        );
      },
    );

    test(
      'failed topic_not_editable refresh remains non-editable after Check',
      () async {
        var fetches = 0;
        final repository = FakeTeacherTopicRepository(
          onFetch: (id) async {
            fetches += 1;
            if (fetches == 2) {
              throw teacherLocalFailure(ApiFailureKind.connection);
            }
            return teacherTopic(
              id: id,
              title: fetches == 3 ? 'Updated' : 'Original',
            );
          },
          onUpdate: (_, _) async => throw teacherServerFailure(
            ApiErrorCodes.topicNotEditable,
            statusCode: 409,
          ),
        );
        final harness = _Harness(topics: repository);
        final provider = teacherTopicEditControllerProvider(_topicId);
        final subscription = harness.container.listen(
          provider,
          (_, _) {},
          fireImmediately: true,
        );
        final controller = harness.container.read(provider.notifier)
          ..enterRoute();
        await flushTeacherControllers();
        controller.updateTitle('Updated');
        await controller.submit();
        expect(
          subscription.read().status,
          TeacherTopicEditStatus.outcomeUnknown,
        );

        await controller.checkCurrentTopic();

        expect(repository.updateRequests, hasLength(1));
        expect(
          subscription.read().status,
          TeacherTopicEditStatus.topicNotEditable,
        );
        expect(subscription.read().canSave, isFalse);
      },
    );
  });

  group('TeacherTopicLifecycleController', () {
    test('action matrix covers active and archived Group states', () {
      final active = teacherGroup();
      final archived = teacherGroup(status: TeacherGroupStatus.archived);
      expect(teacherTopicLifecycleActions(teacherTopic(group: active)), [
        TeacherTopicLifecycleAction.activate,
        TeacherTopicLifecycleAction.archive,
      ]);
      expect(
        teacherTopicLifecycleActions(
          teacherTopic(group: archived, status: TeacherTopicStatus.active),
        ),
        [TeacherTopicLifecycleAction.close],
      );
      expect(
        teacherTopicLifecycleActions(
          teacherTopic(group: archived, status: TeacherTopicStatus.archived),
        ),
        isEmpty,
      );
      expect(
        teacherTopicCanEdit(
          teacherTopic(group: archived, status: TeacherTopicStatus.draft),
        ),
        isFalse,
      );
    });

    test('confirmed lifecycle updates detail/list authority', () async {
      final repository = FakeTeacherTopicRepository(
        onFetch: (id) async => teacherTopic(id: id),
        onLifecycle: (id, action) async =>
            teacherTopic(id: id, status: action.expectedStatus),
      );
      final harness = _Harness(topics: repository);
      final detailProvider = teacherTopicDetailControllerProvider(_topicId);
      final detailSubscription = harness.container.listen(
        detailProvider,
        (_, _) {},
        fireImmediately: true,
      );
      await flushTeacherControllers();
      final lifecycleProvider = teacherTopicLifecycleControllerProvider(
        _topicId,
      );
      final lifecycleSubscription = harness.container.listen(
        lifecycleProvider,
        (_, _) {},
        fireImmediately: true,
      );

      await harness.container
          .read(lifecycleProvider.notifier)
          .perform(TeacherTopicLifecycleAction.activate);

      expect(repository.lifecycleRequests, hasLength(1));
      expect(
        lifecycleSubscription.read().status,
        TeacherTopicLifecycleStatus.confirmedSuccess,
      );
      expect(
        detailSubscription.read().topic!.status,
        TeacherTopicStatus.active,
      );
      expect(
        harness.container
            .read(teacherTopicListRetainedQueryProvider)
            .value!
            .authoritativeRowsStale,
        isTrue,
      );
    });

    test(
      'unknown lifecycle reconciles each target without repeating POST',
      () async {
        for (final action in TeacherTopicLifecycleAction.values) {
          final initialStatus = switch (action) {
            TeacherTopicLifecycleAction.activate => TeacherTopicStatus.draft,
            TeacherTopicLifecycleAction.close => TeacherTopicStatus.active,
            TeacherTopicLifecycleAction.archive => TeacherTopicStatus.closed,
          };
          var fetches = 0;
          final repository = FakeTeacherTopicRepository(
            onFetch: (id) async {
              fetches += 1;
              return teacherTopic(
                id: id,
                status: fetches == 1 ? initialStatus : action.expectedStatus,
              );
            },
            onLifecycle: (_, _) async =>
                throw const TeacherTopicMutationOutcomeUnknownException(),
          );
          final harness = _Harness(topics: repository);
          harness.container.listen(
            teacherTopicDetailControllerProvider(_topicId),
            (_, _) {},
            fireImmediately: true,
          );
          await flushTeacherControllers();
          final lifecycleProvider = teacherTopicLifecycleControllerProvider(
            _topicId,
          );
          final subscription = harness.container.listen(
            lifecycleProvider,
            (_, _) {},
            fireImmediately: true,
          );

          await harness.container
              .read(lifecycleProvider.notifier)
              .perform(action);

          expect(repository.lifecycleRequests, hasLength(1));
          expect(repository.fetchIds, hasLength(2));
          expect(
            subscription.read().status,
            TeacherTopicLifecycleStatus.confirmedSuccess,
          );
        }
      },
    );

    test(
      'topic_not_editable refreshes current state without guessing',
      () async {
        var fetches = 0;
        final repository = FakeTeacherTopicRepository(
          onFetch: (id) async {
            fetches += 1;
            return teacherTopic(
              id: id,
              status: fetches == 1
                  ? TeacherTopicStatus.draft
                  : TeacherTopicStatus.closed,
            );
          },
          onLifecycle: (_, _) async => throw teacherServerFailure(
            ApiErrorCodes.topicNotEditable,
            statusCode: 409,
          ),
        );
        final harness = _Harness(topics: repository);
        harness.container.listen(
          teacherTopicDetailControllerProvider(_topicId),
          (_, _) {},
          fireImmediately: true,
        );
        await flushTeacherControllers();
        final provider = teacherTopicLifecycleControllerProvider(_topicId);
        final subscription = harness.container.listen(
          provider,
          (_, _) {},
          fireImmediately: true,
        );

        await harness.container
            .read(provider.notifier)
            .perform(TeacherTopicLifecycleAction.activate);

        expect(
          subscription.read().status,
          TeacherTopicLifecycleStatus.notAvailable,
        );
        expect(repository.fetchIds, hasLength(2));
      },
    );

    test(
      'topic_not_editable remains not available after GET-only retry',
      () async {
        var fetches = 0;
        final repository = FakeTeacherTopicRepository(
          onFetch: (id) async {
            fetches += 1;
            if (fetches == 2) {
              throw teacherLocalFailure(ApiFailureKind.connection);
            }
            return teacherTopic(
              id: id,
              status: fetches == 1
                  ? TeacherTopicStatus.draft
                  : TeacherTopicStatus.active,
            );
          },
          onLifecycle: (_, _) async => throw teacherServerFailure(
            ApiErrorCodes.topicNotEditable,
            statusCode: 409,
          ),
        );
        final harness = _Harness(topics: repository);
        harness.container.listen(
          teacherTopicDetailControllerProvider(_topicId),
          (_, _) {},
          fireImmediately: true,
        );
        await flushTeacherControllers();
        final provider = teacherTopicLifecycleControllerProvider(_topicId);
        final subscription = harness.container.listen(
          provider,
          (_, _) {},
          fireImmediately: true,
        );
        final controller = harness.container.read(provider.notifier);

        await controller.perform(TeacherTopicLifecycleAction.activate);
        expect(
          subscription.read().status,
          TeacherTopicLifecycleStatus.outcomeUnknown,
        );

        await controller.checkCurrentTopic();

        expect(repository.lifecycleRequests, hasLength(1));
        expect(repository.fetchIds, hasLength(3));
        expect(
          subscription.read().status,
          TeacherTopicLifecycleStatus.notAvailable,
        );
      },
    );

    test(
      'mismatching and failed lifecycle reconciliation never repeat POST',
      () async {
        for (final reconciliationFails in [false, true]) {
          var fetches = 0;
          final repository = FakeTeacherTopicRepository(
            onFetch: (id) async {
              fetches += 1;
              if (reconciliationFails && fetches == 2) {
                throw teacherLocalFailure(ApiFailureKind.connection);
              }
              return teacherTopic(
                id: id,
                status: fetches == 3
                    ? TeacherTopicStatus.active
                    : TeacherTopicStatus.draft,
              );
            },
            onLifecycle: (_, _) async =>
                throw const TeacherTopicMutationOutcomeUnknownException(),
          );
          final harness = _Harness(topics: repository);
          harness.container.listen(
            teacherTopicDetailControllerProvider(_topicId),
            (_, _) {},
            fireImmediately: true,
          );
          await flushTeacherControllers();
          final provider = teacherTopicLifecycleControllerProvider(_topicId);
          final subscription = harness.container.listen(
            provider,
            (_, _) {},
            fireImmediately: true,
          );
          final controller = harness.container.read(provider.notifier);

          await controller.perform(TeacherTopicLifecycleAction.activate);
          expect(repository.lifecycleRequests, hasLength(1));
          if (reconciliationFails) {
            expect(
              subscription.read().status,
              TeacherTopicLifecycleStatus.outcomeUnknown,
            );
            await controller.checkCurrentTopic();
            expect(repository.lifecycleRequests, hasLength(1));
            expect(
              subscription.read().status,
              TeacherTopicLifecycleStatus.confirmedSuccess,
            );
          } else {
            expect(
              subscription.read().status,
              TeacherTopicLifecycleStatus.unconfirmedCurrentState,
            );
          }
        }
      },
    );

    test('mobile cannot dispatch lifecycle operations', () async {
      final repository = FakeTeacherTopicRepository();
      final harness = _Harness(
        topics: repository,
        surface: AppDeviceSurface.mobile,
      );
      final provider = teacherTopicLifecycleControllerProvider(_topicId);
      harness.container.listen(provider, (_, _) {}, fireImmediately: true);

      await harness.container
          .read(provider.notifier)
          .perform(TeacherTopicLifecycleAction.activate);

      expect(repository.lifecycleRequests, isEmpty);
    });
  });
}

void _fillCreate(TeacherTopicCreateController controller) {
  controller
    ..selectGroup(teacherGroup())
    ..updateTitle('Topic title')
    ..updateSubject('Subject')
    ..updateStudentInstructions('Instructions');
}

class _Harness {
  _Harness({
    FakeTeacherAuthSessionController? auth,
    FakeTeacherGroupListRepository? groups,
    FakeTeacherTopicRepository? topics,
    this.surface = AppDeviceSurface.desktop,
  }) : auth =
           auth ??
           FakeTeacherAuthSessionController.authenticated(
             teacherUser('teacher-a'),
           ),
       groups = groups ?? FakeTeacherGroupListRepository(),
       topics = topics ?? FakeTeacherTopicRepository() {
    container = ProviderContainer(
      overrides: [
        authSessionControllerProvider.overrideWith(() => this.auth),
        appDeviceSurfaceProvider.overrideWithValue(surface),
        teacherGroupListRepositoryProvider.overrideWithValue(this.groups),
        teacherTopicRepositoryProvider.overrideWithValue(this.topics),
        teacherTopicListRepositoryProvider.overrideWithValue(
          FakeTeacherTopicListRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);
  }

  final FakeTeacherAuthSessionController auth;
  final FakeTeacherGroupListRepository groups;
  final FakeTeacherTopicRepository topics;
  final AppDeviceSurface surface;
  late final ProviderContainer container;
}
