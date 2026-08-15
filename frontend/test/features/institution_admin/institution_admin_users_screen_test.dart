import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:testlabuz_client/app/app.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/app/router/app_router.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/features/auth/data/auth_repository_impl.dart';
import 'package:testlabuz_client/features/auth/domain/auth_institution.dart';
import 'package:testlabuz_client/features/auth/domain/auth_repository.dart';
import 'package:testlabuz_client/features/auth/domain/auth_user.dart';
import 'package:testlabuz_client/features/auth/domain/user_role.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_user_list_repository_impl.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_user_detail_repository_impl.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user_list.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user_list_query.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user_list_repository.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user_detail_repository.dart';

void main() {
  group('InstitutionAdminUsersScreen', () {
    testWidgets('renders exact controls, columns, row values, and metadata', (
      tester,
    ) async {
      final repository = _FakeUserListRepository(
        onFetch: (query) async => _page(
          rows: [
            _user(
              fullName: 'Teacher Name',
              loginName: 'teacher01',
              email: 'teacher@example.uz',
              phone: '+998901234567',
              mustChangePassword: true,
            ),
            _user(
              id: _userIdTwo,
              role: InstitutionUserRole.parent,
              fullName: 'Parent Name',
              loginName: 'parent01',
              email: null,
              phone: null,
              isActive: false,
              deactivatedAt: DateTime.utc(2026, 8, 8, 10, 30),
            ),
          ],
          page: query.page,
          perPage: query.perPage,
          total: 22,
          lastPage: 2,
        ),
      );
      await _pumpApp(tester, repository: repository);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('institutionUserListHeading')),
        findsOneWidget,
      );
      expect(find.text('Users'), findsWidgets);
      expect(find.text('Create User'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Search users'), findsOneWidget);
      expect(find.text('All roles'), findsOneWidget);
      expect(find.text('All statuses'), findsOneWidget);
      expect(find.text('Clear filters'), findsOneWidget);
      expect(find.text('Refresh'), findsOneWidget);
      expect(find.byKey(const Key('institutionUserTable')), findsOneWidget);
      for (final column in const [
        'Full name',
        'Login name',
        'Role',
        'Contact',
        'Status',
        'First login',
        'Created',
        'Updated',
      ]) {
        expect(
          find.descendant(
            of: find.byKey(const Key('institutionUserTable')),
            matching: find.text(column),
          ),
          findsOneWidget,
        );
      }
      expect(find.text('Teacher Name'), findsOneWidget);
      expect(find.text('teacher01'), findsOneWidget);
      expect(find.text('Teacher'), findsOneWidget);
      expect(find.text('teacher@example.uz'), findsOneWidget);
      expect(find.text('+998901234567'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Password change required'), findsOneWidget);
      expect(find.text('Parent Name'), findsOneWidget);
      expect(find.text('Parent'), findsOneWidget);
      expect(find.text('Not provided'), findsOneWidget);
      expect(find.text('Inactive'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('2026-08-07 15:00 UTC'), findsNWidgets(2));
      expect(find.text('2026-08-07 16:00 UTC'), findsNWidgets(2));
      expect(find.text('1-2 of 22'), findsOneWidget);
      expect(find.text('Page 1 of 2'), findsOneWidget);
      final semanticsHandle = tester.ensureSemantics();
      final rowAction = find.byKey(const Key('institutionUserFullName0'));
      expect(
        tester
            .getSemantics(rowAction)
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isTrue,
      );
      semanticsHandle.dispose();
      expect(repository.queries.single.toQueryParameters(), {
        'page': 1,
        'per_page': 20,
        'sort': 'full_name',
        'direction': 'asc',
      });
      for (final excluded in const [
        'Edit User',
        'Activate',
        'Deactivate',
        'Bulk actions',
        'Import',
        'Export',
        'institution_id',
        'permissions',
        'Groups',
      ]) {
        expect(find.text(excluded), findsNothing);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('search/filter/sort/paging actions commit exact queries', (
      tester,
    ) async {
      final repository = _FakeUserListRepository(
        onFetch: (query) async => _page(
          page: query.page,
          perPage: query.perPage,
          total: query.perPage * 2,
          lastPage: 2,
        ),
      );
      await _pumpApp(tester, repository: repository);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('institutionUserSearchField')),
        '  Ali % _  ',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(repository.queries.last.search, 'Ali % _');

      await tester.tap(find.byKey(const Key('institutionUserRoleFilter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Student').last);
      await tester.pumpAndSettle();
      expect(repository.queries.last.role, InstitutionUserRole.student);
      expect(repository.queries.last.search, 'Ali % _');

      await tester.tap(find.byKey(const Key('institutionUserStatusFilter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Inactive').last);
      await tester.pumpAndSettle();
      expect(
        repository.queries.last.status,
        InstitutionUserStatusFilter.inactive,
      );

      await tester.tap(find.text('Login name'));
      await tester.pumpAndSettle();
      expect(repository.queries.last.sort, InstitutionUserListSort.loginName);
      expect(
        repository.queries.last.direction,
        InstitutionUserSortDirection.asc,
      );

      await tester.tap(find.byKey(const Key('institutionUserPageSize')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('50').last);
      await tester.pumpAndSettle();
      expect(repository.queries.last.perPage, 50);
      expect(repository.queries.last.page, 1);

      await tester.tap(find.byKey(const Key('institutionUserNextButton')));
      await tester.pumpAndSettle();
      expect(repository.queries.last.page, 2);
      expect(repository.queries.last.search, 'Ali % _');
      expect(repository.queries.last.role, InstitutionUserRole.student);

      await tester.tap(
        find.byKey(const Key('institutionUserClearFiltersButton')),
      );
      await tester.pumpAndSettle();
      expect(repository.queries.last.page, 1);
      expect(repository.queries.last.search, isNull);
      expect(repository.queries.last.role, isNull);
      expect(repository.queries.last.status, isNull);
      expect(repository.queries.last.sort, InstitutionUserListSort.loginName);
      expect(repository.queries.last.perPage, 50);
    });

    testWidgets('overlong search blocks requests until Clear filters', (
      tester,
    ) async {
      final repository = _FakeUserListRepository();
      await _pumpApp(tester, repository: repository);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('institutionUserSearchField')),
        List.filled(255, 'x').join(),
      );
      await tester.pump(const Duration(milliseconds: 320));
      expect(
        find.text('Search must be 254 characters or fewer.'),
        findsOneWidget,
      );
      expect(repository.fetchCalls, 1);
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const Key('institutionUserRefreshButton')),
            )
            .onPressed,
        isNull,
      );

      await tester.tap(
        find.byKey(const Key('institutionUserClearFiltersButton')),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Search must be 254 characters or fewer.'),
        findsNothing,
      );
      expect(repository.fetchCalls, 1);
    });

    testWidgets('global and filtered empty states expose exact safe actions', (
      tester,
    ) async {
      final repository = _FakeUserListRepository(
        onFetch: (query) async => _page(
          rows: const [],
          page: query.page,
          perPage: query.perPage,
          total: 0,
        ),
      );
      await _pumpApp(tester, repository: repository);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('institutionUserListGlobalEmpty')),
        findsOneWidget,
      );
      expect(find.text('No users available'), findsOneWidget);
      expect(find.text('0-0 of 0'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('institutionUserSearchField')),
        'Missing',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('institutionUserListFilteredEmpty')),
        findsOneWidget,
      );
      expect(find.text('No matching users'), findsOneWidget);
      expect(
        find.byKey(const Key('institutionUserFilteredEmptyClearButton')),
        findsOneWidget,
      );
    });

    testWidgets('bounded correction ends in a safe manual empty page', (
      tester,
    ) async {
      final repository = _FakeUserListRepository();
      repository.onFetch = (query) async {
        if (repository.fetchCalls == 1) {
          return _page(page: 1, total: 41, lastPage: 3);
        }

        return _page(rows: const [], page: query.page, total: 41, lastPage: 3);
      };
      await _pumpApp(tester, repository: repository);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('institutionUserNextButton')));
      await tester.pumpAndSettle();

      expect(repository.queries.map((query) => query.page), [1, 2, 1]);
      expect(
        find.byKey(const Key('institutionUserListEmptyPage')),
        findsOneWidget,
      );
      expect(find.text('No users on this page'), findsOneWidget);
      expect(
        find.byKey(const Key('institutionUserFirstPageButton')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('institutionUserEmptyRefreshButton')),
        findsOneWidget,
      );
      expect(find.text('Page 1 of 3'), findsOneWidget);
    });

    testWidgets(
      'refresh keeps rows marked and Retry does not leak raw errors',
      (tester) async {
        final refresh = Completer<InstitutionUserListPage>();
        final repository = _FakeUserListRepository();
        await _pumpApp(tester, repository: repository);
        await tester.pumpAndSettle();
        repository.onFetch = (_) => refresh.future;

        await tester.tap(find.byKey(const Key('institutionUserRefreshButton')));
        await tester.pump();
        expect(
          find.byKey(const Key('institutionUserListRefreshing')),
          findsOneWidget,
        );
        expect(find.text('Example User'), findsOneWidget);
        refresh.completeError(
          ApiRequestException(
            ApiFailure.local(
              kind: ApiFailureKind.connection,
              message: 'SQLSTATE stack trace https://secret.example',
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('institutionUserListError')),
          findsOneWidget,
        );
        expect(
          find.text(
            'Could not reach the server. Check the connection and try again.',
          ),
          findsOneWidget,
        );
        expect(find.textContaining('SQLSTATE'), findsNothing);
        expect(find.textContaining('secret.example'), findsNothing);
        expect(find.text('Example User'), findsNothing);
      },
    );

    testWidgets('Create and row navigation retain query but not rows', (
      tester,
    ) async {
      final repository = _FakeUserListRepository(
        onFetch: (query) async => _page(label: query.search ?? 'Example'),
      );
      await _pumpApp(tester, repository: repository);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('institutionUserSearchField')),
        'Retained',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.text('Retained User'), findsOneWidget);

      await tester.tap(find.byKey(const Key('institutionUserCreateButton')));
      await tester.pumpAndSettle();
      expect(_currentPath(tester), AppRoutePaths.institutionAdminUserCreate);
      expect(
        find.byKey(const Key('institutionAdminUserCreatePlaceholder')),
        findsOneWidget,
      );

      _router(tester).go(AppRoutePaths.institutionAdminUsers);
      await tester.pumpAndSettle();
      expect(repository.queries.last.search, 'Retained');
      expect(repository.fetchCalls, 3);
      expect(find.text('Retained User'), findsOneWidget);

      await tester.tap(find.text('Retained User'));
      await tester.pumpAndSettle();
      expect(
        _currentPath(tester),
        AppRoutePaths.institutionAdminUserDetailLocation(_userIdOne),
      );
      expect(
        find.byKey(const Key('institutionUserDetailHeading')),
        findsOneWidget,
      );
    });

    testWidgets('a focused row activates by keyboard with its server UUID', (
      tester,
    ) async {
      await _pumpApp(tester, repository: _FakeUserListRepository());
      await tester.pumpAndSettle();

      final rowInkWell = find
          .ancestor(
            of: find.text('Example User'),
            matching: find.byType(TableRowInkWell),
          )
          .first;
      expect(rowInkWell, findsOneWidget);
      for (var index = 0; index < 40 && !_tableRowHasPrimaryFocus(); index++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab, platform: 'windows');
        await tester.pump();
      }
      expect(_tableRowHasPrimaryFocus(), isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter, platform: 'windows');
      await tester.pumpAndSettle();
      expect(
        _currentPath(tester),
        AppRoutePaths.institutionAdminUserDetailLocation(_userIdOne),
      );
    });

    testWidgets('compact, wide, and text scale 2 layouts do not overflow', (
      tester,
    ) async {
      for (final testCase in [
        (size: const Size(800, 600), textScale: 1.0),
        (size: const Size(1440, 900), textScale: 1.0),
        (size: const Size(800, 600), textScale: 2.0),
      ]) {
        await tester.binding.setSurfaceSize(testCase.size);
        tester.platformDispatcher.textScaleFactorTestValue = testCase.textScale;
        await _pumpApp(
          tester,
          repository: _FakeUserListRepository(
            onFetch: (query) async => _page(
              rows: [
                _user(
                  fullName: List.filled(10, 'Very Long User Name').join(' '),
                  loginName: List.filled(10, 'long-login').join('-'),
                  email: 'very-long-contact-address@example.uz',
                ),
              ],
            ),
          ),
          setDefaultSize: false,
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('institutionUserTable')), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      addTearDown(() {
        tester.binding.setSurfaceSize(null);
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
    });
  });
}

const _userIdOne = '00000000-0000-0000-0000-000000000001';
const _userIdTwo = '00000000-0000-0000-0000-000000000002';

Future<void> _pumpApp(
  WidgetTester tester, {
  required _FakeUserListRepository repository,
  bool setDefaultSize = true,
}) async {
  if (setDefaultSize) {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        appInitialLocationProvider.overrideWithValue(
          AppRoutePaths.institutionAdminUsers,
        ),
        appDeviceSurfaceProvider.overrideWithValue(AppDeviceSurface.desktop),
        authRepositoryProvider.overrideWithValue(
          _FakeAuthRepository(user: _admin()),
        ),
        institutionUserListRepositoryProvider.overrideWithValue(repository),
        institutionUserDetailRepositoryProvider.overrideWithValue(
          _FakeUserDetailRepository(),
        ),
      ],
      child: const TestLabUzApp(),
    ),
  );
  await tester.pump();
  await tester.pump();
}

GoRouter _router(WidgetTester tester) {
  return GoRouter.of(tester.element(find.byType(Scaffold).first));
}

String _currentPath(WidgetTester tester) {
  return _router(tester).routeInformationProvider.value.uri.path;
}

bool _tableRowHasPrimaryFocus() {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context == null) {
    return false;
  }

  var found = context.widget is TableRowInkWell;
  context.visitAncestorElements((element) {
    if (element.widget is TableRowInkWell) {
      found = true;
    }

    return !found;
  });

  return found;
}

InstitutionUserListPage _page({
  String label = 'Example',
  List<InstitutionUser>? rows,
  int page = 1,
  int perPage = 20,
  int total = 1,
  int lastPage = 1,
}) {
  return InstitutionUserListPage(
    users: rows ?? [_user(fullName: '$label User')],
    pagination: InstitutionUserListPagination(
      page: page,
      perPage: perPage,
      total: total,
      lastPage: lastPage,
    ),
  );
}

InstitutionUser _user({
  String id = _userIdOne,
  InstitutionUserRole role = InstitutionUserRole.teacher,
  String fullName = 'Example User',
  String loginName = 'teacher01',
  String? email,
  String? phone,
  bool isActive = true,
  bool mustChangePassword = false,
  DateTime? deactivatedAt,
}) {
  return InstitutionUser(
    id: id,
    role: role,
    fullName: fullName,
    loginName: loginName,
    email: email,
    phone: phone,
    isActive: isActive,
    mustChangePassword: mustChangePassword,
    lastLoginAt: null,
    deactivatedAt: deactivatedAt,
    createdAt: DateTime.utc(2026, 8, 7, 15),
    updatedAt: DateTime.utc(2026, 8, 7, 16),
  );
}

AuthUser _admin() {
  return const AuthUser(
    id: 'admin-id',
    institutionId: 'institution-1',
    role: UserRole.institutionAdmin,
    fullName: 'Admin User',
    loginName: 'admin',
    email: null,
    phone: null,
    isActive: true,
    mustChangePassword: false,
    institution: AuthInstitution(
      id: 'institution-1',
      name: 'Example School',
      status: 'active',
      timezone: 'Asia/Tashkent',
    ),
  );
}

class _FakeUserListRepository implements InstitutionUserListRepository {
  _FakeUserListRepository({this.onFetch});

  Future<InstitutionUserListPage> Function(InstitutionUserListQuery query)?
  onFetch;
  final queries = <InstitutionUserListQuery>[];

  int get fetchCalls => queries.length;

  @override
  Future<InstitutionUserListPage> fetchUsers(InstitutionUserListQuery query) {
    queries.add(query);

    return onFetch?.call(query) ?? Future.value(_page(page: query.page));
  }
}

class _FakeUserDetailRepository implements InstitutionUserDetailRepository {
  @override
  Future<InstitutionUser> fetchUser(String userId) async {
    return _user(id: userId);
  }
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({required this.user});

  AuthUser user;
  var token = 'token-a';
  var tokenVersion = 0;

  @override
  Future<AuthUser> currentUser() async => user;

  @override
  Future<AuthUser> signIn({
    required String login,
    required String password,
  }) async {
    token = 'token-$login';

    return user;
  }

  @override
  Future<AuthUser> changePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) async => user;

  @override
  Future<void> signOut() async {
    token = '';
  }

  @override
  Future<String?> readStoredToken() async => token.isEmpty ? null : token;

  @override
  Future<void> clearToken() async {
    token = '';
    tokenVersion += 1;
  }

  @override
  Future<bool> clearTokenIfVersion(int tokenVersion) async {
    if (this.tokenVersion != tokenVersion) {
      return false;
    }
    await clearToken();

    return true;
  }
}
