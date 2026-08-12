import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:testlabuz_client/app/app.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/app/router/app_router.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_error_response.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/features/auth/data/auth_repository_impl.dart';
import 'package:testlabuz_client/features/auth/domain/auth_institution.dart';
import 'package:testlabuz_client/features/auth/domain/auth_repository.dart';
import 'package:testlabuz_client/features/auth/domain/auth_user.dart';
import 'package:testlabuz_client/features/auth/domain/user_role.dart';
import 'package:testlabuz_client/features/platform_admin/data/platform_dashboard_repository_impl.dart';
import 'package:testlabuz_client/features/platform_admin/data/platform_institution_detail_repository_impl.dart';
import 'package:testlabuz_client/features/platform_admin/data/platform_institution_edit_repository_impl.dart';
import 'package:testlabuz_client/features/platform_admin/data/platform_institution_list_repository_impl.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_dashboard.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_dashboard_repository.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_detail.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_detail_repository.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_edit.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_edit_repository.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_list.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_list_query.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_list_repository.dart';

void main() {
  group('PlatformOwnerInstitutionEditScreen', () {
    testWidgets('direct edit route loads current data and exact six fields', (
      tester,
    ) async {
      final detailRepository = FakePlatformInstitutionDetailRepository(
        onFetch: (institutionId) async => _detail(
          id: institutionId,
          name: 'Editable College',
          type: PlatformInstitutionType.college,
          status: PlatformInstitutionStatus.inactive,
          contactEmail: null,
          contactPhone: '+998901234567',
          address: "Samarqand\nO'zbekiston",
          description: null,
        ),
      );

      await _pumpApp(tester, detailRepository: detailRepository);
      await tester.pumpAndSettle();

      expect(_currentPath(tester), _editPath(_institutionIdA));
      expect(find.byKey(const Key('platformOwnerShell')), findsOneWidget);
      expect(
        tester
            .widget<NavigationRail>(
              find.byKey(const Key('platformOwnerNavigation')),
            )
            .selectedIndex,
        1,
      );
      expect(detailRepository.institutionIds, [_institutionIdA]);
      expect(
        find.byKey(const Key('platformInstitutionEditForm')),
        findsOneWidget,
      );
      expect(find.text('Edit basic information'), findsOneWidget);
      _expectExactEditFields();
      expect(
        find.byKey(const Key('platformInstitutionEditStatusChip')),
        findsOneWidget,
      );
      expect(find.text('Inactive'), findsOneWidget);
      expect(find.text('Status *'), findsNothing);
      expect(
        find.byKey(const Key('platformInstitutionCreateStatusField')),
        findsNothing,
      );
      _expectNoLaterScopeText();

      expect(
        _textField('platformInstitutionEditNameField').controller?.text,
        'Editable College',
      );
      expect(
        _textField('platformInstitutionEditEmailField').controller?.text,
        '',
      );
      expect(
        _textField('platformInstitutionEditPhoneField').controller?.text,
        '+998901234567',
      );
      expect(
        _textField('platformInstitutionEditAddressField').controller?.text,
        "Samarqand\nO'zbekiston",
      );
      expect(
        _textField('platformInstitutionEditDescriptionField').controller?.text,
        '',
      );
    });

    testWidgets('load not-found and retryable error are privacy safe', (
      tester,
    ) async {
      await _pumpApp(
        tester,
        detailRepository: FakePlatformInstitutionDetailRepository(
          onFetch: (_) async => throw _serverFailure(
            ApiErrorCodes.resourceNotFound,
            statusCode: 404,
            message: 'Private missing reason.',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('platformInstitutionEditNotFound')),
        findsOneWidget,
      );
      expect(find.text('Institution not found'), findsOneWidget);
      expect(find.textContaining('Private missing reason'), findsNothing);
      expect(find.text('Retry'), findsNothing);

      final retryCompleter = Completer<PlatformInstitutionDetail>();
      final retryRepository = FakePlatformInstitutionDetailRepository();
      retryRepository.onFetch = (institutionId) {
        if (retryRepository.fetchCalls == 1) {
          throw _serverFailure(
            ApiErrorCodes.serverError,
            statusCode: 500,
            message: 'SQLSTATE private stack',
          );
        }

        return retryCompleter.future;
      };

      await _pumpApp(tester, detailRepository: retryRepository);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('platformInstitutionEditError')),
        findsOneWidget,
      );
      expect(find.text('The institution could not be loaded.'), findsOneWidget);
      expect(find.textContaining('SQLSTATE'), findsNothing);

      await tester.tap(
        find.byKey(const Key('platformInstitutionEditRetryButton')),
      );
      await tester.tap(
        find.byKey(const Key('platformInstitutionEditRetryButton')),
      );
      await tester.pump();
      expect(retryRepository.fetchCalls, 2);
      expect(find.text('Retrying'), findsOneWidget);

      retryCompleter.complete(_detail(name: 'Retry School'));
      await tester.pumpAndSettle();

      expect(find.text('Retry School'), findsOneWidget);
      expect(retryRepository.fetchCalls, 2);
    });

    testWidgets('direct route is guarded by role password and device', (
      tester,
    ) async {
      await _pumpApp(tester);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('platformInstitutionEditHeading')),
        findsOneWidget,
      );

      await _pumpApp(
        tester,
        authRepository: _authenticatedRepository(
          _owner('owner-a', mustChangePassword: true),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Password change is required before normal access.'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('platformInstitutionEditHeading')),
        findsNothing,
      );

      await _pumpApp(
        tester,
        authRepository: _authenticatedRepository(
          _user(loginName: 'teacher-a', role: UserRole.teacher),
        ),
      );
      await tester.pumpAndSettle();
      expect(_currentPath(tester), AppRoutePaths.teacher);
      expect(
        find.byKey(const Key('platformInstitutionEditHeading')),
        findsNothing,
      );

      await _pumpApp(tester, surface: AppDeviceSurface.mobile);
      await tester.pumpAndSettle();
      expect(_currentPath(tester), AppRoutePaths.unsupportedDevice);
      expect(
        find.byKey(const Key('platformInstitutionEditHeading')),
        findsNothing,
      );
    });

    testWidgets('no-change save and normalized dirty cancel are safe', (
      tester,
    ) async {
      final editRepository = FakePlatformInstitutionEditRepository();
      await _pumpApp(tester, editRepository: editRepository);
      await tester.pumpAndSettle();

      await _tapSubmit(tester);
      await tester.pump();

      expect(editRepository.updateCalls, 0);
      expect(
        find.byKey(const Key('platformInstitutionEditNoChangesMessage')),
        findsOneWidget,
      );
      expect(find.text('No changes to save.'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('platformInstitutionEditNameField')),
        'Changed School',
      );
      await _tapCancel(tester);
      await tester.pumpAndSettle();
      expect(find.text('Discard institution edits?'), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('platformInstitutionEditStayButton')),
      );
      await tester.pumpAndSettle();
      expect(_currentPath(tester), _editPath(_institutionIdA));

      await tester.enterText(
        find.byKey(const Key('platformInstitutionEditNameField')),
        ' Example School ',
      );
      await _tapCancel(tester);
      await tester.pumpAndSettle();

      expect(find.text('Discard institution edits?'), findsNothing);
      expect(_currentPath(tester), _detailPath(_institutionIdA));
    });

    testWidgets(
      'success blocks duplicate submit sends changed fields and opens refreshed detail',
      (tester) async {
        final updateCompleter = Completer<PlatformInstitutionEditResult>();
        final editRepository = FakePlatformInstitutionEditRepository(
          onUpdate: (_, _) => updateCompleter.future,
        );
        final detailRepository = FakePlatformInstitutionDetailRepository(
          onFetch: (institutionId) async =>
              _detail(id: institutionId, name: detailNameFor(institutionId)),
        );
        final dashboardRepository = FakePlatformDashboardRepository();

        await _pumpApp(
          tester,
          detailRepository: detailRepository,
          editRepository: editRepository,
          dashboardRepository: dashboardRepository,
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('platformInstitutionEditNameField')),
          ' Updated Name ',
        );
        await tester.enterText(
          find.byKey(const Key('platformInstitutionEditEmailField')),
          '   ',
        );
        await tester.enterText(
          find.byKey(const Key('platformInstitutionEditDescriptionField')),
          "  Unicode izoh\nIkkinchi qator  ",
        );

        await _tapSubmit(tester);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.tap(
          find.byKey(const Key('platformInstitutionEditSubmitButton')),
        );
        await tester.pump();

        expect(editRepository.updateCalls, 1);
        expect(editRepository.institutionIds, [_institutionIdA]);
        expect(editRepository.requests.single.toJson(), {
          'name': 'Updated Name',
          'contact_email': null,
          'description': "  Unicode izoh\nIkkinchi qator  ",
        });
        expect(find.text('Saving changes'), findsOneWidget);
        expect(dashboardRepository.fetchCalls, 0);

        updateCompleter.complete(_result(name: 'Updated Name'));
        await tester.pumpAndSettle();

        expect(_currentPath(tester), _detailPath(_institutionIdA));
        expect(find.text('Institution updated successfully.'), findsOneWidget);
        expect(detailRepository.institutionIds, [
          _institutionIdA,
          _institutionIdA,
        ]);
        expect(dashboardRepository.fetchCalls, 0);
      },
    );

    testWidgets(
      'backend validation maps exact fields and clears one stale field',
      (tester) async {
        final editRepository = FakePlatformInstitutionEditRepository(
          onUpdate: (_, _) async => throw _serverValidationFailure(),
        );
        await _pumpApp(tester, editRepository: editRepository);
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('platformInstitutionEditNameField')),
          'Backend rejected',
        );
        await _tapSubmit(tester);
        await tester.pumpAndSettle();

        expect(
          find.text('The name field failed backend validation.'),
          findsOneWidget,
        );
        expect(
          find.text('The type field failed backend validation.'),
          findsOneWidget,
        );
        expect(find.text('The contact email must be valid.'), findsOneWidget);
        expect(find.text('The contact phone is too long.'), findsOneWidget);
        expect(
          find.text('The address field failed backend validation.'),
          findsOneWidget,
        );
        expect(
          find.text('The description field failed backend validation.'),
          findsOneWidget,
        );
        expect(
          find.text('Some submitted institution details need review.'),
          findsOneWidget,
        );
        expect(find.textContaining('{'), findsNothing);
        expect(find.textContaining('settings'), findsNothing);

        await tester.enterText(
          find.byKey(const Key('platformInstitutionEditNameField')),
          'Corrected School',
        );
        await tester.pump();

        expect(
          find.text('The name field failed backend validation.'),
          findsNothing,
        );
        expect(find.text('The contact email must be valid.'), findsOneWidget);
      },
    );

    testWidgets('ambiguous outcome has no resend action and checks detail', (
      tester,
    ) async {
      final editRepository = FakePlatformInstitutionEditRepository(
        onUpdate: (_, _) async =>
            throw const PlatformInstitutionEditOutcomeUnknownException(
              'unknown',
            ),
      );
      await _pumpApp(tester, editRepository: editRepository);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('platformInstitutionEditNameField')),
        'Maybe Changed',
      );
      await _tapSubmit(tester);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('platformInstitutionEditUnknownMessage')),
        findsOneWidget,
      );
      expect(find.textContaining('Update outcome unknown'), findsOneWidget);
      expect(
        find.byKey(const Key('platformInstitutionEditCheckInstitutionButton')),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsNothing);
      expect(editRepository.updateCalls, 1);

      await _tapSubmit(tester);
      await tester.pump();
      expect(editRepository.updateCalls, 1);

      await tester.tap(
        find.byKey(const Key('platformInstitutionEditCheckInstitutionButton')),
      );
      await tester.pumpAndSettle();
      expect(_currentPath(tester), _detailPath(_institutionIdA));
    });

    testWidgets(
      'logout during submit prevents late success navigation or leak',
      (tester) async {
        final updateCompleter = Completer<PlatformInstitutionEditResult>();
        final editRepository = FakePlatformInstitutionEditRepository(
          onUpdate: (_, _) => updateCompleter.future,
        );
        final authRepository = _authenticatedRepository(
          _owner('owner-a', fullName: 'Owner A'),
        );
        await _pumpApp(
          tester,
          authRepository: authRepository,
          editRepository: editRepository,
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('platformInstitutionEditNameField')),
          'Owner A Private School',
        );
        await _tapSubmit(tester);
        await tester.pump();

        await tester.tap(find.byKey(const Key('entryLogoutButton')));
        await tester.pumpAndSettle();
        updateCompleter.complete(_result(name: 'Owner A Private School'));
        await tester.pumpAndSettle();

        expect(find.text('Login'), findsOneWidget);
        expect(find.textContaining('Owner A Private School'), findsNothing);
        expect(find.text('Institution updated successfully.'), findsNothing);

        authRepository.onSignIn = (_, _) async =>
            _owner('owner-b', fullName: 'Owner B');
        await _submitLogin(tester, login: 'owner-b');
        _router(tester).go(_editPath(_institutionIdA));
        await tester.pumpAndSettle();

        expect(find.text('Current user: Owner B'), findsOneWidget);
        expect(find.textContaining('Owner A Private School'), findsNothing);
        expect(
          _textField('platformInstitutionEditNameField').controller?.text,
          'Example School',
        );
      },
    );

    testWidgets('edit form has no overflow at compact and wide desktop sizes', (
      tester,
    ) async {
      for (final size in [const Size(800, 600), const Size(1440, 900)]) {
        await tester.binding.setSurfaceSize(size);
        await _pumpApp(
          tester,
          surfaceSize: null,
          detailRepository: FakePlatformInstitutionDetailRepository(
            onFetch: (_) async => _detail(
              name: '${List.filled(10, 'Long Institution').join(' ')} Name',
              contactEmail: 'very-long-contact-address-for-layout@example.uz',
              contactPhone: '+998901234567',
              address: '${List.filled(18, 'Samarkand').join(' ')} District',
              description:
                  '${List.filled(20, 'Long description text').join(' ')}.',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('platformInstitutionEditHeading')),
          findsOneWidget,
        );
        await tester.enterText(
          find.byKey(const Key('platformInstitutionEditDescriptionField')),
          "O'quv markazi\n${List.filled(8, 'Long note').join(' ')}",
        );
        await tester.ensureVisible(
          find.byKey(const Key('platformInstitutionEditActions')),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
      addTearDown(() => tester.binding.setSurfaceSize(null));
    });
  });
}

Future<void> _pumpApp(
  WidgetTester tester, {
  String? initialLocation,
  FakeAuthRepository? authRepository,
  FakePlatformInstitutionDetailRepository? detailRepository,
  FakePlatformInstitutionEditRepository? editRepository,
  FakePlatformInstitutionListRepository? listRepository,
  FakePlatformDashboardRepository? dashboardRepository,
  AppDeviceSurface surface = AppDeviceSurface.desktop,
  Size? surfaceSize = const Size(1440, 900),
}) async {
  if (surfaceSize != null) {
    await tester.binding.setSurfaceSize(surfaceSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        appInitialLocationProvider.overrideWithValue(
          initialLocation ?? _editPath(_institutionIdA),
        ),
        authRepositoryProvider.overrideWithValue(
          authRepository ?? _authenticatedRepository(_owner('owner-a')),
        ),
        appDeviceSurfaceProvider.overrideWithValue(surface),
        platformDashboardRepositoryProvider.overrideWithValue(
          dashboardRepository ?? FakePlatformDashboardRepository(),
        ),
        platformInstitutionListRepositoryProvider.overrideWithValue(
          listRepository ?? FakePlatformInstitutionListRepository(),
        ),
        platformInstitutionDetailRepositoryProvider.overrideWithValue(
          detailRepository ?? FakePlatformInstitutionDetailRepository(),
        ),
        platformInstitutionEditRepositoryProvider.overrideWithValue(
          editRepository ?? FakePlatformInstitutionEditRepository(),
        ),
      ],
      child: const TestLabUzApp(),
    ),
  );
  await tester.pump();
  await tester.pump();
}

TextField _textField(String keyName) {
  final element = find.byKey(Key(keyName)).evaluate().single;

  return element.widget as TextField;
}

Future<void> _tapSubmit(WidgetTester tester) async {
  final submit = find.byKey(const Key('platformInstitutionEditSubmitButton'));
  await tester.ensureVisible(submit);
  await tester.pump();
  await tester.tap(submit);
}

Future<void> _tapCancel(WidgetTester tester) async {
  final cancel = find.byKey(const Key('platformInstitutionEditCancelButton'));
  await tester.ensureVisible(cancel);
  await tester.pump();
  await tester.tap(cancel);
}

Future<void> _submitLogin(WidgetTester tester, {required String login}) async {
  await tester.enterText(find.byKey(const Key('loginField')), login);
  await tester.enterText(find.byKey(const Key('passwordField')), 'secret');
  await tester.tap(find.byKey(const Key('signInButton')));
  await tester.pumpAndSettle();
}

GoRouter _router(WidgetTester tester) {
  return GoRouter.of(tester.element(find.byType(Scaffold).first));
}

String _currentPath(WidgetTester tester) {
  return _router(tester).routeInformationProvider.value.uri.path;
}

String _detailPath(String institutionId) {
  return AppRoutePaths.platformOwnerInstitutionDetailLocation(institutionId);
}

String _editPath(String institutionId) {
  return AppRoutePaths.platformOwnerInstitutionEditLocation(institutionId);
}

void _expectExactEditFields() {
  expect(find.text('Institution name *'), findsOneWidget);
  expect(find.text('Institution type *'), findsOneWidget);
  expect(find.text('Contact email'), findsOneWidget);
  expect(find.text('Contact phone'), findsOneWidget);
  expect(find.text('Address'), findsOneWidget);
  expect(find.text('Description / notes'), findsOneWidget);
}

void _expectNoLaterScopeText() {
  for (final text in [
    'Create Institution',
    'Edit Institution',
    'Activate',
    'Deactivate',
    'Institution Admins',
    'Settings',
    'Statistics',
    'Support',
    'Issues',
    'Billing',
    'Licensing',
    'Audit',
    'Export',
    'Reports',
    'Groups',
    'Topics',
    'Learning',
    'Scores',
    'Results',
    'Status *',
    'User counts',
    'Timezone',
    'Upload limits',
  ]) {
    expect(find.text(text), findsNothing);
  }
}

String detailNameFor(String institutionId) {
  if (institutionId == _institutionIdA) {
    return 'Example School';
  }

  return 'Other School';
}

PlatformInstitutionDetail _detail({
  String id = _institutionIdA,
  String name = 'Example School',
  PlatformInstitutionType type = PlatformInstitutionType.school,
  PlatformInstitutionStatus status = PlatformInstitutionStatus.active,
  String? contactEmail = 'info@example.uz',
  String? contactPhone = '+998901234567',
  String? address = 'Samarkand',
  String? description = 'Optional notes',
}) {
  return PlatformInstitutionDetail(
    id: id,
    name: name,
    type: type,
    status: status,
    contactEmail: contactEmail,
    contactPhone: contactPhone,
    address: address,
    description: description,
    createdAt: DateTime.utc(2026, 8, 7, 15),
    updatedAt: DateTime.utc(2026, 8, 7, 16),
    userCounts: const PlatformInstitutionUserCounts(total: 42, active: 40),
  );
}

PlatformInstitutionEditResult _result({
  String id = _institutionIdA,
  String name = 'Updated Name',
  PlatformInstitutionType type = PlatformInstitutionType.school,
  PlatformInstitutionStatus status = PlatformInstitutionStatus.active,
}) {
  return PlatformInstitutionEditResult(
    id: id,
    name: name,
    type: type,
    status: status,
    contactEmail: 'updated@example.uz',
    contactPhone: '+998901234567',
    address: 'Updated address',
    description: null,
    createdAt: DateTime.utc(2026, 8, 7, 15),
    updatedAt: DateTime.utc(2026, 8, 10, 12),
    message: 'Institution updated successfully.',
  );
}

PlatformInstitutionListPage _page({String label = 'Example'}) {
  return PlatformInstitutionListPage(
    institutions: [
      PlatformInstitutionSummary(
        id: _institutionIdA,
        name: '$label School',
        type: PlatformInstitutionType.school,
        status: PlatformInstitutionStatus.active,
        contactEmail: 'info@example.uz',
        contactPhone: '+998901234567',
        createdAt: DateTime.utc(2026, 8, 7, 15),
        updatedAt: DateTime.utc(2026, 8, 7, 16),
        userCounts: const PlatformInstitutionUserCounts(total: 42, active: 40),
      ),
    ],
    pagination: const PlatformInstitutionPagination(
      page: 1,
      perPage: 20,
      total: 1,
      lastPage: 1,
    ),
  );
}

PlatformDashboard _dashboard() {
  return PlatformDashboard(
    institutions: const PlatformInstitutionCounts(
      total: 20,
      active: 18,
      inactive: 2,
    ),
    users: const PlatformUserCounts(total: 2800, active: 2720),
    recentInstitutions: const [],
  );
}

AuthUser _owner(
  String loginName, {
  String? fullName,
  bool mustChangePassword = false,
}) {
  return _user(
    loginName: loginName,
    role: UserRole.platformOwner,
    fullName: fullName,
    mustChangePassword: mustChangePassword,
  );
}

AuthUser _user({
  required String loginName,
  required UserRole role,
  String? fullName,
  bool mustChangePassword = false,
}) {
  return AuthUser(
    id: '$loginName-id',
    institutionId: role == UserRole.platformOwner ? null : 'institution-1',
    role: role,
    fullName: fullName ?? '$loginName User',
    loginName: loginName,
    email: null,
    phone: null,
    isActive: true,
    mustChangePassword: mustChangePassword,
    institution: role == UserRole.platformOwner
        ? null
        : const AuthInstitution(
            id: 'institution-1',
            name: 'Example School',
            status: 'active',
            timezone: 'Asia/Tashkent',
          ),
  );
}

ApiRequestException _serverFailure(
  String code, {
  required int statusCode,
  String message = 'Server rejected the institution edit request.',
}) {
  return ApiRequestException(
    ApiFailure.fromServerError(
      statusCode: statusCode,
      error: ApiErrorResponse(
        message: message,
        code: code,
        fieldErrors: const {},
        requestId: 'req-1',
      ),
    ),
  );
}

ApiRequestException _serverValidationFailure() {
  return ApiRequestException(
    ApiFailure.fromServerError(
      statusCode: 422,
      error: ApiErrorResponse(
        message: 'Invalid data.',
        code: ApiErrorCodes.validationFailed,
        fieldErrors: const {
          'name': ['The name field failed backend validation.'],
          'type': ['The type field failed backend validation.'],
          'contact_email': ['The contact email must be valid.'],
          'contact_phone': ['The contact phone is too long.'],
          'address': ['The address field failed backend validation.'],
          'description': ['The description field failed backend validation.'],
          'settings': ['This field is not allowed.'],
        },
        requestId: 'req-1',
      ),
    ),
  );
}

FakeAuthRepository _authenticatedRepository(AuthUser user) {
  return FakeAuthRepository(
    storedToken: 'token-a',
    onCurrentUser: () async => user,
  );
}

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.storedToken, this.onCurrentUser});

  String? storedToken;
  Future<AuthUser> Function()? onCurrentUser;
  Future<AuthUser> Function(String login, String password)? onSignIn;
  var currentUserCalls = 0;

  @override
  Future<AuthUser> currentUser() {
    currentUserCalls += 1;

    return onCurrentUser?.call() ?? Future.value(_owner('owner-a'));
  }

  @override
  Future<AuthUser> signIn({required String login, required String password}) {
    storedToken = 'token-$login';

    return onSignIn?.call(login, password) ?? Future.value(_owner(login));
  }

  @override
  Future<AuthUser> changePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) async {
    return _owner('owner-a');
  }

  @override
  Future<void> signOut() async {
    storedToken = null;
  }

  @override
  Future<String?> readStoredToken() async {
    return storedToken;
  }

  @override
  Future<void> clearToken() async {
    storedToken = null;
  }

  @override
  Future<bool> clearTokenIfVersion(int tokenVersion) async {
    storedToken = null;

    return true;
  }
}

class FakePlatformInstitutionDetailRepository
    implements PlatformInstitutionDetailRepository {
  FakePlatformInstitutionDetailRepository({this.onFetch});

  Future<PlatformInstitutionDetail> Function(String institutionId)? onFetch;
  final institutionIds = <String>[];

  int get fetchCalls => institutionIds.length;

  @override
  Future<PlatformInstitutionDetail> fetchInstitutionDetail(
    String institutionId,
  ) {
    institutionIds.add(institutionId);

    return onFetch?.call(institutionId) ??
        Future.value(_detail(id: institutionId));
  }
}

class FakePlatformInstitutionEditRepository
    implements PlatformInstitutionEditRepository {
  FakePlatformInstitutionEditRepository({this.onUpdate});

  Future<PlatformInstitutionEditResult> Function(
    String institutionId,
    PlatformInstitutionEditRequest request,
  )?
  onUpdate;
  final institutionIds = <String>[];
  final requests = <PlatformInstitutionEditRequest>[];

  int get updateCalls => requests.length;

  @override
  Future<PlatformInstitutionEditResult> updateInstitution(
    String institutionId,
    PlatformInstitutionEditRequest request,
  ) {
    institutionIds.add(institutionId);
    requests.add(request);

    return onUpdate?.call(institutionId, request) ?? Future.value(_result());
  }
}

class FakePlatformInstitutionListRepository
    implements PlatformInstitutionListRepository {
  var fetchCalls = 0;

  @override
  Future<PlatformInstitutionListPage> fetchInstitutions(
    PlatformInstitutionListQuery query,
  ) async {
    fetchCalls += 1;

    return _page();
  }
}

class FakePlatformDashboardRepository implements PlatformDashboardRepository {
  var fetchCalls = 0;

  @override
  Future<PlatformDashboard> fetchDashboard() async {
    fetchCalls += 1;

    return _dashboard();
  }
}

const _institutionIdA = '550e8400-e29b-41d4-a716-446655440000';
