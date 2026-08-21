import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_group_create_repository_impl.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_group.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_group_create.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_group_create_repository.dart';
import 'package:testlabuz_client/features/institution_admin/presentation/institution_admin_group_create_screen.dart';

import 'institution_group_test_support.dart';

void main() {
  testWidgets('renders controlled fields in order and focuses first error', (
    tester,
  ) async {
    final repository = _FakeCreateRepository();
    await _pump(tester, repository);

    final fields = <Key>[
      const Key('institutionGroupCreateNameField'),
      const Key('institutionGroupCreateLevelField'),
      const Key('institutionGroupCreateSubjectDirectionField'),
      const Key('institutionGroupCreateDescriptionField'),
    ];
    for (final key in fields) {
      expect(find.byKey(key), findsOneWidget);
    }
    final positions = fields.map(
      (key) => tester.getTopLeft(find.byKey(key)).dy,
    );
    expect(positions, orderedEquals(positions.toList()..sort()));

    await tester.tap(
      find.byKey(const Key('institutionGroupCreateSubmitButton')),
    );
    await tester.pump();
    expect(repository.requests, isEmpty);
    expect(find.text('Group name is required.'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(
            find.byKey(const Key('institutionGroupCreateNameField')),
          )
          .focusNode!
          .hasFocus,
      isTrue,
    );
  });

  testWidgets('description Enter inserts newline and explicit action submits', (
    tester,
  ) async {
    final completion = Completer<InstitutionGroup>();
    final repository = _FakeCreateRepository(
      onCreate: (_) => completion.future,
    );
    await _pump(tester, repository);
    await tester.enterText(
      find.byKey(const Key('institutionGroupCreateNameField')),
      '  Advanced Mathematics  ',
    );
    final description = find.byKey(
      const Key('institutionGroupCreateDescriptionField'),
    );
    await tester.enterText(description, 'First line');
    await tester.showKeyboard(description);
    await tester.testTextInput.receiveAction(TextInputAction.newline);
    await tester.enterText(description, 'First line\nSecond line');
    expect(repository.requests, isEmpty);

    await tester.tap(
      find.byKey(const Key('institutionGroupCreateSubmitButton')),
    );
    await tester.pump();
    expect(repository.requests, hasLength(1));
    expect(
      repository.requests.single.toJson()['description'],
      'First line\nSecond line',
    );
  });

  testWidgets('unknown terminal hides form and exposes only safe recovery', (
    tester,
  ) async {
    final repository = _FakeCreateRepository(
      onCreate: (_) =>
          Future.error(const InstitutionGroupCreateOutcomeUnknownException()),
    );
    await _pump(tester, repository);
    await tester.enterText(
      find.byKey(const Key('institutionGroupCreateNameField')),
      'Group',
    );
    await tester.tap(
      find.byKey(const Key('institutionGroupCreateSubmitButton')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('institutionGroupCreateUnknownOutcome')),
      findsOneWidget,
    );
    expect(
      find.text(
        'Group creation could not be confirmed. The request may have succeeded. Review recent groups before creating another group.',
      ),
      findsOneWidget,
    );
    expect(find.text('Review recent groups'), findsOneWidget);
    expect(
      find.byKey(const Key('institutionGroupCreateSubmitButton')),
      findsNothing,
    );
    expect(find.textContaining('Retry'), findsNothing);
    expect(find.text('Cancel'), findsNothing);
    expect(repository.requests, hasLength(1));
  });

  testWidgets('text scale and narrow desktop do not overflow', (tester) async {
    tester.view.physicalSize = const Size(850, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pump(
      tester,
      _FakeCreateRepository(),
      textScaler: const TextScaler.linear(2),
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pump(
  WidgetTester tester,
  _FakeCreateRepository repository, {
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authSessionControllerProvider.overrideWith(
          TestAuthSessionController.new,
        ),
        appDeviceSurfaceProvider.overrideWithValue(AppDeviceSurface.desktop),
        institutionGroupCreateRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: textScaler),
          child: const Scaffold(body: InstitutionAdminGroupCreateScreen()),
        ),
      ),
    ),
  );
  await tester.pump();
}

class _FakeCreateRepository implements InstitutionGroupCreateRepository {
  _FakeCreateRepository({this.onCreate});

  final Future<InstitutionGroup> Function(
    InstitutionGroupCreateRequest request,
  )?
  onCreate;
  final requests = <InstitutionGroupCreateRequest>[];

  @override
  Future<InstitutionGroup> createGroup(InstitutionGroupCreateRequest request) {
    requests.add(request);
    return onCreate?.call(request) ?? Future.value(testGroup());
  }
}
