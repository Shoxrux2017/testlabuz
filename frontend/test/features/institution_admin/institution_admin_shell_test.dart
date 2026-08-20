import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:testlabuz_client/app/app.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/app/router/app_router.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/core/network/session_invalidation_signal.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/auth/data/auth_repository_impl.dart';
import 'package:testlabuz_client/features/auth/domain/auth_institution.dart';
import 'package:testlabuz_client/features/auth/domain/auth_repository.dart';
import 'package:testlabuz_client/features/auth/domain/auth_user.dart';
import 'package:testlabuz_client/features/auth/domain/user_role.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_dashboard_repository_impl.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_assessment_settings_repository_impl.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_profile_repository_impl.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_user_create_repository_impl.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_user_list_repository_impl.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_dashboard.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_dashboard_repository.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_assessment_settings.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_assessment_settings_repository.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_profile.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_profile_repository.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_profile_update.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user_list.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user_list_query.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user_list_repository.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_user_detail_repository_impl.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user_create.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user_create_repository.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user_detail_repository.dart';
import 'package:testlabuz_client/features/institution_admin/presentation/institution_admin_shell.dart';
import 'package:testlabuz_client/features/platform_admin/data/platform_dashboard_repository_impl.dart';
import 'package:testlabuz_client/features/platform_admin/data/platform_institution_list_repository_impl.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_dashboard.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_dashboard_repository.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_list.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_list_query.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_list_repository.dart';

void main() {
  group('Institution Admin direct routing and destination mapping', () {
    testWidgets('all six routes use one shell and exact honest content', (
      tester,
    ) async {
      for (final route in _routeExpectations) {
        final authRepository = _authenticatedRepository(_adminUser());
        final dashboardRepository = FakePlatformDashboardRepository();
        final listRepository = FakePlatformInstitutionListRepository();
        final detailRepository = FakeInstitutionUserDetailRepository();

        await _pumpApp(
          tester,
          initialLocation: route.path,
          authRepository: authRepository,
          dashboardRepository: dashboardRepository,
          listRepository: listRepository,
          institutionUserDetailRepository: detailRepository,
        );
        await tester.pumpAndSettle();

        _expectDestination(tester, route);
        if (!AppRoutePaths.isInstitutionAdminUserDetailPath(route.path)) {
          expect(find.text(_userIdOne), findsNothing);
        }
        expect(find.byKey(const Key('entryRoleTitle')), findsNothing);
        expect(find.byKey(const Key('platformOwnerShell')), findsNothing);
        expect(authRepository.currentUserCalls, 1);
        expect(dashboardRepository.fetchCalls, 0);
        expect(listRepository.fetchCalls, 0);
        expect(
          detailRepository.fetchCalls,
          AppRoutePaths.isInstitutionAdminUserDetailPath(route.path) ? 1 : 0,
          reason: route.path,
        );
      }
    });

    testWidgets('two valid UUID details remain Users destinations', (
      tester,
    ) async {
      for (final userId in const [_userIdOne, _userIdTwo]) {
        final path = AppRoutePaths.institutionAdminUserDetailLocation(userId);
        await _pumpApp(
          tester,
          initialLocation: path,
          authRepository: _authenticatedRepository(_adminUser()),
          institutionUserDetailRepository:
              FakeInstitutionUserDetailRepository(),
        );
        await tester.pumpAndSettle();

        expect(_currentPath(tester), path);
        expect(
          _navigationRail(tester).selectedIndex,
          InstitutionAdminShellDestination.values.indexOf(
            InstitutionAdminShellDestination.users,
          ),
        );
        expect(find.text('User Details'), findsOneWidget);
        expect(
          find.byKey(const Key('institutionUserDetailHeading')),
          findsOneWidget,
        );
        expect(find.text(userId), findsOneWidget);
      }
    });

    testWidgets('malformed descendants resolve safely to Dashboard', (
      tester,
    ) async {
      for (final path in _malformedLocations) {
        final detailRepository = FakeInstitutionUserDetailRepository();
        await _pumpApp(
          tester,
          initialLocation: path,
          authRepository: _authenticatedRepository(_adminUser()),
          institutionUserDetailRepository: detailRepository,
        );
        await tester.pumpAndSettle();

        expect(_currentPath(tester), AppRoutePaths.institutionAdmin);
        expect(
          find.byKey(const Key('institutionDashboardData')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('institutionAdminUserDetailPlaceholder')),
          findsNothing,
        );
        expect(detailRepository.fetchCalls, 0, reason: path);
        expect(tester.takeException(), isNull, reason: path);
      }
    });

    testWidgets(
      'only the profile route owns fresh auto-disposed profile state',
      (tester) async {
        final profileRepository = FakeInstitutionProfileRepository();
        await _pumpApp(
          tester,
          initialLocation: AppRoutePaths.institutionAdmin,
          authRepository: _authenticatedRepository(_adminUser()),
          institutionProfileRepository: profileRepository,
        );
        await tester.pumpAndSettle();
        expect(profileRepository.fetchCalls, 0);
        expect(profileRepository.updateCalls, 0);

        _router(tester).go(AppRoutePaths.institutionAdminInstitution);
        await tester.pumpAndSettle();
        expect(profileRepository.fetchCalls, 1);
        expect(find.byKey(const Key('institutionProfileData')), findsOneWidget);

        _router(tester).go(AppRoutePaths.institutionAdminUsers);
        await tester.pumpAndSettle();
        expect(profileRepository.fetchCalls, 1);
        expect(find.byKey(const Key('institutionProfileData')), findsNothing);

        _router(tester).go(AppRoutePaths.institutionAdminInstitution);
        await tester.pumpAndSettle();
        expect(profileRepository.fetchCalls, 2);
        expect(profileRepository.updateCalls, 0);
      },
    );

    testWidgets(
      'verified profile load and PATCH update reconcile shell name without extra auth or profile requests',
      (tester) async {
        final authRepository = _authenticatedRepository(_adminUser());
        final profileRepository = FakeInstitutionProfileRepository(
          onFetch: (_) async => _institutionProfile(name: 'Loaded School'),
          onUpdate: (_, request) async {
            expect(request.toJson(), {'name': 'Renamed Shell School'});
            return InstitutionProfileUpdateResult(
              profile: _institutionProfile(name: 'Renamed Shell School'),
            );
          },
        );
        await _pumpApp(
          tester,
          initialLocation: AppRoutePaths.institutionAdminInstitution,
          authRepository: authRepository,
          institutionProfileRepository: profileRepository,
        );
        await tester.pumpAndSettle();

        expect(find.text('Institution: Loaded School'), findsOneWidget);
        expect(authRepository.currentUserCalls, 1);
        expect(profileRepository.fetchCalls, 1);
        await tester.tap(find.byKey(const Key('institutionProfileEditButton')));
        await tester.pump();
        await tester.enterText(
          find.byKey(const Key('institutionProfileNameField')),
          'Renamed Shell School',
        );
        final save = find.byKey(const Key('institutionProfileSaveButton'));
        await tester.ensureVisible(save);
        await tester.tap(save);
        await tester.pumpAndSettle();

        expect(_currentPath(tester), AppRoutePaths.institutionAdminInstitution);
        expect(find.text('Institution: Renamed Shell School'), findsOneWidget);
        expect(find.text('Institution: Loaded School'), findsNothing);
        expect(find.text('Institution profile updated.'), findsOneWidget);
        expect(authRepository.currentUserCalls, 1);
        expect(profileRepository.fetchCalls, 1);
        expect(profileRepository.updateCalls, 1);
      },
    );
  });

  group('Institution Admin guard and bootstrap matrix', () {
    testWidgets('unauthenticated approved routes resolve to login', (
      tester,
    ) async {
      for (final route in _routeExpectations) {
        await _pumpApp(
          tester,
          initialLocation: route.path,
          authRepository: FakeAuthRepository(),
        );
        await tester.pumpAndSettle();

        expect(_currentPath(tester), AppRoutePaths.login);
        expect(find.text('Login'), findsOneWidget);
        expect(find.byKey(const Key('institutionAdminShell')), findsNothing);
      }
    });

    testWidgets(
      'password change precedes every approved route for every role',
      (tester) async {
        for (final route in _routeExpectations) {
          for (final role in UserRole.values) {
            await _pumpApp(
              tester,
              initialLocation: route.path,
              authRepository: _authenticatedRepository(
                _user(
                  loginName: '${role.value}-first-login',
                  role: role,
                  mustChangePassword: true,
                ),
              ),
            );
            await tester.pumpAndSettle();

            expect(_currentPath(tester), AppRoutePaths.changePassword);
            expect(
              find.byKey(const Key('institutionAdminShell')),
              findsNothing,
            );
          }
        }
      },
    );

    testWidgets('wrong roles and devices use their canonical outcomes', (
      tester,
    ) async {
      final cases = <_GuardCase>[
        _GuardCase(
          user: _user(loginName: 'owner', role: UserRole.platformOwner),
          surface: AppDeviceSurface.desktop,
          expectedPath: AppRoutePaths.platformOwner,
        ),
        _GuardCase(
          user: _user(loginName: 'teacher', role: UserRole.teacher),
          surface: AppDeviceSurface.desktop,
          expectedPath: AppRoutePaths.teacher,
        ),
        _GuardCase(
          user: _user(loginName: 'teacher', role: UserRole.teacher),
          surface: AppDeviceSurface.mobile,
          expectedPath: AppRoutePaths.teacher,
        ),
        _GuardCase(
          user: _user(loginName: 'student', role: UserRole.student),
          surface: AppDeviceSurface.desktop,
          expectedPath: AppRoutePaths.student,
        ),
        _GuardCase(
          user: _user(loginName: 'student', role: UserRole.student),
          surface: AppDeviceSurface.mobile,
          expectedPath: AppRoutePaths.student,
        ),
        _GuardCase(
          user: _user(loginName: 'parent', role: UserRole.parent),
          surface: AppDeviceSurface.mobile,
          expectedPath: AppRoutePaths.parent,
        ),
        _GuardCase(
          user: _user(loginName: 'parent', role: UserRole.parent),
          surface: AppDeviceSurface.desktop,
          expectedPath: AppRoutePaths.unsupportedDevice,
        ),
        _GuardCase(
          user: _adminUser(),
          surface: AppDeviceSurface.mobile,
          expectedPath: AppRoutePaths.unsupportedDevice,
        ),
        _GuardCase(
          user: _adminUser(),
          surface: AppDeviceSurface.unsupported,
          expectedPath: AppRoutePaths.unsupportedDevice,
        ),
      ];

      for (final route in _routeExpectations) {
        for (final testCase in cases) {
          await _pumpApp(
            tester,
            initialLocation: route.path,
            authRepository: _authenticatedRepository(testCase.user),
            surface: testCase.surface,
          );
          await tester.pumpAndSettle();

          expect(_currentPath(tester), testCase.expectedPath);
          expect(find.byKey(const Key('institutionAdminShell')), findsNothing);
        }
      }
    });

    testWidgets(
      'bootstrap preserves each exact location without identity flash',
      (tester) async {
        for (final route in _routeExpectations) {
          final currentUser = Completer<AuthUser>();
          final repository = FakeAuthRepository(
            storedToken: 'token-a',
            onCurrentUser: () => currentUser.future,
          );

          await _pumpApp(
            tester,
            initialLocation: route.path,
            authRepository: repository,
          );
          await tester.pump();

          expect(_currentPath(tester), route.path);
          expect(find.byType(CircularProgressIndicator), findsOneWidget);
          expect(find.textContaining('Admin User'), findsNothing);
          expect(find.textContaining('Example School'), findsNothing);
          expect(
            find.byKey(const Key('institutionAdminNavigation')),
            findsNothing,
          );

          currentUser.complete(_adminUser());
          await tester.pumpAndSettle();
          _expectDestination(tester, route);
        }
      },
    );

    testWidgets(
      'bootstrap does not preserve malformed Institution Admin paths',
      (tester) async {
        final currentUser = Completer<AuthUser>();
        final repository = FakeAuthRepository(
          storedToken: 'token-a',
          onCurrentUser: () => currentUser.future,
        );

        await _pumpApp(
          tester,
          initialLocation: '/institution-admin/users/not-a-uuid',
          authRepository: repository,
        );
        await tester.pump();

        expect(_currentPath(tester), AppRoutePaths.root);
        expect(find.byKey(const Key('institutionAdminShell')), findsNothing);

        currentUser.complete(_adminUser());
        await tester.pumpAndSettle();
        expect(_currentPath(tester), AppRoutePaths.institutionAdmin);
        expect(
          find.byKey(const Key('institutionDashboardData')),
          findsOneWidget,
        );
      },
    );
  });

  group('Institution Admin shell content and navigation', () {
    testWidgets('shows only approved live identity and four destinations', (
      tester,
    ) async {
      await _pumpApp(
        tester,
        initialLocation: AppRoutePaths.institutionAdminUsers,
        authRepository: _authenticatedRepository(
          _adminUser(
            loginName: 'private-login',
            email: 'private@example.uz',
            phone: '+998900000000',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final navigation = find.byKey(const Key('institutionAdminNavigation'));
      expect(find.text('TestLabUz'), findsOneWidget);
      expect(find.text('Institution Admin'), findsOneWidget);
      expect(find.text('Current user: Admin User'), findsOneWidget);
      expect(find.text('Institution: Example School'), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);
      for (final destination in InstitutionAdminShellDestination.values) {
        expect(
          find.descendant(
            of: navigation,
            matching: find.text(destination.label),
          ),
          findsOneWidget,
        );
        expect(find.byTooltip(destination.label), findsOneWidget);
      }
      expect(_navigationRail(tester).destinations, hasLength(4));
      expect(find.text('private-login'), findsNothing);
      expect(find.text('private@example.uz'), findsNothing);
      expect(find.text('+998900000000'), findsNothing);
      expect(find.text('institution-1'), findsNothing);
      expect(find.text('Asia/Tashkent'), findsNothing);
      _expectNoFutureScope();
    });

    testWidgets('navigation selection reselect and back are URI-driven', (
      tester,
    ) async {
      await _pumpApp(
        tester,
        initialLocation: AppRoutePaths.institutionAdmin,
        authRepository: _authenticatedRepository(_adminUser()),
      );
      await tester.pumpAndSettle();

      expect(_router(tester).canPop(), isFalse);
      await _tapDestination(tester, 'Dashboard');
      await tester.pumpAndSettle();
      expect(_router(tester).canPop(), isFalse);

      await _tapDestination(tester, 'Users');
      await tester.pumpAndSettle();
      expect(_currentPath(tester), AppRoutePaths.institutionAdminUsers);
      expect(find.text('Users'), findsWidgets);

      final couldPopBeforeReselect = _router(tester).canPop();
      await _tapDestination(tester, 'Users');
      await tester.pumpAndSettle();
      expect(_currentPath(tester), AppRoutePaths.institutionAdminUsers);
      expect(_router(tester).canPop(), couldPopBeforeReselect);

      await _tapDestination(tester, 'Settings');
      await tester.pumpAndSettle();
      expect(_currentPath(tester), AppRoutePaths.institutionAdminSettings);
      expect(find.text('Settings'), findsWidgets);

      _router(tester).pop();
      await tester.pumpAndSettle();
      expect(_currentPath(tester), AppRoutePaths.institutionAdminUsers);
      expect(
        _navigationRail(tester).selectedIndex,
        InstitutionAdminShellDestination.values.indexOf(
          InstitutionAdminShellDestination.users,
        ),
      );
    });

    testWidgets(
      'busy User Create disables mouse and keyboard rail navigation until its single detail transition',
      (tester) async {
        final createCompletion = Completer<InstitutionUser>();
        final createRepository = FakeInstitutionUserCreateRepository(
          onCreate: (_) => createCompletion.future,
        );
        final detailRepository = FakeInstitutionUserDetailRepository();
        final dashboardRepository = FakeInstitutionDashboardRepository();

        await _pumpApp(
          tester,
          initialLocation: AppRoutePaths.institutionAdminUserCreate,
          authRepository: _authenticatedRepository(_adminUser()),
          institutionDashboardRepository: dashboardRepository,
          institutionUserCreateRepository: createRepository,
          institutionUserDetailRepository: detailRepository,
        );
        await tester.pumpAndSettle();
        await _fillInstitutionUserCreateForm(tester);

        final submit = tester.widget<FilledButton>(
          find.byKey(const Key('institutionUserCreateSubmitButton')),
        );
        submit.onPressed!();
        await tester.pump();

        final router = _router(tester);
        final visitedPaths = <String>[];
        void recordPath() {
          visitedPaths.add(router.routeInformationProvider.value.uri.path);
        }

        router.routeInformationProvider.addListener(recordPath);
        addTearDown(
          () => router.routeInformationProvider.removeListener(recordPath),
        );
        expect(createRepository.requests, hasLength(1));
        expect(_navigationRail(tester).onDestinationSelected, isNull);

        await _tapDestination(tester, 'Dashboard');
        await tester.pump();
        await tester.sendKeyEvent(
          LogicalKeyboardKey.enter,
          platform: 'windows',
        );
        await tester.sendKeyEvent(
          LogicalKeyboardKey.space,
          platform: 'windows',
        );
        await tester.pump();

        expect(_currentPath(tester), AppRoutePaths.institutionAdminUserCreate);
        expect(visitedPaths, isEmpty);
        expect(dashboardRepository.fetchCalls, 0);

        createCompletion.complete(_createdInstitutionUser(_userIdOne));
        await tester.pumpAndSettle();

        final detailPath = AppRoutePaths.institutionAdminUserDetailLocation(
          _userIdOne,
        );
        expect(_currentPath(tester), detailPath);
        expect(visitedPaths, [detailPath]);
        expect(detailRepository.fetchCalls, 1);
        expect(createRepository.requests, hasLength(1));
        expect(dashboardRepository.fetchCalls, 0);

        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(_currentPath(tester), detailPath);
        expect(visitedPaths, [detailPath]);
        expect(detailRepository.fetchCalls, 1);
        expect(dashboardRepository.fetchCalls, 0);
      },
    );

    testWidgets('invalid live Institution context fails closed', (
      tester,
    ) async {
      final invalidUsers = <AuthUser>[
        _adminUser(isActive: false),
        _adminUser(institutionId: ''),
        _adminUser(institution: null, includeInstitution: false),
        _adminUser(
          institution: const AuthInstitution(
            id: 'institution-2',
            name: 'Other School',
            status: 'active',
            timezone: 'Asia/Tashkent',
          ),
        ),
        _adminUser(
          institution: const AuthInstitution(
            id: 'institution-1',
            name: 'Inactive School',
            status: 'inactive',
            timezone: 'Asia/Tashkent',
          ),
        ),
      ];

      for (final user in invalidUsers) {
        await _pumpApp(
          tester,
          initialLocation: AppRoutePaths.institutionAdmin,
          authRepository: _authenticatedRepository(user),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('institutionAdminUnavailable')),
          findsOneWidget,
        );
        expect(find.text('Session route unavailable'), findsOneWidget);
        expect(find.byKey(const Key('entryLogoutButton')), findsOneWidget);
        expect(
          find.byKey(const Key('institutionAdminNavigation')),
          findsNothing,
        );
        expect(find.textContaining(user.fullName), findsNothing);
        expect(find.byKey(const Key('institutionDashboardData')), findsNothing);
      }
    });
  });

  group('Institution Admin responsive and accessibility behavior', () {
    testWidgets(
      'compact wide text-scale and long identity layouts do not overflow',
      (tester) async {
        addTearDown(() {
          tester.binding.setSurfaceSize(null);
          tester.binding.platformDispatcher.clearTextScaleFactorTestValue();
        });
        final longName = List.filled(10, 'LongName').join();
        final longInstitution = List.filled(10, 'Institution').join();

        for (final size in const [Size(800, 600), Size(1440, 900)]) {
          for (final textScale in const [1.0, 2.0]) {
            await tester.binding.setSurfaceSize(size);
            tester.binding.platformDispatcher.textScaleFactorTestValue =
                textScale;
            await _pumpApp(
              tester,
              initialLocation: AppRoutePaths.institutionAdminSettings,
              authRepository: _authenticatedRepository(
                _adminUser(
                  fullName: longName,
                  institution: AuthInstitution(
                    id: 'institution-1',
                    name: longInstitution,
                    status: 'active',
                    timezone: 'Asia/Tashkent',
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();

            expect(
              find.byKey(const Key('institutionAdminShell')),
              findsOneWidget,
            );
            expect(find.byKey(const Key('entryLogoutButton')), findsOneWidget);
            expect(_navigationRail(tester).extended, size.width >= 1100);
            for (final destination in InstitutionAdminShellDestination.values) {
              expect(find.byTooltip(destination.label), findsOneWidget);
            }
            expect(tester.takeException(), isNull);
          }
        }
      },
    );

    testWidgets('Tab and Shift+Tab follow the logical shell focus order', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
        tester.binding.setSurfaceSize(null);
      });
      final repository = _authenticatedRepository(_adminUser());

      await _pumpApp(
        tester,
        initialLocation: AppRoutePaths.institutionAdmin,
        authRepository: repository,
      );
      await tester.pumpAndSettle();

      for (final destination in InstitutionAdminShellDestination.values) {
        await _sendTab(tester);
        _expectDestinationFocused(tester, destination);
        _expectDashboardSessionUnchanged(tester, repository);
      }

      await _sendTab(tester);
      _expectSignOutFocused(tester);
      _expectDashboardSessionUnchanged(tester, repository);

      for (final destination
          in InstitutionAdminShellDestination.values.reversed) {
        await _sendShiftTab(tester);
        _expectDestinationFocused(tester, destination);
        _expectDashboardSessionUnchanged(tester, repository);
      }

      debugDefaultTargetPlatformOverride = null;
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets(
      'selected destination exposes exact Material semantics and icon state',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          for (final selected in InstitutionAdminShellDestination.values) {
            await _pumpApp(
              tester,
              initialLocation: selected.path,
              authRepository: _authenticatedRepository(_adminUser()),
            );
            await tester.pumpAndSettle();

            expect(
              _navigationRail(tester).selectedIndex,
              InstitutionAdminShellDestination.values.indexOf(selected),
            );
            for (final destination in InstitutionAdminShellDestination.values) {
              final destinationIndex = InstitutionAdminShellDestination.values
                  .indexOf(destination);
              final semanticsLabel =
                  '${destination.label}\nTab ${destinationIndex + 1} of 4';
              final semanticsNode = tester.getSemantics(
                find.bySemanticsLabel(semanticsLabel),
              );

              expect(semanticsNode.label, semanticsLabel);
              expect(
                semanticsNode.flagsCollection.isSelected,
                isNot(Tristate.none),
              );
              expect(
                semanticsNode.flagsCollection.isSelected,
                destination == selected ? Tristate.isTrue : Tristate.isFalse,
                reason:
                    '${destination.label} selection semantics for ${selected.label}',
              );
              expect(
                semanticsNode.flagsCollection.isSelected == Tristate.isTrue,
                destination == selected,
                reason:
                    '${destination.label} isSelected flag for ${selected.label}',
              );
              expect(find.byTooltip(destination.label), findsOneWidget);
              expect(destination.selectedIcon, isNot(destination.icon));
              expect(
                find.byIcon(
                  destination == selected
                      ? destination.selectedIcon
                      : destination.icon,
                ),
                findsOneWidget,
              );
              expect(
                find.byIcon(
                  destination == selected
                      ? destination.icon
                      : destination.selectedIcon,
                ),
                findsNothing,
              );
            }

            final signOutSemantics = tester.getSemantics(
              find.bySemanticsLabel('Sign out'),
            );
            expect(signOutSemantics.label, 'Sign out');
            expect(signOutSemantics.flagsCollection.isButton, isTrue);
            expect(
              signOutSemantics.flagsCollection.isEnabled,
              isNot(Tristate.none),
            );
            expect(signOutSemantics.flagsCollection.isEnabled, Tristate.isTrue);
          }
        } finally {
          semantics.dispose();
        }
      },
    );

    testWidgets('Enter activates a Tab-focused navigation destination', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
        tester.binding.setSurfaceSize(null);
      });

      await _pumpApp(
        tester,
        initialLocation: AppRoutePaths.institutionAdmin,
        authRepository: _authenticatedRepository(_adminUser()),
      );
      await tester.pumpAndSettle();

      await _sendTab(tester);
      _expectDestinationFocused(
        tester,
        InstitutionAdminShellDestination.dashboard,
      );
      await _sendTab(tester);
      _expectDestinationFocused(tester, InstitutionAdminShellDestination.users);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter, platform: 'windows');
      await tester.pumpAndSettle();

      _expectDestination(tester, _routeExpectations[1]);

      debugDefaultTargetPlatformOverride = null;
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('Space activates a Tab-focused navigation destination', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
        tester.binding.setSurfaceSize(null);
      });

      await _pumpApp(
        tester,
        initialLocation: AppRoutePaths.institutionAdmin,
        authRepository: _authenticatedRepository(_adminUser()),
      );
      await tester.pumpAndSettle();

      for (final destination in const [
        InstitutionAdminShellDestination.dashboard,
        InstitutionAdminShellDestination.users,
        InstitutionAdminShellDestination.institution,
      ]) {
        await _sendTab(tester);
        _expectDestinationFocused(tester, destination);
      }

      await tester.sendKeyEvent(LogicalKeyboardKey.space, platform: 'windows');
      await tester.pumpAndSettle();

      _expectDestination(tester, _routeExpectations[4]);

      debugDefaultTargetPlatformOverride = null;
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('Enter and Space activate Tab-focused Sign out immediately', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
        tester.binding.setSurfaceSize(null);
      });

      for (final activationKey in const [
        LogicalKeyboardKey.enter,
        LogicalKeyboardKey.space,
      ]) {
        final repository = _authenticatedRepository(_adminUser());
        if (activationKey == LogicalKeyboardKey.space) {
          repository.onSignOut = () async {
            throw ApiRequestException(
              ApiFailure.local(
                kind: ApiFailureKind.connection,
                message: 'Logout transport failed.',
              ),
            );
          };
        }
        await _pumpApp(
          tester,
          initialLocation: AppRoutePaths.institutionAdminSettings,
          authRepository: repository,
        );
        await tester.pumpAndSettle();

        for (var index = 0; index < 5; index += 1) {
          await _sendTab(tester);
        }
        _expectSignOutFocused(tester);

        await tester.sendKeyEvent(activationKey, platform: 'windows');
        await tester.pump();

        expect(_currentPath(tester), AppRoutePaths.login);
        expect(find.byKey(const Key('institutionAdminShell')), findsNothing);
        expect(find.textContaining('Admin User'), findsNothing);
        expect(find.textContaining('Example School'), findsNothing);
        expect(repository.signOutCalls, 1);
        await tester.pumpAndSettle();
        expect(_currentPath(tester), AppRoutePaths.login);
        expect(find.byKey(const Key('institutionAdminShell')), findsNothing);
        expect(find.textContaining('Admin User'), findsNothing);
        expect(find.textContaining('Example School'), findsNothing);
      }

      debugDefaultTargetPlatformOverride = null;
      await tester.binding.setSurfaceSize(null);
    });
  });

  group('Institution Admin logout and session isolation', () {
    testWidgets(
      'logout removes every destination and backend failure cannot restore it',
      (tester) async {
        for (final route in _routeExpectations) {
          final repository = _authenticatedRepository(_adminUser());
          repository.onSignOut = () async {
            throw ApiRequestException(
              ApiFailure.local(
                kind: ApiFailureKind.connection,
                message: 'Logout transport failed.',
              ),
            );
          };

          await _pumpApp(
            tester,
            initialLocation: route.path,
            authRepository: repository,
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('entryLogoutButton')));
          await tester.pumpAndSettle();

          expect(_currentPath(tester), AppRoutePaths.login);
          expect(find.byKey(const Key('institutionAdminShell')), findsNothing);
          expect(find.textContaining('Admin User'), findsNothing);
          expect(find.textContaining('Example School'), findsNothing);
          expect(repository.signOutCalls, 1);
        }
      },
    );

    testWidgets('current-token global invalidation removes shell', (
      tester,
    ) async {
      final signal = SessionInvalidationSignal();
      addTearDown(signal.dispose);
      final repository = _authenticatedRepository(
        _adminUser(),
        tokenVersion: 4,
      );

      await _pumpApp(
        tester,
        initialLocation: AppRoutePaths.institutionAdminSettings,
        authRepository: repository,
        signal: signal,
      );
      await tester.pumpAndSettle();

      signal.authenticationRequired(tokenVersion: 4);
      await tester.pumpAndSettle();

      expect(_currentPath(tester), AppRoutePaths.login);
      expect(find.byKey(const Key('institutionAdminShell')), findsNothing);
      expect(repository.clearTokenIfVersionCalls, [4]);
    });

    testWidgets(
      'current-token invalidation rejects a late profile response while stale-token invalidation preserves the newer session',
      (tester) async {
        final signal = SessionInvalidationSignal();
        addTearDown(signal.dispose);
        final pendingProfile = Completer<InstitutionProfile>();
        final repository = _authenticatedRepository(
          _adminUser(fullName: 'Admin A', institutionName: 'Institution A'),
          tokenVersion: 4,
        );
        final profileRepository = FakeInstitutionProfileRepository(
          onFetch: (_) => pendingProfile.future,
        );
        await _pumpApp(
          tester,
          initialLocation: AppRoutePaths.institutionAdminInstitution,
          authRepository: repository,
          signal: signal,
          institutionProfileRepository: profileRepository,
        );
        await tester.pump();

        signal.authenticationRequired(tokenVersion: 4);
        await tester.pumpAndSettle();
        expect(_currentPath(tester), AppRoutePaths.login);
        expect(find.byKey(const Key('institutionAdminShell')), findsNothing);

        pendingProfile.complete(
          _institutionProfile(name: 'Late Institution A Secret'),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('Late Institution A Secret'), findsNothing);
        expect(profileRepository.fetchCalls, 1);
        expect(profileRepository.updateCalls, 0);

        repository.onSignIn = (_, _) async => _adminUser(
          loginName: 'admin-b',
          fullName: 'Admin B',
          institutionName: 'Institution B',
        );
        await _submitLogin(tester, login: 'admin-b');
        expect(find.text('Institution: Institution B'), findsOneWidget);

        signal.authenticationRequired(tokenVersion: 4);
        await tester.pumpAndSettle();
        expect(_currentPath(tester), AppRoutePaths.institutionAdmin);
        expect(find.text('Current user: Admin B'), findsOneWidget);
        expect(find.text('Institution: Institution B'), findsOneWidget);
        expect(find.text('Institution: Institution A'), findsNothing);
        expect(find.textContaining('Late Institution A Secret'), findsNothing);
        expect(repository.clearTokenIfVersionCalls, [4, 4]);
      },
    );

    testWidgets('Institution Admin A to B exposes only B and canonical route', (
      tester,
    ) async {
      final repository = _authenticatedRepository(
        _adminUser(fullName: 'Admin A', institutionName: 'Institution A'),
      );
      await _pumpApp(
        tester,
        initialLocation: AppRoutePaths.institutionAdminSettings,
        authRepository: repository,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('entryLogoutButton')));
      await tester.pumpAndSettle();

      repository.onSignIn = (_, _) async =>
          _adminUser(fullName: 'Admin B', institutionName: 'Institution B');
      await _submitLogin(tester, login: 'admin-b');

      expect(_currentPath(tester), AppRoutePaths.institutionAdmin);
      expect(find.text('Current user: Admin B'), findsOneWidget);
      expect(find.text('Institution: Institution B'), findsOneWidget);
      expect(find.textContaining('Admin A'), findsNothing);
      expect(find.text('Institution: Institution A'), findsNothing);
    });

    testWidgets('Admin to another role and another role to Admin do not leak', (
      tester,
    ) async {
      final repository = _authenticatedRepository(
        _adminUser(fullName: 'Admin A', institutionName: 'Institution A'),
      );
      await _pumpApp(
        tester,
        initialLocation: AppRoutePaths.institutionAdminUsers,
        authRepository: repository,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('entryLogoutButton')));
      await tester.pumpAndSettle();

      repository.onSignIn = (_, _) async => _user(
        loginName: 'teacher-b',
        fullName: 'Teacher B',
        role: UserRole.teacher,
      );
      await _submitLogin(tester, login: 'teacher-b');
      expect(_currentPath(tester), AppRoutePaths.teacher);
      expect(find.byKey(const Key('institutionAdminShell')), findsNothing);
      expect(find.textContaining('Admin A'), findsNothing);

      await tester.tap(find.byKey(const Key('entryLogoutButton')));
      await tester.pumpAndSettle();
      repository.onSignIn = (_, _) async =>
          _adminUser(fullName: 'Admin C', institutionName: 'Institution C');
      await _submitLogin(tester, login: 'admin-c');
      expect(_currentPath(tester), AppRoutePaths.institutionAdmin);
      expect(find.text('Current user: Admin C'), findsOneWidget);
      expect(find.textContaining('Teacher B'), findsNothing);
    });

    testWidgets('delayed prior bootstrap cannot restore the old Admin', (
      tester,
    ) async {
      final oldUser = Completer<AuthUser>();
      final repository = FakeAuthRepository(
        storedToken: 'token-a',
        onCurrentUser: () => oldUser.future,
      );
      final container = await _pumpAppWithContainer(
        tester,
        initialLocation: AppRoutePaths.institutionAdminUsers,
        authRepository: repository,
      );
      final controller = container.read(authSessionControllerProvider.notifier);
      await tester.pump();

      await controller.signOut();
      await tester.pumpAndSettle();
      repository.onSignIn = (_, _) async =>
          _adminUser(fullName: 'Admin B', institutionName: 'Institution B');
      await controller.signIn(login: 'admin-b', password: 'secret');
      await tester.pumpAndSettle();

      oldUser.complete(
        _adminUser(fullName: 'Admin A', institutionName: 'Institution A'),
      );
      await tester.pumpAndSettle();

      expect(_currentPath(tester), AppRoutePaths.institutionAdmin);
      expect(find.text('Current user: Admin B'), findsOneWidget);
      expect(find.textContaining('Admin A'), findsNothing);
      expect(find.text('Institution: Institution A'), findsNothing);
    });
  });
}

const _userIdOne = '550e8400-e29b-41d4-a716-446655440000';
const _userIdTwo = 'A0B1C2D3-E4F5-6789-ABCD-EF0123456789';

final _routeExpectations = <_RouteExpectation>[
  const _RouteExpectation(
    path: AppRoutePaths.institutionAdmin,
    destination: InstitutionAdminShellDestination.dashboard,
    title: 'Dashboard',
    placeholderKey: 'institutionDashboardData',
    body: 'Institution Dashboard',
  ),
  const _RouteExpectation(
    path: AppRoutePaths.institutionAdminUsers,
    destination: InstitutionAdminShellDestination.users,
    title: 'Users',
    placeholderKey: 'institutionUserListGlobalEmpty',
    body: 'No Teachers, Students, or Parents exist yet.',
  ),
  const _RouteExpectation(
    path: AppRoutePaths.institutionAdminUserCreate,
    destination: InstitutionAdminShellDestination.users,
    title: 'Create User',
    placeholderKey: 'institutionUserCreateHeading',
    body: 'The user must change this password at first login.',
  ),
  _RouteExpectation(
    path: AppRoutePaths.institutionAdminUserDetailLocation(_userIdOne),
    destination: InstitutionAdminShellDestination.users,
    title: 'User Details',
    placeholderKey: 'institutionUserDetailHeading',
    body: 'User details',
  ),
  const _RouteExpectation(
    path: AppRoutePaths.institutionAdminInstitution,
    destination: InstitutionAdminShellDestination.institution,
    title: 'Institution',
    placeholderKey: 'institutionProfileData',
    body: 'Institution Profile',
  ),
  const _RouteExpectation(
    path: AppRoutePaths.institutionAdminSettings,
    destination: InstitutionAdminShellDestination.settings,
    title: 'Settings',
    placeholderKey: 'institutionAssessmentSettingsScreen',
    body: 'Assessment settings',
  ),
];

const _malformedLocations = <String>[
  '/institution-admin-extra',
  '/institution-admin/',
  '/institution-admin/users/',
  '/institution-admin/users/new/extra',
  '/institution-admin/users//',
  '/institution-admin/users/not-a-uuid',
  '/institution-admin/users/550e8400-e29b-41d4-a716-446655440000/extra',
  '/institution-admin/users/550e8400-e29b-41d4-a716-446655440000?include=private',
  '/institution-admin/users/550e8400-e29b-41d4-a716-446655440000#private',
  '/institution-admin/institution/edit',
  '/institution-admin/settings/categories',
];

Future<void> _pumpApp(
  WidgetTester tester, {
  required String initialLocation,
  required FakeAuthRepository authRepository,
  AppDeviceSurface surface = AppDeviceSurface.desktop,
  SessionInvalidationSignal? signal,
  FakePlatformDashboardRepository? dashboardRepository,
  FakePlatformInstitutionListRepository? listRepository,
  FakeInstitutionDashboardRepository? institutionDashboardRepository,
  FakeInstitutionProfileRepository? institutionProfileRepository,
  FakeInstitutionAssessmentSettingsRepository?
  institutionAssessmentSettingsRepository,
  FakeInstitutionUserListRepository? institutionUserListRepository,
  FakeInstitutionUserCreateRepository? institutionUserCreateRepository,
  FakeInstitutionUserDetailRepository? institutionUserDetailRepository,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        appInitialLocationProvider.overrideWithValue(initialLocation),
        authRepositoryProvider.overrideWithValue(authRepository),
        appDeviceSurfaceProvider.overrideWithValue(surface),
        platformDashboardRepositoryProvider.overrideWithValue(
          dashboardRepository ?? FakePlatformDashboardRepository(),
        ),
        platformInstitutionListRepositoryProvider.overrideWithValue(
          listRepository ?? FakePlatformInstitutionListRepository(),
        ),
        institutionDashboardRepositoryProvider.overrideWithValue(
          institutionDashboardRepository ??
              FakeInstitutionDashboardRepository(),
        ),
        institutionProfileRepositoryProvider.overrideWithValue(
          institutionProfileRepository ?? FakeInstitutionProfileRepository(),
        ),
        institutionAssessmentSettingsRepositoryProvider.overrideWithValue(
          institutionAssessmentSettingsRepository ??
              FakeInstitutionAssessmentSettingsRepository(),
        ),
        institutionUserListRepositoryProvider.overrideWithValue(
          institutionUserListRepository ?? FakeInstitutionUserListRepository(),
        ),
        institutionUserCreateRepositoryProvider.overrideWithValue(
          institutionUserCreateRepository ??
              FakeInstitutionUserCreateRepository(),
        ),
        institutionUserDetailRepositoryProvider.overrideWithValue(
          institutionUserDetailRepository ??
              FakeInstitutionUserDetailRepository(),
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

Future<ProviderContainer> _pumpAppWithContainer(
  WidgetTester tester, {
  required String initialLocation,
  required FakeAuthRepository authRepository,
}) async {
  final container = ProviderContainer(
    overrides: [
      appInitialLocationProvider.overrideWithValue(initialLocation),
      authRepositoryProvider.overrideWithValue(authRepository),
      appDeviceSurfaceProvider.overrideWithValue(AppDeviceSurface.desktop),
      platformDashboardRepositoryProvider.overrideWithValue(
        FakePlatformDashboardRepository(),
      ),
      platformInstitutionListRepositoryProvider.overrideWithValue(
        FakePlatformInstitutionListRepository(),
      ),
      institutionDashboardRepositoryProvider.overrideWithValue(
        FakeInstitutionDashboardRepository(),
      ),
      institutionProfileRepositoryProvider.overrideWithValue(
        FakeInstitutionProfileRepository(),
      ),
      institutionAssessmentSettingsRepositoryProvider.overrideWithValue(
        FakeInstitutionAssessmentSettingsRepository(),
      ),
      institutionUserListRepositoryProvider.overrideWithValue(
        FakeInstitutionUserListRepository(),
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const TestLabUzApp(),
    ),
  );
  await tester.pump();
  await tester.pump();

  return container;
}

void _expectDestination(WidgetTester tester, _RouteExpectation expected) {
  expect(_currentPath(tester), expected.path);
  expect(find.byKey(const Key('institutionAdminShell')), findsOneWidget);
  expect(find.byKey(const Key('institutionAdminNavigation')), findsOneWidget);
  expect(
    tester
        .widget<Text>(find.byKey(const Key('institutionAdminPageTitle')))
        .data,
    expected.title,
  );
  expect(find.byKey(Key(expected.placeholderKey)), findsOneWidget);
  expect(find.text(expected.body), findsOneWidget);
  expect(
    _navigationRail(tester).selectedIndex,
    InstitutionAdminShellDestination.values.indexOf(expected.destination),
  );
}

NavigationRail _navigationRail(WidgetTester tester) {
  return tester.widget<NavigationRail>(
    find.byKey(const Key('institutionAdminNavigation')),
  );
}

GoRouter _router(WidgetTester tester) {
  return GoRouter.of(tester.element(find.byType(Scaffold).first));
}

String _currentPath(WidgetTester tester) {
  return _router(tester).routeInformationProvider.value.uri.path;
}

Future<void> _tapDestination(WidgetTester tester, String label) async {
  final navigation = find.byKey(const Key('institutionAdminNavigation'));
  await tester.tap(find.descendant(of: navigation, matching: find.text(label)));
}

Future<void> _fillInstitutionUserCreateForm(WidgetTester tester) async {
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

Finder _navigationDestinationIcon(
  WidgetTester tester,
  InstitutionAdminShellDestination destination,
) {
  final selectedIndex = _navigationRail(tester).selectedIndex;
  final destinationIndex = InstitutionAdminShellDestination.values.indexOf(
    destination,
  );

  return find.descendant(
    of: find.byKey(const Key('institutionAdminNavigation')),
    matching: find.byIcon(
      selectedIndex == destinationIndex
          ? destination.selectedIcon
          : destination.icon,
    ),
  );
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

void _expectDestinationFocused(
  WidgetTester tester,
  InstitutionAdminShellDestination destination,
) {
  final destinationIcon = _navigationDestinationIcon(tester, destination);
  expect(destinationIcon, findsOneWidget);
  expect(
    Focus.of(tester.element(destinationIcon)).hasFocus,
    isTrue,
    reason: '${destination.label} should own keyboard focus',
  );
}

void _expectSignOutFocused(WidgetTester tester) {
  final signOutIcon = find.byIcon(Icons.logout);
  expect(signOutIcon, findsOneWidget);
  expect(
    Focus.of(tester.element(signOutIcon)).hasFocus,
    isTrue,
    reason: 'Sign out should own keyboard focus',
  );
}

void _expectDashboardSessionUnchanged(
  WidgetTester tester,
  FakeAuthRepository repository,
) {
  expect(_currentPath(tester), AppRoutePaths.institutionAdmin);
  expect(
    _navigationRail(tester).selectedIndex,
    InstitutionAdminShellDestination.values.indexOf(
      InstitutionAdminShellDestination.dashboard,
    ),
  );
  expect(
    tester
        .widget<Text>(find.byKey(const Key('institutionAdminPageTitle')))
        .data,
    'Dashboard',
  );
  expect(find.byKey(const Key('institutionDashboardData')), findsOneWidget);
  expect(find.text('Current user: Admin User'), findsOneWidget);
  expect(find.text('Institution: Example School'), findsOneWidget);
  expect(repository.signOutCalls, 0);
}

Future<void> _submitLogin(WidgetTester tester, {required String login}) async {
  await tester.enterText(find.byKey(const Key('loginField')), login);
  await tester.enterText(find.byKey(const Key('passwordField')), 'secret');
  await tester.tap(find.byKey(const Key('signInButton')));
  await tester.pumpAndSettle();
}

void _expectNoFutureScope() {
  expect(find.text('Groups'), findsNothing);
  expect(find.text('Reports'), findsNothing);
  expect(find.text('Topics'), findsNothing);
  expect(find.text('Homework'), findsNothing);
  expect(find.text('Blitz'), findsNothing);
  expect(find.text('Create Teacher'), findsNothing);
  expect(find.text('Create Student'), findsNothing);
  expect(find.text('Create Parent'), findsNothing);
  expect(find.text('Activate'), findsNothing);
  expect(find.text('Deactivate'), findsNothing);
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

AuthUser _adminUser({
  String loginName = 'admin-a',
  String fullName = 'Admin User',
  String? email,
  String? phone,
  bool isActive = true,
  bool mustChangePassword = false,
  String? institutionId = 'institution-1',
  AuthInstitution? institution,
  bool includeInstitution = true,
  String institutionName = 'Example School',
}) {
  return AuthUser(
    id: '$loginName-id',
    institutionId: institutionId,
    role: UserRole.institutionAdmin,
    fullName: fullName,
    loginName: loginName,
    email: email,
    phone: phone,
    isActive: isActive,
    mustChangePassword: mustChangePassword,
    institution: includeInstitution
        ? institution ??
              AuthInstitution(
                id: 'institution-1',
                name: institutionName,
                status: 'active',
                timezone: 'Asia/Tashkent',
              )
        : null,
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

class _RouteExpectation {
  const _RouteExpectation({
    required this.path,
    required this.destination,
    required this.title,
    required this.placeholderKey,
    required this.body,
  });

  final String path;
  final InstitutionAdminShellDestination destination;
  final String title;
  final String placeholderKey;
  final String body;
}

class _GuardCase {
  const _GuardCase({
    required this.user,
    required this.surface,
    required this.expectedPath,
  });

  final AuthUser user;
  final AppDeviceSurface surface;
  final String expectedPath;
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
  Future<void> Function()? onSignOut;
  final clearTokenIfVersionCalls = <int>[];
  var currentUserCalls = 0;
  var signOutCalls = 0;

  @override
  Future<AuthUser> currentUser() {
    currentUserCalls += 1;

    return onCurrentUser?.call() ?? Future.value(_adminUser());
  }

  @override
  Future<AuthUser> signIn({required String login, required String password}) {
    return onSignIn?.call(login, password) ?? Future.value(_adminUser());
  }

  @override
  Future<AuthUser> changePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) async {
    return _adminUser();
  }

  @override
  Future<void> signOut() {
    signOutCalls += 1;
    storedToken = null;

    return onSignOut?.call() ?? Future.value();
  }

  @override
  Future<String?> readStoredToken() async => storedToken;

  @override
  Future<void> clearToken() async {
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

class FakePlatformDashboardRepository implements PlatformDashboardRepository {
  var fetchCalls = 0;

  @override
  Future<PlatformDashboard> fetchDashboard() async {
    fetchCalls += 1;

    return const PlatformDashboard(
      institutions: PlatformInstitutionCounts(total: 0, active: 0, inactive: 0),
      users: PlatformUserCounts(total: 0, active: 0),
      recentInstitutions: [],
    );
  }
}

class FakeInstitutionDashboardRepository
    implements InstitutionDashboardRepository {
  var fetchCalls = 0;

  @override
  Future<InstitutionDashboard> fetchDashboard() async {
    fetchCalls += 1;

    return const InstitutionDashboard(teachers: 0, students: 0, parents: 0);
  }
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
  Future<InstitutionProfile> fetchProfile() async {
    fetchCalls += 1;

    return onFetch?.call(fetchCalls) ?? _institutionProfile();
  }

  @override
  Future<InstitutionProfileUpdateResult> updateProfile(
    InstitutionProfileUpdateRequest request,
  ) async {
    updateCalls += 1;

    return onUpdate?.call(updateCalls, request) ??
        (throw StateError('Shell tests do not submit profile updates.'));
  }
}

class FakeInstitutionAssessmentSettingsRepository
    implements InstitutionAssessmentSettingsRepository {
  var fetchCalls = 0;
  var updateCalls = 0;

  @override
  Future<InstitutionAssessmentSettings> fetchSettings() async {
    fetchCalls += 1;
    return InstitutionAssessmentSettings(
      educationalPolicyConfigured: true,
      acceptableScoreDifference: ExactAssessmentDecimal.parseUserInput('5'),
      blitzTimerStartMode: BlitzTimerStartMode.synchronized,
      studentResultReleaseMode: StudentResultReleaseMode.automatic,
      parentResultReleaseMode: ParentResultReleaseMode.withStudent,
      timezone: 'Asia/Tashkent',
      learningMaterialMaxMb: 25,
      studentSubmissionMaxMb: 15,
      platformLearningMaterialMaxMb: 25,
      platformStudentSubmissionMaxMb: 15,
      homeworkNormalAttempts: 3,
      blitzNormalAttempts: 1,
      blitzMaxAdditionalExceptionAttempts: 1,
    );
  }

  @override
  Future<InstitutionAssessmentSettings> updateSettings(
    InstitutionAssessmentSettingsUpdateRequest request,
  ) async {
    updateCalls += 1;
    throw StateError('Shell tests do not submit assessment settings.');
  }
}

class FakeInstitutionUserListRepository
    implements InstitutionUserListRepository {
  var fetchCalls = 0;

  @override
  Future<InstitutionUserListPage> fetchUsers(
    InstitutionUserListQuery query,
  ) async {
    fetchCalls += 1;

    return InstitutionUserListPage(
      users: const [],
      pagination: InstitutionUserListPagination(
        page: query.page,
        perPage: query.perPage,
        total: 0,
        lastPage: 1,
      ),
    );
  }
}

class FakeInstitutionUserCreateRepository
    implements InstitutionUserCreateRepository {
  FakeInstitutionUserCreateRepository({this.onCreate});

  final Future<InstitutionUser> Function(InstitutionUserCreateRequest request)?
  onCreate;
  final requests = <InstitutionUserCreateRequest>[];

  @override
  Future<InstitutionUser> createUser(
    InstitutionUserCreateRequest request,
  ) async {
    requests.add(request);
    return onCreate?.call(request) ?? _createdInstitutionUser(_userIdOne);
  }
}

class FakeInstitutionUserDetailRepository
    implements InstitutionUserDetailRepository {
  var fetchCalls = 0;

  @override
  Future<InstitutionUser> fetchUser(String userId) async {
    fetchCalls += 1;
    return _createdInstitutionUser(userId);
  }
}

InstitutionUser _createdInstitutionUser(String userId) {
  return InstitutionUser(
    id: userId,
    role: InstitutionUserRole.teacher,
    fullName: 'Detail User',
    loginName: 'detail-user',
    email: null,
    phone: null,
    isActive: true,
    mustChangePassword: false,
    lastLoginAt: null,
    deactivatedAt: null,
    createdAt: DateTime.utc(2026, 8, 7, 15),
    updatedAt: DateTime.utc(2026, 8, 7, 16),
  );
}

InstitutionProfile _institutionProfile({String name = 'Example School'}) {
  return InstitutionProfile(
    id: 'institution-1',
    name: name,
    type: InstitutionProfileType.school,
    status: InstitutionProfileStatus.active,
    contactEmail: null,
    contactPhone: null,
    address: null,
    description: null,
    createdAt: DateTime.utc(2026, 8, 1),
    updatedAt: DateTime.utc(2026, 8, 7),
  );
}

class FakePlatformInstitutionListRepository
    implements PlatformInstitutionListRepository {
  var fetchCalls = 0;

  @override
  Future<PlatformInstitutionListPage> fetchInstitutions(
    PlatformInstitutionListQuery query,
  ) async {
    fetchCalls += 1;

    return PlatformInstitutionListPage(
      institutions: const [],
      pagination: PlatformInstitutionPagination(
        page: query.page,
        perPage: query.perPage,
        total: 0,
        lastPage: 1,
      ),
    );
  }
}
