import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_error_response.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_state.dart';
import 'package:testlabuz_client/features/auth/domain/auth_institution.dart';
import 'package:testlabuz_client/features/auth/domain/auth_user.dart';
import 'package:testlabuz_client/features/auth/domain/user_role.dart';
import 'package:testlabuz_client/features/institution_admin/application/institution_profile_controller.dart';
import 'package:testlabuz_client/features/institution_admin/application/institution_profile_state.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_profile_repository_impl.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_profile.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_profile_repository.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_profile_update.dart';

void main() {
  group('InstitutionProfileController', () {
    test(
      'eligible route instance loads once and syncs only shell name',
      () async {
        final auth = FakeAuthSessionController(
          AuthSessionState.authenticated(_admin()),
        );
        final repository = FakeInstitutionProfileRepository(
          onFetch: (_) async => _profile(name: 'Authoritative School'),
        );
        final harness = _harness(auth: auth, repository: repository);

        await _flush();

        expect(harness.read().status, InstitutionProfileViewStatus.data);
        expect(harness.read().profile?.name, 'Authoritative School');
        expect(repository.fetchCalls, 1);
        expect(auth.nameReconciliationCalls, 1);
        expect(
          harness.container
              .read(authSessionControllerProvider)
              .user
              ?.institution
              ?.name,
          'Authoritative School',
        );

        harness.container.read(harness.provider);
        expect(repository.fetchCalls, 1);
      },
    );

    test(
      'full ineligible matrix issues zero requests and exposes no data',
      () async {
        final states = [
          const AuthSessionState.initial(),
          const AuthSessionState.bootstrapping(),
          const AuthSessionState.unauthenticated(),
          const AuthSessionState.authenticating(),
          AuthSessionState.bootstrapFailure(_localFailure().failure),
          AuthSessionState.authenticated(_admin(role: UserRole.teacher)),
          AuthSessionState.authenticated(_admin(isActive: false)),
          AuthSessionState.authenticated(_admin(mustChangePassword: true)),
          AuthSessionState.authenticated(_admin(institutionId: null)),
          AuthSessionState.authenticated(_admin(institutionId: '')),
          AuthSessionState.authenticated(_admin(includeInstitution: false)),
          AuthSessionState.authenticated(
            _admin(nestedInstitutionId: _otherInstitutionId),
          ),
          AuthSessionState.authenticated(_admin(institutionStatus: 'inactive')),
        ];

        for (final state in states) {
          final repository = FakeInstitutionProfileRepository();
          final auth = FakeAuthSessionController(state);
          final container = ProviderContainer(
            overrides: [
              authSessionControllerProvider.overrideWith(() => auth),
              institutionProfileRepositoryProvider.overrideWithValue(
                repository,
              ),
            ],
          );
          addTearDown(container.dispose);
          final provider = institutionProfileControllerProvider(_key);
          final subscription = container.listen(
            provider,
            (_, _) {},
            fireImmediately: true,
          );
          await _flush();

          expect(
            subscription.read().status,
            InstitutionProfileViewStatus.initial,
          );
          expect(subscription.read().profile, isNull);
          expect(subscription.read().form, isNull);
          expect(repository.fetchCalls, 0, reason: '${state.status}');
          subscription.close();
        }
      },
    );

    test('response identity mismatch is a safe non-data load error', () async {
      final harness = _harness(
        repository: FakeInstitutionProfileRepository(
          onFetch: (_) async => _profile(id: _otherInstitutionId),
        ),
      );

      await _flush();

      expect(harness.read().status, InstitutionProfileViewStatus.loadError);
      expect(harness.read().failure?.kind, ApiFailureKind.invalidResponse);
      expect(
        harness.read().failureOperation,
        InstitutionProfileFailureOperation.load,
      );
      expect(harness.read().profile, isNull);
      expect(harness.auth.nameReconciliationCalls, 0);
    });

    test(
      'inactive response clears state and bootstraps exactly once',
      () async {
        final harness = _harness(
          repository: FakeInstitutionProfileRepository(
            onFetch: (_) async =>
                _profile(status: InstitutionProfileStatus.inactive),
          ),
        );

        await _flush();

        expect(harness.read().status, InstitutionProfileViewStatus.initial);
        expect(harness.auth.bootstrapCalls, 1);
        expect(harness.auth.nameReconciliationCalls, 0);
      },
    );

    test(
      'refresh and retry are GET-only and deduplicate in-flight intent',
      () async {
        final refresh = Completer<InstitutionProfile>();
        final repository = FakeInstitutionProfileRepository(
          onFetch: (call) {
            if (call == 1) {
              return Future.value(_profile());
            }
            if (call == 2) {
              return refresh.future;
            }
            return Future.value(_profile(name: 'Recovered'));
          },
        );
        final harness = _harness(repository: repository);
        await _flush();

        final first = harness.controller.refresh();
        final duplicate = harness.controller.refresh();
        expect(harness.read().status, InstitutionProfileViewStatus.loading);
        expect(harness.read().profile, isNull);
        expect(repository.fetchCalls, 2);
        refresh.completeError(_localFailure());
        await first;
        await duplicate;
        await _flush();
        expect(harness.read().status, InstitutionProfileViewStatus.loadError);

        final retryA = harness.controller.retry();
        final retryB = harness.controller.retry();
        expect(harness.read().isRetryInFlight, isTrue);
        await retryA;
        await retryB;
        expect(repository.fetchCalls, 3);
        expect(harness.read().profile?.name, 'Recovered');
      },
    );

    test('cancel and normalized no-change submit issue no PATCH', () async {
      final harness = _harness();
      await _flush();

      harness.controller.beginEditing();
      harness.controller.updateField(
        InstitutionProfileEditField.name,
        'Changed locally',
      );
      harness.controller.cancelEditing();
      expect(harness.read().status, InstitutionProfileViewStatus.data);
      expect(harness.read().profile?.name, 'Example School');
      expect(harness.repository.updateCalls, 0);

      harness.controller.beginEditing();
      harness.controller.updateField(
        InstitutionProfileEditField.name,
        '  Example School  ',
      );
      await harness.controller.submit();
      expect(harness.repository.updateCalls, 0);
      expect(harness.read().status, InstitutionProfileViewStatus.data);
      expect(harness.read().notice, 'No changes to save.');
    });

    test('local validation focuses first field and sends no PATCH', () async {
      final harness = _harness();
      await _flush();
      harness.controller.beginEditing();
      harness.controller.updateField(InstitutionProfileEditField.name, ' ');
      harness.controller.updateField(
        InstitutionProfileEditField.contactEmail,
        'bad email',
      );

      await harness.controller.submit();

      expect(
        harness.read().status,
        InstitutionProfileViewStatus.validationFailure,
      );
      expect(harness.read().focusField, InstitutionProfileEditField.name);
      expect(
        harness.read().fieldErrors,
        contains(InstitutionProfileEditField.name),
      );
      expect(harness.repository.updateCalls, 0);
    });

    test(
      'trusted direct success publishes returned resource and syncs name',
      () async {
        final repository = FakeInstitutionProfileRepository(
          onUpdate: (_, request) async {
            expect(request.toJson(), {'name': 'Renamed School'});
            return InstitutionProfileUpdateResult(
              profile: _profile(name: 'Renamed School', contactPhone: '+99899'),
            );
          },
        );
        final harness = _harness(repository: repository);
        await _flush();
        harness.controller.beginEditing();
        harness.controller.updateField(
          InstitutionProfileEditField.name,
          ' Renamed School ',
        );

        await harness.controller.submit();

        expect(repository.updateCalls, 1);
        expect(
          harness.read().status,
          InstitutionProfileViewStatus.confirmedDirectSuccess,
        );
        expect(harness.read().notice, 'Institution profile updated.');
        expect(harness.read().profile?.contactPhone, '+99899');
        expect(
          harness.container
              .read(authSessionControllerProvider)
              .user
              ?.institution
              ?.name,
          'Renamed School',
        );
      },
    );

    test(
      'a session-rejected verified response never enters visible success',
      () async {
        final auth = FakeAuthSessionController(
          AuthSessionState.authenticated(_admin()),
        )..rejectNameReconciliation = true;
        final repository = FakeInstitutionProfileRepository(
          onFetch: (_) async => _profile(),
        );
        final harness = _harness(auth: auth, repository: repository);

        await _flush();

        expect(harness.read().status, InstitutionProfileViewStatus.initial);
        expect(harness.read().profile, isNull);
        expect(harness.read().notice, isNull);
        expect(repository.fetchCalls, 1);
        expect(auth.nameReconciliationCalls, 1);
      },
    );

    test('422 maps only approved fields and retains editable draft', () async {
      final repository = FakeInstitutionProfileRepository(
        onUpdate: (_, _) async => throw ApiRequestException(
          ApiFailure.fromServerError(
            statusCode: 422,
            error: ApiErrorResponse(
              message: 'Raw validation.',
              code: ApiErrorCodes.validationFailed,
              fieldErrors: {
                'contact_email': ['Server email error.'],
                'institution_id': ['Protected error.'],
              },
              requestId: 'private',
            ),
          ),
        ),
      );
      final harness = _harness(repository: repository);
      await _flush();
      harness.controller.beginEditing();
      harness.controller.updateField(
        InstitutionProfileEditField.contactEmail,
        'new@example.uz',
      );

      await harness.controller.submit();

      expect(
        harness.read().status,
        InstitutionProfileViewStatus.validationFailure,
      );
      expect(
        harness.read().fieldErrors[InstitutionProfileEditField.contactEmail],
        'Server email error.',
      );
      expect(harness.read().fieldErrors.length, 1);
      expect(
        harness.read().formError,
        'Some submitted profile details need review.',
      );
      expect(
        harness.read().focusField,
        InstitutionProfileEditField.contactEmail,
      );
    });

    test(
      'forbidden clears draft while lifecycle codes bootstrap once',
      () async {
        for (final code in [
          ApiErrorCodes.forbidden,
          ApiErrorCodes.resourceNotFound,
        ]) {
          final harness = _harness(
            repository: FakeInstitutionProfileRepository(
              onUpdate: (_, _) async => throw _serverFailure(code),
            ),
          );
          await _flush();
          harness.controller.beginEditing();
          harness.controller.updateField(
            InstitutionProfileEditField.name,
            'New',
          );
          await harness.controller.submit();
          expect(harness.read().status, InstitutionProfileViewStatus.loadError);
          expect(
            harness.read().failureOperation,
            InstitutionProfileFailureOperation.mutation,
          );
          expect(harness.read().profile, isNull);
          expect(harness.auth.bootstrapCalls, 0);
        }

        for (final code in [
          ApiErrorCodes.passwordChangeRequired,
          ApiErrorCodes.userInactive,
          ApiErrorCodes.institutionInactive,
        ]) {
          final harness = _harness(
            repository: FakeInstitutionProfileRepository(
              onUpdate: (_, _) async => throw _serverFailure(code),
            ),
          );
          await _flush();
          harness.controller.beginEditing();
          harness.controller.updateField(
            InstitutionProfileEditField.name,
            'New',
          );
          await harness.controller.submit();
          expect(harness.read().status, InstitutionProfileViewStatus.initial);
          expect(harness.auth.bootstrapCalls, 1);
        }
      },
    );

    test(
      'uncertain PATCH reconciles equal and different without replay',
      () async {
        for (final matches in [true, false]) {
          final repository = FakeInstitutionProfileRepository(
            onFetch: (call) async => call == 1
                ? _profile()
                : _profile(
                    name: matches ? 'Renamed School' : 'Other Server Name',
                  ),
            onUpdate: (_, _) async =>
                throw const InstitutionProfileUpdateOutcomeUnknownException(),
          );
          final harness = _harness(repository: repository);
          await _flush();
          harness.controller.beginEditing();
          harness.controller.updateField(
            InstitutionProfileEditField.name,
            'Renamed School',
          );

          await harness.controller.submit();

          expect(repository.updateCalls, 1);
          expect(repository.fetchCalls, 2);
          expect(
            harness.read().status,
            InstitutionProfileViewStatus.unconfirmedCurrentState,
          );
          expect(harness.read().notice, contains('could not be confirmed'));
          expect(
            harness.read().notice,
            contains(matches ? 'matches' : 'differs'),
          );
          expect(harness.read().notice, isNot(contains('succeeded')));
          expect(harness.read().notice, isNot(contains('failed')));
        }
      },
    );

    test(
      'failed reconciliation hides stale profile and reload is GET-only',
      () async {
        final repository = FakeInstitutionProfileRepository(
          onFetch: (call) async {
            if (call == 1) {
              return _profile();
            }
            if (call == 2) {
              throw _localFailure();
            }
            return _profile(name: 'Current Server Name');
          },
          onUpdate: (_, _) async =>
              throw const InstitutionProfileUpdateOutcomeUnknownException(),
        );
        final harness = _harness(repository: repository);
        await _flush();
        harness.controller.beginEditing();
        harness.controller.updateField(InstitutionProfileEditField.name, 'New');
        await harness.controller.submit();

        expect(
          harness.read().status,
          InstitutionProfileViewStatus.outcomeUnknown,
        );
        expect(harness.read().profile, isNull);
        final reloadA = harness.controller.reloadAfterUnknownOutcome();
        final reloadB = harness.controller.reloadAfterUnknownOutcome();
        await reloadA;
        await reloadB;
        expect(repository.updateCalls, 1);
        expect(repository.fetchCalls, 3);
        expect(harness.read().status, InstitutionProfileViewStatus.data);
        expect(harness.read().profile?.name, 'Current Server Name');
      },
    );

    test(
      'logout makes delayed PATCH completion stale with no shell update',
      () async {
        final update = Completer<InstitutionProfileUpdateResult>();
        final repository = FakeInstitutionProfileRepository(
          onUpdate: (_, _) => update.future,
        );
        final harness = _harness(repository: repository);
        await _flush();
        harness.controller.beginEditing();
        harness.controller.updateField(
          InstitutionProfileEditField.name,
          'Late',
        );
        final submit = harness.controller.submit();
        await _flush();

        harness.auth.setSession(const AuthSessionState.unauthenticated());
        await _flush();
        update.complete(
          InstitutionProfileUpdateResult(profile: _profile(name: 'Late')),
        );
        await submit;
        await _flush();

        expect(harness.read().status, InstitutionProfileViewStatus.initial);
        expect(harness.auth.nameReconciliationCalls, 1);
      },
    );

    test(
      'PATCH identity mismatch is never published and reconciles with one GET only',
      () async {
        final repository = FakeInstitutionProfileRepository(
          onFetch: (call) async => call == 1
              ? _profile()
              : _profile(name: 'Current Authoritative School'),
          onUpdate: (_, _) async => InstitutionProfileUpdateResult(
            profile: _profile(
              id: _otherInstitutionId,
              name: 'Foreign Institution Secret',
            ),
          ),
        );
        final harness = _harness(repository: repository);
        await _flush();
        harness.controller.beginEditing();
        harness.controller.updateField(
          InstitutionProfileEditField.name,
          'Requested School',
        );

        await harness.controller.submit();

        expect(repository.updateCalls, 1);
        expect(repository.fetchCalls, 2);
        expect(
          harness.read().status,
          InstitutionProfileViewStatus.unconfirmedCurrentState,
        );
        expect(harness.read().profile?.id, _institutionId);
        expect(harness.read().profile?.name, 'Current Authoritative School');
        expect(
          harness.read().profile?.name,
          isNot('Foreign Institution Secret'),
        );
        expect(harness.read().notice, contains('differs'));
        expect(harness.auth.nameReconciliationCalls, 2);
        expect(
          harness.container
              .read(authSessionControllerProvider)
              .user
              ?.institution
              ?.name,
          'Current Authoritative School',
        );
      },
    );

    test(
      'PATCH and reconciliation identity mismatches lock outcome unknown without disclosure',
      () async {
        final repository = FakeInstitutionProfileRepository(
          onFetch: (call) async => call == 1
              ? _profile()
              : _profile(
                  id: _otherInstitutionId,
                  name: 'Foreign Reconciliation Secret',
                ),
          onUpdate: (_, _) async => InstitutionProfileUpdateResult(
            profile: _profile(
              id: _otherInstitutionId,
              name: 'Foreign PATCH Secret',
            ),
          ),
        );
        final harness = _harness(repository: repository);
        await _flush();
        harness.controller.beginEditing();
        harness.controller.updateField(
          InstitutionProfileEditField.name,
          'Requested School',
        );

        await harness.controller.submit();

        expect(repository.updateCalls, 1);
        expect(repository.fetchCalls, 2);
        expect(
          harness.read().status,
          InstitutionProfileViewStatus.outcomeUnknown,
        );
        expect(harness.read().profile, isNull);
        expect(harness.read().form, isNull);
        expect(harness.auth.nameReconciliationCalls, 1);
        expect(
          harness.container
              .read(authSessionControllerProvider)
              .user
              ?.institution
              ?.name,
          'Example School',
        );
        await _flush();
        expect(repository.updateCalls, 1);
        expect(repository.fetchCalls, 2);
      },
    );

    test(
      'GET definite failure matrix keeps load semantics and safe state',
      () async {
        for (final failureCase in _failureCases()) {
          final harness = _harness(
            repository: FakeInstitutionProfileRepository(
              onFetch: (_) async => throw failureCase.exception,
            ),
          );

          await _flush();

          expect(harness.read().profile, isNull, reason: failureCase.name);
          expect(harness.read().form, isNull, reason: failureCase.name);
          if (failureCase.clearsForSession) {
            expect(
              harness.read().status,
              InstitutionProfileViewStatus.initial,
              reason: failureCase.name,
            );
            expect(
              harness.auth.bootstrapCalls,
              failureCase.bootstraps ? 1 : 0,
              reason: failureCase.name,
            );
          } else {
            expect(
              harness.read().status,
              InstitutionProfileViewStatus.loadError,
              reason: failureCase.name,
            );
            expect(
              harness.read().failureOperation,
              InstitutionProfileFailureOperation.load,
              reason: failureCase.name,
            );
          }
          expect(harness.repository.fetchCalls, 1, reason: failureCase.name);
          expect(harness.repository.updateCalls, 0, reason: failureCase.name);
        }
      },
    );

    test(
      'exact allowed PATCH failures preserve operation-specific state and never retry',
      () async {
        for (final failureCase in _failureCases().where(
          (fixture) => fixture.definiteMutation,
        )) {
          final harness = _harness(
            repository: FakeInstitutionProfileRepository(
              onUpdate: (_, _) async => throw failureCase.exception,
            ),
          );
          await _flush();
          harness.controller.beginEditing();
          harness.controller.updateField(
            InstitutionProfileEditField.name,
            'Draft ${failureCase.name}',
          );

          await harness.controller.submit();

          expect(harness.repository.updateCalls, 1, reason: failureCase.name);
          expect(harness.repository.fetchCalls, 1, reason: failureCase.name);
          if (failureCase.clearsForSession) {
            expect(
              harness.read().status,
              InstitutionProfileViewStatus.initial,
              reason: failureCase.name,
            );
            expect(harness.read().profile, isNull, reason: failureCase.name);
            expect(
              harness.auth.bootstrapCalls,
              failureCase.bootstraps ? 1 : 0,
              reason: failureCase.name,
            );
          } else if (failureCase.serverCode == ApiErrorCodes.forbidden ||
              failureCase.serverCode == ApiErrorCodes.resourceNotFound) {
            expect(
              harness.read().status,
              InstitutionProfileViewStatus.loadError,
              reason: failureCase.name,
            );
            expect(
              harness.read().failureOperation,
              InstitutionProfileFailureOperation.mutation,
              reason: failureCase.name,
            );
            expect(harness.read().profile, isNull, reason: failureCase.name);
          } else if (failureCase.serverCode == ApiErrorCodes.validationFailed) {
            expect(
              harness.read().status,
              InstitutionProfileViewStatus.validationFailure,
              reason: failureCase.name,
            );
            expect(
              harness.read().form?.name,
              'Draft ${failureCase.name}',
              reason: failureCase.name,
            );
          } else {
            expect(
              harness.read().status,
              InstitutionProfileViewStatus.mutationFailure,
              reason: failureCase.name,
            );
            expect(
              harness.read().form?.name,
              'Draft ${failureCase.name}',
              reason: failureCase.name,
            );
          }
        }
      },
    );

    test(
      '500 and other uncertain PATCH failures reconcile once without PATCH replay',
      () async {
        for (final failureCase in _failureCases().where(
          (fixture) => !fixture.definiteMutation,
        )) {
          final repository = FakeInstitutionProfileRepository(
            onFetch: (call) async => call == 1
                ? _profile()
                : _profile(name: 'Current after ${failureCase.name}'),
            onUpdate: (_, _) async => throw failureCase.exception,
          );
          final harness = _harness(repository: repository);
          await _flush();
          harness.controller.beginEditing();
          harness.controller.updateField(
            InstitutionProfileEditField.name,
            'Draft ${failureCase.name}',
          );

          await harness.controller.submit();

          expect(repository.updateCalls, 1, reason: failureCase.name);
          expect(repository.fetchCalls, 2, reason: failureCase.name);
          expect(
            harness.read().status,
            InstitutionProfileViewStatus.unconfirmedCurrentState,
            reason: failureCase.name,
          );
          expect(
            harness.read().notice,
            contains('could not be confirmed'),
            reason: failureCase.name,
          );
          expect(
            harness.read().status,
            isNot(InstitutionProfileViewStatus.confirmedDirectSuccess),
            reason: failureCase.name,
          );
        }
      },
    );

    test(
      'changing one server-invalid field clears only that field and retains the remaining safe errors',
      () async {
        final harness = _harness(
          repository: FakeInstitutionProfileRepository(
            onUpdate: (_, _) async => throw _validationFailure({
              'description': ['Description needs review.'],
              'contact_email': ['Contact email needs review.'],
              'institution_id': ['Foreign tenant raw secret.'],
            }),
          ),
        );
        await _flush();
        harness.controller.beginEditing();
        harness.controller.updateField(
          InstitutionProfileEditField.name,
          'Draft School',
        );

        await harness.controller.submit();
        expect(
          harness.read().focusField,
          InstitutionProfileEditField.contactEmail,
        );

        harness.controller.updateField(
          InstitutionProfileEditField.contactEmail,
          'fixed@example.uz',
        );

        expect(
          harness.read().status,
          InstitutionProfileViewStatus.validationFailure,
        );
        expect(
          harness.read().fieldErrors,
          isNot(contains(InstitutionProfileEditField.contactEmail)),
        );
        expect(
          harness.read().fieldErrors[InstitutionProfileEditField.description],
          'Description needs review.',
        );
        expect(
          harness.read().formError,
          'Some submitted profile details need review.',
        );
        expect(harness.read().form?.name, 'Draft School');
        expect(harness.repository.updateCalls, 1);
      },
    );

    test(
      'every session boundary rejects a pending PATCH success without reconciliation or disclosure',
      () async {
        for (final boundary in _sessionBoundaries()) {
          final update = Completer<InstitutionProfileUpdateResult>();
          final repository = FakeInstitutionProfileRepository(
            onUpdate: (_, _) => update.future,
          );
          final harness = _harness(repository: repository);
          await _flush();
          harness.controller.beginEditing();
          harness.controller.updateField(
            InstitutionProfileEditField.name,
            'Late Secret ${boundary.name}',
          );
          final submit = harness.controller.submit();
          await _flush();

          boundary.apply(harness.auth);
          await _flush();
          final nameBeforeCompletion = harness.container
              .read(authSessionControllerProvider)
              .user
              ?.institution
              ?.name;
          update.complete(
            InstitutionProfileUpdateResult(
              profile: _profile(name: 'Late Secret ${boundary.name}'),
            ),
          );
          await submit;
          await _flush();

          expect(harness.read().status, InstitutionProfileViewStatus.initial);
          expect(harness.read().profile, isNull);
          expect(harness.read().form, isNull);
          expect(
            harness.container
                .read(authSessionControllerProvider)
                .user
                ?.institution
                ?.name,
            nameBeforeCompletion,
            reason: boundary.name,
          );
          expect(repository.updateCalls, 1, reason: boundary.name);
          expect(repository.fetchCalls, 1, reason: boundary.name);
          expect(harness.auth.bootstrapCalls, 0, reason: boundary.name);
          expect(
            harness.auth.nameReconciliationCalls,
            1,
            reason: boundary.name,
          );
        }
      },
    );

    test(
      'stale PATCH validation server and lifecycle failures cannot affect a newer session',
      () async {
        final staleFailures = <ApiRequestException>[
          _validationFailure({
            'name': ['Private validation detail.'],
          }),
          _serverFailure(ApiErrorCodes.serverError, statusCode: 500),
          _serverFailure(ApiErrorCodes.institutionInactive, statusCode: 403),
        ];
        for (final staleFailure in staleFailures) {
          final update = Completer<InstitutionProfileUpdateResult>();
          final harness = _harness(
            repository: FakeInstitutionProfileRepository(
              onUpdate: (_, _) => update.future,
            ),
          );
          await _flush();
          harness.controller.beginEditing();
          harness.controller.updateField(
            InstitutionProfileEditField.name,
            'Old Session Draft',
          );
          final submit = harness.controller.submit();
          await _flush();
          harness.auth.setSession(
            AuthSessionState.authenticated(
              _admin(id: 'admin-b', nestedInstitutionId: _institutionId),
            ),
          );
          await _flush();

          update.completeError(staleFailure);
          await submit;
          await _flush();

          expect(harness.read().status, InstitutionProfileViewStatus.initial);
          expect(harness.read().failure, isNull);
          expect(harness.read().formError, isNull);
          expect(harness.auth.bootstrapCalls, 0);
          expect(harness.repository.fetchCalls, 1);
          expect(harness.repository.updateCalls, 1);
        }
      },
    );

    test(
      'every session boundary rejects pending reconciliation success and failure',
      () async {
        for (final boundary in _sessionBoundaries()) {
          for (final reconciliationFailure in <ApiRequestException?>[
            null,
            _validationFailure({
              'name': ['Private stale validation detail.'],
            }),
            _serverFailure(ApiErrorCodes.serverError, statusCode: 500),
            _serverFailure(ApiErrorCodes.institutionInactive, statusCode: 403),
          ]) {
            final reconciliation = Completer<InstitutionProfile>();
            final repository = FakeInstitutionProfileRepository(
              onFetch: (call) =>
                  call == 1 ? Future.value(_profile()) : reconciliation.future,
              onUpdate: (_, _) async =>
                  throw const InstitutionProfileUpdateOutcomeUnknownException(),
            );
            final harness = _harness(repository: repository);
            await _flush();
            harness.controller.beginEditing();
            harness.controller.updateField(
              InstitutionProfileEditField.name,
              'Old Reconciliation Draft',
            );
            final submit = harness.controller.submit();
            await _flush();
            expect(repository.fetchCalls, 2, reason: boundary.name);

            boundary.apply(harness.auth);
            await _flush();
            final nameBeforeCompletion = harness.container
                .read(authSessionControllerProvider)
                .user
                ?.institution
                ?.name;
            if (reconciliationFailure != null) {
              reconciliation.completeError(reconciliationFailure);
            } else {
              reconciliation.complete(
                _profile(name: 'Late Reconciliation Secret'),
              );
            }
            await submit;
            await _flush();

            expect(harness.read().status, InstitutionProfileViewStatus.initial);
            expect(harness.read().failure, isNull);
            expect(harness.read().profile, isNull);
            expect(
              harness.container
                  .read(authSessionControllerProvider)
                  .user
                  ?.institution
                  ?.name,
              nameBeforeCompletion,
              reason: '${boundary.name}/$reconciliationFailure',
            );
            expect(repository.updateCalls, 1);
            expect(repository.fetchCalls, 2);
            expect(harness.auth.bootstrapCalls, 0);
            expect(harness.auth.nameReconciliationCalls, 1);
          }
        }
      },
    );

    test(
      'provider disposal rejects late PATCH and reconciliation completions',
      () async {
        final pendingPatch = Completer<InstitutionProfileUpdateResult>();
        final patchHarness = _harness(
          repository: FakeInstitutionProfileRepository(
            onUpdate: (_, _) => pendingPatch.future,
          ),
        );
        await _flush();
        patchHarness.controller.beginEditing();
        patchHarness.controller.updateField(
          InstitutionProfileEditField.name,
          'Disposed PATCH Secret',
        );
        final patchSubmit = patchHarness.controller.submit();
        await _flush();
        patchHarness.subscription.close();
        await _flush();
        final patchNameBefore = patchHarness.container
            .read(authSessionControllerProvider)
            .user
            ?.institution
            ?.name;
        pendingPatch.complete(
          InstitutionProfileUpdateResult(
            profile: _profile(name: 'Disposed PATCH Secret'),
          ),
        );
        await patchSubmit;
        expect(
          patchHarness.container
              .read(authSessionControllerProvider)
              .user
              ?.institution
              ?.name,
          patchNameBefore,
        );
        expect(patchHarness.repository.fetchCalls, 1);
        expect(patchHarness.repository.updateCalls, 1);

        final pendingReconciliation = Completer<InstitutionProfile>();
        final reconciliationHarness = _harness(
          repository: FakeInstitutionProfileRepository(
            onFetch: (call) => call == 1
                ? Future.value(_profile())
                : pendingReconciliation.future,
            onUpdate: (_, _) async =>
                throw const InstitutionProfileUpdateOutcomeUnknownException(),
          ),
        );
        await _flush();
        reconciliationHarness.controller.beginEditing();
        reconciliationHarness.controller.updateField(
          InstitutionProfileEditField.name,
          'Disposed Reconciliation Secret',
        );
        final reconciliationSubmit = reconciliationHarness.controller.submit();
        await _flush();
        reconciliationHarness.subscription.close();
        await _flush();
        final reconciliationNameBefore = reconciliationHarness.container
            .read(authSessionControllerProvider)
            .user
            ?.institution
            ?.name;
        pendingReconciliation.complete(
          _profile(name: 'Disposed Reconciliation Secret'),
        );
        await reconciliationSubmit;
        expect(
          reconciliationHarness.container
              .read(authSessionControllerProvider)
              .user
              ?.institution
              ?.name,
          reconciliationNameBefore,
        );
        expect(reconciliationHarness.repository.fetchCalls, 2);
        expect(reconciliationHarness.repository.updateCalls, 1);
      },
    );
  });
}

const _institutionId = '550e8400-e29b-41d4-a716-446655440000';
const _otherInstitutionId = '550e8400-e29b-41d4-a716-446655440001';
const _key = InstitutionProfileSessionKey(
  userId: 'admin-a',
  institutionId: _institutionId,
);

_Harness _harness({
  FakeAuthSessionController? auth,
  FakeInstitutionProfileRepository? repository,
}) {
  final resolvedAuth =
      auth ??
      FakeAuthSessionController(AuthSessionState.authenticated(_admin()));
  final resolvedRepository = repository ?? FakeInstitutionProfileRepository();
  final container = ProviderContainer(
    overrides: [
      authSessionControllerProvider.overrideWith(() => resolvedAuth),
      institutionProfileRepositoryProvider.overrideWithValue(
        resolvedRepository,
      ),
    ],
  );
  addTearDown(container.dispose);
  final provider = institutionProfileControllerProvider(_key);
  final subscription = container.listen(
    provider,
    (_, _) {},
    fireImmediately: true,
  );
  addTearDown(subscription.close);

  return _Harness(
    container: container,
    provider: provider,
    subscription: subscription,
    auth: resolvedAuth,
    repository: resolvedRepository,
  );
}

class _Harness {
  const _Harness({
    required this.container,
    required this.provider,
    required this.subscription,
    required this.auth,
    required this.repository,
  });

  final ProviderContainer container;
  final NotifierProvider<InstitutionProfileController, InstitutionProfileState>
  provider;
  final ProviderSubscription<InstitutionProfileState> subscription;
  final FakeAuthSessionController auth;
  final FakeInstitutionProfileRepository repository;

  InstitutionProfileState read() => subscription.read();

  InstitutionProfileController get controller =>
      container.read(provider.notifier);
}

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

AuthUser _admin({
  String id = 'admin-a',
  String? institutionId = _institutionId,
  String nestedInstitutionId = _institutionId,
  UserRole role = UserRole.institutionAdmin,
  bool isActive = true,
  bool mustChangePassword = false,
  bool includeInstitution = true,
  String institutionStatus = 'active',
}) {
  return AuthUser(
    id: id,
    institutionId: institutionId,
    role: role,
    fullName: 'Admin User',
    loginName: 'admin',
    email: 'admin@example.uz',
    phone: '+99890',
    isActive: isActive,
    mustChangePassword: mustChangePassword,
    institution: includeInstitution
        ? AuthInstitution(
            id: nestedInstitutionId,
            name: 'Session School',
            status: institutionStatus,
            timezone: 'Asia/Tashkent',
          )
        : null,
  );
}

InstitutionProfile _profile({
  String id = _institutionId,
  String name = 'Example School',
  InstitutionProfileStatus status = InstitutionProfileStatus.active,
  String? contactPhone,
}) {
  return InstitutionProfile(
    id: id,
    name: name,
    type: InstitutionProfileType.school,
    status: status,
    contactEmail: 'office@example.uz',
    contactPhone: contactPhone,
    address: 'Address',
    description: 'Description',
    createdAt: DateTime.utc(2026, 8, 1),
    updatedAt: DateTime.utc(2026, 8, 7),
  );
}

ApiRequestException _localFailure() {
  return ApiRequestException(
    ApiFailure.local(
      kind: ApiFailureKind.connection,
      message: 'Connection failed.',
    ),
  );
}

ApiRequestException _serverFailure(String code, {int? statusCode}) {
  return ApiRequestException(
    ApiFailure.fromServerError(
      statusCode:
          statusCode ??
          (code == ApiErrorCodes.resourceNotFound
              ? 404
              : code == ApiErrorCodes.validationFailed
              ? 422
              : 403),
      error: ApiErrorResponse(
        message: 'Raw server error.',
        code: code,
        fieldErrors: const {},
        requestId: 'private',
      ),
    ),
  );
}

ApiRequestException _validationFailure(Map<String, List<String>> fieldErrors) {
  return ApiRequestException(
    ApiFailure.fromServerError(
      statusCode: 422,
      error: ApiErrorResponse(
        message: 'Raw validation payload.',
        code: ApiErrorCodes.validationFailed,
        fieldErrors: fieldErrors,
        requestId: 'private-request-id',
      ),
    ),
  );
}

List<_FailureCase> _failureCases() {
  return [
    _FailureCase(
      name: 'authentication_required',
      exception: _serverFailure(
        ApiErrorCodes.authenticationRequired,
        statusCode: 401,
      ),
      serverCode: ApiErrorCodes.authenticationRequired,
      clearsForSession: true,
      definiteMutation: true,
    ),
    _FailureCase(
      name: 'password_change_required',
      exception: _serverFailure(
        ApiErrorCodes.passwordChangeRequired,
        statusCode: 403,
      ),
      serverCode: ApiErrorCodes.passwordChangeRequired,
      clearsForSession: true,
      bootstraps: true,
      definiteMutation: true,
    ),
    _FailureCase(
      name: 'user_inactive',
      exception: _serverFailure(ApiErrorCodes.userInactive, statusCode: 403),
      serverCode: ApiErrorCodes.userInactive,
      clearsForSession: true,
      bootstraps: true,
      definiteMutation: true,
    ),
    _FailureCase(
      name: 'institution_inactive',
      exception: _serverFailure(
        ApiErrorCodes.institutionInactive,
        statusCode: 403,
      ),
      serverCode: ApiErrorCodes.institutionInactive,
      clearsForSession: true,
      bootstraps: true,
      definiteMutation: true,
    ),
    _FailureCase(
      name: 'forbidden',
      exception: _serverFailure(ApiErrorCodes.forbidden, statusCode: 403),
      serverCode: ApiErrorCodes.forbidden,
      definiteMutation: true,
    ),
    _FailureCase(
      name: 'resource_not_found',
      exception: _serverFailure(
        ApiErrorCodes.resourceNotFound,
        statusCode: 404,
      ),
      serverCode: ApiErrorCodes.resourceNotFound,
      definiteMutation: true,
    ),
    _FailureCase(
      name: 'validation_failed',
      exception: _validationFailure(const {}),
      serverCode: ApiErrorCodes.validationFailed,
      definiteMutation: true,
    ),
    _FailureCase(
      name: 'rate_limited',
      exception: _serverFailure(ApiErrorCodes.rateLimited, statusCode: 429),
      serverCode: ApiErrorCodes.rateLimited,
      definiteMutation: true,
    ),
    _FailureCase(
      name: 'connection',
      exception: _kindFailure(ApiFailureKind.connection),
    ),
    _FailureCase(
      name: 'timeout',
      exception: _kindFailure(ApiFailureKind.timeout),
    ),
    _FailureCase(
      name: 'invalidResponse',
      exception: _kindFailure(ApiFailureKind.invalidResponse),
    ),
    _FailureCase(
      name: 'cancelled',
      exception: _kindFailure(ApiFailureKind.cancelled),
    ),
    _FailureCase(
      name: 'server',
      exception: _serverFailure(ApiErrorCodes.serverError, statusCode: 500),
      serverCode: ApiErrorCodes.serverError,
    ),
    _FailureCase(
      name: 'unknown_server_409',
      exception: _serverFailure('unexpected_conflict', statusCode: 409),
      serverCode: 'unexpected_conflict',
    ),
    _FailureCase(
      name: 'unknown',
      exception: _kindFailure(ApiFailureKind.unknown),
    ),
  ];
}

ApiRequestException _kindFailure(ApiFailureKind kind) {
  return ApiRequestException(
    ApiFailure.local(kind: kind, message: 'Raw $kind private detail.'),
  );
}

List<_SessionBoundary> _sessionBoundaries() {
  return [
    _SessionBoundary(
      'logout',
      (auth) => auth.setSession(const AuthSessionState.unauthenticated()),
    ),
    _SessionBoundary(
      'user-a-to-user-b',
      (auth) => auth.setSession(
        AuthSessionState.authenticated(_admin(id: 'admin-b')),
      ),
    ),
    _SessionBoundary(
      'institution-a-to-institution-b',
      (auth) => auth.setSession(
        AuthSessionState.authenticated(
          _admin(
            institutionId: _otherInstitutionId,
            nestedInstitutionId: _otherInstitutionId,
          ),
        ),
      ),
    ),
    _SessionBoundary(
      'institution-admin-to-teacher',
      (auth) => auth.setSession(
        AuthSessionState.authenticated(_admin(role: UserRole.teacher)),
      ),
    ),
    _SessionBoundary(
      'account-inactive',
      (auth) => auth.setSession(
        AuthSessionState.authenticated(_admin(isActive: false)),
      ),
    ),
    _SessionBoundary(
      'institution-inactive',
      (auth) => auth.setSession(
        AuthSessionState.authenticated(_admin(institutionStatus: 'inactive')),
      ),
    ),
    _SessionBoundary(
      'password-gate',
      (auth) => auth.setSession(
        AuthSessionState.authenticated(_admin(mustChangePassword: true)),
      ),
    ),
  ];
}

class _FailureCase {
  const _FailureCase({
    required this.name,
    required this.exception,
    this.serverCode,
    this.clearsForSession = false,
    this.bootstraps = false,
    this.definiteMutation = false,
  });

  final String name;
  final ApiRequestException exception;
  final String? serverCode;
  final bool clearsForSession;
  final bool bootstraps;
  final bool definiteMutation;
}

class _SessionBoundary {
  const _SessionBoundary(this.name, this.apply);

  final String name;
  final void Function(FakeAuthSessionController auth) apply;
}

class FakeInstitutionProfileRepository implements InstitutionProfileRepository {
  FakeInstitutionProfileRepository({this.onFetch, this.onUpdate});

  final Future<InstitutionProfile> Function(int call)? onFetch;
  final Future<InstitutionProfileUpdateResult> Function(
    int call,
    InstitutionProfileUpdateRequest request,
  )?
  onUpdate;
  var fetchCalls = 0;
  var updateCalls = 0;

  @override
  Future<InstitutionProfile> fetchProfile() {
    fetchCalls += 1;

    return onFetch?.call(fetchCalls) ?? Future.value(_profile());
  }

  @override
  Future<InstitutionProfileUpdateResult> updateProfile(
    InstitutionProfileUpdateRequest request,
  ) {
    updateCalls += 1;

    return onUpdate?.call(updateCalls, request) ??
        Future.value(InstitutionProfileUpdateResult(profile: _profile()));
  }
}

class FakeAuthSessionController extends AuthSessionController {
  FakeAuthSessionController(this.initialState);

  final AuthSessionState initialState;
  var bootstrapCalls = 0;
  var nameReconciliationCalls = 0;
  var rejectNameReconciliation = false;

  @override
  AuthSessionState build() => initialState;

  void setSession(AuthSessionState nextState) {
    state = nextState;
  }

  @override
  Future<void> bootstrap() async {
    bootstrapCalls += 1;
  }

  @override
  bool reconcileInstitutionNameFromServer({
    required String expectedUserId,
    required String expectedInstitutionId,
    required String institutionName,
  }) {
    nameReconciliationCalls += 1;

    if (rejectNameReconciliation) {
      return false;
    }

    return super.reconcileInstitutionNameFromServer(
      expectedUserId: expectedUserId,
      expectedInstitutionId: expectedInstitutionId,
      institutionName: institutionName,
    );
  }
}
