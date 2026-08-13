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
import 'package:testlabuz_client/features/platform_admin/data/platform_institution_admin_repository_impl.dart';
import 'package:testlabuz_client/features/platform_admin/data/platform_institution_create_repository_impl.dart';
import 'package:testlabuz_client/features/platform_admin/data/platform_institution_detail_repository_impl.dart';
import 'package:testlabuz_client/features/platform_admin/data/platform_institution_list_repository_impl.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_dashboard.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_dashboard_repository.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_admin_create.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_admin_lifecycle.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_admin_list.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_admin_list_query.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_admin_repository.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_admin_update.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_create.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_create_repository.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_detail.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_detail_repository.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_list.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_list_query.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_list_repository.dart';

void main() {
  group('PlatformOwnerInstitutionCreateScreen', () {
    testWidgets('list action opens exact static route inside accepted shell', (
      tester,
    ) async {
      final detailRepository = FakePlatformInstitutionDetailRepository();
      final listRepository = FakePlatformInstitutionListRepository();

      await _pumpApp(
        tester,
        listRepository: listRepository,
        detailRepository: detailRepository,
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('platformInstitutionCreateButton')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const Key('platformInstitutionCreateButton')),
      );
      await tester.pumpAndSettle();

      expect(
        _currentPath(tester),
        AppRoutePaths.platformOwnerInstitutionCreate,
      );
      expect(find.byKey(const Key('platformOwnerShell')), findsOneWidget);
      expect(find.text('Institutions'), findsWidgets);
      expect(
        find.byKey(const Key('platformInstitutionCreateHeading')),
        findsOneWidget,
      );
      _expectExactCreateFields();
      _expectNoProhibitedCreateText();
      expect(detailRepository.fetchCalls, 0);
    });

    testWidgets('direct route is guarded by role password and device', (
      tester,
    ) async {
      await _pumpApp(
        tester,
        initialLocation: AppRoutePaths.platformOwnerInstitutionCreate,
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('platformInstitutionCreateHeading')),
        findsOneWidget,
      );

      await _pumpApp(
        tester,
        initialLocation: AppRoutePaths.platformOwnerInstitutionCreate,
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
        find.byKey(const Key('platformInstitutionCreateHeading')),
        findsNothing,
      );

      await _pumpApp(
        tester,
        initialLocation: AppRoutePaths.platformOwnerInstitutionCreate,
        authRepository: _authenticatedRepository(
          _user(loginName: 'teacher-a', role: UserRole.teacher),
        ),
      );
      await tester.pumpAndSettle();
      expect(_currentPath(tester), AppRoutePaths.teacher);
      expect(
        find.byKey(const Key('platformInstitutionCreateHeading')),
        findsNothing,
      );

      await _pumpApp(
        tester,
        initialLocation: AppRoutePaths.platformOwnerInstitutionCreate,
        surface: AppDeviceSurface.mobile,
      );
      await tester.pumpAndSettle();
      expect(_currentPath(tester), AppRoutePaths.unsupportedDevice);
      expect(
        find.byKey(const Key('platformInstitutionCreateHeading')),
        findsNothing,
      );
    });

    testWidgets('local validation and dirty cancel are accessible and safe', (
      tester,
    ) async {
      final createRepository = FakePlatformInstitutionCreateRepository();
      await _pumpApp(
        tester,
        initialLocation: AppRoutePaths.platformOwnerInstitutionCreate,
        createRepository: createRepository,
      );
      await tester.pumpAndSettle();

      await _tapSubmit(tester);
      await tester.pump();

      expect(createRepository.createCalls, 0);
      expect(find.text('Institution name is required.'), findsOneWidget);
      expect(find.text('Choose an institution type.'), findsOneWidget);
      expect(find.text('Choose an institution status.'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('platformInstitutionCreateEmailField')),
        'not an email',
      );
      await _selectType(tester, 'School');
      await _selectStatus(tester, 'Active');
      await _tapSubmit(tester);
      await tester.pump();
      expect(
        find.text('Contact email must be a valid email address.'),
        findsOneWidget,
      );
      expect(createRepository.createCalls, 0);

      await tester.tap(
        find.byKey(const Key('platformInstitutionCreateCancelButton')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Discard institution draft?'), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('platformInstitutionCreateStayButton')),
      );
      await tester.pumpAndSettle();
      expect(
        _currentPath(tester),
        AppRoutePaths.platformOwnerInstitutionCreate,
      );

      await tester.tap(
        find.byKey(const Key('platformInstitutionCreateCancelButton')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('platformInstitutionCreateDiscardButton')),
      );
      await tester.pumpAndSettle();
      expect(_currentPath(tester), AppRoutePaths.platformOwnerInstitutions);
    });

    testWidgets(
      'success blocks duplicate submit, returns to retained list, and offers detail',
      (tester) async {
        final createCompleter = Completer<PlatformInstitutionCreateResult>();
        final createRepository = FakePlatformInstitutionCreateRepository(
          onCreate: (_) => createCompleter.future,
        );
        final listRepository = FakePlatformInstitutionListRepository(
          onFetch: (query) async => _page(label: query.search ?? 'Visible'),
        );
        final detailRepository = FakePlatformInstitutionDetailRepository(
          onFetch: (institutionId) async =>
              _detail(id: institutionId, name: 'Created Detail School'),
        );
        final dashboardRepository = FakePlatformDashboardRepository();

        await _pumpApp(
          tester,
          listRepository: listRepository,
          detailRepository: detailRepository,
          dashboardRepository: dashboardRepository,
          createRepository: createRepository,
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('platformInstitutionSearchField')),
          'Retained',
        );
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pumpAndSettle();
        expect(listRepository.queries.last.search, 'Retained');

        await tester.tap(
          find.byKey(const Key('platformInstitutionCreateButton')),
        );
        await tester.pumpAndSettle();
        await _fillValidCreateForm(tester);

        await _tapSubmit(tester);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.tap(
          find.byKey(const Key('platformInstitutionCreateSubmitButton')),
        );
        await tester.pump();

        expect(createRepository.createCalls, 1);
        expect(find.text('Creating institution'), findsOneWidget);
        expect(dashboardRepository.fetchCalls, 0);

        createCompleter.complete(_result());
        await tester.pumpAndSettle();

        expect(_currentPath(tester), AppRoutePaths.platformOwnerInstitutions);
        expect(find.text('Institution created successfully.'), findsOneWidget);
        expect(find.text('View institution'), findsOneWidget);
        expect(listRepository.queries.last.search, 'Retained');
        expect(find.text('Retained School'), findsOneWidget);
        expect(dashboardRepository.fetchCalls, 0);

        await tester.tap(find.text('View institution'));
        await tester.pumpAndSettle();

        expect(
          _currentPath(tester),
          AppRoutePaths.platformOwnerInstitutionDetailLocation(_result().id),
        );
        expect(detailRepository.institutionIds, [_result().id]);

        GoRouter.of(
          tester.element(find.byType(Scaffold).first),
        ).go(AppRoutePaths.platformOwner);
        await tester.pumpAndSettle();
        expect(dashboardRepository.fetchCalls, 1);
      },
    );

    testWidgets(
      'backend validation maps exact fields and clears one stale field',
      (tester) async {
        final createRepository = FakePlatformInstitutionCreateRepository(
          onCreate: (_) async => throw _serverValidationFailure(),
        );
        await _pumpApp(
          tester,
          initialLocation: AppRoutePaths.platformOwnerInstitutionCreate,
          createRepository: createRepository,
        );
        await tester.pumpAndSettle();
        await _fillValidCreateForm(tester);

        await _tapSubmit(tester);
        await tester.pumpAndSettle();

        expect(
          find.text('The name field failed backend validation.'),
          findsOneWidget,
        );
        expect(find.text('The contact email must be valid.'), findsOneWidget);
        expect(
          find.text('Some submitted institution details need review.'),
          findsOneWidget,
        );
        expect(find.textContaining('{'), findsNothing);
        expect(find.textContaining('settings'), findsNothing);

        await tester.enterText(
          find.byKey(const Key('platformInstitutionCreateNameField')),
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

    testWidgets(
      'ambiguous outcome has no resend action and returns safely to list',
      (tester) async {
        final createRepository = FakePlatformInstitutionCreateRepository(
          onCreate: (_) async =>
              throw const PlatformInstitutionCreateOutcomeUnknownException(
                'unknown',
              ),
        );
        await _pumpApp(
          tester,
          initialLocation: AppRoutePaths.platformOwnerInstitutionCreate,
          createRepository: createRepository,
        );
        await tester.pumpAndSettle();
        await _fillValidCreateForm(tester);

        await _tapSubmit(tester);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('platformInstitutionCreateUnknownMessage')),
          findsOneWidget,
        );
        expect(
          find.textContaining('Submission outcome unknown'),
          findsOneWidget,
        );
        expect(
          find.textContaining('duplicate Institution names are possible'),
          findsOneWidget,
        );
        expect(
          find.byKey(
            const Key('platformInstitutionCreateCheckInstitutionsButton'),
          ),
          findsOneWidget,
        );
        expect(find.text('Retry'), findsNothing);
        expect(createRepository.createCalls, 1);

        await _tapSubmit(tester);
        await tester.pump();
        expect(createRepository.createCalls, 1);

        await tester.tap(
          find.byKey(
            const Key('platformInstitutionCreateCheckInstitutionsButton'),
          ),
        );
        await tester.pumpAndSettle();
        expect(_currentPath(tester), AppRoutePaths.platformOwnerInstitutions);
      },
    );

    testWidgets(
      'logout during submit prevents late success navigation or leak',
      (tester) async {
        final createCompleter = Completer<PlatformInstitutionCreateResult>();
        final createRepository = FakePlatformInstitutionCreateRepository(
          onCreate: (_) => createCompleter.future,
        );
        final authRepository = _authenticatedRepository(
          _owner('owner-a', fullName: 'Owner A'),
        );
        await _pumpApp(
          tester,
          initialLocation: AppRoutePaths.platformOwnerInstitutionCreate,
          authRepository: authRepository,
          createRepository: createRepository,
        );
        await tester.pumpAndSettle();
        await _fillValidCreateForm(tester, name: 'Owner A Private School');
        await _tapSubmit(tester);
        await tester.pump();

        await tester.tap(find.byKey(const Key('entryLogoutButton')));
        await tester.pumpAndSettle();
        createCompleter.complete(_result(name: 'Owner A Private School'));
        await tester.pumpAndSettle();

        expect(find.text('Login'), findsOneWidget);
        expect(find.textContaining('Owner A Private School'), findsNothing);
        expect(find.text('Institution created successfully.'), findsNothing);

        authRepository.onSignIn = (_, _) async =>
            _owner('owner-b', fullName: 'Owner B');
        await _submitLogin(tester, login: 'owner-b');
        GoRouter.of(
          tester.element(find.byType(Scaffold).first),
        ).go(AppRoutePaths.platformOwnerInstitutionCreate);
        await tester.pumpAndSettle();

        expect(find.text('Current user: Owner B'), findsOneWidget);
        expect(find.textContaining('Owner A Private School'), findsNothing);
        final field = tester.widget<TextField>(
          find.byKey(const Key('platformInstitutionCreateNameField')),
        );
        expect(field.controller?.text, '');
      },
    );

    testWidgets(
      'create form has no overflow at compact and wide desktop sizes',
      (tester) async {
        for (final size in [const Size(800, 600), const Size(1440, 900)]) {
          await tester.binding.setSurfaceSize(size);
          await _pumpApp(
            tester,
            surfaceSize: null,
            initialLocation: AppRoutePaths.platformOwnerInstitutionCreate,
          );
          await tester.pumpAndSettle();

          expect(
            find.byKey(const Key('platformInstitutionCreateHeading')),
            findsOneWidget,
          );
          await tester.enterText(
            find.byKey(const Key('platformInstitutionCreateNameField')),
            '${List.filled(8, 'Long Institution').join(' ')} Name',
          );
          await tester.enterText(
            find.byKey(const Key('platformInstitutionCreateDescriptionField')),
            "O'quv markazi\n${List.filled(8, 'Long note').join(' ')}",
          );
          await tester.ensureVisible(
            find.byKey(const Key('platformInstitutionCreateActions')),
          );
          await tester.pump();
          expect(tester.takeException(), isNull);
        }
        addTearDown(() => tester.binding.setSurfaceSize(null));
      },
    );
  });
}

Future<void> _pumpApp(
  WidgetTester tester, {
  String initialLocation = AppRoutePaths.platformOwnerInstitutions,
  FakeAuthRepository? authRepository,
  FakePlatformInstitutionListRepository? listRepository,
  FakePlatformInstitutionDetailRepository? detailRepository,
  FakePlatformDashboardRepository? dashboardRepository,
  FakePlatformInstitutionCreateRepository? createRepository,
  FakePlatformInstitutionAdminRepository? adminRepository,
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
        appInitialLocationProvider.overrideWithValue(initialLocation),
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
        platformInstitutionCreateRepositoryProvider.overrideWithValue(
          createRepository ?? FakePlatformInstitutionCreateRepository(),
        ),
        platformInstitutionAdminRepositoryProvider.overrideWithValue(
          adminRepository ?? FakePlatformInstitutionAdminRepository(),
        ),
      ],
      child: const TestLabUzApp(),
    ),
  );
  await tester.pump();
  await tester.pump();
}

Future<void> _fillValidCreateForm(
  WidgetTester tester, {
  String name = 'Example School',
}) async {
  await tester.enterText(
    find.byKey(const Key('platformInstitutionCreateNameField')),
    name,
  );
  await _selectType(tester, 'School');
  await tester.enterText(
    find.byKey(const Key('platformInstitutionCreateEmailField')),
    'info@example.uz',
  );
  await tester.enterText(
    find.byKey(const Key('platformInstitutionCreatePhoneField')),
    '+998901234567',
  );
  await tester.enterText(
    find.byKey(const Key('platformInstitutionCreateAddressField')),
    "Samarqand\nO'zbekiston",
  );
  await tester.enterText(
    find.byKey(const Key('platformInstitutionCreateDescriptionField')),
    "O'quv markazi\nOptional notes",
  );
  await _selectStatus(tester, 'Active');
  await tester.pump();
}

Future<void> _selectType(WidgetTester tester, String label) async {
  final field = find.byKey(const Key('platformInstitutionCreateTypeField'));
  await tester.ensureVisible(field);
  await tester.pump();
  await tester.tap(
    find.descendant(of: field, matching: find.text('Choose one')),
    warnIfMissed: false,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> _selectStatus(WidgetTester tester, String label) async {
  final field = find.byKey(const Key('platformInstitutionCreateStatusField'));
  await tester.ensureVisible(field);
  await tester.pump();
  await tester.tap(
    find.descendant(of: field, matching: find.text('Choose one')),
    warnIfMissed: false,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> _tapSubmit(WidgetTester tester) async {
  final submit = find.byKey(const Key('platformInstitutionCreateSubmitButton'));
  await tester.ensureVisible(submit);
  await tester.pump();
  await tester.tap(submit);
}

Future<void> _submitLogin(WidgetTester tester, {required String login}) async {
  await tester.enterText(find.byKey(const Key('loginField')), login);
  await tester.enterText(find.byKey(const Key('passwordField')), 'secret');
  await tester.tap(find.byKey(const Key('signInButton')));
  await tester.pumpAndSettle();
}

String _currentPath(WidgetTester tester) {
  return GoRouter.of(
    tester.element(find.byType(Scaffold).first),
  ).routeInformationProvider.value.uri.path;
}

void _expectExactCreateFields() {
  expect(find.text('Institution name *'), findsOneWidget);
  expect(find.text('Institution type *'), findsOneWidget);
  expect(find.text('Contact email'), findsOneWidget);
  expect(find.text('Contact phone'), findsOneWidget);
  expect(find.text('Address'), findsOneWidget);
  expect(find.text('Description / notes'), findsOneWidget);
  expect(find.text('Status *'), findsOneWidget);
}

void _expectNoProhibitedCreateText() {
  for (final text in [
    'UUID',
    'Creator',
    'Institution Admin',
    'Timezone',
    'Upload limits',
    'Educational policies',
    'User counts',
    'Billing',
    'Plan',
    'License',
    'Edit Institution',
    'Activate',
    'Deactivate',
    'Settings',
  ]) {
    expect(find.text(text), findsNothing);
  }
}

PlatformInstitutionCreateResult _result({
  String id = '550e8400-e29b-41d4-a716-446655440000',
  String name = 'Example School',
}) {
  return PlatformInstitutionCreateResult(
    id: id,
    name: name,
    type: PlatformInstitutionType.school,
    status: PlatformInstitutionStatus.active,
    contactEmail: 'info@example.uz',
    contactPhone: '+998901234567',
    address: 'Samarkand',
    description: 'Optional notes',
    createdAt: DateTime.utc(2026, 8, 7, 15),
    updatedAt: DateTime.utc(2026, 8, 7, 16),
    message: 'Institution created successfully.',
  );
}

PlatformInstitutionListPage _page({
  String label = 'Example',
  int page = 1,
  int perPage = 20,
}) {
  return PlatformInstitutionListPage(
    institutions: [
      PlatformInstitutionSummary(
        id: '00000000-0000-0000-0000-000000000001',
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
    pagination: PlatformInstitutionPagination(
      page: page,
      perPage: perPage,
      total: 1,
      lastPage: 1,
    ),
  );
}

PlatformInstitutionDetail _detail({
  required String id,
  String name = 'Example School',
}) {
  return PlatformInstitutionDetail(
    id: id,
    name: name,
    type: PlatformInstitutionType.school,
    status: PlatformInstitutionStatus.active,
    contactEmail: 'info@example.uz',
    contactPhone: '+998901234567',
    address: 'Samarkand',
    description: 'Optional notes',
    createdAt: DateTime.utc(2026, 8, 7, 15),
    updatedAt: DateTime.utc(2026, 8, 7, 16),
    userCounts: const PlatformInstitutionUserCounts(total: 42, active: 40),
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

ApiRequestException _serverValidationFailure() {
  return ApiRequestException(
    ApiFailure.fromServerError(
      statusCode: 422,
      error: ApiErrorResponse(
        message: 'Invalid data.',
        code: ApiErrorCodes.validationFailed,
        fieldErrors: const {
          'name': ['The name field failed backend validation.'],
          'contact_email': ['The contact email must be valid.'],
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

class FakePlatformInstitutionCreateRepository
    implements PlatformInstitutionCreateRepository {
  FakePlatformInstitutionCreateRepository({this.onCreate});

  Future<PlatformInstitutionCreateResult> Function(
    PlatformInstitutionCreateRequest request,
  )?
  onCreate;
  final requests = <PlatformInstitutionCreateRequest>[];

  int get createCalls => requests.length;

  @override
  Future<PlatformInstitutionCreateResult> createInstitution(
    PlatformInstitutionCreateRequest request,
  ) {
    requests.add(request);

    return onCreate?.call(request) ?? Future.value(_result());
  }
}

class FakePlatformInstitutionListRepository
    implements PlatformInstitutionListRepository {
  FakePlatformInstitutionListRepository({this.onFetch});

  Future<PlatformInstitutionListPage> Function(
    PlatformInstitutionListQuery query,
  )?
  onFetch;
  final queries = <PlatformInstitutionListQuery>[];

  int get fetchCalls => queries.length;

  @override
  Future<PlatformInstitutionListPage> fetchInstitutions(
    PlatformInstitutionListQuery query,
  ) {
    queries.add(query);

    return onFetch?.call(query) ??
        Future.value(_page(page: query.page, perPage: query.perPage));
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

class FakePlatformInstitutionAdminRepository
    implements PlatformInstitutionAdminRepository {
  final fetchCalls =
      <({String institutionId, PlatformInstitutionAdminListQuery query})>[];

  @override
  Future<PlatformInstitutionAdminList> fetchAdmins({
    required String institutionId,
    required PlatformInstitutionAdminListQuery query,
  }) {
    fetchCalls.add((institutionId: institutionId, query: query));

    return Future.value(
      PlatformInstitutionAdminList(
        admins: const [],
        pagination: PlatformInstitutionAdminPagination(
          page: query.page,
          perPage: query.perPage,
          total: 0,
          lastPage: 1,
        ),
      ),
    );
  }

  @override
  Future<PlatformInstitutionAdminCreateResult> createAdmin({
    required String institutionId,
    required PlatformInstitutionAdminCreateRequest request,
  }) {
    throw UnimplementedError('Create screen tests do not create admins.');
  }

  @override
  Future<PlatformInstitutionAdminUpdateResult> updateAdmin({
    required String adminId,
    required PlatformInstitutionAdminUpdateRequest request,
  }) {
    throw UnimplementedError('Create screen tests do not update admins.');
  }

  @override
  Future<PlatformInstitutionAdminLifecycleResult> activateAdmin({
    required String adminId,
  }) {
    throw UnimplementedError('Create screen tests do not activate admins.');
  }

  @override
  Future<PlatformInstitutionAdminLifecycleResult> deactivateAdmin({
    required String adminId,
  }) {
    throw UnimplementedError('Create screen tests do not deactivate admins.');
  }
}

class FakePlatformDashboardRepository implements PlatformDashboardRepository {
  var fetchCalls = 0;

  @override
  Future<PlatformDashboard> fetchDashboard() {
    fetchCalls += 1;

    return Future.value(_dashboard());
  }
}
