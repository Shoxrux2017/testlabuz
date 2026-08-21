import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_state.dart';
import 'package:testlabuz_client/features/auth/domain/auth_user.dart';
import 'package:testlabuz_client/features/institution_admin/application/institution_group_create_controller.dart';
import 'package:testlabuz_client/features/institution_admin/application/institution_group_create_state.dart';
import 'package:testlabuz_client/features/institution_admin/application/institution_group_list_controller.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_group_create_repository_impl.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_group.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_group_create.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_group_create_repository.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_group_list_query.dart';

import 'institution_group_test_support.dart';

void main() {
  test('requires route ownership and validates before transport', () async {
    final repository = _FakeCreateRepository();
    final setup = _setup(repository);
    final controller = setup.container.read(
      institutionGroupCreateControllerProvider.notifier,
    );

    await controller.submit();
    expect(repository.requests, isEmpty);

    controller.enterRoute();
    await controller.submit();
    expect(repository.requests, isEmpty);
    expect(
      setup.subscription.read().status,
      InstitutionGroupCreateStatus.localValidationFailure,
    );
    expect(
      setup.subscription.read().firstErrorField,
      InstitutionGroupCreateField.name,
    );
  });

  test(
    'submits once and marks retained list stale without changing query',
    () async {
      final response = Completer<InstitutionGroup>();
      final repository = _FakeCreateRepository(
        onCreate: (_) => response.future,
      );
      final admin = testInstitutionAdmin();
      final setup = _setup(repository, admin: admin);
      final store = setup.container.read(
        institutionGroupListRetainedQueryProvider,
      );
      final retainedQuery = const InstitutionGroupListQuery.initial().copyWith(
        search: 'algebra',
        status: InstitutionGroupStatusFilter.archived,
        page: 2,
        perPage: 50,
        sort: InstitutionGroupListSort.updatedAt,
        direction: InstitutionGroupSortDirection.desc,
      );
      store.value = InstitutionGroupListRetainedQuery(
        sessionKey: InstitutionGroupListSessionKey(
          userId: admin.id,
          userInstance: admin,
          institutionId: admin.institutionId!,
        ),
        query: retainedQuery,
        searchDraft: 'algebra draft',
      );
      final controller = setup.container.read(
        institutionGroupCreateControllerProvider.notifier,
      );
      controller.enterRoute();
      _fill(controller);

      final first = controller.submit();
      final duplicate = controller.submit();
      expect(repository.requests, hasLength(1));
      expect(setup.subscription.read().isRouteBlocking, isTrue);
      response.complete(testGroup());
      await first;
      await duplicate;

      expect(repository.requests.single.toJson(), {
        'name': 'Advanced Mathematics',
        'level': 'Grade 10',
        'subject_direction': 'Mathematics',
        'description': 'First line\n  second line',
      });
      expect(setup.subscription.read().confirmedGroupId, testGroupId);
      expect(store.value!.query, retainedQuery);
      expect(store.value!.searchDraft, 'algebra draft');
      expect(store.value!.authoritativeRowsStale, isTrue);
    },
  );

  test('maps mixed validation fields to safe local copy', () async {
    final repository = _FakeCreateRepository(
      onCreate: (_) => Future.error(
        ApiRequestException(
          ApiFailure(
            kind: ApiFailureKind.validation,
            statusCode: 422,
            serverCode: ApiErrorCodes.validationFailed,
            message: 'Private backend copy.',
            fieldErrors: const {
              'name': ['Private name detail.'],
              'body': ['Private protocol detail.'],
            },
          ),
        ),
      ),
    );
    final setup = _setup(repository);
    final controller = setup.container.read(
      institutionGroupCreateControllerProvider.notifier,
    );
    controller.enterRoute();
    _fill(controller);
    await controller.submit();

    final state = setup.subscription.read();
    expect(state.status, InstitutionGroupCreateStatus.serverValidationFailure);
    expect(
      state.errorTextFor(InstitutionGroupCreateField.name),
      'Review the group name.',
    );
    expect(state.formError, 'The group could not be created.');
    expect(state.toString(), isNot(contains('Private')));
    expect(state.isRouteBlocking, isFalse);
  });

  test(
    'unknown outcome never retries and commits exact recovery query',
    () async {
      final repository = _FakeCreateRepository(
        onCreate: (_) =>
            Future.error(const InstitutionGroupCreateOutcomeUnknownException()),
      );
      final setup = _setup(repository);
      final controller = setup.container.read(
        institutionGroupCreateControllerProvider.notifier,
      );
      controller.enterRoute();
      _fill(controller);
      await controller.submit();

      expect(repository.requests, hasLength(1));
      expect(
        setup.subscription.read().status,
        InstitutionGroupCreateStatus.unknown,
      );
      expect(setup.subscription.read().isRouteBlocking, isTrue);
      await controller.submit();
      expect(repository.requests, hasLength(1));

      expect(controller.reviewRecentGroups(), isTrue);
      final retained = setup.container
          .read(institutionGroupListRetainedQueryProvider)
          .value!;
      expect(retained.searchDraft, '');
      expect(retained.query.toQueryParameters(), {
        'page': 1,
        'per_page': 20,
        'sort': 'created_at',
        'direction': 'desc',
        'status': 'active',
      });
      expect(retained.authoritativeRowsStale, isTrue);
      expect(retained.recoveryWarningPending, isTrue);
      expect(
        setup.subscription.read().status,
        InstitutionGroupCreateStatus.editing,
      );
    },
  );

  test('same-role AuthUser replacement rejects stale success', () async {
    final response = Completer<InstitutionGroup>();
    final repository = _FakeCreateRepository(onCreate: (_) => response.future);
    final auth = TestAuthSessionController();
    final setup = _setup(repository, auth: auth);
    final controller = setup.container.read(
      institutionGroupCreateControllerProvider.notifier,
    );
    controller.enterRoute();
    _fill(controller);
    final operation = controller.submit();

    auth.setSession(AuthSessionState.authenticated(testInstitutionAdmin()));
    await _flush();
    response.complete(testGroup());
    await operation;

    expect(setup.subscription.read().confirmedGroupId, isNull);
  });
}

({
  ProviderContainer container,
  ProviderSubscription<InstitutionGroupCreateState> subscription,
})
_setup(
  _FakeCreateRepository repository, {
  AuthUser? admin,
  TestAuthSessionController? auth,
}) {
  final currentAdmin = admin ?? testInstitutionAdmin();
  final container = ProviderContainer(
    overrides: [
      authSessionControllerProvider.overrideWith(
        () =>
            auth ??
            TestAuthSessionController(
              AuthSessionState.authenticated(currentAdmin),
            ),
      ),
      appDeviceSurfaceProvider.overrideWithValue(AppDeviceSurface.desktop),
      institutionGroupCreateRepositoryProvider.overrideWithValue(repository),
    ],
  );
  final subscription = container.listen(
    institutionGroupCreateControllerProvider,
    (_, _) {},
    fireImmediately: true,
  );
  addTearDown(subscription.close);
  addTearDown(container.dispose);
  return (container: container, subscription: subscription);
}

void _fill(InstitutionGroupCreateController controller) {
  controller.updateName('  Advanced Mathematics  ');
  controller.updateLevel('  Grade 10  ');
  controller.updateSubjectDirection('  Mathematics  ');
  controller.updateDescription('  First line\n  second line  ');
}

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

class _FakeCreateRepository implements InstitutionGroupCreateRepository {
  _FakeCreateRepository({this.onCreate});

  final Future<InstitutionGroup> Function(
    InstitutionGroupCreateRequest request,
  )?
  onCreate;
  final requests = <InstitutionGroupCreateRequest>[];

  @override
  Future<InstitutionGroup> createGroup(InstitutionGroupCreateRequest request) {
    requests.add(request);
    return onCreate?.call(request) ?? Future.value(testGroup());
  }
}
