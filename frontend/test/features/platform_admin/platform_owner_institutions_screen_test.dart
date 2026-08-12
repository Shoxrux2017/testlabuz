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
import 'package:testlabuz_client/features/auth/data/auth_repository_impl.dart';
import 'package:testlabuz_client/features/auth/domain/auth_institution.dart';
import 'package:testlabuz_client/features/auth/domain/auth_repository.dart';
import 'package:testlabuz_client/features/auth/domain/auth_user.dart';
import 'package:testlabuz_client/features/auth/domain/user_role.dart';
import 'package:testlabuz_client/features/platform_admin/data/platform_dashboard_repository_impl.dart';
import 'package:testlabuz_client/features/platform_admin/data/platform_institution_admin_repository_impl.dart';
import 'package:testlabuz_client/features/platform_admin/data/platform_institution_detail_repository_impl.dart';
import 'package:testlabuz_client/features/platform_admin/data/platform_institution_list_repository_impl.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_dashboard.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_dashboard_repository.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_admin_create.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_admin_list.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_admin_list_query.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_admin_repository.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_detail.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_detail_repository.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_list.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_list_query.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_list_repository.dart';

void main() {
  group('PlatformOwnerInstitutionsScreen', () {
    testWidgets('loads inside accepted shell with no fake rows while loading', (
      tester,
    ) async {
      final listCompleter = Completer<PlatformInstitutionListPage>();
      final listRepository = FakePlatformInstitutionListRepository(
        onFetch: (_) => listCompleter.future,
      );

      await _pumpApp(tester, listRepository: listRepository);
      await tester.pump();

      expect(find.byKey(const Key('platformOwnerShell')), findsOneWidget);
      expect(find.text('Current user: owner-a User'), findsOneWidget);
      expect(
        find.byKey(const Key('platformInstitutionListHeading')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('platformInstitutionListLoading')),
        findsOneWidget,
      );
      expect(find.text('Example School'), findsNothing);
      expect(listRepository.fetchCalls, 1);
      expect(
        listRepository.queries.single,
        const PlatformInstitutionListQuery.initial(),
      );
    });

    testWidgets('renders exact table fields controls and no protected scope', (
      tester,
    ) async {
      final longName =
          '${List.filled(12, 'VeryLongInstitutionName').join(' ')} School';
      await _pumpApp(
        tester,
        listRepository: FakePlatformInstitutionListRepository(
          onFetch: (_) async => _page(
            rows: [
              _institution(
                name: longName,
                type: PlatformInstitutionType.privateEducation,
                status: PlatformInstitutionStatus.inactive,
                contactEmail: null,
                contactPhone: null,
                activeUsers: 7,
                totalUsers: 9,
              ),
              _institution(
                id: '00000000-0000-0000-0000-000000000002',
                name: 'Second Learning Center',
                type: PlatformInstitutionType.learningCenter,
                status: PlatformInstitutionStatus.active,
                contactEmail: 'long-contact-address@example.uz',
                contactPhone: '+998901234567',
              ),
            ],
            total: 2,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Institutions'), findsWidgets);
      expect(
        find.byKey(const Key('platformInstitutionSearchField')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('platformInstitutionStatusFilter')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('platformInstitutionTypeFilter')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('platformInstitutionResetButton')),
        findsOneWidget,
      );
      expect(find.text('Create Institution'), findsOneWidget);
      expect(
        find.byKey(const Key('platformInstitutionCreateButton')),
        findsOneWidget,
      );
      for (final header in [
        'Institution',
        'Type',
        'Status',
        'Users',
        'Contact',
        'Created',
        'Updated',
        'Details',
      ]) {
        expect(
          find.descendant(
            of: find.byKey(const Key('platformInstitutionTable')),
            matching: find.text(header),
          ),
          findsOneWidget,
        );
      }

      expect(find.text(longName), findsOneWidget);
      expect(find.text('Private education'), findsOneWidget);
      expect(find.text('Inactive'), findsOneWidget);
      expect(find.text('7 active / 9 total'), findsOneWidget);
      expect(find.text('Not provided'), findsOneWidget);
      expect(find.text('Second Learning Center'), findsOneWidget);
      expect(find.text('Learning center'), findsOneWidget);
      expect(find.text('long-contact-address@example.uz'), findsOneWidget);
      expect(find.text('+998901234567'), findsOneWidget);
      expect(find.text('2026-08-07 15:00 UTC'), findsNWidgets(2));
      expect(find.text('2026-08-07 16:00 UTC'), findsNWidgets(2));
      expect(find.text('View details'), findsNWidgets(2));
      expect(find.text('Page 1 / 1'), findsOneWidget);
      expect(find.text('2 matching Institutions'), findsOneWidget);
      expect(find.text('Sorted by Institution, ascending'), findsOneWidget);

      expect(find.text('null'), findsNothing);
      expect(find.textContaining('00000000-0000-0000-0000'), findsNothing);
      expect(find.text('Creator'), findsNothing);
      expect(find.text('Address'), findsNothing);
      expect(find.text('Description'), findsNothing);
      expect(find.text('Teachers'), findsNothing);
      expect(find.text('Students'), findsNothing);
      _expectNoLaterScopeText();
    });

    testWidgets('row View details transitions to exact nested detail route', (
      tester,
    ) async {
      const institutionId = '550e8400-e29b-41d4-a716-446655440000';
      final listRepository = FakePlatformInstitutionListRepository(
        onFetch: (_) async => _page(
          rows: [_institution(id: institutionId, name: 'Transition School')],
        ),
      );
      final detailRepository = FakePlatformInstitutionDetailRepository(
        onFetch: (requestedId) async =>
            _detail(id: requestedId, name: 'Transition Detail School'),
      );

      await _pumpApp(
        tester,
        listRepository: listRepository,
        detailRepository: detailRepository,
      );
      await tester.pumpAndSettle();

      await tester.drag(
        find.byKey(const Key('platformInstitutionHorizontalScroll')),
        const Offset(-1400, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('platformInstitutionViewDetails0')),
      );
      await tester.pumpAndSettle();

      expect(
        _currentPath(tester),
        AppRoutePaths.platformOwnerInstitutionDetailLocation(institutionId),
      );
      expect(
        find.byKey(const Key('platformInstitutionDetailData')),
        findsOneWidget,
      );
      expect(find.text('Transition Detail School'), findsNWidgets(2));
      expect(detailRepository.institutionIds, [institutionId]);
      expect(listRepository.fetchCalls, 1);
    });

    testWidgets('search Enter filters sort page size pagination and reset', (
      tester,
    ) async {
      final listRepository = FakePlatformInstitutionListRepository(
        onFetch: (query) async {
          return _page(
            label: query.search ?? 'Page ${query.page}',
            page: query.page,
            perPage: query.perPage,
            total: 45,
            lastPage: 3,
          );
        },
      );
      await _pumpApp(tester, listRepository: listRepository);
      await tester.pumpAndSettle();
      expect(listRepository.fetchCalls, 1);

      await tester.enterText(
        find.byKey(const Key('platformInstitutionSearchField')),
        "  Samarqand % _ o'quv  ",
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(listRepository.fetchCalls, 1);
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(listRepository.queries.last.search, "Samarqand % _ o'quv");

      await tester.tap(
        find.byKey(const Key('platformInstitutionStatusFilter')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Inactive').last);
      await tester.pumpAndSettle();
      expect(
        listRepository.queries.last.status,
        PlatformInstitutionStatus.inactive,
      );
      expect(listRepository.queries.last.page, 1);

      await tester.tap(find.byKey(const Key('platformInstitutionTypeFilter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('University').last);
      await tester.pumpAndSettle();
      expect(
        listRepository.queries.last.type,
        PlatformInstitutionType.university,
      );

      await _scrollTableHorizontally(tester);
      await tester.tap(find.text('Created'));
      await tester.pumpAndSettle();
      expect(
        listRepository.queries.last.sort,
        PlatformInstitutionListSort.createdAt,
      );
      expect(listRepository.queries.last.direction, PlatformSortDirection.asc);
      await _scrollTableHorizontally(tester);
      await tester.tap(find.text('Created'));
      await tester.pumpAndSettle();
      expect(listRepository.queries.last.direction, PlatformSortDirection.desc);

      await tester.tap(find.byKey(const Key('platformInstitutionPageSize')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('50').last);
      await tester.pumpAndSettle();
      expect(listRepository.queries.last.perPage, 50);
      expect(listRepository.queries.last.page, 1);

      final beforeNextCalls = listRepository.fetchCalls;
      final pageTwo = Completer<PlatformInstitutionListPage>();
      listRepository.onFetch = (query) {
        if (query.page == 2) {
          return pageTwo.future;
        }

        return Future.value(
          _page(
            label: query.search ?? 'Page ${query.page}',
            page: query.page,
            perPage: query.perPage,
            total: 45,
            lastPage: 3,
          ),
        );
      };
      await tester.tap(find.byKey(const Key('platformInstitutionNextButton')));
      await tester.tap(find.byKey(const Key('platformInstitutionNextButton')));
      await tester.pump();
      expect(listRepository.fetchCalls, beforeNextCalls + 1);
      pageTwo.complete(_page(label: 'Page 2', page: 2, perPage: 50));
      await tester.pumpAndSettle();
      expect(listRepository.queries.last.page, 2);

      await tester.tap(
        find.byKey(const Key('platformInstitutionPreviousButton')),
      );
      await tester.pumpAndSettle();
      expect(listRepository.queries.last.page, 1);

      await tester.tap(find.byKey(const Key('platformInstitutionResetButton')));
      await tester.pumpAndSettle();
      expect(
        listRepository.queries.last,
        const PlatformInstitutionListQuery.initial(),
      );
    });

    testWidgets('overlong search shows feedback and does not request', (
      tester,
    ) async {
      final listRepository = FakePlatformInstitutionListRepository();
      await _pumpApp(tester, listRepository: listRepository);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('platformInstitutionSearchField')),
        '${List.filled(200, 'x').join()}!',
      );
      await tester.pump(
        PlatformInstitutionListQuery.searchDebounceDuration +
            const Duration(milliseconds: 40),
      );

      expect(
        find.text('Search must be 200 characters or fewer.'),
        findsOneWidget,
      );
      expect(listRepository.fetchCalls, 1);
    });

    testWidgets(
      'query-change loading clears old rows until latest response wins',
      (tester) async {
        final second = Completer<PlatformInstitutionListPage>();
        final listRepository = FakePlatformInstitutionListRepository();
        listRepository.onFetch = (query) {
          if (listRepository.fetchCalls == 1) {
            return Future.value(_page(label: 'Old'));
          }

          return second.future;
        };
        await _pumpApp(tester, listRepository: listRepository);
        await tester.pumpAndSettle();
        expect(find.text('Old School'), findsOneWidget);

        await tester.enterText(
          find.byKey(const Key('platformInstitutionSearchField')),
          'New',
        );
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pump();

        expect(
          find.byKey(const Key('platformInstitutionListQueryLoading')),
          findsOneWidget,
        );
        expect(find.text('Old School'), findsNothing);

        second.complete(_page(label: 'New'));
        await tester.pumpAndSettle();
        expect(find.text('New School'), findsOneWidget);
        expect(find.text('Old School'), findsNothing);
      },
    );

    testWidgets('shows global filtered and empty-page states without loops', (
      tester,
    ) async {
      final globalRepository = FakePlatformInstitutionListRepository(
        onFetch: (_) async => _page(rows: const [], total: 0),
      );
      await _pumpApp(tester, listRepository: globalRepository);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('platformInstitutionListGlobalEmpty')),
        findsOneWidget,
      );
      expect(find.text('No platform institutions exist yet.'), findsOneWidget);
      expect(find.text('Create Institution'), findsOneWidget);

      final filteredRepository = FakePlatformInstitutionListRepository(
        onFetch: (query) async => query.search == null
            ? _page(label: 'Initial')
            : _page(rows: const [], total: 0),
      );
      await _pumpApp(tester, listRepository: filteredRepository);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('platformInstitutionSearchField')),
        'Missing',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('platformInstitutionListFilteredEmpty')),
        findsOneWidget,
      );
      expect(
        find.text('No institutions match the current search or filters.'),
        findsOneWidget,
      );
      expect(filteredRepository.fetchCalls, 2);

      final emptyPageRepository = FakePlatformInstitutionListRepository(
        onFetch: (query) async => query.page == 1
            ? _page(total: 5, lastPage: 2)
            : _page(rows: const [], page: 2, total: 5, lastPage: 2),
      );
      await _pumpApp(tester, listRepository: emptyPageRepository);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('platformInstitutionNextButton')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('platformInstitutionListEmptyPage')),
        findsOneWidget,
      );
      expect(find.text('No institutions on this page'), findsOneWidget);
      expect(find.text('Page 2 / 2'), findsOneWidget);
      expect(emptyPageRepository.fetchCalls, 2);
    });

    testWidgets('safe error and duplicate-protected retry', (tester) async {
      final retryCompleter = Completer<PlatformInstitutionListPage>();
      final listRepository = FakePlatformInstitutionListRepository();
      listRepository.onFetch = (_) {
        if (listRepository.fetchCalls == 1) {
          throw _serverFailure(
            'server_error',
            statusCode: 500,
            message: 'SQLSTATE token stack trace https://secret.example',
          );
        }

        return retryCompleter.future;
      };
      await _pumpApp(tester, listRepository: listRepository);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('platformInstitutionListError')),
        findsOneWidget,
      );
      expect(
        find.text('The institutions list could not be loaded.'),
        findsOneWidget,
      );
      expect(find.textContaining('SQLSTATE'), findsNothing);
      expect(find.textContaining('secret.example'), findsNothing);
      expect(find.textContaining('stack trace'), findsNothing);
      expect(find.text('Example School'), findsNothing);

      await tester.tap(find.byKey(const Key('platformInstitutionRetryButton')));
      await tester.tap(find.byKey(const Key('platformInstitutionRetryButton')));
      await tester.pump();
      expect(listRepository.fetchCalls, 2);
      expect(find.text('Retrying'), findsOneWidget);

      retryCompleter.complete(_page(label: 'Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Retry School'), findsOneWidget);
      expect(listRepository.fetchCalls, 2);
    });

    testWidgets(
      'auth password and status failures remove shell or rows safely',
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
            listRepository: FakePlatformInstitutionListRepository(
              onFetch: (_) async => throw _serverFailure(
                testCase.code,
                statusCode: testCase.statusCode,
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text(testCase.expectedText), findsOneWidget);
          expect(
            find.byKey(const Key('platformInstitutionTable')),
            findsNothing,
          );
          expect(find.text('Example School'), findsNothing);
        }
      },
    );

    testWidgets(
      'logout and account switch clear list state between identities',
      (tester) async {
        var currentOwnerLabel = 'Owner A';
        final listRepository = FakePlatformInstitutionListRepository(
          onFetch: (query) async =>
              _page(label: query.search ?? currentOwnerLabel),
        );
        final authRepository = _authenticatedRepository(
          _owner('owner-a', fullName: 'Owner A'),
        );
        await _pumpApp(
          tester,
          authRepository: authRepository,
          listRepository: listRepository,
        );
        await tester.pumpAndSettle();
        expect(find.text('Owner A School'), findsOneWidget);

        await tester.enterText(
          find.byKey(const Key('platformInstitutionSearchField')),
          'Private A',
        );
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pumpAndSettle();
        expect(find.text('Private A School'), findsOneWidget);

        await tester.tap(find.byKey(const Key('entryLogoutButton')));
        await tester.pumpAndSettle();
        expect(find.text('Login'), findsOneWidget);
        expect(find.textContaining('Private A'), findsNothing);
        expect(find.byKey(const Key('platformOwnerShell')), findsNothing);

        authRepository.onSignIn = (_, _) async {
          currentOwnerLabel = 'Owner B';

          return _owner('owner-b', fullName: 'Owner B');
        };
        await _submitLogin(tester, login: 'owner-b');
        expect(find.text('Current user: Owner B'), findsOneWidget);
        expect(find.textContaining('Private A'), findsNothing);

        GoRouter.of(
          tester.element(find.byType(Scaffold).first),
        ).push(AppRoutePaths.platformOwnerInstitutions);
        await tester.pumpAndSettle();

        expect(find.text('Owner B School'), findsOneWidget);
        expect(find.textContaining('Owner A'), findsNothing);
        expect(find.textContaining('Private A'), findsNothing);
      },
    );

    testWidgets(
      'institutions table has no overflow at compact and wide sizes',
      (tester) async {
        for (final size in [const Size(800, 600), const Size(1440, 900)]) {
          await tester.binding.setSurfaceSize(size);
          await _pumpApp(
            tester,
            surfaceSize: null,
            listRepository: FakePlatformInstitutionListRepository(
              onFetch: (_) async => _page(
                rows: [
                  _institution(
                    name:
                        '${List.filled(8, 'Long Institution').join(' ')} Name',
                    contactEmail:
                        'very-long-contact-address-for-layout@example.uz',
                    contactPhone: '+998901234567',
                  ),
                ],
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            find.byKey(const Key('platformInstitutionTable')),
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
  String initialLocation = AppRoutePaths.platformOwnerInstitutions,
  FakeAuthRepository? authRepository,
  required FakePlatformInstitutionListRepository listRepository,
  FakePlatformInstitutionDetailRepository? detailRepository,
  FakePlatformDashboardRepository? dashboardRepository,
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
          listRepository,
        ),
        platformInstitutionDetailRepositoryProvider.overrideWithValue(
          detailRepository ?? FakePlatformInstitutionDetailRepository(),
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

Future<void> _submitLogin(WidgetTester tester, {required String login}) async {
  await tester.enterText(find.byKey(const Key('loginField')), login);
  await tester.enterText(find.byKey(const Key('passwordField')), 'secret');
  await tester.tap(find.byKey(const Key('signInButton')));
  await tester.pumpAndSettle();
}

Future<void> _scrollTableHorizontally(WidgetTester tester) async {
  await tester.drag(
    find.byKey(const Key('platformInstitutionHorizontalScroll')),
    const Offset(-520, 0),
  );
  await tester.pumpAndSettle();
}

GoRouter _router(WidgetTester tester) {
  return GoRouter.of(tester.element(find.byType(Scaffold).first));
}

String _currentPath(WidgetTester tester) {
  return _router(tester).routeInformationProvider.value.uri.path;
}

void _expectNoLaterScopeText() {
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
}

PlatformInstitutionListPage _page({
  String label = 'Example',
  List<PlatformInstitutionSummary>? rows,
  int page = 1,
  int perPage = 20,
  int total = 1,
  int lastPage = 1,
}) {
  return PlatformInstitutionListPage(
    institutions: rows ?? [_institution(name: '$label School')],
    pagination: PlatformInstitutionPagination(
      page: page,
      perPage: perPage,
      total: total,
      lastPage: lastPage,
    ),
  );
}

PlatformInstitutionSummary _institution({
  String id = '00000000-0000-0000-0000-000000000001',
  String name = 'Example School',
  PlatformInstitutionType type = PlatformInstitutionType.school,
  PlatformInstitutionStatus status = PlatformInstitutionStatus.active,
  String? contactEmail = 'info@example.uz',
  String? contactPhone = '+998901234567',
  int activeUsers = 40,
  int totalUsers = 42,
}) {
  return PlatformInstitutionSummary(
    id: id,
    name: name,
    type: type,
    status: status,
    contactEmail: contactEmail,
    contactPhone: contactPhone,
    createdAt: DateTime.utc(2026, 8, 7, 15),
    updatedAt: DateTime.utc(2026, 8, 7, 16),
    userCounts: PlatformInstitutionUserCounts(
      total: totalUsers,
      active: activeUsers,
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
  String message = 'Server rejected the institution list request.',
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
  var signOutCalls = 0;

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
    storedToken = null;
  }

  @override
  Future<bool> clearTokenIfVersion(int tokenVersion) async {
    storedToken = null;

    return true;
  }
}

class FakePlatformDashboardRepository implements PlatformDashboardRepository {
  @override
  Future<PlatformDashboard> fetchDashboard() async {
    return PlatformDashboard(
      institutions: const PlatformInstitutionCounts(
        total: 20,
        active: 18,
        inactive: 2,
      ),
      users: const PlatformUserCounts(total: 2800, active: 2720),
      recentInstitutions: [
        RecentPlatformInstitution(
          id: '00000000-0000-0000-0000-000000000001',
          name: 'Example School',
          type: PlatformInstitutionType.school,
          status: PlatformInstitutionStatus.active,
          createdAt: DateTime.utc(2026, 8, 1, 10),
        ),
      ],
    );
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
        Future.value(
          _page(page: query.page, perPage: query.perPage, lastPage: 3),
        );
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
    throw UnimplementedError('Institution list tests do not create admins.');
  }
}
