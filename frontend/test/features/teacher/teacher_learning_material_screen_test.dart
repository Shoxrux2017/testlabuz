import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/app.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/app/router/app_router.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_material_file_picker.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_group_list_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_learning_material_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_topic_list_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_topic_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_group.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_learning_material.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_learning_material_mutation.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_topic.dart';

import 'teacher_test_support.dart';

const _topicId = '10000000-0000-0000-0000-000000000001';

void main() {
  testWidgets(
    'desktop Material section loads capability and editable actions',
    (tester) async {
      final materials = FakeTeacherLearningMaterialRepository();
      await _pump(tester, materials: materials);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('teacherLearningMaterialsSection')),
        findsOneWidget,
      );
      expect(
        find.text('Allowed: PDF, DOCX, PPT, PPTX\nMaximum size: 20 MiB'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('teacherMaterialUploadButton')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey(
            'teacherMaterialReplace20000000-0000-0000-0000-000000000001',
          ),
        ),
        findsOneWidget,
      );
      expect(find.text('Lesson slides'), findsOneWidget);
      expect(find.text('lesson.pptx'), findsOneWidget);
      expect(find.text('PPTX'), findsOneWidget);
      expect(materials.fetchIds, [_topicId]);
    },
  );

  testWidgets('initial loading, empty, and error states are explicit', (
    tester,
  ) async {
    final completer = Completer<TeacherLearningMaterialCollection>();
    final loading = FakeTeacherLearningMaterialRepository(
      onFetch: (_) => completer.future,
    );
    await _pump(tester, materials: loading);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('teacherMaterialsLoading')), findsOneWidget);
    completer.complete(teacherMaterialCollection(materials: []));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('teacherMaterialsEmpty')), findsOneWidget);

    await _pump(
      tester,
      materials: FakeTeacherLearningMaterialRepository(
        onFetch: (_) async =>
            throw teacherLocalFailure(ApiFailureKind.connection),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('teacherMaterialsError')), findsOneWidget);
    expect(
      find.byKey(const Key('teacherMaterialsRetryButton')),
      findsOneWidget,
    );
  });

  testWidgets(
    'historical Topic and archived Group are read and transfer only',
    (tester) async {
      for (final topic in [
        teacherTopic(status: TeacherTopicStatus.closed),
        teacherTopic(group: teacherGroup(status: TeacherGroupStatus.archived)),
      ]) {
        await _pump(
          tester,
          topics: FakeTeacherTopicRepository(onFetch: (_) async => topic),
          materials: FakeTeacherLearningMaterialRepository(),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('teacherMaterialUploadButton')),
          findsNothing,
        );
        expect(find.text('Replace file'), findsNothing);
        expect(find.text('Edit title'), findsNothing);
        expect(find.text('Remove material'), findsNothing);
        expect(find.text('Open'), findsOneWidget);
        expect(find.text('Save as…'), findsOneWidget);
      }
    },
  );

  testWidgets('upload uses injectable picker and exact optional title UX', (
    tester,
  ) async {
    final materials = FakeTeacherLearningMaterialRepository();
    await _pump(
      tester,
      materials: materials,
      picker: _FakePicker(_uploadFile()),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('teacherMaterialUploadButton')),
    );
    await tester.tap(find.byKey(const Key('teacherMaterialUploadButton')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('teacherMaterialUploadDialog')),
      findsOneWidget,
    );
    expect(
      find.text('Leave the title empty to use the original file name.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('teacherMaterialChooseFileButton')));
    await tester.pumpAndSettle();
    expect(find.text('picked.pdf'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('teacherMaterialUploadSubmitButton')),
    );
    await tester.pumpAndSettle();

    expect(materials.uploadRequests, hasLength(1));
    expect(materials.uploadRequests.single.title, isNull);
    expect(find.text('Learning material uploaded.'), findsOneWidget);
  });

  testWidgets('replace and remove require confirmation before dispatch', (
    tester,
  ) async {
    final materials = FakeTeacherLearningMaterialRepository();
    await _pump(
      tester,
      materials: materials,
      picker: _FakePicker(_uploadFile()),
    );
    await tester.pumpAndSettle();
    final replace = find.byKey(
      const ValueKey(
        'teacherMaterialReplace20000000-0000-0000-0000-000000000001',
      ),
    );
    await tester.ensureVisible(replace);
    await tester.tap(replace);
    await tester.pumpAndSettle();
    expect(find.text('Replace this file?'), findsOneWidget);
    expect(materials.replaceRequests, isEmpty);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    final remove = find.byKey(
      const ValueKey(
        'teacherMaterialRemove20000000-0000-0000-0000-000000000001',
      ),
    );
    await tester.ensureVisible(remove);
    await tester.tap(remove);
    await tester.pumpAndSettle();
    expect(find.text('Remove this learning material?'), findsOneWidget);
    expect(materials.removeRequests, isEmpty);
    await tester.tap(
      find.byKey(const Key('teacherMaterialRemoveConfirmButton')),
    );
    await tester.pumpAndSettle();
    expect(materials.removeRequests, hasLength(1));
  });

  testWidgets(
    'mutation progress is announced and conflicting controls disable',
    (tester) async {
      final upload = Completer<TeacherLearningMaterial>();
      final materials = FakeTeacherLearningMaterialRepository(
        onUpload: (_, _, _, onProgress) {
          onProgress?.call(2, 4);
          return upload.future;
        },
      );
      await _pump(
        tester,
        materials: materials,
        picker: _FakePicker(_uploadFile()),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('teacherMaterialUploadButton')),
      );
      await tester.tap(find.byKey(const Key('teacherMaterialUploadButton')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('teacherMaterialChooseFileButton')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('teacherMaterialUploadSubmitButton')),
      );
      await tester.pump();

      final progress = tester.widget<LinearProgressIndicator>(
        find.byKey(const Key('teacherMaterialsBusyProgress')),
      );
      expect(progress.value, 0.5);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('teacherTopicLifecycleactivate')),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextButton>(
              find.byKey(
                const ValueKey(
                  'teacherMaterialReplace20000000-0000-0000-0000-000000000001',
                ),
              ),
            )
            .onPressed,
        isNull,
      );

      upload.complete(teacherMaterial());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'stale remove confirmation cannot dispatch in replacement session',
    (tester) async {
      final auth = FakeTeacherAuthSessionController.authenticated(
        teacherUser('teacher-a'),
      );
      final materials = FakeTeacherLearningMaterialRepository();
      await _pump(tester, materials: materials, auth: auth);
      await tester.pumpAndSettle();
      final remove = find.byKey(
        const ValueKey(
          'teacherMaterialRemove20000000-0000-0000-0000-000000000001',
        ),
      );
      await tester.ensureVisible(remove);
      await tester.tap(remove);
      await tester.pumpAndSettle();

      auth.replaceUser(teacherUser('teacher-b'));
      await tester.pump();
      await tester.tap(
        find.byKey(const Key('teacherMaterialRemoveConfirmButton')),
      );
      await tester.pumpAndSettle();

      expect(materials.removeRequests, isEmpty);
    },
  );

  testWidgets(
    'long Material names and narrow desktop use wrapping without overflow',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(700, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _pump(
        tester,
        materials: FakeTeacherLearningMaterialRepository(
          onFetch: (_) async => teacherMaterialCollection(
            materials: [
              teacherMaterial(
                title: List.filled(220, 'Uzun').join(' '),
                originalName: '${List.filled(100, 'document').join('-')}.pptx',
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('teacherLearningMaterialsSection')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('mobile Topic Detail gains no Material UI or Material GET', (
    tester,
  ) async {
    final materials = FakeTeacherLearningMaterialRepository();
    await _pump(tester, materials: materials, surface: AppDeviceSurface.mobile);
    await tester.pumpAndSettle();

    expect(find.text('Learning Materials'), findsNothing);
    expect(find.text('Open'), findsNothing);
    expect(find.text('Save as…'), findsNothing);
    expect(materials.fetchIds, isEmpty);
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required FakeTeacherLearningMaterialRepository materials,
  FakeTeacherTopicRepository? topics,
  FakeTeacherAuthSessionController? auth,
  TeacherMaterialFilePicker? picker,
  AppDeviceSurface surface = AppDeviceSurface.desktop,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        appInitialLocationProvider.overrideWithValue(
          AppRoutePaths.teacherTopicDetailLocation(_topicId),
        ),
        authSessionControllerProvider.overrideWith(
          () =>
              auth ??
              FakeTeacherAuthSessionController.authenticated(
                teacherUser('teacher-a'),
              ),
        ),
        appDeviceSurfaceProvider.overrideWithValue(surface),
        teacherGroupListRepositoryProvider.overrideWithValue(
          FakeTeacherGroupListRepository(),
        ),
        teacherTopicListRepositoryProvider.overrideWithValue(
          FakeTeacherTopicListRepository(),
        ),
        teacherTopicRepositoryProvider.overrideWithValue(
          topics ?? FakeTeacherTopicRepository(),
        ),
        teacherLearningMaterialRepositoryProvider.overrideWithValue(materials),
        if (picker != null)
          teacherMaterialFilePickerProvider.overrideWithValue(picker),
      ],
      child: const TestLabUzApp(),
    ),
  );
  await tester.pump();
  await tester.pump();
}

TeacherMaterialUploadFile _uploadFile() {
  return TeacherMaterialUploadFile(
    name: 'picked.pdf',
    length: 4,
    openRead: () => Stream<List<int>>.value([1, 2, 3, 4]),
  );
}

class _FakePicker implements TeacherMaterialFilePicker {
  const _FakePicker(this.file);

  final TeacherMaterialUploadFile file;

  @override
  Future<TeacherMaterialUploadFile?> pickFile() async => file;
}
