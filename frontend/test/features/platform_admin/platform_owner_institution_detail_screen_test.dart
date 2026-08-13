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
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/auth/data/auth_repository_impl.dart';
import 'package:testlabuz_client/features/auth/domain/auth_institution.dart';
import 'package:testlabuz_client/features/auth/domain/auth_repository.dart';
import 'package:testlabuz_client/features/auth/domain/auth_user.dart';
import 'package:testlabuz_client/features/auth/domain/user_role.dart';
import 'package:testlabuz_client/features/platform_admin/application/platform_institution_admin_action_controller.dart';
import 'package:testlabuz_client/features/platform_admin/application/platform_institution_admin_action_state.dart';
import 'package:testlabuz_client/features/platform_admin/data/platform_dashboard_repository_impl.dart';
import 'package:testlabuz_client/features/platform_admin/data/platform_institution_admin_repository_impl.dart';
import 'package:testlabuz_client/features/platform_admin/data/platform_institution_detail_repository_impl.dart';
import 'package:testlabuz_client/features/platform_admin/data/platform_institution_lifecycle_repository_impl.dart';
import 'package:testlabuz_client/features/platform_admin/data/platform_institution_list_repository_impl.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_dashboard.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_dashboard_repository.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_admin.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_admin_create.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_admin_lifecycle.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_admin_list.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_admin_list_query.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_admin_repository.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_admin_update.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_detail.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_detail_repository.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_lifecycle.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_lifecycle_repository.dart';
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
        final adminRepository = FakePlatformInstitutionAdminRepository();

        await _pumpApp(
          tester,
          detailRepository: detailRepository,
          listRepository: listRepository,
          adminRepository: adminRepository,
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
        expect(adminRepository.fetchCalls, isEmpty);

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
        expect(find.text('Institution administrators'), findsOneWidget);
        expect(find.text('No administrators yet'), findsOneWidget);
        expect(adminRepository.fetchCalls, hasLength(1));
        expect(
          adminRepository.fetchCalls.single.institutionId,
          _institutionIdA,
        );
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
        expect(
          find.byKey(const Key('platformInstitutionDetailEditButton')),
          findsOneWidget,
        );
        expect(find.text('Edit basic information'), findsOneWidget);
        expect(
          find.byKey(const Key('platformInstitutionLifecycleActivateButton')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('platformInstitutionLifecycleDeactivateButton')),
          findsNothing,
        );
        _expectNoLaterScopeText();
      },
    );

    testWidgets('detail not-found does not probe institution admins', (
      tester,
    ) async {
      final adminRepository = FakePlatformInstitutionAdminRepository();

      await _pumpApp(
        tester,
        detailRepository: FakePlatformInstitutionDetailRepository(
          onFetch: (_) async => throw _serverFailure(
            ApiErrorCodes.resourceNotFound,
            statusCode: 404,
          ),
        ),
        adminRepository: adminRepository,
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('platformInstitutionDetailNotFound')),
        findsOneWidget,
      );
      expect(adminRepository.fetchCalls, isEmpty);
      expect(
        find.byKey(const Key('platformInstitutionAdministratorsSection')),
        findsNothing,
      );
    });

    testWidgets('admin list renders public facts with row lifecycle actions', (
      tester,
    ) async {
      final adminRepository = FakePlatformInstitutionAdminRepository(
        admins: [
          _admin(
            fullName: 'Ali Valiyev',
            loginName: 'Admin.MixedCase',
            email: 'ali@example.uz',
            phone: '+998901234567',
          ),
          _admin(
            id: '550e8400-e29b-41d4-a716-446655440002',
            fullName: 'Inactive Admin',
            loginName: 'inactive.admin',
            isActive: false,
            mustChangePassword: false,
            email: null,
            phone: null,
            lastLoginAt: DateTime.utc(2026, 8, 9, 10),
          ),
        ],
      );

      await _pumpApp(tester, adminRepository: adminRepository);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('platformInstitutionAdministratorsSection')),
        findsOneWidget,
      );
      expect(find.text('Institution administrators'), findsOneWidget);
      expect(find.text('2 matching administrators'), findsOneWidget);
      expect(find.text('Ali Valiyev'), findsOneWidget);
      expect(find.text('Admin.MixedCase'), findsOneWidget);
      expect(find.text('ali@example.uz'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('platformInstitutionAdministratorsSection')),
          matching: find.text('+998901234567'),
        ),
        findsOneWidget,
      );
      expect(find.text('Inactive Admin'), findsOneWidget);
      expect(find.text('inactive.admin'), findsOneWidget);
      expect(find.text('Password change required'), findsOneWidget);
      expect(find.text('Password change completed'), findsOneWidget);
      expect(find.text('Never'), findsOneWidget);
      expect(find.text('2026-08-09 10:00 UTC'), findsOneWidget);
      expect(find.textContaining('password_hash'), findsNothing);
      expect(find.textContaining('institution_id'), findsNothing);
      expect(
        find.byKey(
          const Key(
            'platformInstitutionAdminEditButton-550e8400-e29b-41d4-a716-446655440001',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const Key(
            'platformInstitutionAdminDeactivateButton-550e8400-e29b-41d4-a716-446655440001',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const Key(
            'platformInstitutionAdminActivateButton-550e8400-e29b-41d4-a716-446655440002',
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'create dialog validates exact fields and cancel clears without POST',
      (tester) async {
        final adminRepository = FakePlatformInstitutionAdminRepository();

        await _pumpApp(
          tester,
          detailRepository: FakePlatformInstitutionDetailRepository(
            onFetch: (_) async => _detail(
              name: 'Inactive School',
              status: PlatformInstitutionStatus.inactive,
            ),
          ),
          adminRepository: adminRepository,
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('platformInstitutionAdminCreateButton')),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('platformInstitutionAdminCreateDialog')),
          findsOneWidget,
        );
        expect(
          find.text('Add administrator for Inactive School'),
          findsOneWidget,
        );
        expect(
          find.textContaining('active and must change the initial password'),
          findsOneWidget,
        );
        expect(
          find.byKey(
            const Key('platformInstitutionAdminInactiveInstitutionNote'),
          ),
          findsWidgets,
        );
        expect(find.text('Full name *'), findsOneWidget);
        expect(find.text('Login name *'), findsOneWidget);
        expect(find.text('Email'), findsOneWidget);
        expect(find.text('Phone'), findsOneWidget);
        expect(find.text('Initial password *'), findsOneWidget);
        expect(find.text('Role'), findsNothing);
        expect(find.text('Institution ID'), findsNothing);
        expect(find.text('Password confirmation'), findsNothing);

        await tester.tap(
          find.byKey(const Key('platformInstitutionAdminCreateSubmitButton')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Full name is required.'), findsOneWidget);
        expect(find.text('Login name is required.'), findsOneWidget);
        expect(find.text('Initial password is required.'), findsOneWidget);
        expect(adminRepository.createCalls, isEmpty);

        await tester.tap(
          find.byKey(const Key('platformInstitutionAdminCreateCancelButton')),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('platformInstitutionAdminCreateDialog')),
          findsNothing,
        );
        expect(adminRepository.createCalls, isEmpty);
      },
    );

    testWidgets(
      'confirmed admin create posts once and refreshes visible facts',
      (tester) async {
        final adminRepository = FakePlatformInstitutionAdminRepository();
        final detailRepository = FakePlatformInstitutionDetailRepository(
          onFetch: (institutionId) async =>
              _detail(id: institutionId, name: 'Create School'),
        );
        final listRepository = FakePlatformInstitutionListRepository();
        final dashboardRepository = FakePlatformDashboardRepository();

        await _pumpApp(
          tester,
          detailRepository: detailRepository,
          adminRepository: adminRepository,
          listRepository: listRepository,
          dashboardRepository: dashboardRepository,
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('platformInstitutionAdminSearchField')),
          'Current query',
        );
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pumpAndSettle();
        final listCallsBeforeCreate = adminRepository.fetchCalls.length;
        final detailCallsBeforeCreate = detailRepository.fetchCalls;

        await tester.tap(
          find.byKey(const Key('platformInstitutionAdminCreateButton')),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('platformInstitutionAdminCreateFullNameField')),
          '  New Admin  ',
        );
        await tester.enterText(
          find.byKey(const Key('platformInstitutionAdminCreateLoginNameField')),
          'New.Admin',
        );
        await tester.enterText(
          find.byKey(const Key('platformInstitutionAdminCreateEmailField')),
          '',
        );
        await tester.enterText(
          find.byKey(const Key('platformInstitutionAdminCreatePhoneField')),
          '  +998901111111  ',
        );
        await tester.enterText(
          find.byKey(const Key('platformInstitutionAdminCreatePasswordField')),
          'valid-password',
        );

        await tester.tap(
          find.byKey(const Key('platformInstitutionAdminCreateSubmitButton')),
        );
        await tester.pumpAndSettle();

        expect(adminRepository.createCalls, hasLength(1));
        expect(
          adminRepository.createCalls.single.institutionId,
          _institutionIdA,
        );
        expect(adminRepository.createCalls.single.request.toJson(), {
          'full_name': 'New Admin',
          'login_name': 'New.Admin',
          'email': null,
          'phone': '+998901111111',
          'password': 'valid-password',
        });
        expect(
          find.byKey(const Key('platformInstitutionAdminCreateDialog')),
          findsNothing,
        );
        expect(
          find.byKey(
            const Key('platformInstitutionAdminCreateSuccessSnackBar'),
          ),
          findsOneWidget,
        );
        expect(adminRepository.fetchCalls.length, listCallsBeforeCreate + 1);
        expect(adminRepository.fetchCalls.last.query.search, 'Current query');
        expect(detailRepository.fetchCalls, detailCallsBeforeCreate + 1);
        expect(listRepository.fetchCalls, 0);
        expect(dashboardRepository.fetchCalls, 0);
      },
    );

    testWidgets(
      'edit dialog submits changed administrator fields and refreshes list only',
      (tester) async {
        final admin = _admin(
          fullName: 'Ali Valiyev',
          loginName: 'admin.school1',
          email: 'ali@example.uz',
          phone: '+998901234567',
        );
        final updateCompleter =
            Completer<PlatformInstitutionAdminUpdateResult>();
        final adminRepository = FakePlatformInstitutionAdminRepository(
          admins: [admin],
          onUpdate: (_, _) => updateCompleter.future,
        );
        final detailRepository = FakePlatformInstitutionDetailRepository();
        final listRepository = FakePlatformInstitutionListRepository();
        final dashboardRepository = FakePlatformDashboardRepository();

        await _pumpApp(
          tester,
          detailRepository: detailRepository,
          adminRepository: adminRepository,
          listRepository: listRepository,
          dashboardRepository: dashboardRepository,
        );
        await tester.pumpAndSettle();
        final listCallsBeforeEdit = adminRepository.fetchCalls.length;
        final detailCallsBeforeEdit = detailRepository.fetchCalls;

        final editButton = find.byKey(
          Key('platformInstitutionAdminEditButton-${admin.id}'),
        );
        await tester.ensureVisible(editButton);
        await tester.pumpAndSettle();
        await tester.tap(editButton);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('platformInstitutionAdminEditDialog')),
          findsOneWidget,
        );
        expect(find.text('Edit administrator'), findsOneWidget);
        expect(find.text('admin.school1'), findsWidgets);
        expect(find.text('Active'), findsWidgets);
        expect(find.text('Password change required'), findsWidgets);
        expect(find.text('Login name *'), findsNothing);
        expect(find.text('Initial password *'), findsNothing);
        expect(find.text('Role'), findsNothing);
        expect(find.text('Institution ID'), findsNothing);

        await tester.enterText(
          find.byKey(const Key('platformInstitutionAdminEditFullNameField')),
          '  Updated Institution Admin  ',
        );
        await tester.enterText(
          find.byKey(const Key('platformInstitutionAdminEditEmailField')),
          '',
        );
        await tester.enterText(
          find.byKey(const Key('platformInstitutionAdminEditPhoneField')),
          '  +998901111111  ',
        );
        await tester.tap(
          find.byKey(const Key('platformInstitutionAdminEditSubmitButton')),
        );
        await tester.pump();

        expect(adminRepository.updateCalls, hasLength(1));
        expect(adminRepository.updateCalls.single.adminId, admin.id);
        expect(adminRepository.updateCalls.single.request.toJson(), {
          'full_name': 'Updated Institution Admin',
          'email': null,
          'phone': '+998901111111',
        });
        expect(
          find.byKey(const Key('platformInstitutionAdminEditDialog')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('platformInstitutionAdminEditSubmitButton')),
          findsOneWidget,
        );

        updateCompleter.complete(
          PlatformInstitutionAdminUpdateResult(
            admin: _copyAdmin(
              admin,
              fullName: 'Updated Institution Admin',
              email: null,
              phone: '+998901111111',
            ),
            message: 'Institution admin updated successfully.',
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('platformInstitutionAdminEditDialog')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('platformInstitutionAdminActionSnackBar')),
          findsOneWidget,
        );
        expect(adminRepository.fetchCalls.length, listCallsBeforeEdit + 1);
        expect(detailRepository.fetchCalls, detailCallsBeforeEdit);
        expect(listRepository.fetchCalls, 0);
        expect(dashboardRepository.fetchCalls, 0);
        expect(find.text('Updated Institution Admin'), findsNothing);
        expect(find.text('Ali Valiyev'), findsOneWidget);
      },
    );

    testWidgets('edit no-change keeps dialog and sends no PATCH', (
      tester,
    ) async {
      final admin = _admin(loginName: 'admin.school1');
      final adminRepository = FakePlatformInstitutionAdminRepository(
        admins: [admin],
      );

      await _pumpApp(tester, adminRepository: adminRepository);
      await tester.pumpAndSettle();

      final editButton = find.byKey(
        Key('platformInstitutionAdminEditButton-${admin.id}'),
      );
      await tester.ensureVisible(editButton);
      await tester.pumpAndSettle();
      await tester.tap(editButton);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('platformInstitutionAdminEditSubmitButton')),
      );
      await tester.pumpAndSettle();

      expect(adminRepository.updateCalls, isEmpty);
      expect(
        find.byKey(const Key('platformInstitutionAdminEditDialog')),
        findsOneWidget,
      );
      expect(find.text('No administrator changes to save.'), findsOneWidget);
    });

    testWidgets(
      'edit target 404 closes dialog resets action refreshes list and never retries PATCH',
      (tester) async {
        final admin = _admin(loginName: 'admin.school1');
        var serverListRead = 0;
        final adminRepository = FakePlatformInstitutionAdminRepository(
          admins: [admin],
          onFetch: (institutionId, query) async {
            serverListRead += 1;
            return _adminPage(
              admins: serverListRead == 1 ? [admin] : const [],
              query: query,
            );
          },
          onUpdate: (_, _) async => throw _serverFailure(
            ApiErrorCodes.resourceNotFound,
            statusCode: 404,
          ),
        );

        await _pumpApp(tester, adminRepository: adminRepository);
        await tester.pumpAndSettle();
        final listCallsBeforeEdit = adminRepository.fetchCalls.length;

        final editButton = find.byKey(
          Key('platformInstitutionAdminEditButton-${admin.id}'),
        );
        await tester.ensureVisible(editButton);
        await tester.tap(editButton);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('platformInstitutionAdminEditFullNameField')),
          'Updated Institution Admin',
        );
        await tester.tap(
          find.byKey(const Key('platformInstitutionAdminEditSubmitButton')),
        );
        await _pumpThroughTargetUnavailableCompletion(tester);

        expect(adminRepository.updateCalls, hasLength(1));
        expect(adminRepository.updateCalls.single.adminId, admin.id);
        expect(adminRepository.activateAdminIds, isEmpty);
        expect(adminRepository.deactivateAdminIds, isEmpty);
        expect(adminRepository.fetchCalls.length, listCallsBeforeEdit + 1);
        expect(adminRepository.fetchCalls.last.institutionId, _institutionIdA);
        expect(
          find.byKey(const Key('platformInstitutionAdminEditDialog')),
          findsNothing,
        );
        expect(
          find.byKey(
            const Key('platformInstitutionAdminEditUnavailableDialog'),
          ),
          findsNothing,
        );
        expect(
          find.byKey(
            const Key('platformInstitutionAdminLifecycleUnavailableDialog'),
          ),
          findsNothing,
        );
        expect(
          find.byKey(const Key('platformInstitutionAdminActionSnackBar')),
          findsOneWidget,
        );
        expect(
          find.text('Administrator is no longer available.'),
          findsOneWidget,
        );
        expect(
          find.text('Institution admin updated successfully.'),
          findsNothing,
        );
        expect(
          _adminActionState(tester).status,
          PlatformInstitutionAdminActionStatus.idle,
        );
        expect(_adminActionState(tester).snapshot, isNull);
        expect(_adminActionState(tester).form, isNull);
        expect(_adminActionState(tester).completion, isNull);

        await tester.pump(const Duration(seconds: 1));
        expect(adminRepository.updateCalls, hasLength(1));
        expect(adminRepository.fetchCalls.length, listCallsBeforeEdit + 1);
      },
    );

    testWidgets(
      'lifecycle target 404 closes dialog resets action refreshes list and never retries POST',
      (tester) async {
        final admin = _admin(loginName: 'admin.school1');
        var serverListRead = 0;
        final adminRepository = FakePlatformInstitutionAdminRepository(
          admins: [admin],
          onFetch: (institutionId, query) async {
            serverListRead += 1;
            return _adminPage(
              admins: serverListRead == 1 ? [admin] : const [],
              query: query,
            );
          },
          onDeactivate: (_) async => throw _serverFailure(
            ApiErrorCodes.resourceNotFound,
            statusCode: 404,
          ),
        );
        final detailRepository = FakePlatformInstitutionDetailRepository();
        final listRepository = FakePlatformInstitutionListRepository();
        final dashboardRepository = FakePlatformDashboardRepository();

        await _pumpApp(
          tester,
          detailRepository: detailRepository,
          adminRepository: adminRepository,
          listRepository: listRepository,
          dashboardRepository: dashboardRepository,
        );
        await tester.pumpAndSettle();
        final listCallsBeforeLifecycle = adminRepository.fetchCalls.length;
        final detailCallsBeforeLifecycle = detailRepository.fetchCalls;

        final deactivateButton = find.byKey(
          Key('platformInstitutionAdminDeactivateButton-${admin.id}'),
        );
        await tester.ensureVisible(deactivateButton);
        await tester.tap(deactivateButton);
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(
            const Key(
              'platformInstitutionAdminLifecycleConfirmDeactivateButton',
            ),
          ),
        );
        await _pumpThroughTargetUnavailableCompletion(tester);

        expect(adminRepository.deactivateAdminIds, [admin.id]);
        expect(adminRepository.activateAdminIds, isEmpty);
        expect(adminRepository.updateCalls, isEmpty);
        expect(adminRepository.fetchCalls.length, listCallsBeforeLifecycle + 1);
        expect(adminRepository.fetchCalls.last.institutionId, _institutionIdA);
        expect(detailRepository.fetchCalls, detailCallsBeforeLifecycle);
        expect(listRepository.fetchCalls, 0);
        expect(dashboardRepository.fetchCalls, 0);
        expect(
          find.byKey(const Key('platformInstitutionAdminLifecycleDialog')),
          findsNothing,
        );
        expect(
          find.byKey(
            const Key('platformInstitutionAdminLifecycleUnavailableDialog'),
          ),
          findsNothing,
        );
        expect(
          find.byKey(
            const Key('platformInstitutionAdminEditUnavailableDialog'),
          ),
          findsNothing,
        );
        expect(
          find.byKey(const Key('platformInstitutionAdminActionSnackBar')),
          findsOneWidget,
        );
        expect(
          find.text('Administrator is no longer available.'),
          findsOneWidget,
        );
        expect(
          find.text('Institution admin deactivated successfully.'),
          findsNothing,
        );
        expect(
          _adminActionState(tester).status,
          PlatformInstitutionAdminActionStatus.idle,
        );
        expect(_adminActionState(tester).snapshot, isNull);
        expect(_adminActionState(tester).completion, isNull);

        await tester.pump(const Duration(seconds: 1));
        expect(adminRepository.deactivateAdminIds, [admin.id]);
        expect(adminRepository.fetchCalls.length, listCallsBeforeLifecycle + 1);
      },
    );

    testWidgets(
      'target 404 refresh completion from stale route and Admin is ignored',
      (tester) async {
        final adminA = _admin(loginName: 'admin.school1');
        final adminB = _admin(
          id: '550e8400-e29b-41d4-a716-446655440002',
          fullName: 'Current Route Admin',
          loginName: 'admin.school2',
        );
        final staleRefreshCompleter = Completer<PlatformInstitutionAdminList>();
        var institutionAReads = 0;
        final adminRepository = FakePlatformInstitutionAdminRepository(
          admins: [adminA],
          onFetch: (institutionId, query) {
            if (institutionId == _institutionIdB) {
              return Future.value(_adminPage(admins: [adminB], query: query));
            }

            institutionAReads += 1;
            if (institutionAReads == 1) {
              return Future.value(_adminPage(admins: [adminA], query: query));
            }

            return staleRefreshCompleter.future;
          },
          onUpdate: (_, _) async => throw _serverFailure(
            ApiErrorCodes.resourceNotFound,
            statusCode: 404,
          ),
        );
        final detailRepository = FakePlatformInstitutionDetailRepository(
          onFetch: (institutionId) async => _detail(id: institutionId),
        );

        await _pumpApp(
          tester,
          detailRepository: detailRepository,
          adminRepository: adminRepository,
        );
        await tester.pumpAndSettle();

        final editButton = find.byKey(
          Key('platformInstitutionAdminEditButton-${adminA.id}'),
        );
        await tester.ensureVisible(editButton);
        await tester.tap(editButton);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('platformInstitutionAdminEditFullNameField')),
          'Stale Route Admin',
        );
        await tester.tap(
          find.byKey(const Key('platformInstitutionAdminEditSubmitButton')),
        );
        await tester.pump();
        await tester.pump();

        expect(adminRepository.updateCalls, hasLength(1));
        expect(adminRepository.updateCalls.single.adminId, adminA.id);
        expect(institutionAReads, 2);

        _router(tester).go(_detailPath(_institutionIdB));
        await tester.pumpAndSettle();

        expect(_currentPath(tester), _detailPath(_institutionIdB));
        expect(find.text('Current Route Admin'), findsOneWidget);
        expect(
          find.byKey(const Key('platformInstitutionAdminEditDialog')),
          findsNothing,
        );

        final staleQuery = adminRepository.fetchCalls
            .firstWhere((call) => call.institutionId == _institutionIdA)
            .query;
        staleRefreshCompleter.complete(
          _adminPage(admins: const [], query: staleQuery),
        );
        await tester.pumpAndSettle();

        expect(_currentPath(tester), _detailPath(_institutionIdB));
        expect(find.text('Current Route Admin'), findsOneWidget);
        expect(find.text('Stale Route Admin'), findsNothing);
        expect(
          find.byKey(const Key('platformInstitutionAdminActionSnackBar')),
          findsNothing,
        );
        expect(
          find.byKey(
            const Key('platformInstitutionAdminEditUnavailableDialog'),
          ),
          findsNothing,
        );
        expect(
          _adminActionState(tester, institutionId: _institutionIdB).status,
          PlatformInstitutionAdminActionStatus.idle,
        );
        expect(adminRepository.updateCalls, hasLength(1));
        expect(adminRepository.activateAdminIds, isEmpty);
        expect(adminRepository.deactivateAdminIds, isEmpty);
      },
    );

    testWidgets(
      'lifecycle confirmation posts once and refreshes list plus detail',
      (tester) async {
        final admin = _admin(loginName: 'admin.school1');
        final adminRepository = FakePlatformInstitutionAdminRepository(
          admins: [admin],
        );
        final detailRepository = FakePlatformInstitutionDetailRepository();

        await _pumpApp(
          tester,
          detailRepository: detailRepository,
          adminRepository: adminRepository,
        );
        await tester.pumpAndSettle();
        final listCallsBeforeLifecycle = adminRepository.fetchCalls.length;
        final detailCallsBeforeLifecycle = detailRepository.fetchCalls;

        final deactivateButton = find.byKey(
          Key('platformInstitutionAdminDeactivateButton-${admin.id}'),
        );
        await tester.ensureVisible(deactivateButton);
        await tester.pumpAndSettle();
        await tester.tap(deactivateButton);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('platformInstitutionAdminLifecycleDialog')),
          findsOneWidget,
        );
        expect(find.text('Deactivate administrator'), findsOneWidget);
        expect(find.text('admin.school1'), findsWidgets);
        expect(find.textContaining('Normal protected access'), findsOneWidget);
        expect(find.textContaining('historical data remain'), findsOneWidget);

        await tester.tap(
          find.byKey(
            const Key(
              'platformInstitutionAdminLifecycleConfirmDeactivateButton',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(adminRepository.deactivateAdminIds, [admin.id]);
        expect(adminRepository.activateAdminIds, isEmpty);
        expect(
          find.byKey(const Key('platformInstitutionAdminLifecycleDialog')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('platformInstitutionAdminActionSnackBar')),
          findsOneWidget,
        );
        expect(adminRepository.fetchCalls.length, listCallsBeforeLifecycle + 1);
        expect(detailRepository.fetchCalls, detailCallsBeforeLifecycle + 1);
      },
    );

    testWidgets(
      'detail exposes one accessible edit action to exact edit route',
      (tester) async {
        final detailRepository = FakePlatformInstitutionDetailRepository(
          onFetch: (institutionId) async => _detail(
            id: institutionId,
            name: 'Editable School',
            status: PlatformInstitutionStatus.inactive,
          ),
        );

        await _pumpApp(tester, detailRepository: detailRepository);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('platformInstitutionDetailEditButton')),
          findsOneWidget,
        );
        final semanticsWidget = tester.widget<Semantics>(
          find
              .ancestor(
                of: find.byKey(
                  const Key('platformInstitutionDetailEditButton'),
                ),
                matching: find.byType(Semantics),
              )
              .first,
        );
        expect(
          semanticsWidget.properties.label,
          'Edit basic information for Editable School',
        );
        expect(semanticsWidget.properties.button, isTrue);
        expect(
          find.byKey(const Key('platformInstitutionLifecycleActivateButton')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('platformInstitutionLifecycleDeactivateButton')),
          findsNothing,
        );
        expect(find.text('Institution Admins'), findsNothing);

        await tester.tap(
          find.byKey(const Key('platformInstitutionDetailEditButton')),
        );
        await tester.pumpAndSettle();

        expect(_currentPath(tester), '${_detailPath(_institutionIdA)}/edit');
        expect(
          tester
              .widget<NavigationRail>(
                find.byKey(const Key('platformOwnerNavigation')),
              )
              .selectedIndex,
          1,
        );
        expect(
          find.byKey(const Key('platformInstitutionEditHeading')),
          findsOneWidget,
        );
        expect(detailRepository.institutionIds, [
          _institutionIdA,
          _institutionIdA,
        ]);
      },
    );

    testWidgets(
      'lifecycle confirmation shows truthful wording and cancel sends no request',
      (tester) async {
        final activateRepository = FakePlatformInstitutionLifecycleRepository();
        await _pumpApp(
          tester,
          detailRepository: FakePlatformInstitutionDetailRepository(
            onFetch: (_) async => _detail(
              name: 'Inactive School',
              status: PlatformInstitutionStatus.inactive,
            ),
          ),
          lifecycleRepository: activateRepository,
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('platformInstitutionLifecycleActivateButton')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('platformInstitutionLifecycleDeactivateButton')),
          findsNothing,
        );

        await tester.tap(
          find.byKey(const Key('platformInstitutionLifecycleActivateButton')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Activate institution'), findsOneWidget);
        expect(find.text('Inactive School'), findsNWidgets(3));
        expect(find.text('Current status'), findsOneWidget);
        expect(find.text('Target status'), findsOneWidget);
        expect(find.text('Inactive'), findsWidgets);
        expect(find.text('Active'), findsWidgets);
        expect(find.text('Cancel'), findsOneWidget);
        expect(
          find.byKey(
            const Key('platformInstitutionLifecycleConfirmActivateButton'),
          ),
          findsOneWidget,
        );
        expect(find.textContaining('first-login requirement'), findsOneWidget);
        expect(find.textContaining('reactivates'), findsNothing);

        await tester.tap(
          find.byKey(const Key('platformInstitutionLifecycleCancelButton')),
        );
        await tester.pumpAndSettle();
        expect(activateRepository.activateCalls, 0);
        expect(
          find.byKey(const Key('platformInstitutionLifecycleDialog')),
          findsNothing,
        );

        final deactivateRepository =
            FakePlatformInstitutionLifecycleRepository();
        await _pumpApp(
          tester,
          detailRepository: FakePlatformInstitutionDetailRepository(
            onFetch: (_) async => _detail(name: 'Active School'),
          ),
          lifecycleRepository: deactivateRepository,
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('platformInstitutionLifecycleDeactivateButton')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('platformInstitutionLifecycleActivateButton')),
          findsNothing,
        );

        await tester.tap(
          find.byKey(const Key('platformInstitutionLifecycleDeactivateButton')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Deactivate institution'), findsOneWidget);
        expect(
          find.byKey(
            const Key('platformInstitutionLifecycleConfirmDeactivateButton'),
          ),
          findsOneWidget,
        );
        expect(find.textContaining('Institution Admins'), findsOneWidget);
        expect(
          find.textContaining('Historical data is preserved'),
          findsOneWidget,
        );
        expect(find.textContaining('delete'), findsNothing);

        await tester.tap(
          find.byKey(const Key('platformInstitutionLifecycleCancelButton')),
        );
        await tester.pumpAndSettle();
        expect(deactivateRepository.deactivateCalls, 0);
      },
    );

    testWidgets(
      'confirmed deactivation sends one POST and refreshes visible detail',
      (tester) async {
        final deactivateCompleter =
            Completer<PlatformInstitutionLifecycleResult>();
        final lifecycleRepository = FakePlatformInstitutionLifecycleRepository(
          onDeactivate: (_) => deactivateCompleter.future,
        );
        final detailRepository = FakePlatformInstitutionDetailRepository();
        detailRepository.onFetch = (_) async {
          if (detailRepository.fetchCalls == 1) {
            return _detail(name: 'Lifecycle School');
          }

          return _detail(
            name: 'Lifecycle School',
            status: PlatformInstitutionStatus.inactive,
          );
        };
        final listRepository = FakePlatformInstitutionListRepository();
        final dashboardRepository = FakePlatformDashboardRepository();

        await _pumpApp(
          tester,
          detailRepository: detailRepository,
          lifecycleRepository: lifecycleRepository,
          listRepository: listRepository,
          dashboardRepository: dashboardRepository,
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('platformInstitutionLifecycleDeactivateButton')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(
            const Key('platformInstitutionLifecycleConfirmDeactivateButton'),
          ),
        );
        await tester.tap(
          find.byKey(
            const Key('platformInstitutionLifecycleConfirmDeactivateButton'),
          ),
        );
        await tester.pump();

        expect(lifecycleRepository.deactivateCalls, 1);
        expect(find.text('Deactivate in progress'), findsOneWidget);

        deactivateCompleter.complete(
          _lifecycleResult(status: PlatformInstitutionStatus.inactive),
        );
        await tester.pumpAndSettle();

        expect(lifecycleRepository.deactivateCalls, 1);
        expect(detailRepository.fetchCalls, 2);
        expect(listRepository.fetchCalls, 0);
        expect(dashboardRepository.fetchCalls, 0);
        expect(
          find.text('Institution deactivated successfully.'),
          findsOneWidget,
        );
        expect(find.text('Inactive'), findsNWidgets(2));
        expect(
          find.byKey(const Key('platformInstitutionLifecycleActivateButton')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('platformInstitutionLifecycleDeactivateButton')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'ambiguous outcome exposes GET-only Check status without POST retry',
      (tester) async {
        final statusCompleter = Completer<PlatformInstitutionDetail>();
        final lifecycleRepository = FakePlatformInstitutionLifecycleRepository(
          onDeactivate: (_) async =>
              throw const PlatformInstitutionLifecycleOutcomeUnknownException(
                'unknown',
              ),
        );
        final detailRepository = FakePlatformInstitutionDetailRepository();
        detailRepository.onFetch = (_) {
          if (detailRepository.fetchCalls == 1) {
            return Future.value(_detail(name: 'Ambiguous School'));
          }

          if (detailRepository.fetchCalls == 2) {
            throw _localFailure(ApiFailureKind.connection);
          }

          return statusCompleter.future;
        };

        await _pumpApp(
          tester,
          detailRepository: detailRepository,
          lifecycleRepository: lifecycleRepository,
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('platformInstitutionLifecycleDeactivateButton')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(
            const Key('platformInstitutionLifecycleConfirmDeactivateButton'),
          ),
        );
        await tester.pumpAndSettle();

        expect(lifecycleRepository.deactivateCalls, 1);
        expect(detailRepository.fetchCalls, 2);
        expect(
          find.text(
            'Lifecycle outcome is unknown. Check status before acting again.',
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(
            const Key('platformInstitutionLifecycleCheckStatusButton'),
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(
            const Key('platformInstitutionLifecycleConfirmDeactivateButton'),
          ),
          findsNothing,
        );

        await tester.tap(
          find.byKey(
            const Key('platformInstitutionLifecycleCheckStatusButton'),
          ),
        );
        await tester.pump();
        expect(find.text('Checking status'), findsOneWidget);
        expect(lifecycleRepository.deactivateCalls, 1);
        expect(detailRepository.fetchCalls, 3);

        statusCompleter.complete(
          _detail(
            name: 'Ambiguous School',
            status: PlatformInstitutionStatus.inactive,
          ),
        );
        await tester.pumpAndSettle();

        expect(lifecycleRepository.deactivateCalls, 1);
        expect(find.text('Current server status is inactive.'), findsOneWidget);
        expect(find.text('Check status'), findsNothing);
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
      'route change closes an in-flight admin dialog and ignores late success',
      (tester) async {
        final admin = _admin(loginName: 'admin.school1');
        final updateCompleter =
            Completer<PlatformInstitutionAdminUpdateResult>();
        final adminRepository = FakePlatformInstitutionAdminRepository(
          admins: [admin],
          onFetch: (institutionId, query) async => _adminPage(
            admins: institutionId == _institutionIdA ? [admin] : const [],
            query: query,
          ),
          onUpdate: (_, _) => updateCompleter.future,
        );
        final detailRepository = FakePlatformInstitutionDetailRepository(
          onFetch: (institutionId) async => _detail(id: institutionId),
        );

        await _pumpApp(
          tester,
          detailRepository: detailRepository,
          adminRepository: adminRepository,
        );
        await tester.pumpAndSettle();

        final editButton = find.byKey(
          Key('platformInstitutionAdminEditButton-${admin.id}'),
        );
        await tester.ensureVisible(editButton);
        await tester.tap(editButton);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('platformInstitutionAdminEditFullNameField')),
          'Late Admin',
        );
        await tester.tap(
          find.byKey(const Key('platformInstitutionAdminEditSubmitButton')),
        );
        await tester.pump();

        expect(adminRepository.updateCalls, hasLength(1));
        expect(
          find.byKey(const Key('platformInstitutionAdminEditDialog')),
          findsOneWidget,
        );

        _router(tester).go(_detailPath(_institutionIdB));
        await tester.pumpAndSettle();

        expect(_currentPath(tester), _detailPath(_institutionIdB));
        expect(
          find.byKey(const Key('platformInstitutionAdminEditDialog')),
          findsNothing,
        );

        updateCompleter.complete(
          PlatformInstitutionAdminUpdateResult(
            admin: _copyAdmin(admin, fullName: 'Late Admin'),
            message: 'Institution admin updated successfully.',
          ),
        );
        await tester.pumpAndSettle();

        expect(_currentPath(tester), _detailPath(_institutionIdB));
        expect(
          find.byKey(const Key('platformInstitutionAdminActionSnackBar')),
          findsNothing,
        );
      },
    );

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
  FakePlatformInstitutionLifecycleRepository? lifecycleRepository,
  FakePlatformInstitutionAdminRepository? adminRepository,
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
        platformInstitutionLifecycleRepositoryProvider.overrideWithValue(
          lifecycleRepository ?? FakePlatformInstitutionLifecycleRepository(),
        ),
        platformInstitutionAdminRepositoryProvider.overrideWithValue(
          adminRepository ?? FakePlatformInstitutionAdminRepository(),
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

PlatformInstitutionAdminActionState _adminActionState(
  WidgetTester tester, {
  String institutionId = _institutionIdA,
}) {
  final context = tester.element(
    find.byKey(const Key('platformInstitutionDetailData')),
  );
  final container = ProviderScope.containerOf(context);
  final user = container.read(authSessionControllerProvider).user!;
  final key = PlatformInstitutionAdminActionKey(
    sessionUserId: user.id,
    sessionInstanceId: identityHashCode(user),
    institutionId: institutionId,
  );

  return container.read(platformInstitutionAdminActionControllerProvider(key));
}

Future<void> _pumpThroughTargetUnavailableCompletion(
  WidgetTester tester,
) async {
  var feedbackFound = false;

  for (var frame = 0; frame < 20; frame += 1) {
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      find.byKey(const Key('platformInstitutionAdminEditUnavailableDialog')),
      findsNothing,
    );
    expect(
      find.byKey(
        const Key('platformInstitutionAdminLifecycleUnavailableDialog'),
      ),
      findsNothing,
    );
    feedbackFound =
        feedbackFound ||
        find
            .byKey(const Key('platformInstitutionAdminActionSnackBar'))
            .evaluate()
            .isNotEmpty;
  }

  expect(feedbackFound, isTrue);
}

void _expectNoLaterScopeText() {
  expect(find.text('Create Institution'), findsNothing);
  expect(find.text('Edit Institution'), findsNothing);
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

PlatformInstitutionLifecycleResult _lifecycleResult({
  String id = _institutionIdA,
  String name = 'Example School',
  PlatformInstitutionStatus status = PlatformInstitutionStatus.active,
}) {
  final message = status == PlatformInstitutionStatus.active
      ? 'Institution activated successfully.'
      : 'Institution deactivated successfully.';

  return PlatformInstitutionLifecycleResult(
    id: id,
    name: name,
    type: PlatformInstitutionType.school,
    status: status,
    contactEmail: 'info@example.uz',
    contactPhone: '+998901234567',
    address: 'Samarkand',
    description: null,
    createdAt: DateTime.utc(2026, 8, 7, 15),
    updatedAt: DateTime.utc(2026, 8, 10, 12),
    message: message,
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

PlatformInstitutionAdminList _adminPage({
  required List<PlatformInstitutionAdmin> admins,
  required PlatformInstitutionAdminListQuery query,
}) {
  return PlatformInstitutionAdminList(
    admins: List<PlatformInstitutionAdmin>.unmodifiable(admins),
    pagination: PlatformInstitutionAdminPagination(
      page: query.page,
      perPage: query.perPage,
      total: admins.length,
      lastPage: 1,
    ),
  );
}

PlatformInstitutionAdmin _admin({
  String id = '550e8400-e29b-41d4-a716-446655440001',
  String fullName = 'Ali Valiyev',
  String loginName = 'admin-a',
  String? email = 'ali@example.uz',
  String? phone,
  bool isActive = true,
  bool mustChangePassword = true,
  DateTime? lastLoginAt,
}) {
  return PlatformInstitutionAdmin(
    id: id,
    fullName: fullName,
    loginName: loginName,
    email: email,
    phone: phone,
    isActive: isActive,
    mustChangePassword: mustChangePassword,
    lastLoginAt: lastLoginAt,
    deactivatedAt: isActive ? null : DateTime.utc(2026, 8, 8, 9),
    createdAt: DateTime.utc(2026, 8, 7, 15),
    updatedAt: DateTime.utc(2026, 8, 7, 16),
  );
}

PlatformInstitutionAdmin _copyAdmin(
  PlatformInstitutionAdmin admin, {
  String? fullName,
  Object? email = _sentinel,
  Object? phone = _sentinel,
  bool? isActive,
  Object? deactivatedAt = _sentinel,
}) {
  return PlatformInstitutionAdmin(
    id: admin.id,
    fullName: fullName ?? admin.fullName,
    loginName: admin.loginName,
    email: identical(email, _sentinel) ? admin.email : email as String?,
    phone: identical(phone, _sentinel) ? admin.phone : phone as String?,
    isActive: isActive ?? admin.isActive,
    mustChangePassword: admin.mustChangePassword,
    lastLoginAt: admin.lastLoginAt,
    deactivatedAt: identical(deactivatedAt, _sentinel)
        ? admin.deactivatedAt
        : deactivatedAt as DateTime?,
    createdAt: admin.createdAt,
    updatedAt: DateTime.utc(2026, 8, 9, 10),
  );
}

const _sentinel = Object();

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

ApiRequestException _localFailure(ApiFailureKind kind) {
  return ApiRequestException(
    ApiFailure.local(kind: kind, message: 'Local lifecycle failure.'),
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

class FakePlatformInstitutionLifecycleRepository
    implements PlatformInstitutionLifecycleRepository {
  FakePlatformInstitutionLifecycleRepository({
    this.onActivate,
    this.onDeactivate,
  });

  Future<PlatformInstitutionLifecycleResult> Function(String institutionId)?
  onActivate;
  Future<PlatformInstitutionLifecycleResult> Function(String institutionId)?
  onDeactivate;
  final activateInstitutionIds = <String>[];
  final deactivateInstitutionIds = <String>[];

  int get activateCalls => activateInstitutionIds.length;
  int get deactivateCalls => deactivateInstitutionIds.length;

  @override
  Future<PlatformInstitutionLifecycleResult> activateInstitution(
    String institutionId,
  ) {
    activateInstitutionIds.add(institutionId);

    return onActivate?.call(institutionId) ??
        Future.value(_lifecycleResult(id: institutionId));
  }

  @override
  Future<PlatformInstitutionLifecycleResult> deactivateInstitution(
    String institutionId,
  ) {
    deactivateInstitutionIds.add(institutionId);

    return onDeactivate?.call(institutionId) ??
        Future.value(
          _lifecycleResult(
            id: institutionId,
            status: PlatformInstitutionStatus.inactive,
          ),
        );
  }
}

class FakePlatformInstitutionAdminRepository
    implements PlatformInstitutionAdminRepository {
  FakePlatformInstitutionAdminRepository({
    this.admins = const [],
    this.onFetch,
    this.onCreate,
    this.onUpdate,
    this.onActivate,
    this.onDeactivate,
  });

  final List<PlatformInstitutionAdmin> admins;
  Future<PlatformInstitutionAdminList> Function(
    String institutionId,
    PlatformInstitutionAdminListQuery query,
  )?
  onFetch;
  Future<PlatformInstitutionAdminCreateResult> Function(
    String institutionId,
    PlatformInstitutionAdminCreateRequest request,
  )?
  onCreate;
  Future<PlatformInstitutionAdminUpdateResult> Function(
    String adminId,
    PlatformInstitutionAdminUpdateRequest request,
  )?
  onUpdate;
  Future<PlatformInstitutionAdminLifecycleResult> Function(String adminId)?
  onActivate;
  Future<PlatformInstitutionAdminLifecycleResult> Function(String adminId)?
  onDeactivate;
  final fetchCalls =
      <({String institutionId, PlatformInstitutionAdminListQuery query})>[];
  final createCalls =
      <
        ({String institutionId, PlatformInstitutionAdminCreateRequest request})
      >[];
  final updateCalls =
      <({String adminId, PlatformInstitutionAdminUpdateRequest request})>[];
  final activateAdminIds = <String>[];
  final deactivateAdminIds = <String>[];

  @override
  Future<PlatformInstitutionAdminList> fetchAdmins({
    required String institutionId,
    required PlatformInstitutionAdminListQuery query,
  }) {
    fetchCalls.add((institutionId: institutionId, query: query));

    return onFetch?.call(institutionId, query) ??
        Future.value(_adminPage(admins: admins, query: query));
  }

  @override
  Future<PlatformInstitutionAdminCreateResult> createAdmin({
    required String institutionId,
    required PlatformInstitutionAdminCreateRequest request,
  }) {
    createCalls.add((institutionId: institutionId, request: request));

    return onCreate?.call(institutionId, request) ??
        Future.value(
          PlatformInstitutionAdminCreateResult(
            admin: _admin(
              fullName: request.fullName,
              loginName: request.loginName,
              email: request.email,
              phone: request.phone,
            ),
            message: 'Institution administrator created.',
          ),
        );
  }

  @override
  Future<PlatformInstitutionAdminUpdateResult> updateAdmin({
    required String adminId,
    required PlatformInstitutionAdminUpdateRequest request,
  }) {
    updateCalls.add((adminId: adminId, request: request));

    final existing = admins.firstWhere(
      (admin) => admin.id == adminId,
      orElse: () => _admin(id: adminId),
    );
    final body = request.toJson();

    return onUpdate?.call(adminId, request) ??
        Future.value(
          PlatformInstitutionAdminUpdateResult(
            admin: _copyAdmin(
              existing,
              fullName: body.containsKey('full_name')
                  ? body['full_name']! as String
                  : existing.fullName,
              email: body.containsKey('email')
                  ? body['email'] as String?
                  : existing.email,
              phone: body.containsKey('phone')
                  ? body['phone'] as String?
                  : existing.phone,
            ),
            message: 'Institution admin updated successfully.',
          ),
        );
  }

  @override
  Future<PlatformInstitutionAdminLifecycleResult> activateAdmin({
    required String adminId,
  }) {
    activateAdminIds.add(adminId);

    final existing = admins.firstWhere(
      (admin) => admin.id == adminId,
      orElse: () => _admin(id: adminId, isActive: false),
    );

    return onActivate?.call(adminId) ??
        Future.value(
          PlatformInstitutionAdminLifecycleResult(
            admin: _copyAdmin(existing, isActive: true, deactivatedAt: null),
            message: 'Institution admin activated successfully.',
            action: PlatformInstitutionAdminLifecycleAction.activate,
          ),
        );
  }

  @override
  Future<PlatformInstitutionAdminLifecycleResult> deactivateAdmin({
    required String adminId,
  }) {
    deactivateAdminIds.add(adminId);

    final existing = admins.firstWhere(
      (admin) => admin.id == adminId,
      orElse: () => _admin(id: adminId),
    );

    return onDeactivate?.call(adminId) ??
        Future.value(
          PlatformInstitutionAdminLifecycleResult(
            admin: _copyAdmin(
              existing,
              isActive: false,
              deactivatedAt: DateTime.utc(2026, 8, 9, 10),
            ),
            message: 'Institution admin deactivated successfully.',
            action: PlatformInstitutionAdminLifecycleAction.deactivate,
          ),
        );
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
