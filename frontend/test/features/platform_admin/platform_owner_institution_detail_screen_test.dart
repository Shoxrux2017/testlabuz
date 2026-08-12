import 'dart:async';

import 'package:flutter/material.dart';
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
import 'package:testlabuz_client/core/network/session_invalidation_signal.dart';
import 'package:testlabuz_client/features/auth/data/auth_repository_impl.dart';
import 'package:testlabuz_client/features/auth/domain/auth_institution.dart';
import 'package:testlabuz_client/features/auth/domain/auth_repository.dart';
import 'package:testlabuz_client/features/auth/domain/auth_user.dart';
import 'package:testlabuz_client/features/auth/domain/user_role.dart';
import 'package:testlabuz_client/features/platform_admin/data/platform_dashboard_repository_impl.dart';
import 'package:testlabuz_client/features/platform_admin/data/platform_institution_detail_repository_impl.dart';
import 'package:testlabuz_client/features/platform_admin/data/platform_institution_list_repository_impl.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_dashboard.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_dashboard_repository.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_detail.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_detail_repository.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_list.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_list_query.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_list_repository.dart';

void main() {
  group('PlatformOwnerInstitutionDetailScreen', () {
    testWidgets(
      'direct URL keeps shell selected and renders exact detail fields only',
      (tester) async {
        final detailCompleter = Completer<PlatformInstitutionDetail>();
        final detailRepository = FakePlatformInstitutionDetailRepository(
          onFetch: (_) => detailCompleter.future,
        );
        final listRepository = FakePlatformInstitutionListRepository(
          label: 'Cached List',
        );

        await _pumpApp(
          tester,
          detailRepository: detailRepository,
          listRepository: listRepository,
        );
        await tester.pump();

        expect(_currentPath(tester), _detailPath(_institutionIdA));
        expect(find.byKey(const Key('platformOwnerShell')), findsOneWidget);
        expect(
          tester
              .widget<NavigationRail>(
                find.byKey(const Key('platformOwnerNavigation')),
              )
              .selectedIndex,
          1,
        );
        expect(
          find.byKey(const Key('platformInstitutionDetailLoading')),
          findsOneWidget,
        );
        expect(find.text('Cached List School'), findsNothing);
        expect(find.text('Detail School'), findsNothing);
        expect(detailRepository.institutionIds, [_institutionIdA]);
        expect(listRepository.fetchCalls, 0);

        detailCompleter.complete(
          _detail(
            name: 'Detail School',
            status: PlatformInstitutionStatus.inactive,
            contactEmail: null,
            contactPhone: null,
            address: null,
            description: null,
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('platformInstitutionDetailData')),
          findsOneWidget,
        );
        expect(find.text('Back to Institutions'), findsOneWidget);
        expect(find.text('Detail School'), findsNWidgets(2));
        expect(find.text('School'), findsNWidgets(2));
        expect(find.text('Inactive'), findsNWidgets(2));
        expect(find.text('Basic information'), findsOneWidget);
        for (final label in [
          'Name',
          'Type',
          'Status',
          'Contact email',
          'Contact phone',
          'Address',
          'Description',
          'Created at',
          'Updated at',
        ]) {
          expect(
            find.descendant(
              of: find.byKey(const Key('platformInstitutionBasicInformation')),
              matching: find.text(label),
            ),
            findsOneWidget,
          );
        }
        expect(find.text('Not provided'), findsNWidgets(4));
        expect(find.text('2026-08-07 15:00 UTC'), findsOneWidget);
        expect(find.text('2026-08-07 16:30 UTC'), findsOneWidget);
        expect(find.text('Basic usage'), findsOneWidget);
        expect(
          find.byKey(
            const Key('platformInstitutionDetailUsageLabelTotal user accounts'),
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(
            const Key(
              'platformInstitutionDetailUsageLabelActive user accounts',
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(
            const Key('platformInstitutionDetailUsageValueTotal user accounts'),
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(
            const Key(
              'platformInstitutionDetailUsageValueActive user accounts',
            ),
          ),
          findsOneWidget,
        );
        expect(find.text('42'), findsOneWidget);
        expect(find.text('40'), findsOneWidget);
        expect(find.text('null'), findsNothing);
        expect(find.textContaining(_institutionIdA), findsNothing);
        expect(find.textContaining('{'), findsNothing);
        expect(find.text('Inactive user accounts'), findsNothing);
        expect(find.text('Online users'), findsNothing);
        expect(find.text('Role counts'), findsNothing);
        _expectNoLaterScopeText();
      },
    );

    testWidgets('Back works after direct URL entry and returns to list route', (
      tester,
    ) async {
      final listRepository = FakePlatformInstitutionListRepository();
      final detailRepository = FakePlatformInstitutionDetailRepository();

      await _pumpApp(
        tester,
        detailRepository: detailRepository,
        listRepository: listRepository,
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('platformInstitutionDetailBackButton')),
      );
      await tester.pumpAndSettle();

      expect(_currentPath(tester), AppRoutePaths.platformOwnerInstitutions);
      expect(
        find.byKey(const Key('platformInstitutionListSurface')),
        findsOneWidget,
      );
      expect(listRepository.fetchCalls, 1);
      expect(detailRepository.fetchCalls, 1);
    });

    testWidgets('resource_not_found shows safe not-found state without Retry', (
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
        find.byKey(const Key('platformInstitutionDetailNotFound')),
        findsOneWidget,
      );
      expect(find.text('Institution not found'), findsOneWidget);
      expect(find.text('Back to Institutions'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
      expect(find.textContaining('Private missing reason'), findsNothing);
      expect(find.text('Example School'), findsNothing);
    });

    testWidgets(
      'retryable error hides internals and Retry is in-flight protected',
      (tester) async {
        final retryCompleter = Completer<PlatformInstitutionDetail>();
        final detailRepository = FakePlatformInstitutionDetailRepository();
        detailRepository.onFetch = (_) {
          if (detailRepository.fetchCalls == 1) {
            throw _serverFailure(
              'server_error',
              statusCode: 500,
              message: 'SQLSTATE token stack trace https://secret.example',
            );
          }

          return retryCompleter.future;
        };

        await _pumpApp(tester, detailRepository: detailRepository);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('platformInstitutionDetailError')),
          findsOneWidget,
        );
        expect(
          find.text('The institution details could not be loaded.'),
          findsOneWidget,
        );
        expect(find.textContaining('SQLSTATE'), findsNothing);
        expect(find.textContaining('secret.example'), findsNothing);
        expect(find.textContaining('stack trace'), findsNothing);
        expect(find.text('Example School'), findsNothing);

        await tester.tap(
          find.byKey(const Key('platformInstitutionDetailRetryButton')),
        );
        await tester.tap(
          find.byKey(const Key('platformInstitutionDetailRetryButton')),
        );
        await tester.pump();

        expect(detailRepository.fetchCalls, 2);
        expect(find.text('Retrying'), findsOneWidget);

        retryCompleter.complete(_detail(name: 'Retry School'));
        await tester.pumpAndSettle();

        expect(find.text('Retry School'), findsNWidgets(2));
        expect(detailRepository.fetchCalls, 2);
      },
    );

    testWidgets('route A to B never shows A under B URL after stale success', (
      tester,
    ) async {
      final completerA = Completer<PlatformInstitutionDetail>();
      final completerB = Completer<PlatformInstitutionDetail>();
      final detailRepository = FakePlatformInstitutionDetailRepository(
        onFetch: (institutionId) {
          if (institutionId == _institutionIdA) {
            return completerA.future;
          }

          return completerB.future;
        },
      );

      await _pumpApp(tester, detailRepository: detailRepository);
      await tester.pump();
      expect(detailRepository.institutionIds, [_institutionIdA]);

      _router(tester).go(_detailPath(_institutionIdB));
      await tester.pump();
      await tester.pump();
      expect(_currentPath(tester), _detailPath(_institutionIdB));
      expect(detailRepository.institutionIds, [
        _institutionIdA,
        _institutionIdB,
      ]);
      expect(find.text('A School'), findsNothing);

      completerA.complete(_detail(id: _institutionIdA, name: 'A School'));
      await tester.pump();
      expect(find.text('A School'), findsNothing);
      expect(
        find.byKey(const Key('platformInstitutionDetailLoading')),
        findsOneWidget,
      );

      completerB.complete(_detail(id: _institutionIdB, name: 'B School'));
      await tester.pumpAndSettle();
      expect(find.text('B School'), findsNWidgets(2));
      expect(find.text('A School'), findsNothing);
    });

    testWidgets(
      'auth password and account-status failures remove protected detail',
      (tester) async {
        final cases = [
          (
            code: ApiErrorCodes.authenticationRequired,
            statusCode: 401,
            expectedText: 'Login',
          ),
          (
            code: ApiErrorCodes.passwordChangeRequired,
            statusCode: 403,
            expectedText: 'Password change is required before normal access.',
          ),
          (
            code: ApiErrorCodes.userInactive,
            statusCode: 403,
            expectedText: 'Login',
          ),
          (
            code: ApiErrorCodes.institutionInactive,
            statusCode: 403,
            expectedText: 'Login',
          ),
        ];

        for (final testCase in cases) {
          var currentUserResponses = 0;
          final authRepository = _authenticatedRepository(_owner('owner-a'));
          authRepository.onCurrentUser = () async {
            currentUserResponses += 1;

            if (currentUserResponses == 1) {
              return _owner('owner-a');
            }

            if (testCase.code == ApiErrorCodes.passwordChangeRequired) {
              return _owner('owner-a', mustChangePassword: true);
            }

            throw _serverFailure(
              testCase.code,
              statusCode: testCase.statusCode,
            );
          };

          await _pumpApp(
            tester,
            authRepository: authRepository,
            detailRepository: FakePlatformInstitutionDetailRepository(
              onFetch: (_) async => throw _serverFailure(
                testCase.code,
                statusCode: testCase.statusCode,
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text(testCase.expectedText), findsOneWidget);
          expect(
            find.byKey(const Key('platformInstitutionDetailData')),
            findsNothing,
          );
          expect(find.text('Example School'), findsNothing);
        }
      },
    );

    testWidgets('global invalidation clears late detail responses', (
      tester,
    ) async {
      final signal = SessionInvalidationSignal();
      addTearDown(signal.dispose);
      final detailCompleter = Completer<PlatformInstitutionDetail>();
      final detailRepository = FakePlatformInstitutionDetailRepository(
        onFetch: (_) => detailCompleter.future,
      );
      final authRepository = _authenticatedRepository(
        _owner('owner-a', fullName: 'Owner A'),
        tokenVersion: 1,
      );

      await _pumpApp(
        tester,
        authRepository: authRepository,
        detailRepository: detailRepository,
        signal: signal,
      );
      await tester.pump();

      signal.authenticationRequired(tokenVersion: 1);
      await tester.pumpAndSettle();
      detailCompleter.complete(_detail(name: 'Old Owner School'));
      await tester.pumpAndSettle();

      expect(find.text('Login'), findsOneWidget);
      expect(find.byKey(const Key('platformOwnerShell')), findsNothing);
      expect(find.text('Old Owner School'), findsNothing);
      expect(authRepository.clearTokenIfVersionCalls, [1]);
    });

    testWidgets(
      'detail layout has no overflow at compact and wide desktop sizes',
      (tester) async {
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
            find.byKey(const Key('platformInstitutionDetailData')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        }
        addTearDown(() => tester.binding.setSurfaceSize(null));
      },
    );
  });
}

Future<void> _pumpApp(
  WidgetTester tester, {
  String? initialLocation,
  FakeAuthRepository? authRepository,
  FakePlatformInstitutionDetailRepository? detailRepository,
  FakePlatformInstitutionListRepository? listRepository,
  FakePlatformDashboardRepository? dashboardRepository,
  AppDeviceSurface surface = AppDeviceSurface.desktop,
  SessionInvalidationSignal? signal,
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
          initialLocation ?? _detailPath(_institutionIdA),
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
        if (signal != null)
          sessionInvalidationSignalProvider.overrideWithValue(signal),
      ],
      child: const TestLabUzApp(),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void _expectNoLaterScopeText() {
  expect(find.text('Create Institution'), findsNothing);
  expect(find.text('Edit Institution'), findsNothing);
  expect(find.text('Activate'), findsNothing);
  expect(find.text('Deactivate'), findsNothing);
  expect(find.text('Institution Admins'), findsNothing);
  expect(find.text('Settings'), findsNothing);
  expect(find.text('Statistics'), findsNothing);
  expect(find.text('Support'), findsNothing);
  expect(find.text('Issues'), findsNothing);
  expect(find.text('Billing'), findsNothing);
  expect(find.text('Licensing'), findsNothing);
  expect(find.text('Audit'), findsNothing);
  expect(find.text('Export'), findsNothing);
  expect(find.text('Reports'), findsNothing);
  expect(find.text('Groups'), findsNothing);
  expect(find.text('Topics'), findsNothing);
  expect(find.text('Learning'), findsNothing);
  expect(find.text('Scores'), findsNothing);
  expect(find.text('Results'), findsNothing);
  expect(find.text('Chart'), findsNothing);
  expect(find.text('Trend'), findsNothing);
  expect(find.text('Percentage'), findsNothing);
}

String _detailPath(String institutionId) {
  return AppRoutePaths.platformOwnerInstitutionDetailLocation(institutionId);
}

GoRouter _router(WidgetTester tester) {
  return GoRouter.of(tester.element(find.byType(Scaffold).first));
}

String _currentPath(WidgetTester tester) {
  return _router(tester).routeInformationProvider.value.uri.path;
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
    updatedAt: DateTime.utc(2026, 8, 7, 16, 30),
    userCounts: const PlatformInstitutionUserCounts(total: 42, active: 40),
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
    recentInstitutions: [
      RecentPlatformInstitution(
        id: _institutionIdA,
        name: 'Example School',
        type: PlatformInstitutionType.school,
        status: PlatformInstitutionStatus.active,
        createdAt: DateTime.utc(2026, 8, 1, 10),
      ),
    ],
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
    fullName: fullName ?? '$loginName User',
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
  String message = 'Server rejected the institution detail request.',
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

FakeAuthRepository _authenticatedRepository(
  AuthUser user, {
  int tokenVersion = 0,
}) {
  return FakeAuthRepository(
    storedToken: 'token-a',
    tokenVersion: tokenVersion,
    onCurrentUser: () async => user,
  );
}

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({
    this.storedToken,
    this.tokenVersion = 0,
    this.onCurrentUser,
  });

  String? storedToken;
  int tokenVersion;
  Future<AuthUser> Function()? onCurrentUser;
  Future<AuthUser> Function(String login, String password)? onSignIn;
  final clearTokenIfVersionCalls = <int>[];
  var currentUserCalls = 0;
  var signOutCalls = 0;
  var clearTokenCalls = 0;

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
    signOutCalls += 1;
    storedToken = null;
  }

  @override
  Future<String?> readStoredToken() async {
    return storedToken;
  }

  @override
  Future<void> clearToken() async {
    clearTokenCalls += 1;
    storedToken = null;
    tokenVersion += 1;
  }

  @override
  Future<bool> clearTokenIfVersion(int tokenVersion) async {
    clearTokenIfVersionCalls.add(tokenVersion);

    if (this.tokenVersion != tokenVersion) {
      return false;
    }

    storedToken = null;
    this.tokenVersion += 1;

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

class FakePlatformInstitutionListRepository
    implements PlatformInstitutionListRepository {
  FakePlatformInstitutionListRepository({this.label = 'Example'});

  final String label;
  var fetchCalls = 0;

  @override
  Future<PlatformInstitutionListPage> fetchInstitutions(
    PlatformInstitutionListQuery query,
  ) async {
    fetchCalls += 1;

    return _page(label: label);
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
const _institutionIdB = '550e8400-e29b-41d4-a716-446655440001';
