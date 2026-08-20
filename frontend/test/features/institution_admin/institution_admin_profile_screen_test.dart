import 'dart:async';

import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:testlabuz_client/features/institution_admin/data/institution_profile_repository_impl.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_profile.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_profile_repository.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_profile_update.dart';
import 'package:testlabuz_client/features/institution_admin/presentation/institution_admin_profile_screen.dart';

void main() {
  testWidgets('loading is live and hides all profile content', (tester) async {
    final pending = Completer<InstitutionProfile>();
    await _pump(
      tester,
      repository: FakeProfileRepository(onFetch: (_) => pending.future),
    );

    expect(find.byKey(const Key('institutionProfileLoading')), findsOneWidget);
    expect(
      find.bySemanticsLabel('Loading institution profile'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('institutionProfileData')), findsNothing);
    expect(find.byKey(const Key('institutionProfileEditForm')), findsNothing);
  });

  testWidgets('renders exact ordered public rows labels values and actions', (
    tester,
  ) async {
    await _pump(tester);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('institutionProfileData')), findsOneWidget);
    expect(find.text('Institution Profile'), findsOneWidget);
    expect(find.text('Refresh'), findsOneWidget);
    expect(find.text('Edit profile'), findsOneWidget);
    expect(find.text('Learning center'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Not provided'), findsNWidgets(2));
    expect(find.text('2026-08-07 15:00 UTC'), findsOneWidget);
    expect(find.text(_institutionId), findsNothing);
    expect(find.text('institution_id'), findsNothing);
    expect(find.text('creator'), findsNothing);

    final rowKeys = [
      'institutionProfileNameValue',
      'institutionProfileTypeValue',
      'institutionProfileStatusValue',
      'institutionProfileContactEmailValue',
      'institutionProfileContactPhoneValue',
      'institutionProfileAddressValue',
      'institutionProfileDescriptionValue',
      'institutionProfileCreatedAtValue',
      'institutionProfileUpdatedAtValue',
    ];
    final positions = rowKeys
        .map((key) => tester.getTopLeft(find.byKey(Key(key))).dy)
        .toList();
    expect(positions, orderedEquals([...positions]..sort()));
  });

  testWidgets('inline edit has exact order and local validation focuses name', (
    tester,
  ) async {
    final repository = FakeProfileRepository();
    await _pump(tester, repository: repository);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('institutionProfileEditButton')));
    await tester.pump();
    expect(find.byKey(const Key('institutionProfileEditForm')), findsOneWidget);
    expect(find.text('Type: Learning center'), findsOneWidget);
    expect(find.text('Status: Active'), findsOneWidget);
    expect(find.text('Save changes'), findsOneWidget);
    expect(find.byType(DropdownButton), findsNothing);
    expect(find.text('Institution ID'), findsNothing);

    final formKeys = [
      'institutionProfileNameField',
      'institutionProfileContactEmailField',
      'institutionProfileContactPhoneField',
      'institutionProfileAddressField',
      'institutionProfileDescriptionField',
    ];
    final positions = formKeys
        .map((key) => tester.getTopLeft(find.byKey(Key(key))).dy)
        .toList();
    expect(positions, orderedEquals([...positions]..sort()));

    await tester.enterText(
      find.byKey(const Key('institutionProfileNameField')),
      ' ',
    );
    await tester.enterText(
      find.byKey(const Key('institutionProfileContactEmailField')),
      'bad email',
    );
    await _tapVisible(tester, 'institutionProfileSaveButton');
    await tester.pump();

    expect(find.text('Name is required.'), findsOneWidget);
    expect(find.text('Enter a valid contact email.'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(
            find.byKey(const Key('institutionProfileNameField')),
          )
          .focusNode
          ?.hasFocus,
      isTrue,
    );
    expect(repository.updateCalls, 0);
  });

  testWidgets('cancel and no-change notices never PATCH', (tester) async {
    final repository = FakeProfileRepository();
    await _pump(tester, repository: repository);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('institutionProfileEditButton')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('institutionProfileNameField')),
      'Local only',
    );
    await _tapVisible(tester, 'institutionProfileCancelButton');
    await tester.pump();
    expect(repository.updateCalls, 0);
    expect(find.text('Example School'), findsOneWidget);

    await tester.tap(find.byKey(const Key('institutionProfileEditButton')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('institutionProfileNameField')),
      '  Example School ',
    );
    await _tapVisible(tester, 'institutionProfileSaveButton');
    await tester.pump();
    expect(repository.updateCalls, 0);
    expect(find.text('No changes to save.'), findsOneWidget);
    expect(find.byKey(const Key('institutionProfileNotice')), findsOneWidget);
  });

  testWidgets('trusted PATCH shows Saving then exact confirmed notice', (
    tester,
  ) async {
    final update = Completer<InstitutionProfileUpdateResult>();
    final repository = FakeProfileRepository(onUpdate: (_, _) => update.future);
    await _pump(tester, repository: repository);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('institutionProfileEditButton')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('institutionProfileNameField')),
      'Renamed School',
    );
    await _tapVisible(tester, 'institutionProfileSaveButton');
    await tester.pump();

    expect(find.text('Saving'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('institutionProfileSaveButton')),
          )
          .onPressed,
      isNull,
    );
    update.complete(
      InstitutionProfileUpdateResult(profile: _profile(name: 'Renamed School')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('institutionProfileConfirmedDirectSuccess')),
      findsOneWidget,
    );
    expect(find.text('Institution profile updated.'), findsOneWidget);
  });

  testWidgets('uncertain PATCH shows Verifying and neutral current state', (
    tester,
  ) async {
    final reconciliation = Completer<InstitutionProfile>();
    final repository = FakeProfileRepository(
      onFetch: (call) =>
          call == 1 ? Future.value(_profile()) : reconciliation.future,
      onUpdate: (_, _) async =>
          throw const InstitutionProfileUpdateOutcomeUnknownException(),
    );
    await _pump(tester, repository: repository);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('institutionProfileEditButton')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('institutionProfileNameField')),
      'Renamed School',
    );
    await _tapVisible(tester, 'institutionProfileSaveButton');
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const Key('institutionProfileReconciling')),
      findsOneWidget,
    );
    expect(find.text('Verifying'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('institutionProfileSaveButton')),
          )
          .onPressed,
      isNull,
    );
    reconciliation.complete(_profile(name: 'Renamed School'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('institutionProfileUnconfirmedCurrentState')),
      findsOneWidget,
    );
    expect(
      find.text(
        'Current server profile matches your submitted changes, but this request result could not be confirmed.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('succeeded'), findsNothing);
    expect(repository.updateCalls, 1);
    expect(repository.fetchCalls, 2);
  });

  testWidgets('unknown outcome hides stale data and reloads read-only', (
    tester,
  ) async {
    final repository = FakeProfileRepository(
      onFetch: (call) async {
        if (call == 1) {
          return _profile();
        }
        if (call == 2) {
          throw _failure();
        }
        return _profile(name: 'Reloaded School');
      },
      onUpdate: (_, _) async =>
          throw const InstitutionProfileUpdateOutcomeUnknownException(),
    );
    await _pump(tester, repository: repository);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('institutionProfileEditButton')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('institutionProfileNameField')),
      'New',
    );
    await _tapVisible(tester, 'institutionProfileSaveButton');
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('institutionProfileOutcomeUnknown')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('institutionProfileData')), findsNothing);
    expect(find.text('Update outcome unknown'), findsOneWidget);
    expect(find.text('Reload profile'), findsOneWidget);
    await _tapVisible(tester, 'institutionProfileReloadButton');
    await tester.pumpAndSettle();
    expect(find.text('Reloaded School'), findsOneWidget);
    expect(repository.updateCalls, 1);
    expect(repository.fetchCalls, 3);
  });

  testWidgets('load error Retry is safe and deduplicated', (tester) async {
    final retry = Completer<InstitutionProfile>();
    final repository = FakeProfileRepository(
      onFetch: (call) => call == 1
          ? Future<InstitutionProfile>.error(_failure())
          : retry.future,
    );
    await _pump(tester, repository: repository);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('institutionProfileError')), findsOneWidget);
    expect(find.text('Profile unavailable'), findsOneWidget);
    expect(
      find.text(
        'Could not reach the server. Check the connection and try again.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('institutionProfileRetryButton')));
    await tester.pump();
    expect(find.text('Retrying'), findsOneWidget);
    expect(repository.fetchCalls, 2);
    retry.complete(_profile());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('institutionProfileData')), findsOneWidget);
  });

  testWidgets('GET forbidden uses exact view copy', (tester) async {
    final repository = FakeProfileRepository(
      onFetch: (_) async =>
          throw _serverFailure(ApiErrorCodes.forbidden, statusCode: 403),
    );
    await _pump(tester, repository: repository);
    await tester.pumpAndSettle();

    expect(find.text('Profile unavailable'), findsOneWidget);
    expect(
      find.text('You do not have permission to view this institution profile.'),
      findsOneWidget,
    );
    expect(
      find.text('You do not have permission to edit this institution profile.'),
      findsNothing,
    );
    expect(find.text('Retry'), findsOneWidget);
    expect(repository.fetchCalls, 1);
    expect(repository.updateCalls, 0);
  });

  testWidgets(
    'GET failure copy matrix is exact and never exposes raw details',
    (tester) async {
      final cases = <ApiRequestException, String>{
        _serverFailure(ApiErrorCodes.resourceNotFound, statusCode: 404):
            'The institution profile could not be found.',
        _validationFailure(const {}):
            'The profile request did not match the API contract.',
        _kindFailure(ApiFailureKind.connection):
            'Could not reach the server. Check the connection and try again.',
        _kindFailure(ApiFailureKind.timeout): 'The profile request timed out.',
        _kindFailure(ApiFailureKind.invalidResponse):
            'The server returned an unexpected institution profile response.',
        _kindFailure(ApiFailureKind.cancelled):
            'The profile request was cancelled.',
        _serverFailure(ApiErrorCodes.serverError, statusCode: 500):
            'The institution profile could not be loaded.',
        _kindFailure(ApiFailureKind.unknown):
            'The institution profile could not be loaded.',
      };

      for (final entry in cases.entries) {
        final repository = FakeProfileRepository(
          onFetch: (_) async => throw entry.key,
        );
        await _pump(tester, repository: repository);
        await tester.pumpAndSettle();

        expect(find.text(entry.value), findsOneWidget);
        expect(find.textContaining('Raw private'), findsNothing);
        expect(find.textContaining('private-request-id'), findsNothing);
        expect(find.textContaining(_institutionId), findsNothing);
        expect(repository.fetchCalls, 1);
        expect(repository.updateCalls, 0);
      }
    },
  );

  testWidgets(
    'PATCH forbidden uses exact edit copy and Retry remains a GET-only action',
    (tester) async {
      final repository = FakeProfileRepository(
        onFetch: (call) => call == 1
            ? Future.value(_profile())
            : Future<InstitutionProfile>.error(
                _serverFailure(ApiErrorCodes.forbidden, statusCode: 403),
              ),
        onUpdate: (_, _) async => throw _serverFailure(
          ApiErrorCodes.forbidden,
          statusCode: 403,
          rawMessage:
              'Raw backend PATCH secret user-a tenant-a request-private.',
        ),
      );
      await _pump(tester, repository: repository);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('institutionProfileEditButton')));
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('institutionProfileNameField')),
        'Changed School',
      );
      await _tapVisible(tester, 'institutionProfileSaveButton');
      await tester.pumpAndSettle();

      expect(
        find.text(
          'You do not have permission to edit this institution profile.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'You do not have permission to view this institution profile.',
        ),
        findsNothing,
      );
      expect(find.byKey(const Key('institutionProfileEditForm')), findsNothing);
      expect(find.text('Save changes'), findsNothing);
      expect(find.text('Retry'), findsOneWidget);
      for (final privateDetail in const [
        'Raw backend PATCH secret',
        'user-a',
        'tenant-a',
        'request-private',
      ]) {
        expect(find.textContaining(privateDetail), findsNothing);
      }

      await tester.tap(find.byKey(const Key('institutionProfileRetryButton')));
      await tester.pumpAndSettle();
      expect(repository.fetchCalls, 2);
      expect(repository.updateCalls, 1);
      expect(
        find.text(
          'You do not have permission to view this institution profile.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'You do not have permission to edit this institution profile.',
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'server validation exposes only approved exact field copy and focuses the first field in form order',
    (tester) async {
      final repository = FakeProfileRepository(
        onUpdate: (_, _) async => throw _validationFailure({
          'description': ['Review the description.'],
          'address': ['Review the address.'],
          'contact_email': ['Enter a deliverable contact email.'],
          'institution_id': ['Foreign tenant private detail.'],
          'settings': ['Protected settings private detail.'],
        }),
      );
      await _pump(tester, repository: repository);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('institutionProfileEditButton')));
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('institutionProfileNameField')),
        'Draft School',
      );

      await _tapVisible(tester, 'institutionProfileSaveButton');
      await tester.pumpAndSettle();

      expect(find.text('Enter a deliverable contact email.'), findsOneWidget);
      expect(find.text('Review the address.'), findsOneWidget);
      expect(find.text('Review the description.'), findsOneWidget);
      expect(
        find.text('Some submitted profile details need review.'),
        findsOneWidget,
      );
      for (final protectedText in const [
        'Raw validation backend detail.',
        'private-request-id',
        'Foreign tenant private detail.',
        'Protected settings private detail.',
        'institution_id',
        'settings',
      ]) {
        expect(find.textContaining(protectedText), findsNothing);
      }
      expect(
        tester
            .widget<TextField>(
              find.byKey(const Key('institutionProfileContactEmailField')),
            )
            .focusNode
            ?.hasFocus,
        isTrue,
      );
      expect(
        tester
            .widget<TextField>(
              find.byKey(const Key('institutionProfileNameField')),
            )
            .controller
            ?.text,
        'Draft School',
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('institutionProfileSaveButton')),
            )
            .onPressed,
        isNotNull,
      );
      expect(repository.updateCalls, 1);

      await tester.enterText(
        find.byKey(const Key('institutionProfileContactEmailField')),
        'fixed@example.uz',
      );
      await tester.pump();

      expect(find.text('Enter a deliverable contact email.'), findsNothing);
      expect(find.text('Review the address.'), findsOneWidget);
      expect(find.text('Review the description.'), findsOneWidget);
      expect(
        find.text('Some submitted profile details need review.'),
        findsOneWidget,
      );
      expect(repository.updateCalls, 1);
    },
  );

  testWidgets(
    'uncertain PATCH failure matrix reconciles once and never confirms stale draft or raw details',
    (tester) async {
      final cases = <ApiRequestException>[
        _kindFailure(ApiFailureKind.connection),
        _kindFailure(ApiFailureKind.timeout),
        _kindFailure(ApiFailureKind.invalidResponse),
        _kindFailure(ApiFailureKind.cancelled),
        _serverFailure(ApiErrorCodes.serverError, statusCode: 500),
        _serverFailure('unexpected_conflict', statusCode: 409),
        _kindFailure(ApiFailureKind.unknown),
      ];

      for (final failure in cases) {
        final repository = FakeProfileRepository(
          onFetch: (call) async =>
              call == 1 ? _profile() : _profile(name: 'Current Server School'),
          onUpdate: (_, _) async => throw failure,
        );
        await _pump(tester, repository: repository);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('institutionProfileEditButton')));
        await tester.pump();
        await tester.enterText(
          find.byKey(const Key('institutionProfileNameField')),
          'Retained Draft',
        );

        await _tapVisible(tester, 'institutionProfileSaveButton');
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('institutionProfileUnconfirmedCurrentState')),
          findsOneWidget,
        );
        expect(
          find.text(
            'Current server profile differs from your submitted changes. This request result could not be confirmed.',
          ),
          findsOneWidget,
        );
        expect(find.text('Current Server School'), findsOneWidget);
        expect(
          find.byKey(const Key('institutionProfileEditForm')),
          findsNothing,
        );
        expect(find.text('Retained Draft'), findsNothing);
        expect(
          find.byKey(const Key('institutionProfileConfirmedDirectSuccess')),
          findsNothing,
        );
        expect(find.text('Institution profile updated.'), findsNothing);
        expect(find.textContaining('Raw private'), findsNothing);
        expect(find.textContaining('private-request-id'), findsNothing);
        expect(find.textContaining(_institutionId), findsNothing);
        expect(repository.updateCalls, 1);
        expect(repository.fetchCalls, 2);
      }
    },
  );

  testWidgets(
    'Tab and Shift+Tab traverse view actions and exact form order without side effects',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final repository = FakeProfileRepository();
      final auth = FakeAuthController(AuthSessionState.authenticated(_admin()));
      await _pump(tester, repository: repository, auth: auth);
      await tester.pumpAndSettle();

      await _sendTab(tester);
      _expectFocused(tester, 'institutionProfileRefreshButton');
      await _sendTab(tester);
      _expectFocused(tester, 'institutionProfileEditButton');
      expect(repository.fetchCalls, 1);
      expect(repository.updateCalls, 0);
      expect(auth.currentState.user?.institution?.name, 'Example School');
      expect(
        tester.state<NavigatorState>(find.byType(Navigator)).canPop(),
        isFalse,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.space, platform: 'windows');
      await tester.pump();
      expect(
        find.byKey(const Key('institutionProfileEditForm')),
        findsOneWidget,
      );

      for (final key in const [
        'institutionProfileNameField',
        'institutionProfileContactEmailField',
        'institutionProfileContactPhoneField',
        'institutionProfileAddressField',
        'institutionProfileDescriptionField',
        'institutionProfileCancelButton',
        'institutionProfileSaveButton',
      ]) {
        await _sendTab(tester);
        _expectFocused(tester, key);
      }
      for (final key in const [
        'institutionProfileCancelButton',
        'institutionProfileDescriptionField',
        'institutionProfileAddressField',
        'institutionProfileContactPhoneField',
        'institutionProfileContactEmailField',
        'institutionProfileNameField',
      ]) {
        await _sendShiftTab(tester);
        _expectFocused(tester, key);
      }

      expect(
        tester
            .widget<TextField>(
              find.byKey(const Key('institutionProfileNameField')),
            )
            .controller
            ?.text,
        'Example School',
      );
      expect(repository.fetchCalls, 1);
      expect(repository.updateCalls, 0);
      expect(auth.currentState.user?.institution?.name, 'Example School');
      expect(
        tester.state<NavigatorState>(find.byType(Navigator)).canPop(),
        isFalse,
      );
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets(
    'Enter activates Refresh and Cancel as separate read-only actions',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final repository = FakeProfileRepository();
      await _pump(tester, repository: repository);
      await tester.pumpAndSettle();

      await _sendTab(tester);
      _expectFocused(tester, 'institutionProfileRefreshButton');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter, platform: 'windows');
      await tester.pumpAndSettle();
      expect(repository.fetchCalls, 2);
      expect(repository.updateCalls, 0);

      await tester.tap(find.byKey(const Key('institutionProfileEditButton')));
      await tester.pump();
      for (var index = 0; index < 6; index += 1) {
        await _sendTab(tester);
      }
      _expectFocused(tester, 'institutionProfileCancelButton');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter, platform: 'windows');
      await tester.pump();
      expect(find.byKey(const Key('institutionProfileData')), findsOneWidget);
      expect(repository.updateCalls, 0);
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets(
    'Space activates Save once and disabled in-flight actions ignore keys',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final pending = Completer<InstitutionProfileUpdateResult>();
      final repository = FakeProfileRepository(
        onUpdate: (_, _) => pending.future,
      );
      await _pump(tester, repository: repository);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('institutionProfileEditButton')));
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('institutionProfileNameField')),
        'Keyboard Save School',
      );
      for (var index = 0; index < 6; index += 1) {
        await _sendTab(tester);
      }
      _expectFocused(tester, 'institutionProfileSaveButton');

      await tester.sendKeyEvent(LogicalKeyboardKey.space, platform: 'windows');
      await tester.pump();
      expect(repository.updateCalls, 1);
      expect(find.text('Saving'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('institutionProfileSaveButton')),
            )
            .onPressed,
        isNull,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter, platform: 'windows');
      await tester.sendKeyEvent(LogicalKeyboardKey.space, platform: 'windows');
      await tester.pump();
      expect(repository.updateCalls, 1);

      pending.complete(
        InstitutionProfileUpdateResult(
          profile: _profile(name: 'Keyboard Save School'),
        ),
      );
      await tester.pumpAndSettle();
      expect(repository.updateCalls, 1);
      expect(find.text('Institution profile updated.'), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets('Enter activates Retry independently and never submits PATCH', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final repository = FakeProfileRepository(
      onFetch: (call) => call == 1
          ? Future<InstitutionProfile>.error(_failure())
          : Future.value(_profile()),
    );
    await _pump(tester, repository: repository);
    await tester.pumpAndSettle();
    await _sendTab(tester);
    _expectFocused(tester, 'institutionProfileRetryButton');

    await tester.sendKeyEvent(LogicalKeyboardKey.enter, platform: 'windows');
    await tester.pumpAndSettle();

    expect(repository.fetchCalls, 2);
    expect(repository.updateCalls, 0);
    expect(find.byKey(const Key('institutionProfileData')), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  for (final size in const [Size(800, 600), Size(1440, 900)]) {
    for (final textScale in const [1.0, 2.0]) {
      testWidgets('is scroll-safe at $size and text scale $textScale', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await _pump(tester, textScale: textScale);
        await tester.pumpAndSettle();
        expect(find.byType(SingleChildScrollView), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.tap(find.byKey(const Key('institutionProfileEditButton')));
        await tester.pump();
        expect(find.byType(SingleChildScrollView), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}

const _institutionId = '550e8400-e29b-41d4-a716-446655440000';

Future<void> _pump(
  WidgetTester tester, {
  FakeProfileRepository? repository,
  FakeAuthController? auth,
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        authSessionControllerProvider.overrideWith(
          () =>
              auth ??
              FakeAuthController(AuthSessionState.authenticated(_admin())),
        ),
        institutionProfileRepositoryProvider.overrideWithValue(
          repository ?? FakeProfileRepository(),
        ),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: const Scaffold(body: InstitutionAdminProfileScreen()),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

Future<void> _sendTab(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.tab, platform: 'windows');
  await tester.pump();
}

Future<void> _sendShiftTab(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.shift, platform: 'windows');
  await tester.sendKeyEvent(LogicalKeyboardKey.tab, platform: 'windows');
  await tester.sendKeyUpEvent(LogicalKeyboardKey.shift, platform: 'windows');
  await tester.pump();
}

void _expectFocused(WidgetTester tester, String key) {
  final finder = find.byKey(Key(key));
  expect(finder, findsOneWidget);
  final field = finder.evaluate().single.widget;
  final hasFocus = field is TextField
      ? field.focusNode?.hasFocus == true
      : Focus.of(
          tester.element(
            find.descendant(of: finder, matching: find.byType(Text)).first,
          ),
        ).hasFocus;
  expect(hasFocus, isTrue, reason: '$key should own keyboard focus');
}

Future<void> _tapVisible(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
}

AuthUser _admin() {
  return const AuthUser(
    id: 'admin-a',
    institutionId: _institutionId,
    role: UserRole.institutionAdmin,
    fullName: 'Admin User',
    loginName: 'admin',
    email: null,
    phone: null,
    isActive: true,
    mustChangePassword: false,
    institution: AuthInstitution(
      id: _institutionId,
      name: 'Session School',
      status: 'active',
      timezone: 'Asia/Tashkent',
    ),
  );
}

InstitutionProfile _profile({String name = 'Example School'}) {
  return InstitutionProfile(
    id: _institutionId,
    name: name,
    type: InstitutionProfileType.learningCenter,
    status: InstitutionProfileStatus.active,
    contactEmail: 'office@example.uz',
    contactPhone: null,
    address: 'Long address that can wrap safely across available space.',
    description: null,
    createdAt: DateTime.utc(2026, 8, 1, 10, 30),
    updatedAt: DateTime.utc(2026, 8, 7, 15),
  );
}

ApiRequestException _failure() {
  return ApiRequestException(
    ApiFailure.local(
      kind: ApiFailureKind.connection,
      message: 'Raw connection detail.',
    ),
  );
}

ApiRequestException _serverFailure(
  String code, {
  required int statusCode,
  String rawMessage = 'Raw backend detail.',
}) {
  return ApiRequestException(
    ApiFailure.fromServerError(
      statusCode: statusCode,
      error: ApiErrorResponse(
        message: rawMessage,
        code: code,
        fieldErrors: const {},
        requestId: 'private-request-id',
      ),
    ),
  );
}

ApiRequestException _validationFailure(Map<String, List<String>> fieldErrors) {
  return ApiRequestException(
    ApiFailure.fromServerError(
      statusCode: 422,
      error: ApiErrorResponse(
        message: 'Raw validation backend detail.',
        code: ApiErrorCodes.validationFailed,
        fieldErrors: fieldErrors,
        requestId: 'private-request-id',
      ),
    ),
  );
}

ApiRequestException _kindFailure(ApiFailureKind kind) {
  return ApiRequestException(
    ApiFailure.local(kind: kind, message: 'Raw private $kind detail.'),
  );
}

class FakeProfileRepository implements InstitutionProfileRepository {
  FakeProfileRepository({this.onFetch, this.onUpdate});

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
        Future.value(
          InstitutionProfileUpdateResult(profile: _profile(name: 'Updated')),
        );
  }
}

class FakeAuthController extends AuthSessionController {
  FakeAuthController(this.initialState);

  final AuthSessionState initialState;

  AuthSessionState get currentState => state;

  @override
  AuthSessionState build() => initialState;
}
