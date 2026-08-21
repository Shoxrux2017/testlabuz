import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_state.dart';
import 'package:testlabuz_client/features/institution_admin/application/institution_group_detail_controller.dart';
import 'package:testlabuz_client/features/institution_admin/application/institution_group_detail_state.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_group_detail_repository_impl.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_group.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_group_detail_repository.dart';

import 'institution_group_test_support.dart';

void main() {
  test(
    'invalid direct target publishes unavailable with zero network',
    () async {
      final repository = _FakeDetailRepository();
      final setup = _setup(repository, 'not-a-uuid');
      await _flush();
      expect(repository.targets, isEmpty);
      expect(
        setup.subscription.read().status,
        InstitutionGroupDetailStatus.localUnavailableTarget,
      );
    },
  );

  test('loads exact target and suppresses duplicate refresh', () async {
    final refresh = Completer<InstitutionGroup>();
    var calls = 0;
    final repository = _FakeDetailRepository(
      onFetch: (_) {
        calls += 1;
        return calls == 1 ? Future.value(testGroup()) : refresh.future;
      },
    );
    final setup = _setup(repository, testGroupId);
    await _flush();
    expect(setup.subscription.read().status, InstitutionGroupDetailStatus.data);

    final controller = setup.container.read(
      institutionGroupDetailControllerProvider(testGroupId).notifier,
    );
    controller.refresh();
    controller.refresh();
    expect(repository.targets, [testGroupId, testGroupId]);
    expect(
      setup.subscription.read().status,
      InstitutionGroupDetailStatus.refreshing,
    );
    expect(setup.subscription.read().group, isNotNull);
    refresh.complete(testGroup(name: 'Updated Group'));
    await _flush();
    expect(setup.subscription.read().group!.name, 'Updated Group');
  });

  test(
    'refresh 404 discards prior data and becomes privacy-safe not found',
    () async {
      var calls = 0;
      final repository = _FakeDetailRepository(
        onFetch: (_) async {
          calls += 1;
          if (calls == 1) {
            return testGroup();
          }
          throw ApiRequestException(
            ApiFailure(
              kind: ApiFailureKind.server,
              statusCode: 404,
              serverCode: ApiErrorCodes.resourceNotFound,
              message: 'Private.',
            ),
          );
        },
      );
      final setup = _setup(repository, testGroupId);
      await _flush();
      setup.container
          .read(institutionGroupDetailControllerProvider(testGroupId).notifier)
          .refresh();
      await _flush();
      expect(
        setup.subscription.read().status,
        InstitutionGroupDetailStatus.notFound,
      );
      expect(setup.subscription.read().group, isNull);
    },
  );

  test(
    'retry is limited to connection timeout unknown and server 5xx',
    () async {
      for (final failure in <ApiFailure>[
        ApiFailure.local(kind: ApiFailureKind.connection, message: 'private'),
        ApiFailure.local(kind: ApiFailureKind.timeout, message: 'private'),
        ApiFailure.local(kind: ApiFailureKind.unknown, message: 'private'),
        ApiFailure(
          kind: ApiFailureKind.server,
          statusCode: 500,
          message: 'private',
        ),
      ]) {
        final repository = _FakeDetailRepository(
          onFetch: (_) => Future.error(ApiRequestException(failure)),
        );
        final setup = _setup(repository, testGroupId);
        await _flush();
        expect(setup.subscription.read().isRetryable, isTrue);
      }

      final repository = _FakeDetailRepository(
        onFetch: (_) => Future.error(
          ApiRequestException(
            ApiFailure.local(
              kind: ApiFailureKind.invalidResponse,
              message: 'private',
            ),
          ),
        ),
      );
      final setup = _setup(repository, testGroupId);
      await _flush();
      expect(setup.subscription.read().isRetryable, isFalse);
    },
  );

  test('session replacement rejects stale target completion', () async {
    final firstResponse = Completer<InstitutionGroup>();
    final secondResponse = Completer<InstitutionGroup>();
    var calls = 0;
    final auth = TestAuthSessionController();
    final repository = _FakeDetailRepository(
      onFetch: (_) {
        calls += 1;
        return calls == 1 ? firstResponse.future : secondResponse.future;
      },
    );
    final setup = _setup(repository, testGroupId, auth: auth);
    await _flush();
    auth.setSession(AuthSessionState.authenticated(testInstitutionAdmin()));
    await _flush();
    expect(repository.targets, hasLength(2));
    firstResponse.complete(testGroup(name: 'Stale Group'));
    await _flush();
    expect(
      setup.subscription.read().status,
      InstitutionGroupDetailStatus.loading,
    );
    expect(setup.subscription.read().group, isNull);
  });
}

({
  ProviderContainer container,
  ProviderSubscription<InstitutionGroupDetailState> subscription,
})
_setup(
  _FakeDetailRepository repository,
  String target, {
  TestAuthSessionController? auth,
}) {
  final container = ProviderContainer(
    overrides: [
      authSessionControllerProvider.overrideWith(
        () => auth ?? TestAuthSessionController(),
      ),
      appDeviceSurfaceProvider.overrideWithValue(AppDeviceSurface.desktop),
      institutionGroupDetailRepositoryProvider.overrideWithValue(repository),
    ],
  );
  final subscription = container.listen(
    institutionGroupDetailControllerProvider(target),
    (_, _) {},
    fireImmediately: true,
  );
  addTearDown(subscription.close);
  addTearDown(container.dispose);
  return (container: container, subscription: subscription);
}

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
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
