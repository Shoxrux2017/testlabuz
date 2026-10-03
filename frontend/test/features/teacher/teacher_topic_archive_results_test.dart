import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/app.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/app/router/app_router.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_blitz_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_group_list_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_homework_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_learning_material_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_topic_list_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_topic_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_topic_result_pair_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_topic_result_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_topic.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_topic_mutation.dart';

import 'teacher_test_support.dart';
import 'teacher_topic_result_test_support.dart';

void main() {
  testWidgets('archiving warns that results close and reloads them', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final topics = FakeTeacherTopicRepository(
      onFetch: (id) async =>
          teacherTopic(id: id, status: TeacherTopicStatus.closed),
    );
    final results = FakeTeacherTopicResultRepository(
      onFetchResults: (_, query) async => teacherTopicResultList(query: query),
    );
    await _pumpApp(tester, topics: topics, results: results);
    final reads = results.listRequests.length;
    expect(reads, greaterThan(0));

    await tester.tap(
      find.byKey(const ValueKey('teacherTopicLifecyclearchive')),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(
        'The Topic content is retained as historical read-only data. '
        'Archiving also closes every calculated or Not completed Topic result '
        'for good; results still waiting stay open.',
      ),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const Key('teacherTopicLifecycleConfirmButton')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Topic archived successfully.'), findsOneWidget);
    expect(results.listRequests.length, reads + 1);
  });

  testWidgets('a Topic found archived after a conflict reloads the results', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var reads = 0;
    final topics = FakeTeacherTopicRepository(
      onFetch: (id) async {
        reads += 1;
        return teacherTopic(
          id: id,
          status: reads == 1
              ? TeacherTopicStatus.closed
              : TeacherTopicStatus.archived,
        );
      },
      onLifecycle: (_, _) async => throw teacherServerFailure(
        ApiErrorCodes.topicNotEditable,
        statusCode: 409,
      ),
    );
    final results = FakeTeacherTopicResultRepository(
      onFetchResults: (_, query) async => teacherTopicResultList(query: query),
    );
    await _pumpApp(tester, topics: topics, results: results);
    final resultReads = results.listRequests.length;

    await tester.tap(
      find.byKey(const ValueKey('teacherTopicLifecyclearchive')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('teacherTopicLifecycleConfirmButton')),
    );
    await tester.pumpAndSettle();

    expect(reads, 2);
    expect(results.listRequests.length, resultReads + 1);
  });

  testWidgets('a confirmed archive after an unknown outcome reloads once', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var reads = 0;
    final topics = FakeTeacherTopicRepository(
      onFetch: (id) async {
        reads += 1;
        return teacherTopic(
          id: id,
          status: reads == 1
              ? TeacherTopicStatus.closed
              : TeacherTopicStatus.archived,
        );
      },
      onLifecycle: (_, _) async =>
          throw const TeacherTopicMutationOutcomeUnknownException(),
    );
    final results = FakeTeacherTopicResultRepository(
      onFetchResults: (_, query) async => teacherTopicResultList(query: query),
    );
    await _pumpApp(tester, topics: topics, results: results);
    final resultReads = results.listRequests.length;

    await tester.tap(
      find.byKey(const ValueKey('teacherTopicLifecyclearchive')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('teacherTopicLifecycleConfirmButton')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Topic archived successfully.'), findsOneWidget);
    expect(results.listRequests.length, resultReads + 1);
  });
}

Future<void> _pumpApp(
  WidgetTester tester, {
  required FakeTeacherTopicRepository topics,
  required FakeTeacherTopicResultRepository results,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        appInitialLocationProvider.overrideWithValue(
          AppRoutePaths.teacherTopicDetailLocation(teacherResultTopicId),
        ),
        authSessionControllerProvider.overrideWith(
          () => FakeTeacherAuthSessionController.authenticated(
            teacherUser('teacher-a'),
          ),
        ),
        appDeviceSurfaceProvider.overrideWithValue(AppDeviceSurface.desktop),
        teacherGroupListRepositoryProvider.overrideWithValue(
          FakeTeacherGroupListRepository(),
        ),
        teacherTopicListRepositoryProvider.overrideWithValue(
          FakeTeacherTopicListRepository(),
        ),
        teacherTopicRepositoryProvider.overrideWithValue(topics),
        teacherLearningMaterialRepositoryProvider.overrideWithValue(
          FakeTeacherLearningMaterialRepository(),
        ),
        teacherHomeworkRepositoryProvider.overrideWithValue(
          FakeTeacherHomeworkRepository(),
        ),
        teacherTopicResultPairRepositoryProvider.overrideWithValue(
          FakeTeacherTopicResultPairRepository(),
        ),
        teacherBlitzRepositoryProvider.overrideWithValue(
          FakeTeacherBlitzRepository(),
        ),
        teacherTopicResultRepositoryProvider.overrideWithValue(results),
      ],
      child: const TestLabUzApp(),
    ),
  );
  await tester.pumpAndSettle();
}
