import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_error_response.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/institution_admin/application/institution_parent_student_relationship_list_controller.dart';
import 'package:testlabuz_client/features/institution_admin/application/institution_parent_student_relationship_list_state.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_parent_student_relationship_repository_impl.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_parent_student_relationship.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_parent_student_relationship_list.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_parent_student_relationship_mutation.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_parent_student_relationship_query.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_parent_student_relationship_repository.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user.dart';

import 'institution_parent_student_relationship_test_support.dart';

void main() {
  test(
    'no anchor sends no GET and perspectives preserve independent state',
    () async {
      final repository = _FakeRelationshipRepository();
      final container = _container(repository);
      final byParent = _listen(
        container,
        InstitutionParentStudentPerspective.byParent,
      );
      final byStudent = _listen(
        container,
        InstitutionParentStudentPerspective.byStudent,
      );
      await _flush();
      expect(repository.fetches, isEmpty);
      expect(
        byParent.read().status,
        InstitutionParentStudentRelationshipListStatus.noAnchor,
      );
      expect(
        byStudent.read().status,
        InstitutionParentStudentRelationshipListStatus.noAnchor,
      );

      _controller(
        container,
        InstitutionParentStudentPerspective.byParent,
      ).selectAnchor(testInstitutionUser());
      _controller(
        container,
        InstitutionParentStudentPerspective.byStudent,
      ).selectAnchor(
        testInstitutionUser(
          id: testStudentId,
          role: InstitutionUserRole.student,
          fullName: 'Student One',
          loginName: 'student.one',
        ),
      );
      await _flush();
      expect(repository.fetches, hasLength(2));
      expect(byParent.read().anchor!.id, testParentId);
      expect(byStudent.read().anchor!.id, testStudentId);
    },
  );

  test(
    'search pending invalid clear and one page correction are exact',
    () async {
      final repository = _FakeRelationshipRepository(
        onFetch: (perspective, anchorId, query) async {
          if (query.page == 2) {
            return _page(
              perspective,
              query,
              relationships: const [],
              total: 21,
              lastPage: 2,
            );
          }
          return _page(perspective, query, total: 21, lastPage: 2);
        },
      );
      final container = _container(repository);
      final subscription = _listen(
        container,
        InstitutionParentStudentPerspective.byParent,
      );
      final controller = _controller(
        container,
        InstitutionParentStudentPerspective.byParent,
      );
      controller.selectAnchor(testInstitutionUser());
      await _flush();

      controller.updateSearchDraft('  Ali % _ !  ');
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(repository.fetches, hasLength(1));
      await Future<void>.delayed(const Duration(milliseconds: 130));
      expect(repository.fetches.last.query.search, 'Ali % _ !');

      controller.updateSearchDraft('merged');
      controller.setStatus(
        InstitutionParentStudentRelationshipStatusFilter.inactive,
      );
      await _flush();
      expect(repository.fetches.last.query.search, 'merged');
      expect(
        repository.fetches.last.query.status,
        InstitutionParentStudentRelationshipStatusFilter.inactive,
      );

      final beforeInvalid = repository.fetches.length;
      controller.updateSearchDraft(List.filled(255, '😀').join());
      controller.refresh();
      controller.nextPage();
      await Future<void>.delayed(const Duration(milliseconds: 320));
      expect(repository.fetches, hasLength(beforeInvalid));
      expect(
        subscription.read().searchErrorText,
        'Search must be 254 characters or fewer.',
      );
      controller.clearFilters();
      await _flush();
      expect(subscription.read().searchErrorText, isNull);

      controller.nextPage();
      await _flush();
      expect(
        repository.fetches.map((fetch) => fetch.query.page),
        containsAllInOrder([2, 1]),
      );
    },
  );

  test(
    'checking drops stale rows on failure and Retry uses exact query',
    () async {
      var fail = false;
      final repository = _FakeRelationshipRepository(
        onFetch: (perspective, anchorId, query) async {
          if (fail) {
            fail = false;
            throw ApiRequestException(
              ApiFailure.local(
                kind: ApiFailureKind.connection,
                message: 'private',
              ),
            );
          }
          return _page(perspective, query);
        },
      );
      final container = _container(repository);
      final subscription = _listen(
        container,
        InstitutionParentStudentPerspective.byParent,
      );
      final controller = _controller(
        container,
        InstitutionParentStudentPerspective.byParent,
      );
      controller.selectAnchor(testInstitutionUser());
      await _flush();
      final query = subscription.read().query;
      fail = true;
      final reconciliation = controller.markCheckingAndReload();
      expect(
        subscription.read().status,
        InstitutionParentStudentRelationshipListStatus.checkingCurrentState,
      );
      expect(subscription.read().result, isNotNull);
      await reconciliation;
      expect(
        subscription.read().status,
        InstitutionParentStudentRelationshipListStatus.error,
      );
      expect(subscription.read().result, isNull);
      controller.retry();
      await _flush();
      expect(repository.fetches.last.query, query);
    },
  );

  test(
    'same-anchor reconciliation preserves the exact query and pending draft',
    () async {
      final repository = _FakeRelationshipRepository();
      final container = _container(repository);
      final subscription = _listen(
        container,
        InstitutionParentStudentPerspective.byParent,
      );
      final controller = _controller(
        container,
        InstitutionParentStudentPerspective.byParent,
      );
      controller.selectAnchor(testInstitutionUser());
      await _flush();
      controller.setStatus(
        InstitutionParentStudentRelationshipStatusFilter.inactive,
      );
      await _flush();
      controller.updateSearchDraft('pending relationship search');

      await controller.selectAnchorForMutation(
        testInstitutionUser(fullName: 'Parent One Updated'),
        preserveQueryForSameAnchor: true,
      );

      expect(
        subscription.read().query.status,
        InstitutionParentStudentRelationshipStatusFilter.inactive,
      );
      expect(subscription.read().searchDraft, 'pending relationship search');

      final invalidDraft = List.filled(255, 'x').join();
      controller.updateSearchDraft(invalidDraft);
      await controller.selectAnchorForMutation(
        testInstitutionUser(fullName: 'Parent One Updated Again'),
        preserveQueryForSameAnchor: true,
      );
      expect(subscription.read().searchDraft, invalidDraft);
      expect(
        subscription.read().searchErrorText,
        'Search must be 254 characters or fewer.',
      );
    },
  );

  test(
    'new-anchor reconciliation never exposes the prior anchor rows',
    () async {
      const nextParentId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
      final nextLoad =
          Completer<InstitutionParentStudentRelationshipListPage>();
      final repository = _FakeRelationshipRepository(
        onFetch: (perspective, anchorId, query) {
          if (anchorId == nextParentId) {
            return nextLoad.future;
          }
          return Future.value(_page(perspective, query));
        },
      );
      final container = _container(repository);
      final subscription = _listen(
        container,
        InstitutionParentStudentPerspective.byParent,
      );
      final controller = _controller(
        container,
        InstitutionParentStudentPerspective.byParent,
      );
      controller.selectAnchor(testInstitutionUser());
      await _flush();

      final reconciliation = controller.selectAnchorForMutation(
        testInstitutionUser(
          id: nextParentId,
          fullName: 'Parent Two',
          loginName: 'parent.two',
        ),
      );
      expect(
        subscription.read().status,
        InstitutionParentStudentRelationshipListStatus.checkingCurrentState,
      );
      expect(subscription.read().anchor!.id, nextParentId);
      expect(subscription.read().result, isNull);

      nextLoad.complete(
        _page(
          InstitutionParentStudentPerspective.byParent,
          const InstitutionParentStudentRelationshipQuery.initial(),
          relationships: const [],
          total: 0,
        ),
      );
      await reconciliation;
    },
  );

  test('stale marking rejects an older in-flight completion', () async {
    final olderCompletion =
        Completer<InstitutionParentStudentRelationshipListPage>();
    var fetchCount = 0;
    final repository = _FakeRelationshipRepository(
      onFetch: (perspective, anchorId, query) {
        fetchCount += 1;
        if (fetchCount == 2) {
          return olderCompletion.future;
        }
        return Future.value(
          _page(perspective, query, total: fetchCount, lastPage: 1),
        );
      },
    );
    final container = _container(repository);
    final subscription = _listen(
      container,
      InstitutionParentStudentPerspective.byParent,
    );
    final controller = _controller(
      container,
      InstitutionParentStudentPerspective.byParent,
    );
    controller.selectAnchor(testInstitutionUser());
    await _flush();

    controller.refresh();
    await _flush();
    controller.markStale();
    await controller.activate();
    expect(subscription.read().result!.pagination.total, 3);

    olderCompletion.complete(
      _page(
        InstitutionParentStudentPerspective.byParent,
        const InstitutionParentStudentRelationshipQuery.initial(),
        total: 999,
      ),
    );
    await _flush();
    expect(subscription.read().result!.pagination.total, 3);
  });

  test(
    'old anchor completion and exact 404 cannot publish stale data',
    () async {
      final first = Completer<InstitutionParentStudentRelationshipListPage>();
      final repository = _FakeRelationshipRepository(
        onFetch: (perspective, anchorId, query) {
          if (anchorId == testParentId) {
            return first.future;
          }
          throw _serverFailure(
            status: 404,
            code: ApiErrorCodes.resourceNotFound,
          );
        },
      );
      final container = _container(repository);
      final subscription = _listen(
        container,
        InstitutionParentStudentPerspective.byParent,
      );
      final controller = _controller(
        container,
        InstitutionParentStudentPerspective.byParent,
      );
      controller.selectAnchor(testInstitutionUser());
      await _flush();
      controller.selectAnchor(
        testInstitutionUser(
          id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
          fullName: 'Parent Two',
          loginName: 'parent.two',
        ),
      );
      await _flush();
      expect(
        subscription.read().status,
        InstitutionParentStudentRelationshipListStatus.noAnchor,
      );
      expect(
        subscription.read().feedback,
        'The selected user is no longer available for relationship management.',
      );
      first.complete(
        _page(
          InstitutionParentStudentPerspective.byParent,
          const InstitutionParentStudentRelationshipQuery.initial(),
        ),
      );
      await _flush();
      expect(subscription.read().anchor, isNull);
    },
  );
}

ProviderContainer _container(_FakeRelationshipRepository repository) {
  final container = ProviderContainer(
    overrides: [
      authSessionControllerProvider.overrideWith(TestAuthSessionController.new),
      appDeviceSurfaceProvider.overrideWithValue(AppDeviceSurface.desktop),
      institutionParentStudentRelationshipRepositoryProvider.overrideWithValue(
        repository,
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

ProviderSubscription<InstitutionParentStudentRelationshipListState> _listen(
  ProviderContainer container,
  InstitutionParentStudentPerspective perspective,
) {
  final subscription = container.listen(
    institutionParentStudentRelationshipListControllerProvider(perspective),
    (_, _) {},
    fireImmediately: true,
  );
  addTearDown(subscription.close);
  return subscription;
}

InstitutionParentStudentRelationshipListController _controller(
  ProviderContainer container,
  InstitutionParentStudentPerspective perspective,
) => container.read(
  institutionParentStudentRelationshipListControllerProvider(
    perspective,
  ).notifier,
);

Future<void> _flush() async {
  for (var index = 0; index < 8; index += 1) {
    await Future<void>.delayed(Duration.zero);
  }
}

InstitutionParentStudentRelationshipListPage _page(
  InstitutionParentStudentPerspective perspective,
  InstitutionParentStudentRelationshipQuery query, {
  List<InstitutionParentStudentRelationship>? relationships,
  int total = 1,
  int lastPage = 1,
}) => InstitutionParentStudentRelationshipListPage(
  relationships: relationships ?? [testRelationship(perspective: perspective)],
  pagination: InstitutionParentStudentRelationshipListPagination(
    page: query.page,
    perPage: query.perPage,
    total: total,
    lastPage: lastPage,
  ),
);

ApiRequestException _serverFailure({
  required int status,
  required String code,
}) => ApiRequestException(
  ApiFailure.fromServerError(
    statusCode: status,
    error: ApiErrorResponse(
      message: 'Private',
      code: code,
      fieldErrors: const {},
      requestId: null,
    ),
  ),
);

class _RelationshipFetch {
  const _RelationshipFetch(this.perspective, this.anchorId, this.query);
  final InstitutionParentStudentPerspective perspective;
  final String anchorId;
  final InstitutionParentStudentRelationshipQuery query;
}

class _FakeRelationshipRepository
    implements InstitutionParentStudentRelationshipRepository {
  _FakeRelationshipRepository({this.onFetch});

  final Future<InstitutionParentStudentRelationshipListPage> Function(
    InstitutionParentStudentPerspective perspective,
    String anchorId,
    InstitutionParentStudentRelationshipQuery query,
  )?
  onFetch;
  final fetches = <_RelationshipFetch>[];

  @override
  Future<InstitutionParentStudentRelationshipListPage> fetchRelationships({
    required InstitutionParentStudentPerspective perspective,
    required String anchorId,
    required InstitutionParentStudentRelationshipQuery query,
  }) {
    fetches.add(_RelationshipFetch(perspective, anchorId, query));
    return onFetch?.call(perspective, anchorId, query) ??
        Future.value(_page(perspective, query));
  }

  @override
  Future<InstitutionParentStudentMutationResult> connect(
    InstitutionParentStudentConnectRequest request,
  ) => throw UnimplementedError();

  @override
  Future<void> disconnect(String relationshipId) => throw UnimplementedError();
}
