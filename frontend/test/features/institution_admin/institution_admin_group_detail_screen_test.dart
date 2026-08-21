import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_group_detail_repository_impl.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_group.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_group_detail_repository.dart';
import 'package:testlabuz_client/features/institution_admin/presentation/institution_admin_group_detail_screen.dart';

import 'institution_group_test_support.dart';

void main() {
  testWidgets('renders exact authoritative fields and no future actions', (
    tester,
  ) async {
    await _pump(tester, _FakeDetailRepository());
    await tester.pumpAndSettle();

    expect(find.text('Group Details'), findsOneWidget);
    expect(find.text('Advanced Mathematics'), findsWidgets);
    for (final label in const [
      'Name',
      'Status',
      'Level',
      'Subject direction',
      'Description',
      'Teachers',
      'Students',
      'Archived at',
      'Created',
      'Updated',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('2026-08-15 08:00 UTC'), findsOneWidget);
    expect(find.text('2026-08-15 09:30 UTC'), findsOneWidget);
    expect(find.text('Edit'), findsNothing);
    expect(find.text('Archive'), findsNothing);
    expect(find.textContaining('Manage'), findsNothing);
  });

  testWidgets(
    'invalid local target performs zero requests and is unavailable',
    (tester) async {
      final repository = _FakeDetailRepository();
      await _pump(tester, repository, target: 'not-a-uuid');
      await tester.pumpAndSettle();
      expect(repository.targets, isEmpty);
      expect(find.text('Group not found'), findsOneWidget);
      expect(
        find.text('The requested group is not available.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('exact 404 uses privacy-safe not-found copy', (tester) async {
    final repository = _FakeDetailRepository(
      onFetch: (_) => Future.error(
        ApiRequestException(
          ApiFailure(
            kind: ApiFailureKind.server,
            statusCode: 404,
            serverCode: ApiErrorCodes.resourceNotFound,
            message: 'Private reason.',
          ),
        ),
      ),
    );
    await _pump(tester, repository);
    await tester.pumpAndSettle();
    expect(find.text('Group not found'), findsOneWidget);
    expect(find.textContaining('Private'), findsNothing);
  });

  testWidgets('long content text scale and narrow width do not overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(760, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final long = List.filled(40, 'Long group content').join(' ');
    await _pump(
      tester,
      _FakeDetailRepository(
        group: testGroup(name: long, description: long),
      ),
      textScaler: const TextScaler.linear(2),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pump(
  WidgetTester tester,
  _FakeDetailRepository repository, {
  String target = testGroupId,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authSessionControllerProvider.overrideWith(
          TestAuthSessionController.new,
        ),
        appDeviceSurfaceProvider.overrideWithValue(AppDeviceSurface.desktop),
        institutionGroupDetailRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: textScaler),
          child: Scaffold(
            body: InstitutionAdminGroupDetailScreen(groupId: target),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

class _FakeDetailRepository implements InstitutionGroupDetailRepository {
  _FakeDetailRepository({this.onFetch, InstitutionGroup? group})
    : group = group ?? testGroup();

  final Future<InstitutionGroup> Function(String target)? onFetch;
  final InstitutionGroup group;
  final targets = <String>[];

  @override
  Future<InstitutionGroup> fetchGroup(String groupId) {
    targets.add(groupId);
    return onFetch?.call(groupId) ?? Future.value(group);
  }
}
