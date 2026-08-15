import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/app/router/app_route_paths.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_state.dart';
import 'package:testlabuz_client/features/auth/domain/auth_institution.dart';
import 'package:testlabuz_client/features/auth/domain/auth_user.dart';
import 'package:testlabuz_client/features/auth/domain/user_role.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_user_create_repository_impl.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_user_detail_repository_impl.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_user_list_repository_impl.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user_create.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user_create_repository.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user_detail_repository.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user_list.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user_list_query.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user_list_repository.dart';
import 'package:testlabuz_client/features/institution_admin/presentation/institution_admin_placeholder_screen.dart';
import 'package:testlabuz_client/features/institution_admin/presentation/institution_admin_user_detail_screen.dart';

void main() {
  testWidgets(
    'renders the exact ordered accessible create form with no default role',
    (tester) async {
      await _pump(tester, create: _FakeCreateRepository());

      expect(
        find.byKey(const Key('institutionAdminUserCreateScreen')),
        findsOneWidget,
      );
      expect(find.text('Create User'), findsNWidgets(2));
      for (final label in const [
        'Role',
        'Full name',
        'Login name',
        'Email (optional)',
        'Phone (optional)',
        'Initial password',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(
        find.text('The user must change this password at first login.'),
        findsOneWidget,
      );
      final role = tester.widget<DropdownButtonFormField<InstitutionUserRole>>(
        find.byKey(const Key('institutionUserCreateRoleField')),
      );
      expect(role.initialValue, isNull);
      expect(find.text('Cancel'), findsOneWidget);
      expect(
        find.byKey(const Key('institutionUserCreateSubmitButton')),
        findsOneWidget,
      );
    },
  );

  testWidgets('local validation focuses errors and issues no mutation', (
    tester,
  ) async {
    final create = _FakeCreateRepository();
    await _pump(tester, create: create);

    await tester.tap(
      find.byKey(const Key('institutionUserCreateSubmitButton')),
    );
    await tester.pump();
    await tester.pump();

    expect(create.requests, isEmpty);
    expect(find.text('Review the highlighted fields.'), findsOneWidget);
    expect(find.text('Select a role.'), findsOneWidget);
    expect(find.text('Full name is required.'), findsOneWidget);
    expect(find.text('Login name is required.'), findsOneWidget);
    expect(find.text('Initial password is required.'), findsOneWidget);
  });

  testWidgets(
    'password visibility toggles and confirmed POST opens returned detail',
    (tester) async {
      final create = _FakeCreateRepository();
      final detail = _FakeDetailRepository();
      await _pump(tester, create: create, detail: detail);
      await _fillForm(tester);

      var passwordField = tester.widget<TextField>(
        find.byKey(const Key('institutionUserCreatePasswordField')),
      );
      expect(passwordField.obscureText, isTrue);
      await tester.tap(
        find.byKey(const Key('institutionUserCreatePasswordVisibilityButton')),
      );
      await tester.pump();
      passwordField = tester.widget<TextField>(
        find.byKey(const Key('institutionUserCreatePasswordField')),
      );
      expect(passwordField.obscureText, isFalse);

      await tester.tap(
        find.byKey(const Key('institutionUserCreateSubmitButton')),
      );
      await tester.pumpAndSettle();

      expect(create.requests, hasLength(1));
      expect(
        create.requests.single.toString(),
        isNot(contains('private-password')),
      );
      expect(
        find.byKey(const Key('institutionUserCreateSuccessSnackBar')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('institutionUserDetailHeading')),
        findsOneWidget,
      );
      expect(find.text(_userId), findsOneWidget);
      expect(detail.targets, [_userId]);
    },
  );

  testWidgets(
    'unknown result never reports success and requires Review Users',
    (tester) async {
      final create = _FakeCreateRepository(unknown: true);
      final users = _FakeListRepository(
        page: InstitutionUserListPage(
          users: [_createdUser()],
          pagination: const InstitutionUserListPagination(
            page: 1,
            perPage: 100,
            total: 1,
            lastPage: 1,
          ),
        ),
      );
      await _pump(tester, create: create, users: users);
      await _fillForm(tester);
      await tester.tap(
        find.byKey(const Key('institutionUserCreateSubmitButton')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Creation outcome unknown'), findsOneWidget);
      expect(find.textContaining('cannot confirm'), findsOneWidget);
      expect(find.text('User created successfully.'), findsNothing);
      expect(create.requests, hasLength(1));
      expect(users.queries, hasLength(1));

      await tester.tap(
        find.byKey(const Key('institutionUserCreateReviewUsersButton')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('testUsers')), findsOneWidget);
    },
  );

  testWidgets('inconclusive unknown result exposes only safe review action', (
    tester,
  ) async {
    final create = _FakeCreateRepository(unknown: true);
    await _pump(tester, create: create, users: _FakeListRepository());
    await _fillForm(tester);
    await tester.tap(
      find.byKey(const Key('institutionUserCreateSubmitButton')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Creation outcome unknown'), findsOneWidget);
    expect(
      find.text(
        'The request may have completed. Review Users before trying again.',
      ),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsNothing);
    expect(find.text('Create User'), findsOneWidget);
    expect(
      find.byKey(const Key('institutionUserCreateReviewUsersButton')),
      findsOneWidget,
    );
    expect(create.requests, hasLength(1));
  });

  testWidgets('Cancel exits without a mutation', (tester) async {
    final create = _FakeCreateRepository();
    await _pump(tester, create: create);
    await tester.enterText(
      find.byKey(const Key('institutionUserCreatePasswordField')),
      'private-password',
    );

    await tester.tap(
      find.byKey(const Key('institutionUserCreateCancelButton')),
    );
    await tester.pumpAndSettle();

    expect(create.requests, isEmpty);
    expect(find.byKey(const Key('testUsers')), findsOneWidget);
    expect(find.text('private-password'), findsNothing);
  });

  testWidgets('busy state disables controls and announces progress', (
    tester,
  ) async {
    final completion = Completer<InstitutionUser>();
    final create = _FakeCreateRepository(onCreate: (_) => completion.future);
    final semantics = tester.ensureSemantics();
    await _pump(tester, create: create);
    await _fillForm(tester);

    await tester.tap(
      find.byKey(const Key('institutionUserCreateSubmitButton')),
    );
    await tester.pump();

    expect(find.byKey(const Key('institutionUserCreateBusy')), findsOneWidget);
    expect(
      tester
          .getSemantics(find.byKey(const Key('institutionUserCreateBusy')))
          .flagsCollection
          .isLiveRegion,
      isTrue,
    );
    expect(
      tester
          .widget<TextField>(
            find.byKey(const Key('institutionUserCreateFullNameField')),
          )
          .enabled,
      isFalse,
    );
    expect(
      tester
          .widget<TextButton>(
            find.byKey(const Key('institutionUserCreateCancelButton')),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<IconButton>(
            find.byKey(
              const Key('institutionUserCreatePasswordVisibilityButton'),
            ),
          )
          .onPressed,
      isNull,
    );
    expect(create.requests, hasLength(1));

    completion.complete(_createdUser());
    await tester.pumpAndSettle();
    semantics.dispose();
  });

  testWidgets('obscured password is absent from text and semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, create: _FakeCreateRepository());
    await tester.enterText(
      find.byKey(const Key('institutionUserCreatePasswordField')),
      'private-password',
    );
    await tester.pump();

    expect(
      tester
          .getSemantics(
            find.byKey(const Key('institutionUserCreatePasswordField')),
          )
          .value,
      isNot(contains('private-password')),
    );
    semantics.dispose();
  });

  testWidgets(
    'compact text-scale layout scrolls without overflow or extra controls',
    (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _pump(
        tester,
        create: _FakeCreateRepository(),
        size: const Size(800, 600),
      );
      await tester.enterText(
        find.byKey(const Key('institutionUserCreateFullNameField')),
        List.filled(200, '🧪').join(),
      );
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -600),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('institutionUserCreateSubmitButton')),
        findsOneWidget,
      );
      for (final disallowed in const [
        'Edit',
        'Activate',
        'Deactivate',
        'Reset password',
        'Import',
        'Invite',
        'Settings',
        'Categories',
      ]) {
        expect(find.text(disallowed), findsNothing, reason: disallowed);
      }
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required _FakeCreateRepository create,
  _FakeListRepository? users,
  _FakeDetailRepository? detail,
  Size size = const Size(1000, 900),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final router = GoRouter(
    initialLocation: '/users/new',
    routes: [
      GoRoute(
        path: '/users',
        name: AppRouteNames.institutionAdminUsers,
        builder: (_, _) =>
            const Scaffold(body: Text('Users', key: Key('testUsers'))),
        routes: [
          GoRoute(
            path: 'new',
            name: AppRouteNames.institutionAdminUserCreate,
            builder: (_, _) => const Scaffold(
              body: InstitutionAdminUserCreatePlaceholderScreen(),
            ),
          ),
          GoRoute(
            path: ':${AppRoutePaths.institutionAdminUserIdParameter}',
            name: AppRouteNames.institutionAdminUserDetail,
            builder: (_, state) => Scaffold(
              body: InstitutionAdminUserDetailScreen(
                userId:
                    state.pathParameters[AppRoutePaths
                        .institutionAdminUserIdParameter]!,
              ),
            ),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authSessionControllerProvider.overrideWith(
          () => _FakeAuthSessionController(),
        ),
        appDeviceSurfaceProvider.overrideWithValue(AppDeviceSurface.desktop),
        institutionUserCreateRepositoryProvider.overrideWithValue(create),
        institutionUserListRepositoryProvider.overrideWithValue(
          users ?? _FakeListRepository(),
        ),
        institutionUserDetailRepositoryProvider.overrideWithValue(
          detail ?? _FakeDetailRepository(),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump();
  await tester.pump();
}

Future<void> _fillForm(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('institutionUserCreateRoleField')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Teacher').last);
  await tester.enterText(
    find.byKey(const Key('institutionUserCreateFullNameField')),
    'Teacher Name',
  );
  await tester.enterText(
    find.byKey(const Key('institutionUserCreateLoginNameField')),
    'teacher01',
  );
  await tester.enterText(
    find.byKey(const Key('institutionUserCreatePasswordField')),
    'private-password',
  );
  await tester.pump();
}

const _userId = '00000000-0000-0000-0000-000000000001';

InstitutionUser _createdUser() => InstitutionUser(
  id: _userId,
  role: InstitutionUserRole.teacher,
  fullName: 'Teacher Name',
  loginName: 'teacher01',
  email: null,
  phone: null,
  isActive: true,
  mustChangePassword: true,
  lastLoginAt: null,
  deactivatedAt: null,
  createdAt: DateTime.utc(2026, 8, 15, 8),
  updatedAt: DateTime.utc(2026, 8, 15, 8),
);

class _FakeCreateRepository implements InstitutionUserCreateRepository {
  _FakeCreateRepository({this.unknown = false, this.onCreate});

  final bool unknown;
  final Future<InstitutionUser> Function(InstitutionUserCreateRequest request)?
  onCreate;
  final requests = <InstitutionUserCreateRequest>[];

  @override
  Future<InstitutionUser> createUser(
    InstitutionUserCreateRequest request,
  ) async {
    requests.add(request);
    if (unknown) {
      throw const InstitutionUserCreateOutcomeUnknownException();
    }
    return onCreate?.call(request) ?? _createdUser();
  }
}

class _FakeListRepository implements InstitutionUserListRepository {
  _FakeListRepository({
    this.page = const InstitutionUserListPage(
      users: [],
      pagination: InstitutionUserListPagination(
        page: 1,
        perPage: 100,
        total: 0,
        lastPage: 1,
      ),
    ),
  });

  final InstitutionUserListPage page;
  final queries = <InstitutionUserListQuery>[];

  @override
  Future<InstitutionUserListPage> fetchUsers(
    InstitutionUserListQuery query,
  ) async {
    queries.add(query);
    return page;
  }
}

class _FakeAuthSessionController extends AuthSessionController {
  @override
  AuthSessionState build() => AuthSessionState.authenticated(
    const AuthUser(
      id: 'admin-a',
      institutionId: 'institution-a',
      role: UserRole.institutionAdmin,
      fullName: 'Admin User',
      loginName: 'admin',
      email: null,
      phone: null,
      isActive: true,
      mustChangePassword: false,
      institution: AuthInstitution(
        id: 'institution-a',
        name: 'Institution A',
        status: 'active',
        timezone: 'Asia/Tashkent',
      ),
    ),
  );
}

class _FakeDetailRepository implements InstitutionUserDetailRepository {
  final targets = <String>[];

  @override
  Future<InstitutionUser> fetchUser(String userId) async {
    targets.add(userId);
    return _createdUser();
  }
}
