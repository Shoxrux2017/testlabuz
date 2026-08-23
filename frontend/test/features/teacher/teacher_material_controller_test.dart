import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_error_response.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_material_file_picker.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_material_list_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_material_mutation_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_material_mutation_state.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_topic_detail_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_topic_lifecycle_controller.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_learning_material_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_topic_list_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_topic_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_learning_material.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_learning_material_mutation.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_topic.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_topic_mutation.dart';

import 'teacher_test_support.dart';

const _topicId = '10000000-0000-0000-0000-000000000001';

void main() {
  test('Teacher file picker boundary is injectable and fakeable', () async {
    final picked = _uploadFile('lesson.pdf', length: 4);
    final container = ProviderContainer(
      overrides: [
        teacherMaterialFilePickerProvider.overrideWithValue(
          _FakePicker(picked),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(
      await container.read(teacherMaterialFilePickerProvider).pickFile(),
      same(picked),
    );
  });

  group('TeacherMaterialMutationController', () {
    test('local file and title validation dispatch no mutation', () async {
      final materials = FakeTeacherLearningMaterialRepository();
      final harness = await _Harness.ready(materials: materials);
      final controller = harness.container.read(
        teacherMaterialMutationControllerProvider(_topicId).notifier,
      );

      await controller.uploadMaterial(
        file: _uploadFile('lesson.txt', length: 1),
        title: '',
      );
      expect(materials.uploadRequests, isEmpty);
      expect(harness.mutation.fieldErrors['file'], contains('supported'));

      await controller.uploadMaterial(
        file: _uploadFile('lesson.PDF', length: 20_971_521),
        title: '',
      );
      expect(materials.uploadRequests, isEmpty);
      expect(harness.mutation.fieldErrors['file'], contains('allowed size'));

      await controller.uploadMaterial(
        file: _uploadFile('lesson.PDF', length: 4),
        title: List.filled(256, 'x').join(),
      );
      expect(materials.uploadRequests, isEmpty);
      expect(harness.mutation.fieldErrors['title'], contains('255'));
    });

    test(
      'confirmed upload omits blank title, publishes progress, and GET refreshes',
      () async {
        final materials = FakeTeacherLearningMaterialRepository(
          onUpload: (topicId, file, title, onProgress) async {
            onProgress?.call(2, 4);
            onProgress?.call(4, 4);
            return teacherMaterial(topicId: topicId, title: title);
          },
        );
        final harness = await _Harness.ready(materials: materials);

        final success = await harness.container
            .read(teacherMaterialMutationControllerProvider(_topicId).notifier)
            .uploadMaterial(
              file: _uploadFile('lesson.PDF', length: 4),
              title: '   ',
            );

        expect(success, isTrue);
        expect(materials.uploadRequests, hasLength(1));
        expect(materials.uploadRequests.single.title, isNull);
        expect(materials.fetchIds, [_topicId, _topicId]);
        expect(
          harness.mutation.status,
          TeacherMaterialMutationStatus.confirmedSuccess,
        );
        expect(harness.mutation.sentBytes, 4);
        expect(harness.mutation.totalBytes, 4);
      },
    );

    test('unknown upload performs one GET and never repeats POST', () async {
      final materials = FakeTeacherLearningMaterialRepository(
        onUpload: (_, _, _, _) async =>
            throw const TeacherMaterialMutationOutcomeUnknownException(),
      );
      final harness = await _Harness.ready(materials: materials);

      await harness.container
          .read(teacherMaterialMutationControllerProvider(_topicId).notifier)
          .uploadMaterial(file: _uploadFile('lesson.pdf'), title: 'Lesson');

      expect(materials.uploadRequests, hasLength(1));
      expect(materials.fetchIds, [_topicId, _topicId]);
      expect(
        harness.mutation.status,
        TeacherMaterialMutationStatus.unconfirmedCurrentState,
      );
      expect(harness.mutation.feedback, contains('could not be confirmed'));
    });

    test('unknown replace refreshes metadata and never repeats POST', () async {
      final materials = FakeTeacherLearningMaterialRepository(
        onReplace: (_, _, _, _) async =>
            throw const TeacherMaterialMutationOutcomeUnknownException(),
      );
      final harness = await _Harness.ready(materials: materials);

      await harness.container
          .read(teacherMaterialMutationControllerProvider(_topicId).notifier)
          .replaceMaterialFile(
            current: teacherMaterial(),
            file: _uploadFile('replacement.pptx'),
          );

      expect(materials.replaceRequests, hasLength(1));
      expect(materials.fetchIds, [_topicId, _topicId]);
      expect(
        harness.mutation.status,
        TeacherMaterialMutationStatus.unconfirmedCurrentState,
      );
    });

    test('title exact no-op sends no PATCH and null clear is exact', () async {
      final materials = FakeTeacherLearningMaterialRepository();
      final harness = await _Harness.ready(materials: materials);
      final controller = harness.container.read(
        teacherMaterialMutationControllerProvider(_topicId).notifier,
      );

      await controller.updateMaterialTitle(
        current: teacherMaterial(title: 'Lesson slides'),
        title: ' Lesson slides ',
        useOriginalFileName: false,
      );
      expect(materials.titleRequests, isEmpty);
      expect(harness.mutation.status, TeacherMaterialMutationStatus.noChanges);

      await controller.updateMaterialTitle(
        current: teacherMaterial(title: 'Lesson slides'),
        title: 'ignored',
        useOriginalFileName: true,
      );
      expect(materials.titleRequests.single.title, isNull);
    });

    test(
      'ambiguous title and remove use GET evidence for reconciled success',
      () async {
        var titleFetches = 0;
        final titleMaterials = FakeTeacherLearningMaterialRepository(
          onFetch: (_) async {
            titleFetches += 1;
            return teacherMaterialCollection(
              materials: [
                teacherMaterial(
                  title: titleFetches == 1 ? 'Lesson slides' : 'Updated',
                ),
              ],
            );
          },
          onUpdateTitle: (_, _, _) async =>
              throw const TeacherMaterialMutationOutcomeUnknownException(),
        );
        final titleHarness = await _Harness.ready(materials: titleMaterials);
        await titleHarness.container
            .read(teacherMaterialMutationControllerProvider(_topicId).notifier)
            .updateMaterialTitle(
              current: teacherMaterial(),
              title: ' Updated ',
              useOriginalFileName: false,
            );
        expect(titleMaterials.titleRequests, hasLength(1));
        expect(
          titleHarness.mutation.status,
          TeacherMaterialMutationStatus.confirmedSuccess,
        );

        var removeFetches = 0;
        final removeMaterials = FakeTeacherLearningMaterialRepository(
          onFetch: (_) async {
            removeFetches += 1;
            return teacherMaterialCollection(
              materials: removeFetches == 1 ? [teacherMaterial()] : [],
            );
          },
          onRemove: (_, _) async =>
              throw const TeacherMaterialMutationOutcomeUnknownException(),
        );
        final removeHarness = await _Harness.ready(materials: removeMaterials);
        await removeHarness.container
            .read(teacherMaterialMutationControllerProvider(_topicId).notifier)
            .removeMaterial(teacherMaterial());
        expect(removeMaterials.removeRequests, hasLength(1));
        expect(
          removeHarness.mutation.status,
          TeacherMaterialMutationStatus.confirmedSuccess,
        );
      },
    );

    test(
      'ambiguous title and remove remain unconfirmed without GET evidence',
      () async {
        final titleMaterials = FakeTeacherLearningMaterialRepository(
          onUpdateTitle: (_, _, _) async =>
              throw const TeacherMaterialMutationOutcomeUnknownException(),
        );
        final titleHarness = await _Harness.ready(materials: titleMaterials);
        await titleHarness.container
            .read(teacherMaterialMutationControllerProvider(_topicId).notifier)
            .updateMaterialTitle(
              current: teacherMaterial(),
              title: 'Different',
              useOriginalFileName: false,
            );
        expect(
          titleHarness.mutation.status,
          TeacherMaterialMutationStatus.unconfirmedCurrentState,
        );

        final removeMaterials = FakeTeacherLearningMaterialRepository(
          onRemove: (_, _) async =>
              throw const TeacherMaterialMutationOutcomeUnknownException(),
        );
        final removeHarness = await _Harness.ready(materials: removeMaterials);
        await removeHarness.container
            .read(teacherMaterialMutationControllerProvider(_topicId).notifier)
            .removeMaterial(teacherMaterial());
        expect(
          removeHarness.mutation.status,
          TeacherMaterialMutationStatus.unconfirmedCurrentState,
        );
        expect(removeMaterials.removeRequests, hasLength(1));
      },
    );

    test(
      'failed unknown reconciliation exposes GET-only check action',
      () async {
        var fetches = 0;
        final materials = FakeTeacherLearningMaterialRepository(
          onFetch: (_) async {
            fetches += 1;
            if (fetches == 2) {
              throw teacherLocalFailure(ApiFailureKind.connection);
            }
            return teacherMaterialCollection(
              materials: fetches == 1 ? [teacherMaterial()] : [],
            );
          },
          onRemove: (_, _) async =>
              throw const TeacherMaterialMutationOutcomeUnknownException(),
        );
        final harness = await _Harness.ready(materials: materials);
        final controller = harness.container.read(
          teacherMaterialMutationControllerProvider(_topicId).notifier,
        );

        await controller.removeMaterial(teacherMaterial());
        expect(harness.mutation.canCheckCurrent, isTrue);
        await controller.checkCurrentMaterials();

        expect(materials.removeRequests, hasLength(1));
        expect(materials.fetchIds, [_topicId, _topicId, _topicId]);
        expect(
          harness.mutation.status,
          TeacherMaterialMutationStatus.confirmedSuccess,
        );
      },
    );

    test('file_too_large refreshes authoritative capability', () async {
      final materials = FakeTeacherLearningMaterialRepository(
        onUpload: (_, _, _, _) async => throw ApiRequestException(
          ApiFailure.fromServerError(
            statusCode: 422,
            error: ApiErrorResponse(
              message: 'Raw error.',
              code: ApiErrorCodes.fileTooLarge,
              fieldErrors: const {},
              requestId: 'req-1',
            ),
          ),
        ),
      );
      final harness = await _Harness.ready(materials: materials);

      await harness.container
          .read(teacherMaterialMutationControllerProvider(_topicId).notifier)
          .uploadMaterial(file: _uploadFile('lesson.pdf'), title: '');

      expect(materials.fetchIds, [_topicId, _topicId]);
      expect(harness.mutation.feedback, contains('allowed size'));
    });

    test(
      'topic_not_editable refreshes Topic then Materials authority',
      () async {
        var topicFetches = 0;
        final topics = FakeTeacherTopicRepository(
          onFetch: (id) async {
            topicFetches += 1;
            return teacherTopic(
              id: id,
              status: topicFetches == 1
                  ? TeacherTopicStatus.draft
                  : TeacherTopicStatus.closed,
            );
          },
        );
        final materials = FakeTeacherLearningMaterialRepository(
          onUpload: (_, _, _, _) async => throw teacherServerFailure(
            ApiErrorCodes.topicNotEditable,
            statusCode: 409,
          ),
        );
        final harness = await _Harness.ready(
          materials: materials,
          topics: topics,
        );

        await harness.container
            .read(teacherMaterialMutationControllerProvider(_topicId).notifier)
            .uploadMaterial(file: _uploadFile('lesson.pdf'), title: '');

        expect(topics.fetchIds, [_topicId, _topicId]);
        expect(materials.fetchIds, [_topicId, _topicId]);
        expect(
          harness.mutation.status,
          TeacherMaterialMutationStatus.notEditable,
        );
        expect(
          harness.container
              .read(teacherTopicDetailControllerProvider(_topicId))
              .topic
              ?.status,
          TeacherTopicStatus.closed,
        );
      },
    );

    test('lifecycle and Material mutation dispatch cross-disable', () async {
      final uploadCompleter = Completer<TeacherLearningMaterial>();
      final materials = FakeTeacherLearningMaterialRepository(
        onUpload: (_, _, _, _) => uploadCompleter.future,
      );
      final topics = FakeTeacherTopicRepository();
      final harness = await _Harness.ready(
        materials: materials,
        topics: topics,
      );
      final uploadFuture = harness.container
          .read(teacherMaterialMutationControllerProvider(_topicId).notifier)
          .uploadMaterial(file: _uploadFile('lesson.pdf'), title: '');
      await flushTeacherControllers();

      await harness.container
          .read(teacherTopicLifecycleControllerProvider(_topicId).notifier)
          .perform(TeacherTopicLifecycleAction.activate);
      expect(topics.lifecycleRequests, isEmpty);
      uploadCompleter.complete(teacherMaterial());
      await uploadFuture;

      final lifecycleCompleter = Completer<TeacherTopic>();
      final lifecycleTopics = FakeTeacherTopicRepository(
        onLifecycle: (_, _) => lifecycleCompleter.future,
      );
      final second = await _Harness.ready(
        materials: FakeTeacherLearningMaterialRepository(),
        topics: lifecycleTopics,
      );
      final lifecycleFuture = second.container
          .read(teacherTopicLifecycleControllerProvider(_topicId).notifier)
          .perform(TeacherTopicLifecycleAction.activate);
      await flushTeacherControllers();

      await second.container
          .read(teacherMaterialMutationControllerProvider(_topicId).notifier)
          .uploadMaterial(file: _uploadFile('lesson.pdf'), title: '');
      expect(second.materials.uploadRequests, isEmpty);
      lifecycleCompleter.complete(
        teacherTopic(status: TeacherTopicStatus.active),
      );
      await lifecycleFuture;
    });

    test(
      'stale session upload completion cannot publish or reconcile',
      () async {
        final completer = Completer<TeacherLearningMaterial>();
        final materials = FakeTeacherLearningMaterialRepository(
          onUpload: (_, _, _, _) => completer.future,
        );
        final auth = FakeTeacherAuthSessionController.authenticated(
          teacherUser('teacher-a'),
        );
        final harness = await _Harness.ready(materials: materials, auth: auth);
        final future = harness.container
            .read(teacherMaterialMutationControllerProvider(_topicId).notifier)
            .uploadMaterial(file: _uploadFile('lesson.pdf'), title: '');
        await flushTeacherControllers();

        auth.replaceUser(teacherUser('teacher-b'));
        await flushTeacherControllers();
        completer.complete(teacherMaterial());
        expect(await future, isFalse);

        expect(materials.uploadRequests, hasLength(1));
        expect(materials.fetchIds, [_topicId, _topicId]);
        expect(harness.mutation.feedback, isNull);
      },
    );
  });
}

TeacherMaterialUploadFile _uploadFile(String name, {int length = 4}) {
  return TeacherMaterialUploadFile(
    name: name,
    length: length,
    openRead: () => Stream<List<int>>.value(List<int>.filled(length, 1)),
  );
}

class _FakePicker implements TeacherMaterialFilePicker {
  const _FakePicker(this.file);

  final TeacherMaterialUploadFile file;

  @override
  Future<TeacherMaterialUploadFile?> pickFile() async => file;
}

class _Harness {
  _Harness._({
    required this.container,
    required this.auth,
    required this.materials,
  });

  static Future<_Harness> ready({
    required FakeTeacherLearningMaterialRepository materials,
    FakeTeacherTopicRepository? topics,
    FakeTeacherAuthSessionController? auth,
  }) async {
    final effectiveAuth =
        auth ??
        FakeTeacherAuthSessionController.authenticated(
          teacherUser('teacher-a'),
        );
    final container = ProviderContainer(
      overrides: [
        authSessionControllerProvider.overrideWith(() => effectiveAuth),
        appDeviceSurfaceProvider.overrideWithValue(AppDeviceSurface.desktop),
        teacherTopicRepositoryProvider.overrideWithValue(
          topics ?? FakeTeacherTopicRepository(),
        ),
        teacherTopicListRepositoryProvider.overrideWithValue(
          FakeTeacherTopicListRepository(),
        ),
        teacherLearningMaterialRepositoryProvider.overrideWithValue(materials),
      ],
    );
    addTearDown(container.dispose);
    container.listen(
      teacherTopicDetailControllerProvider(_topicId),
      (_, _) {},
      fireImmediately: true,
    );
    container.listen(
      teacherMaterialListControllerProvider(_topicId),
      (_, _) {},
      fireImmediately: true,
    );
    container.listen(
      teacherMaterialMutationControllerProvider(_topicId),
      (_, _) {},
      fireImmediately: true,
    );
    container.listen(
      teacherTopicLifecycleControllerProvider(_topicId),
      (_, _) {},
      fireImmediately: true,
    );
    await flushTeacherControllers();
    await flushTeacherControllers();
    return _Harness._(
      container: container,
      auth: effectiveAuth,
      materials: materials,
    );
  }

  final ProviderContainer container;
  final FakeTeacherAuthSessionController auth;
  final FakeTeacherLearningMaterialRepository materials;

  TeacherMaterialMutationState get mutation =>
      container.read(teacherMaterialMutationControllerProvider(_topicId));
}
