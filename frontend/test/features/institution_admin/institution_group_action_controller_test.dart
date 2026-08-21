import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_state.dart';
import 'package:testlabuz_client/features/institution_admin/application/institution_group_action_controller.dart';
import 'package:testlabuz_client/features/institution_admin/application/institution_group_action_state.dart';
import 'package:testlabuz_client/features/institution_admin/application/institution_group_detail_controller.dart';
import 'package:testlabuz_client/features/institution_admin/application/institution_group_detail_state.dart';
import 'package:testlabuz_client/features/institution_admin/application/institution_group_list_controller.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_group_detail_repository_impl.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_group_mutation_repository_impl.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_group.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_group_detail_repository.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_group_list_query.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_group_mutation.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_group_mutation_repository.dart';

import 'institution_group_test_support.dart';

void main() {
  test('begins only from exact active confirmed selected Group', () async {
    final setup = await _setup();
    final controller = setup.controller;
    final selected = setup.detailState.group!;

    expect(controller.beginEdit(testGroup()), isFalse);
    expect(controller.beginEdit(selected), isTrue);
    expect(controller.beginArchive(selected), isFalse);
    controller.dismiss();

    setup.detailController.replaceFromMutation(
      selected,
      testGroup(
        status: InstitutionGroupStatus.archived,
        archivedAt: DateTime.utc(2026, 8, 21, 10),
      ),
    );
    await _flush();
    expect(controller.beginEdit(setup.detailState.group!), isFalse);
    expect(controller.beginArchive(setup.detailState.group!), isFalse);
  });

  test(
    'local no-op sends no request or GET and clears message on edit',
    () async {
      final setup = await _setup();
      final controller = setup.controller;
      expect(controller.beginEdit(setup.detailState.group!), isTrue);

      await controller.submitEdit();

      expect(setup.mutation.updateCalls, 0);
      expect(setup.detailRepository.targets, [testGroupId]);
      expect(setup.actionState.formMessage, 'No group changes to save.');
      expect(setup.actionState.isEditing, isTrue);
      expect(
        setup.retainedStore.value?.authoritativeRowsStale ?? false,
        isFalse,
      );

      controller.updateName('10-B');
      expect(setup.actionState.formMessage, isNull);
    },
  );

  test('direct update marks list stale and safely replaces Detail', () async {
    final admin = testInstitutionAdmin();
    final auth = TestAuthSessionController(
      AuthSessionState.authenticated(admin),
    );
    final mutation = _FakeMutationRepository(
      onUpdate: (_, _, _) async => testGroup(name: '10-B'),
    );
    final setup = await _setup(mutation: mutation, auth: auth);
    final retainedQuery = const InstitutionGroupListQuery.initial().copyWith(
      search: 'algebra',
      status: InstitutionGroupStatusFilter.active,
      page: 3,
      perPage: 50,
      sort: InstitutionGroupListSort.updatedAt,
      direction: InstitutionGroupSortDirection.desc,
    );
    setup.retainedStore.value = InstitutionGroupListRetainedQuery(
      sessionKey: InstitutionGroupListSessionKey(
        userId: admin.id,
        userInstance: admin,
        institutionId: admin.institutionId!,
      ),
      query: retainedQuery,
      searchDraft: '  algebra draft  ',
    );
    final controller = setup.controller;
    expect(controller.beginEdit(setup.detailState.group!), isTrue);
    final focusKey = controller.focusKey!;
    controller.updateName('10-B');

    await controller.submitEdit();

    expect(mutation.updateCalls, 1);
    expect(setup.detailRepository.targets, [testGroupId]);
    expect(setup.detailState.group!.name, '10-B');
    expect(setup.actionState.feedback, 'Group updated successfully.');
    expect(setup.actionState.hasOpenAction, isFalse);
    expect(setup.retainedStore.value!.authoritativeRowsStale, isTrue);
    expect(setup.retainedStore.value!.query, retainedQuery);
    expect(setup.retainedStore.value!.searchDraft, '  algebra draft  ');
    expect(controller.canRestoreFocus(focusKey), isTrue);
  });

  test('direct archive makes Detail read-only and marks list stale', () async {
    final archived = testGroup(
      status: InstitutionGroupStatus.archived,
      archivedAt: DateTime.utc(2026, 8, 21, 10),
    );
    final setup = await _setup(
      mutation: _FakeMutationRepository(onArchive: (_, _) async => archived),
    );
    final controller = setup.controller;
    expect(controller.beginArchive(setup.detailState.group!), isTrue);
    final focusKey = controller.focusKey!;

    await controller.confirmArchive();

    expect(setup.mutation.archiveCalls, 1);
    expect(setup.detailState.group, same(archived));
    expect(setup.detailState.group!.status, InstitutionGroupStatus.archived);
    expect(setup.actionState.feedback, 'Group archived successfully.');
    expect(setup.retainedStore.value!.authoritativeRowsStale, isTrue);
    expect(controller.canRestoreFocus(focusKey), isFalse);
  });

  test(
    'mixed edit 422 preserves draft and maps safe field plus protocol errors',
    () async {
      final setup = await _setup(
        mutation: _FakeMutationRepository(
          onUpdate: (_, _, _) => Future.error(
            ApiRequestException(
              ApiFailure(
                kind: ApiFailureKind.validation,
                statusCode: 422,
                serverCode: ApiErrorCodes.validationFailed,
                message: 'Private.',
                fieldErrors: const {
                  'name': ['Private name rule.'],
                  'body': ['Private protocol rule.'],
                },
              ),
            ),
          ),
        ),
      );
      final controller = setup.controller;
      controller.beginEdit(setup.detailState.group!);
      controller.updateName('10-B');

      await controller.submitEdit();

      expect(setup.actionState.isEditing, isTrue);
      expect(setup.actionState.form!.name, '10-B');
      expect(
        setup.actionState.errorFor(InstitutionGroupEditField.name),
        'Review the group name.',
      );
      expect(
        setup.actionState.formMessage,
        'The update request did not match the server contract.',
      );
      expect(
        setup.retainedStore.value?.authoritativeRowsStale ?? false,
        isFalse,
      );
    },
  );

  test(
    'unknown update reconciles once without replay and compares submitted fields',
    () async {
      var detailCalls = 0;
      final detailRepository = _FakeDetailRepository(
        onFetch: (_) async {
          detailCalls += 1;
          return detailCalls == 1 ? testGroup() : testGroup(name: '10-B');
        },
      );
      final setup = await _setup(
        detailRepository: detailRepository,
        mutation: _FakeMutationRepository(
          onUpdate: (_, _, _) => Future.error(
            const InstitutionGroupMutationOutcomeUnknownException(),
          ),
        ),
      );
      final controller = setup.controller;
      controller.beginEdit(setup.detailState.group!);
      controller.updateName('10-B');

      await controller.submitEdit();

      expect(setup.mutation.updateCalls, 1);
      expect(detailRepository.targets, [testGroupId, testGroupId]);
      expect(setup.detailState.group!.name, '10-B');
      expect(
        setup.actionState.feedback,
        'Current server state includes your requested values, but the update result could not be confirmed.',
      );
      expect(setup.retainedStore.value!.authoritativeRowsStale, isTrue);
    },
  );

  test(
    'edit business conflict reconciles archived state without PATCH replay',
    () async {
      var detailCalls = 0;
      final archived = testGroup(
        status: InstitutionGroupStatus.archived,
        archivedAt: DateTime.utc(2026, 8, 21, 10),
      );
      final setup = await _setup(
        detailRepository: _FakeDetailRepository(
          onFetch: (_) async => ++detailCalls == 1 ? testGroup() : archived,
        ),
        mutation: _FakeMutationRepository(
          onUpdate: (_, _, _) => Future.error(
            ApiRequestException(
              ApiFailure(
                kind: ApiFailureKind.server,
                statusCode: 409,
                serverCode: ApiErrorCodes.businessConflict,
                message: 'Private.',
              ),
            ),
          ),
        ),
      );
      setup.controller.beginEdit(setup.detailState.group!);
      setup.controller.updateName('10-B');

      await setup.controller.submitEdit();

      expect(setup.mutation.updateCalls, 1);
      expect(setup.detailRepository.targets, [testGroupId, testGroupId]);
      expect(setup.detailState.group!.status, InstitutionGroupStatus.archived);
      expect(
        setup.actionState.feedback,
        'Group is archived and can no longer be edited.',
      );
    },
  );

  test(
    'archive unknown reconciles active state once without POST replay',
    () async {
      var detailCalls = 0;
      final setup = await _setup(
        detailRepository: _FakeDetailRepository(
          onFetch: (_) async => ++detailCalls == 1
              ? testGroup()
              : testGroup(name: 'Current active'),
        ),
        mutation: _FakeMutationRepository(
          onArchive: (_, _) => Future.error(
            const InstitutionGroupMutationOutcomeUnknownException(),
          ),
        ),
      );
      setup.controller.beginArchive(setup.detailState.group!);

      await setup.controller.confirmArchive();

      expect(setup.mutation.archiveCalls, 1);
      expect(setup.detailRepository.targets, [testGroupId, testGroupId]);
      expect(setup.detailState.group!.status, InstitutionGroupStatus.active);
      expect(
        setup.actionState.feedback,
        'The group is still active. The archive request result could not be confirmed.',
      );
    },
  );

  test(
    'archive business conflict reconciles active state without POST replay',
    () async {
      var detailCalls = 0;
      final setup = await _setup(
        detailRepository: _FakeDetailRepository(
          onFetch: (_) async => ++detailCalls == 1
              ? testGroup()
              : testGroup(name: 'Current active'),
        ),
        mutation: _FakeMutationRepository(
          onArchive: (_, _) => Future.error(
            ApiRequestException(
              ApiFailure(
                kind: ApiFailureKind.server,
                statusCode: 409,
                serverCode: ApiErrorCodes.businessConflict,
                message: 'Private.',
              ),
            ),
          ),
        ),
      );
      setup.controller.beginArchive(setup.detailState.group!);

      await setup.controller.confirmArchive();

      expect(setup.mutation.archiveCalls, 1);
      expect(setup.detailRepository.targets, [testGroupId, testGroupId]);
      expect(
        setup.actionState.feedback,
        'The archive request was not accepted in its current state.',
      );
    },
  );

  test('mutation 404 removes stale Detail and marks list stale', () async {
    final setup = await _setup(
      mutation: _FakeMutationRepository(
        onArchive: (_, _) => Future.error(
          ApiRequestException(
            ApiFailure(
              kind: ApiFailureKind.server,
              statusCode: 404,
              serverCode: ApiErrorCodes.resourceNotFound,
              message: 'Private.',
            ),
          ),
        ),
      ),
    );
    setup.controller.beginArchive(setup.detailState.group!);

    await setup.controller.confirmArchive();

    expect(setup.detailState.status, InstitutionGroupDetailStatus.notFound);
    expect(setup.detailState.group, isNull);
    expect(setup.retainedStore.value!.authoritativeRowsStale, isTrue);
  });

  test('reconciliation failure discards old authoritative Detail', () async {
    var detailCalls = 0;
    final setup = await _setup(
      detailRepository: _FakeDetailRepository(
        onFetch: (_) {
          detailCalls += 1;
          if (detailCalls == 1) {
            return Future.value(testGroup());
          }
          return Future.error(
            ApiRequestException(
              ApiFailure.local(
                kind: ApiFailureKind.connection,
                message: 'Private.',
              ),
            ),
          );
        },
      ),
      mutation: _FakeMutationRepository(
        onArchive: (_, _) => Future.error(
          const InstitutionGroupMutationOutcomeUnknownException(),
        ),
      ),
    );
    setup.controller.beginArchive(setup.detailState.group!);

    await setup.controller.confirmArchive();
    await _flush();

    expect(setup.detailState.status, InstitutionGroupDetailStatus.error);
    expect(setup.detailState.group, isNull);
    expect(
      setup.actionState.feedback,
      'The archive result could not be confirmed. Current server state is unavailable.',
    );
  });

  test(
    'selected object replacement rejects stale mutation completion',
    () async {
      final result = Completer<InstitutionGroup>();
      final setup = await _setup(
        mutation: _FakeMutationRepository(onUpdate: (_, _, _) => result.future),
      );
      final original = setup.detailState.group!;
      setup.controller.beginEdit(original);
      final focusKey = setup.controller.focusKey!;
      setup.controller.updateName('10-B');
      final submit = setup.controller.submitEdit();
      await _flush();

      final newer = testGroup(name: 'Newer authoritative');
      expect(
        setup.detailController.replaceFromMutation(original, newer),
        isTrue,
      );
      result.complete(testGroup(name: '10-B'));
      await submit;
      await _flush();

      expect(setup.detailState.group, same(newer));
      expect(setup.actionState.status, InstitutionGroupActionStatus.idle);
      expect(setup.controller.canRestoreFocus(focusKey), isFalse);
      expect(
        setup.retainedStore.value?.authoritativeRowsStale ?? false,
        isFalse,
      );
    },
  );

  test('session replacement rejects stale mutation completion', () async {
    final result = Completer<InstitutionGroup>();
    final auth = TestAuthSessionController();
    final setup = await _setup(
      auth: auth,
      mutation: _FakeMutationRepository(onUpdate: (_, _, _) => result.future),
    );
    setup.controller.beginEdit(setup.detailState.group!);
    final focusKey = setup.controller.focusKey!;
    setup.controller.updateName('10-B');
    final submit = setup.controller.submitEdit();
    await _flush();

    auth.setSession(
      AuthSessionState.authenticated(testInstitutionAdmin(id: 'admin-b')),
    );
    await _flush();
    result.complete(testGroup(name: '10-B'));
    await submit;
    await _flush();

    expect(setup.actionState.status, InstitutionGroupActionStatus.idle);
    expect(setup.actionState.feedback, isNull);
    expect(setup.controller.canRestoreFocus(focusKey), isFalse);
    expect(setup.retainedStore.value?.authoritativeRowsStale ?? false, isFalse);
  });

  test(
    'session authority failure discards protected Detail and bootstraps auth',
    () async {
      final auth = TestAuthSessionController();
      final setup = await _setup(
        auth: auth,
        mutation: _FakeMutationRepository(
          onArchive: (_, _) => Future.error(
            ApiRequestException(
              ApiFailure(
                kind: ApiFailureKind.server,
                statusCode: 401,
                serverCode: ApiErrorCodes.authenticationRequired,
                message: 'Private.',
              ),
            ),
          ),
        ),
      );
      setup.controller.beginArchive(setup.detailState.group!);

      await setup.controller.confirmArchive();

      expect(auth.bootstrapCalls, 1);
      expect(setup.detailState.group, isNull);
      expect(setup.actionState.status, InstitutionGroupActionStatus.idle);
    },
  );
}

Future<_ActionSetup> _setup({
  _FakeMutationRepository? mutation,
  _FakeDetailRepository? detailRepository,
  TestAuthSessionController? auth,
}) async {
  final actualMutation = mutation ?? _FakeMutationRepository();
  final actualDetail = detailRepository ?? _FakeDetailRepository();
  final container = ProviderContainer(
    overrides: [
      authSessionControllerProvider.overrideWith(
        () => auth ?? TestAuthSessionController(),
      ),
      appDeviceSurfaceProvider.overrideWithValue(AppDeviceSurface.desktop),
      institutionGroupDetailRepositoryProvider.overrideWithValue(actualDetail),
      institutionGroupMutationRepositoryProvider.overrideWithValue(
        actualMutation,
      ),
    ],
  );
  final detailSubscription = container.listen(
    institutionGroupDetailControllerProvider(testGroupId),
    (_, _) {},
    fireImmediately: true,
  );
  final actionSubscription = container.listen(
    institutionGroupActionControllerProvider(testGroupId),
    (_, _) {},
    fireImmediately: true,
  );
  addTearDown(detailSubscription.close);
  addTearDown(actionSubscription.close);
  addTearDown(container.dispose);
  await _flush();
  return _ActionSetup(
    container: container,
    mutation: actualMutation,
    detailRepository: actualDetail,
  );
}

class _ActionSetup {
  const _ActionSetup({
    required this.container,
    required this.mutation,
    required this.detailRepository,
  });

  final ProviderContainer container;
  final _FakeMutationRepository mutation;
  final _FakeDetailRepository detailRepository;

  InstitutionGroupActionController get controller => container.read(
    institutionGroupActionControllerProvider(testGroupId).notifier,
  );

  InstitutionGroupActionState get actionState =>
      container.read(institutionGroupActionControllerProvider(testGroupId));

  InstitutionGroupDetailController get detailController => container.read(
    institutionGroupDetailControllerProvider(testGroupId).notifier,
  );

  InstitutionGroupDetailState get detailState =>
      container.read(institutionGroupDetailControllerProvider(testGroupId));

  InstitutionGroupListRetainedQueryStore get retainedStore =>
      container.read(institutionGroupListRetainedQueryProvider);
}

class _FakeMutationRepository implements InstitutionGroupMutationRepository {
  _FakeMutationRepository({this.onUpdate, this.onArchive});

  final Future<InstitutionGroup> Function(
    String target,
    InstitutionGroup selected,
    InstitutionGroupEditRequest request,
  )?
  onUpdate;
  final Future<InstitutionGroup> Function(
    String target,
    InstitutionGroup selected,
  )?
  onArchive;
  var updateCalls = 0;
  var archiveCalls = 0;

  @override
  Future<InstitutionGroup> updateGroup(
    String groupId,
    InstitutionGroup selected,
    InstitutionGroupEditRequest request,
  ) {
    updateCalls += 1;
    return onUpdate?.call(groupId, selected, request) ??
        Future.value(testGroup(name: 'Updated'));
  }

  @override
  Future<InstitutionGroup> archiveGroup(
    String groupId,
    InstitutionGroup selected,
  ) {
    archiveCalls += 1;
    return onArchive?.call(groupId, selected) ??
        Future.value(
          testGroup(
            status: InstitutionGroupStatus.archived,
            archivedAt: DateTime.utc(2026, 8, 21, 10),
          ),
        );
  }
}

class _FakeDetailRepository implements InstitutionGroupDetailRepository {
  _FakeDetailRepository({this.onFetch});

  final Future<InstitutionGroup> Function(String target)? onFetch;
  final targets = <String>[];

  @override
  Future<InstitutionGroup> fetchGroup(String groupId) {
    targets.add(groupId);
    return onFetch?.call(groupId) ?? Future.value(testGroup(id: groupId));
  }
}

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}
