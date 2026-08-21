import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/app.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/app/router/app_router.dart';
import 'package:testlabuz_client/core/network/api_error_response.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/features/auth/data/auth_repository_impl.dart';
import 'package:testlabuz_client/features/auth/domain/auth_institution.dart';
import 'package:testlabuz_client/features/auth/domain/auth_repository.dart';
import 'package:testlabuz_client/features/auth/domain/auth_user.dart';
import 'package:testlabuz_client/features/auth/domain/user_role.dart';
import 'package:testlabuz_client/features/institution_admin/application/institution_group_list_controller.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_group_list_repository_impl.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_group.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_group_list.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_group_list_query.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_group_list_repository.dart';

void main() {
  group('InstitutionAdminGroupsScreen', () {
    testWidgets(
      'renders exact toolbar columns rows semantics and no future actions',
      (tester) async {
        final repository = _FakeGroupListRepository(
          onFetch: (query) async => _page(
            rows: [
              _group(
                name: 'Advanced Mathematics',
                level: null,
                subjectDirection: 'Mathematics and logic',
                teachersCount: 2,
                studentsCount: 15,
              ),
              _group(
                id: '00000000-0000-0000-0000-000000000002',
                name: 'Archived Group',
                level: 'Grade 10',
                subjectDirection: null,
                status: InstitutionGroupStatus.archived,
                teachersCount: 1,
                studentsCount: 8,
                archivedAt: DateTime.utc(2026, 8, 9, 10),
              ),
            ],
            total: 22,
            lastPage: 2,
          ),
        );
        await _pumpApp(tester, repository: repository);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('institutionGroupListHeading')),
          findsOneWidget,
        );
        expect(find.widgetWithText(TextField, 'Search groups'), findsOneWidget);
        expect(find.text('All statuses'), findsOneWidget);
        expect(find.text('Clear filters'), findsOneWidget);
        expect(find.text('Refresh'), findsOneWidget);
        final table = find.byKey(const Key('institutionGroupTable'));
        expect(table, findsOneWidget);
        for (final column in const [
          'Name',
          'Level',
          'Subject direction',
          'Status',
          'Teachers',
          'Students',
          'Created',
          'Updated',
        ]) {
          expect(
            find.descendant(of: table, matching: find.text(column)),
            findsOneWidget,
          );
        }
        expect(find.text('Advanced Mathematics'), findsOneWidget);
        expect(find.text('Archived Group'), findsOneWidget);
        expect(find.text('—'), findsNWidgets(2));
        expect(find.text('Active'), findsOneWidget);
        expect(find.text('Archived'), findsWidgets);
        expect(find.text('2'), findsOneWidget);
        expect(find.text('15'), findsOneWidget);
        expect(find.text('2026-08-07 15:00 UTC'), findsNWidgets(2));
        expect(find.text('2026-08-07 16:00 UTC'), findsNWidgets(2));
        expect(find.text('1-2 of 22'), findsOneWidget);
        expect(find.text('Page 1 of 2'), findsOneWidget);
        expect(
          tester
              .widget<DataTable>(table)
              .rows
              .every((row) => row.onSelectChanged != null),
          isTrue,
        );
        final semantics = tester.ensureSemantics();
        expect(find.bySemanticsLabel('Group status: Active'), findsOneWidget);
        expect(
          find.bySemanticsLabel(
            RegExp(r'Name.*sorted ascending.*Activate to change sorting'),
          ),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel('Open group details for Advanced Mathematics'),
          findsOneWidget,
        );
        semantics.dispose();
        for (final excluded in const [
          'Open Group',
          'View Group',
          'Edit',
          'Archive',
          'Manage members',
        ]) {
          expect(find.text(excluded), findsNothing);
        }
        expect(find.text('Create Group'), findsOneWidget);
        expect(
          repository.queries.single,
          const InstitutionGroupListQuery.initial(),
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('URL query and fragment never alter controller-owned query', (
      tester,
    ) async {
      final repository = _FakeGroupListRepository();
      await _pumpApp(
        tester,
        repository: repository,
        initialLocation:
            '${AppRoutePaths.institutionAdminGroups}?search=hidden&page=99#private',
      );
      await tester.pumpAndSettle();

      expect(
        repository.queries.single,
        const InstitutionGroupListQuery.initial(),
      );
      expect(find.byKey(const Key('institutionGroupListData')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'keyboard search filter sort size paging and clear send exact queries',
      (tester) async {
        final repository = _FakeGroupListRepository(
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
          find.byKey(const Key('institutionGroupSearchField')),
          '  Algebra % _  ',
        );
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pumpAndSettle();
        expect(repository.queries.last.search, 'Algebra % _');

        await tester.tap(find.byKey(const Key('institutionGroupStatusFilter')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Archived').last);
        await tester.pumpAndSettle();
        expect(
          repository.queries.last.status,
          InstitutionGroupStatusFilter.archived,
        );

        final dataTable = tester.widget<DataTable>(
          find.byKey(const Key('institutionGroupTable')),
        );
        dataTable.columns[7].onSort!(7, true);
        await tester.pumpAndSettle();
        expect(
          repository.queries.last.sort,
          InstitutionGroupListSort.updatedAt,
        );
        expect(
          repository.queries.last.direction,
          InstitutionGroupSortDirection.asc,
        );

        await tester.tap(find.byKey(const Key('institutionGroupPageSize')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('50').last);
        await tester.pumpAndSettle();
        expect(repository.queries.last.perPage, 50);

        await tester.tap(find.byKey(const Key('institutionGroupNextButton')));
        await tester.pumpAndSettle();
        expect(repository.queries.last.page, 2);

        await tester.tap(
          find.byKey(const Key('institutionGroupClearFiltersButton')),
        );
        await tester.pumpAndSettle();
        expect(repository.queries.last.page, 1);
        expect(repository.queries.last.search, isNull);
        expect(repository.queries.last.status, isNull);
        expect(repository.queries.last.perPage, 50);
        expect(
          repository.queries.last.sort,
          InstitutionGroupListSort.updatedAt,
        );
      },
    );

    testWidgets('overlong search blocks actions while Clear filters recovers', (
      tester,
    ) async {
      final repository = _FakeGroupListRepository();
      await _pumpApp(tester, repository: repository);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('institutionGroupSearchField')),
        List.filled(255, '😀').join(),
      );
      await tester.pump();
      expect(
        find.text('Search must be 254 characters or fewer.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const Key('institutionGroupRefreshButton')),
            )
            .onPressed,
        isNull,
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump(const Duration(milliseconds: 320));
      expect(repository.fetchCalls, 1);

      await tester.tap(
        find.byKey(const Key('institutionGroupClearFiltersButton')),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Search must be 254 characters or fewer.'),
        findsNothing,
      );
      expect(repository.fetchCalls, 1);
    });

    testWidgets('refresh retains rows and exposes semantic progress', (
      tester,
    ) async {
      final refresh = Completer<InstitutionGroupListPage>();
      final repository = _FakeGroupListRepository();
      repository.onFetch = (_) => repository.fetchCalls == 1
          ? Future.value(_page(label: 'Confirmed'))
          : refresh.future;
      await _pumpApp(tester, repository: repository);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('institutionGroupRefreshButton')));
      await tester.pump();
      expect(find.text('Confirmed Group'), findsOneWidget);
      expect(
        find.byKey(const Key('institutionGroupListRefreshing')),
        findsOneWidget,
      );
      final semantics = tester.ensureSemantics();
      expect(find.bySemanticsLabel('Refreshing groups'), findsOneWidget);
      semantics.dispose();

      refresh.complete(_page(label: 'Updated'));
      await tester.pumpAndSettle();
      expect(find.text('Updated Group'), findsOneWidget);
    });

    testWidgets('global filtered empty and safe error Retry are rendered', (
      tester,
    ) async {
      var shouldFail = false;
      final repository = _FakeGroupListRepository(
        onFetch: (query) async {
          if (shouldFail) {
            shouldFail = false;
            throw ApiRequestException(
              ApiFailure.fromServerError(
                statusCode: 403,
                error: ApiErrorResponse(
                  message: 'Raw private backend message.',
                  code: 'forbidden',
                  fieldErrors: {},
                  requestId: 'private-request-id',
                ),
              ),
            );
          }
          return _page(rows: const [], total: 0);
        },
      );
      await _pumpApp(tester, repository: repository);
      await tester.pumpAndSettle();
      expect(find.text('No groups available'), findsOneWidget);
      expect(find.text('Create Group'), findsNWidgets(2));
      expect(
        find.byKey(const Key('institutionGroupGlobalEmptyCreateButton')),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const Key('institutionGroupSearchField')),
        'missing',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.text('No matching groups'), findsOneWidget);
      expect(find.text('Clear filters'), findsWidgets);
      expect(
        find.byKey(const Key('institutionGroupGlobalEmptyCreateButton')),
        findsNothing,
      );

      await tester.tap(
        find.byKey(const Key('institutionGroupClearFiltersButton')),
      );
      await tester.pumpAndSettle();
      shouldFail = true;
      await tester.tap(find.byKey(const Key('institutionGroupRefreshButton')));
      await tester.pumpAndSettle();
      expect(find.text('Unable to load groups'), findsOneWidget);
      expect(
        find.text('You do not have permission to view groups.'),
        findsOneWidget,
      );
      expect(find.textContaining('Raw private'), findsNothing);
      expect(find.textContaining('private-request-id'), findsNothing);
      expect(
        find.byKey(const Key('institutionGroupRetryButton')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('institutionGroupRetryButton')));
      await tester.pumpAndSettle();
      expect(find.text('No groups available'), findsOneWidget);
    });

    testWidgets(
      'text scale 2 and narrow desktop use horizontal overflow safely',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(850, 700));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await _pumpApp(
          tester,
          repository: _FakeGroupListRepository(),
          setDefaultSize: false,
          textScaler: const TextScaler.linear(2),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('institutionGroupHorizontalScroll')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('institutionGroupSearchField')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('institutionGroupRefreshButton')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('institutionGroupPagination')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('recovery query shows its warning once and then consumes it', (
      tester,
    ) async {
      final store = InstitutionGroupListRetainedQueryStore();
      final sessionKey = InstitutionGroupListSessionKey(
        userId: _admin().id,
        userInstance: _admin(),
        institutionId: _admin().institutionId!,
      );
      store.prepareUnknownCreateRecovery(sessionKey);
      final repository = _FakeGroupListRepository();
      await _pumpApp(tester, repository: repository, retainedStore: store);
      await tester.pumpAndSettle();

      expect(repository.queries.single.toQueryParameters(), {
        'page': 1,
        'per_page': 20,
        'sort': 'created_at',
        'direction': 'desc',
        'status': 'active',
      });
      expect(find.text(institutionGroupCreateRecoveryWarning), findsOneWidget);
      expect(store.value!.recoveryWarningPending, isFalse);

      await _pumpApp(
        tester,
        repository: _FakeGroupListRepository(),
        retainedStore: store,
      );
      await tester.pumpAndSettle();
      expect(find.text(institutionGroupCreateRecoveryWarning), findsNothing);
    });
  });
}

Future<void> _pumpApp(
  WidgetTester tester, {
  required _FakeGroupListRepository repository,
  String initialLocation = AppRoutePaths.institutionAdminGroups,
  bool setDefaultSize = true,
  TextScaler textScaler = TextScaler.noScaling,
  InstitutionGroupListRetainedQueryStore? retainedStore,
}) async {
  if (setDefaultSize) {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        appInitialLocationProvider.overrideWithValue(initialLocation),
        appDeviceSurfaceProvider.overrideWithValue(AppDeviceSurface.desktop),
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        institutionGroupListRepositoryProvider.overrideWithValue(repository),
        if (retainedStore != null)
          institutionGroupListRetainedQueryProvider.overrideWithValue(
            retainedStore,
          ),
      ],
      child: MediaQuery(
        data: MediaQueryData(textScaler: textScaler),
        child: const TestLabUzApp(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

InstitutionGroupListPage _page({
  String label = 'Example',
  List<InstitutionGroup>? rows,
  int page = 1,
  int perPage = 20,
  int total = 1,
  int lastPage = 1,
}) {
  return InstitutionGroupListPage(
    groups: rows ?? [_group(name: '$label Group')],
    pagination: InstitutionGroupListPagination(
      page: page,
      perPage: perPage,
      total: total,
      lastPage: lastPage,
    ),
  );
}

InstitutionGroup _group({
  String id = '00000000-0000-0000-0000-000000000001',
  String name = 'Example Group',
  String? level,
  String? subjectDirection,
  InstitutionGroupStatus status = InstitutionGroupStatus.active,
  int teachersCount = 1,
  int studentsCount = 10,
  DateTime? archivedAt,
}) {
  return InstitutionGroup(
    id: id,
    name: name,
    level: level,
    subjectDirection: subjectDirection,
    description: 'Not displayed',
    status: status,
    teachersCount: teachersCount,
    studentsCount: studentsCount,
    archivedAt: archivedAt,
    createdAt: DateTime.utc(2026, 8, 7, 15),
    updatedAt: DateTime.utc(2026, 8, 7, 16),
  );
}

class _FakeGroupListRepository implements InstitutionGroupListRepository {
  _FakeGroupListRepository({this.onFetch});

  Future<InstitutionGroupListPage> Function(InstitutionGroupListQuery query)?
  onFetch;
  final queries = <InstitutionGroupListQuery>[];

  int get fetchCalls => queries.length;

  @override
  Future<InstitutionGroupListPage> fetchGroups(
    InstitutionGroupListQuery query,
  ) {
    queries.add(query);

    return onFetch?.call(query) ??
        Future.value(_page(page: query.page, perPage: query.perPage));
  }
}

class _FakeAuthRepository implements AuthRepository {
  var token = 'token-a';
  var tokenVersion = 0;

  @override
  Future<AuthUser> currentUser() async => _admin();

  @override
  Future<AuthUser> signIn({
    required String login,
    required String password,
  }) async => _admin();

  @override
  Future<AuthUser> changePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) async => _admin();

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
