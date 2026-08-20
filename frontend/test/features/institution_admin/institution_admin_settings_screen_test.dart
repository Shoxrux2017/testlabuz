import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_state.dart';
import 'package:testlabuz_client/features/auth/domain/auth_institution.dart';
import 'package:testlabuz_client/features/auth/domain/auth_user.dart';
import 'package:testlabuz_client/features/auth/domain/user_role.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_assessment_settings_repository_impl.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_assessment_settings.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_assessment_settings_repository.dart';
import 'package:testlabuz_client/features/institution_admin/presentation/institution_admin_settings_screen.dart';

void main() {
  testWidgets('shows confirmed policy, fixed facts and honest categories placeholder', (
    tester,
  ) async {
    final repository = _FakeRepository();
    await _pump(tester, repository: repository);

    expect(find.byKey(const Key('assessmentSettingsHeading')), findsOneWidget);
    expect(find.byKey(const Key('assessmentSettingsSummary')), findsOneWidget);
    expect(find.text('Homework normal attempts'), findsOneWidget);
    expect(find.text('Educational policy status: Configured.'), findsOneWidget);
    expect(find.text('How changes take effect'), findsOneWidget);
    expect(
      find.text(
        'Synchronized — Teacher activation starts one shared whole-Blitz timer for all assigned Students.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Automatic — A fully calculated result becomes visible to the Student automatically.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'With Student — A connected Parent receives access only after the Student result is released.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        '• These settings control future dependent behavior according to backend rules.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        '• Changing timezone does not rewrite already stored absolute timestamps.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        '• Changing timer/release/threshold settings does not rewrite active snapshots, calculated/closed results, release history, or category snapshots.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('• Parent visibility never precedes Student visibility.'),
      findsOneWidget,
    );
    expect(
      find.text(
        '• Lowering upload limits affects future uploads only. Existing files are not revalidated or deleted.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        '• Runtime Learning/Homework/Blitz/result/file/category behavior is implemented in later tasks/stages, not here.',
      ),
      findsOneWidget,
    );
    expect(find.text('1 MB = 1,048,576 bytes'), findsOneWidget);
    expect(find.text('Read-only server facts'), findsOneWidget);
    expect(
      find.text('Maximum additional exception attempts per Student and Blitz'),
      findsOneWidget,
    );
    expect(
      find.text('Platform maximum learning material size'),
      findsOneWidget,
    );
    expect(
      find.text('Platform maximum student submission size'),
      findsOneWidget,
    );
    expect(
      find.text('Understanding categories will be implemented in S03-FE-009.'),
      findsOneWidget,
    );
    expect(repository.fetchCalls, 1);
    expect(repository.updateCalls, 0);
  });

  testWidgets(
    'shows Configuration required for exactly four null policy fields',
    (tester) async {
      final repository = _FakeRepository(settings: _unconfiguredSettings());
      await _pump(tester, repository: repository);

      expect(find.text('Configuration required'), findsNWidgets(4));
      expect(
        find.textContaining('Dependent assessment operations remain blocked'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('assessmentSettingsEditButton')));
      await tester.pump();

      expect(find.text('Configuration required'), findsNWidgets(4));
    },
  );

  testWidgets('preserves populated values and marks only null fields as required', (
    tester,
  ) async {
    final repository = _FakeRepository(
      settings: _partiallyConfiguredSettings(),
    );
    await _pump(tester, repository: repository);

    expect(find.text('Configuration required'), findsOneWidget);
    expect(find.text('7.5'), findsOneWidget);
    expect(
      find.text(
        'Individual — After Teacher activation, each Student receives the full whole-Blitz duration when they start.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'With Student — A connected Parent receives access only after the Student result is released.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('assessmentSettingsEditButton')));
    await tester.pump();

    expect(find.text('Configuration required'), findsOneWidget);
    final scoreField = tester.widget<TextFormField>(
      find.byKey(const Key('assessmentSettingsScoreDifferenceField')),
    );
    expect(scoreField.controller!.text, '7.5');
  });

  testWidgets('edits only seven fields and validates before sending', (
    tester,
  ) async {
    final repository = _FakeRepository();
    await _pump(tester, repository: repository);
    await tester.tap(find.byKey(const Key('assessmentSettingsEditButton')));
    await tester.pump();

    expect(find.byType(TextFormField), findsNWidgets(4));
    expect(
      find.byKey(const Key('assessmentSettingsTimerModeField')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('assessmentSettingsStudentReleaseField')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('assessmentSettingsParentReleaseField')),
      findsOneWidget,
    );
    expect(find.text('Read-only server facts'), findsOneWidget);
    expect(
      find.text(
        'Saving sends all seven assessment settings together as one complete replacement.',
      ),
      findsOneWidget,
    );
    expect(find.text('1 MB = 1,048,576 bytes'), findsOneWidget);
    expect(
      find.text(
        'Teacher activation starts one shared whole-Blitz timer for all assigned Students.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'A fully calculated result becomes visible to the Student automatically.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'A connected Parent receives access only after the Student result is released.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Use an IANA identifier such as Asia/Tashkent. Changing the timezone does not rewrite already stored absolute timestamps.',
      ),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const Key('assessmentSettingsScoreDifferenceField')),
      '101',
    );
    tester
        .widget<FilledButton>(
          find.byKey(const Key('assessmentSettingsSaveButton')),
        )
        .onPressed!();
    await tester.pump();

    expect(
      find.text('Enter a value from 0 to 100 using up to 8 decimal places.'),
      findsOneWidget,
    );
    expect(repository.updateCalls, 0);
  });

  testWidgets('rejects invalid pasted text without silently coercing it', (
    tester,
  ) async {
    final repository = _FakeRepository();
    await _pump(tester, repository: repository);
    await tester.tap(find.byKey(const Key('assessmentSettingsEditButton')));
    await tester.pump();

    final scoreFinder = find.byKey(
      const Key('assessmentSettingsScoreDifferenceField'),
    );
    final learningLimitFinder = find.byKey(
      const Key('assessmentSettingsLearningLimitField'),
    );
    await tester.enterText(scoreFinder, '1e2');
    await tester.enterText(learningLimitFinder, '1.5');
    tester
        .widget<FilledButton>(
          find.byKey(const Key('assessmentSettingsSaveButton')),
        )
        .onPressed!();
    await tester.pump();

    expect(tester.widget<TextFormField>(scoreFinder).controller!.text, '1e2');
    expect(
      tester.widget<TextFormField>(learningLimitFinder).controller!.text,
      '1.5',
    );
    expect(
      find.text('Enter a value from 0 to 100 using up to 8 decimal places.'),
      findsOneWidget,
    );
    expect(find.text('Enter a whole number from 1 to 25.'), findsOneWidget);
    expect(repository.updateCalls, 0);
  });

  testWidgets('shows a safe load error with an explicit Retry action', (
    tester,
  ) async {
    final repository = _FailingRepository();
    await _pump(tester, repository: repository);

    expect(
      find.text('Assessment settings could not be loaded.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);
    expect(find.byKey(const Key('assessmentSettingsSummary')), findsNothing);
  });

  testWidgets('shows loading and refresh progress without replacing data', (
    tester,
  ) async {
    final repository = _ControlledReadRepository();
    await _pump(tester, repository: repository);

    expect(find.byKey(const Key('assessmentSettingsLoading')), findsOneWidget);
    repository.initialRead.complete(_settings());
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byKey(const Key('assessmentSettingsRefreshButton')));
    await tester.pump();

    expect(find.text('Refreshing assessment settings…'), findsOneWidget);
    expect(find.byKey(const Key('assessmentSettingsSummary')), findsOneWidget);
    repository.refreshRead.complete(_settings());
    await tester.pump();
    await tester.pump();
  });

  testWidgets('warns before a dirty Refresh discards the local draft', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.byKey(const Key('assessmentSettingsEditButton')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('assessmentSettingsScoreDifferenceField')),
      '6',
    );
    await _tapVisible(
      tester,
      find.byKey(const Key('assessmentSettingsEditRefreshButton')),
    );
    await tester.pump();

    expect(find.text('Discard unsaved changes?'), findsOneWidget);
    expect(
      find.text(
        'Refreshing loads the current server settings and discards this local draft.',
      ),
      findsOneWidget,
    );
    expect(find.text('Keep editing'), findsOneWidget);
    expect(find.text('Discard and refresh'), findsOneWidget);
  });

  testWidgets('dirty Refresh cancel and confirm have exact GET counts', (
    tester,
  ) async {
    final repository = _FakeRepository();
    await _pump(tester, repository: repository);
    await tester.tap(find.byKey(const Key('assessmentSettingsEditButton')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('assessmentSettingsScoreDifferenceField')),
      '6',
    );

    await _tapVisible(
      tester,
      find.byKey(const Key('assessmentSettingsEditRefreshButton')),
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'Keep editing'));
    await tester.pumpAndSettle();
    expect(repository.fetchCalls, 1);
    expect(find.byKey(const Key('assessmentSettingsForm')), findsOneWidget);

    await _tapVisible(
      tester,
      find.byKey(const Key('assessmentSettingsEditRefreshButton')),
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Discard and refresh'));
    await tester.pumpAndSettle();
    expect(repository.fetchCalls, 2);
    expect(find.byKey(const Key('assessmentSettingsSummary')), findsOneWidget);
    expect(repository.updateCalls, 0);
  });

  testWidgets('Reset restores draft and Cancel sends no request', (
    tester,
  ) async {
    final repository = _FakeRepository();
    await _pump(tester, repository: repository);
    await tester.tap(find.byKey(const Key('assessmentSettingsEditButton')));
    await tester.pump();
    final score = find.byKey(
      const Key('assessmentSettingsScoreDifferenceField'),
    );
    await tester.enterText(score, '6');
    await _tapVisible(
      tester,
      find.byKey(const Key('assessmentSettingsResetButton')),
    );
    await tester.pump();

    expect(tester.widget<TextFormField>(score).controller!.text, '5');
    expect(find.byKey(const Key('assessmentSettingsForm')), findsOneWidget);
    expect(repository.fetchCalls, 1);
    expect(repository.updateCalls, 0);

    await tester.enterText(score, '7');
    await _tapVisible(
      tester,
      find.byKey(const Key('assessmentSettingsCancelButton')),
    );
    await tester.pump();
    expect(find.byKey(const Key('assessmentSettingsSummary')), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(repository.fetchCalls, 1);
    expect(repository.updateCalls, 0);
  });

  testWidgets(
    'Reset restores dropdowns and numeric fields so Save sends no PUT',
    (tester) async {
      final repository = _FakeRepository();
      await _pump(tester, repository: repository);
      await tester.tap(find.byKey(const Key('assessmentSettingsEditButton')));
      await tester.pump();

      await _selectDropdownValue(
        tester,
        fieldKey: const Key('assessmentSettingsTimerModeField'),
        label: 'Individual',
      );
      await _selectDropdownValue(
        tester,
        fieldKey: const Key('assessmentSettingsStudentReleaseField'),
        label: 'Teacher-controlled',
      );
      await _selectDropdownValue(
        tester,
        fieldKey: const Key('assessmentSettingsParentReleaseField'),
        label: 'Hidden',
      );
      await tester.enterText(
        find.byKey(const Key('assessmentSettingsScoreDifferenceField')),
        '6',
      );
      await tester.enterText(
        find.byKey(const Key('assessmentSettingsLearningLimitField')),
        '20',
      );
      await tester.enterText(
        find.byKey(const Key('assessmentSettingsSubmissionLimitField')),
        '10',
      );

      tester
          .widget<TextButton>(
            find.byKey(const Key('assessmentSettingsResetButton')),
          )
          .onPressed!();
      await tester.pump();

      expect(
        find.descendant(
          of: find.byKey(const Key('assessmentSettingsTimerModeField')),
          matching: find.text('Synchronized'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('assessmentSettingsStudentReleaseField')),
          matching: find.text('Automatic'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('assessmentSettingsParentReleaseField')),
          matching: find.text('With Student'),
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const Key('assessmentSettingsScoreDifferenceField')),
            )
            .controller!
            .text,
        '5',
      );
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const Key('assessmentSettingsLearningLimitField')),
            )
            .controller!
            .text,
        '25',
      );
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const Key('assessmentSettingsSubmissionLimitField')),
            )
            .controller!
            .text,
        '15',
      );

      await _tapVisible(
        tester,
        find.byKey(const Key('assessmentSettingsSaveButton')),
      );
      await tester.pump();

      expect(find.text('No changes to save.'), findsOneWidget);
      expect(repository.fetchCalls, 1);
      expect(repository.updateCalls, 0);
    },
  );

  testWidgets(
    'Cancel returns keyboard focus to the configured Edit settings button',
    (tester) async {
      await _expectCancelRestoresInitiatingButtonFocus(
        tester,
        repository: _FakeRepository(),
        expectedLabel: 'Edit settings',
        activationKey: LogicalKeyboardKey.enter,
      );
    },
  );

  testWidgets(
    'Cancel returns keyboard focus to the incomplete Configure settings button',
    (tester) async {
      await _expectCancelRestoresInitiatingButtonFocus(
        tester,
        repository: _FakeRepository(settings: _unconfiguredSettings()),
        expectedLabel: 'Configure settings',
        activationKey: LogicalKeyboardKey.space,
      );
    },
  );

  testWidgets('uses exact notices for no-change and direct-success outcomes', (
    tester,
  ) async {
    final repository = _FakeRepository();
    await _pump(tester, repository: repository);

    await tester.tap(find.byKey(const Key('assessmentSettingsEditButton')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('assessmentSettingsSaveButton')));
    await tester.pump();

    expect(find.text('No changes to save.'), findsOneWidget);
    expect(repository.updateCalls, 0);

    await tester.tap(find.byKey(const Key('assessmentSettingsEditButton')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('assessmentSettingsScoreDifferenceField')),
      '6',
    );
    await tester.tap(find.byKey(const Key('assessmentSettingsSaveButton')));
    await tester.pump();
    await tester.pump();

    expect(find.text('Assessment settings saved.'), findsOneWidget);
    expect(repository.updateCalls, 1);
  });

  testWidgets('announces submitting and read-only reconciliation progress', (
    tester,
  ) async {
    final repository = _ControlledMutationRepository();
    await _pump(tester, repository: repository);

    await tester.tap(find.byKey(const Key('assessmentSettingsEditButton')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('assessmentSettingsScoreDifferenceField')),
      '6',
    );
    await tester.tap(find.byKey(const Key('assessmentSettingsSaveButton')));
    await tester.pump();

    expect(find.text('Saving assessment settings…'), findsOneWidget);
    repository.updateResult.completeError(
      const InstitutionAssessmentSettingsUpdateOutcomeUnknownException(),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Checking current server settings…'), findsOneWidget);
    expect(
      find.text(
        'The request result could not be confirmed. Checking the current server state…',
      ),
      findsOneWidget,
    );
    repository.reconciliationRead.complete(_settings(score: '6'));
    await tester.pump();
    await tester.pump();
  });

  testWidgets('keeps an unprovable PUT outcome explicitly unconfirmed', (
    tester,
  ) async {
    final repository = _UnconfirmedRepository();
    await _pump(tester, repository: repository);

    await tester.tap(find.byKey(const Key('assessmentSettingsEditButton')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('assessmentSettingsScoreDifferenceField')),
      '6',
    );
    await tester.tap(find.byKey(const Key('assessmentSettingsSaveButton')));
    await tester.pump();
    await tester.pump();

    expect(
      find.text(
        'Current server settings differ from your submitted values. This request result could not be confirmed.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('saved'), findsNothing);
    expect(repository.updateCalls, 1);
    expect(repository.fetchCalls, 2);
  });

  testWidgets(
    'does not convert matching reconciliation state into save success',
    (tester) async {
      final repository = _MatchingUnconfirmedRepository();
      await _pump(tester, repository: repository);

      await tester.tap(find.byKey(const Key('assessmentSettingsEditButton')));
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('assessmentSettingsScoreDifferenceField')),
        '6',
      );
      await tester.tap(find.byKey(const Key('assessmentSettingsSaveButton')));
      await tester.pump();
      await tester.pump();

      expect(
        find.text(
          'Current server settings match your submitted values, but this request result could not be confirmed.',
        ),
        findsOneWidget,
      );
      expect(find.text('Assessment settings saved.'), findsNothing);
      expect(repository.updateCalls, 1);
      expect(repository.fetchCalls, 2);
    },
  );

  testWidgets(
    'states when neither PUT outcome nor current server settings are confirmed',
    (tester) async {
      final repository = _UnavailableReconciliationRepository();
      await _pump(tester, repository: repository);

      await tester.tap(find.byKey(const Key('assessmentSettingsEditButton')));
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('assessmentSettingsScoreDifferenceField')),
        '6',
      );
      await tester.tap(find.byKey(const Key('assessmentSettingsSaveButton')));
      await tester.pump();
      await tester.pump();

      expect(
        find.text(
          'The request result and current server settings could not be confirmed. Refresh before making a new change.',
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('assessmentSettingsRefreshButton')),
        findsOneWidget,
      );
      expect(find.textContaining('saved'), findsNothing);
      expect(repository.updateCalls, 1);
      expect(repository.fetchCalls, 2);

      tester
          .widget<OutlinedButton>(
            find.byKey(const Key('assessmentSettingsRefreshButton')),
          )
          .onPressed!();
      await tester.pumpAndSettle();

      expect(repository.fetchCalls, 3);
      expect(
        find.text('Assessment settings could not be loaded.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('remains scrollable at 800x600 and text scale 2', (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pump(tester, textScaler: const TextScaler.linear(2));
    await tester.tap(find.byKey(const Key('assessmentSettingsEditButton')));
    await tester.pump();

    expect(find.byType(SingleChildScrollView), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus, isNotNull);
  });

  testWidgets('remains usable at 1440x900 and exposes live semantics', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    final repository = _ControlledReadRepository();
    await _pump(
      tester,
      repository: repository,
      textScaler: const TextScaler.linear(2),
    );

    expect(
      find.bySemanticsLabel('Loading assessment settings'),
      findsOneWidget,
    );
    repository.initialRead.complete(_settings());
    await tester.pump();
    await tester.pump();
    expect(find.text('Educational policy status: Configured.'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsWidgets);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets(
    'local validation focuses and announces the first invalid field',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester);
      await tester.tap(find.byKey(const Key('assessmentSettingsEditButton')));
      await tester.pump();
      final score = find.byKey(
        const Key('assessmentSettingsScoreDifferenceField'),
      );
      await tester.enterText(score, 'invalid');
      await _tapVisible(
        tester,
        find.byKey(const Key('assessmentSettingsSaveButton')),
      );
      await tester.pump();

      final editable = tester.widget<EditableText>(
        find.descendant(of: score, matching: find.byType(EditableText)),
      );
      expect(FocusManager.instance.primaryFocus, same(editable.focusNode));
      expect(
        find.text('Enter a value from 0 to 100 using up to 8 decimal places.'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp('Acceptable Homework')),
        findsWidgets,
      );
      semantics.dispose();
    },
  );
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
}

Future<void> _selectDropdownValue(
  WidgetTester tester, {
  required Key fieldKey,
  required String label,
}) async {
  final field = find.byKey(fieldKey);
  await tester.ensureVisible(field);
  await tester.tap(field);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> _expectCancelRestoresInitiatingButtonFocus(
  WidgetTester tester, {
  required _FakeRepository repository,
  required String expectedLabel,
  required LogicalKeyboardKey activationKey,
}) async {
  await _pump(tester, repository: repository);
  final editFinder = find.byKey(const Key('assessmentSettingsEditButton'));
  final originalButton = tester.widget<FilledButton>(editFinder);
  originalButton.focusNode!.requestFocus();
  await tester.pump();
  expect(FocusManager.instance.primaryFocus, same(originalButton.focusNode));

  await tester.sendKeyEvent(activationKey);
  await tester.pump();
  expect(find.byKey(const Key('assessmentSettingsForm')), findsOneWidget);
  await tester.tap(find.byKey(const Key('assessmentSettingsCancelButton')));
  await tester.pump();
  await tester.pump();

  final restoredButton = tester.widget<FilledButton>(editFinder);
  expect(find.widgetWithText(FilledButton, expectedLabel), findsOneWidget);
  expect(restoredButton.focusNode, same(originalButton.focusNode));
  expect(FocusManager.instance.primaryFocus, same(restoredButton.focusNode));
  expect(repository.fetchCalls, 1);
  expect(repository.updateCalls, 0);
}

Future<void> _pump(
  WidgetTester tester, {
  _FakeRepository? repository,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authSessionControllerProvider.overrideWith(() => _FakeAuthController()),
        appDeviceSurfaceProvider.overrideWithValue(AppDeviceSurface.desktop),
        institutionAssessmentSettingsRepositoryProvider.overrideWithValue(
          repository ?? _FakeRepository(),
        ),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: textScaler),
          child: const Scaffold(
            body: InstitutionAdminSettingsScreen(
              routePath: '/institution-admin/settings',
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

class _FakeRepository implements InstitutionAssessmentSettingsRepository {
  _FakeRepository({InstitutionAssessmentSettings? settings})
    : _response = settings ?? _settings();

  final InstitutionAssessmentSettings _response;
  var fetchCalls = 0;
  var updateCalls = 0;
  @override
  Future<InstitutionAssessmentSettings> fetchSettings() async {
    fetchCalls += 1;
    return _response;
  }

  @override
  Future<InstitutionAssessmentSettings> updateSettings(
    InstitutionAssessmentSettingsUpdateRequest request,
  ) async {
    updateCalls += 1;
    return _settings(score: request.acceptableScoreDifference.canonical);
  }
}

class _FailingRepository extends _FakeRepository {
  @override
  Future<InstitutionAssessmentSettings> fetchSettings() async {
    fetchCalls += 1;
    throw StateError('controlled read failure');
  }
}

class _ControlledReadRepository extends _FakeRepository {
  final initialRead = Completer<InstitutionAssessmentSettings>();
  final refreshRead = Completer<InstitutionAssessmentSettings>();

  @override
  Future<InstitutionAssessmentSettings> fetchSettings() {
    fetchCalls += 1;
    return fetchCalls == 1 ? initialRead.future : refreshRead.future;
  }
}

class _UnconfirmedRepository extends _FakeRepository {
  @override
  Future<InstitutionAssessmentSettings> updateSettings(
    InstitutionAssessmentSettingsUpdateRequest request,
  ) async {
    updateCalls += 1;
    throw const InstitutionAssessmentSettingsUpdateOutcomeUnknownException();
  }
}

class _ControlledMutationRepository extends _FakeRepository {
  final updateResult = Completer<InstitutionAssessmentSettings>();
  final reconciliationRead = Completer<InstitutionAssessmentSettings>();

  @override
  Future<InstitutionAssessmentSettings> fetchSettings() async {
    fetchCalls += 1;
    if (fetchCalls == 1) {
      return _settings();
    }
    return reconciliationRead.future;
  }

  @override
  Future<InstitutionAssessmentSettings> updateSettings(
    InstitutionAssessmentSettingsUpdateRequest request,
  ) {
    updateCalls += 1;
    return updateResult.future;
  }
}

class _MatchingUnconfirmedRepository extends _UnconfirmedRepository {
  InstitutionAssessmentSettingsUpdateRequest? _submittedRequest;

  @override
  Future<InstitutionAssessmentSettings> fetchSettings() async {
    fetchCalls += 1;
    if (fetchCalls == 1) {
      return _settings();
    }
    return _settings(
      score: _submittedRequest!.acceptableScoreDifference.canonical,
    );
  }

  @override
  Future<InstitutionAssessmentSettings> updateSettings(
    InstitutionAssessmentSettingsUpdateRequest request,
  ) async {
    _submittedRequest = request;
    return super.updateSettings(request);
  }
}

class _UnavailableReconciliationRepository extends _UnconfirmedRepository {
  @override
  Future<InstitutionAssessmentSettings> fetchSettings() async {
    fetchCalls += 1;
    if (fetchCalls == 1) {
      return _settings();
    }
    throw StateError('controlled reconciliation read failure');
  }
}

class _FakeAuthController extends AuthSessionController {
  @override
  AuthSessionState build() => AuthSessionState.authenticated(_admin());
}

AuthUser _admin() => const AuthUser(
  id: 'admin-a',
  institutionId: 'institution-a',
  role: UserRole.institutionAdmin,
  fullName: 'Admin',
  loginName: 'admin',
  email: null,
  phone: null,
  isActive: true,
  mustChangePassword: false,
  institution: AuthInstitution(
    id: 'institution-a',
    name: 'School',
    status: 'active',
    timezone: 'Asia/Tashkent',
  ),
);

InstitutionAssessmentSettings _settings({String score = '5'}) =>
    InstitutionAssessmentSettings(
      educationalPolicyConfigured: true,
      acceptableScoreDifference: ExactAssessmentDecimal.parseUserInput(score),
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

InstitutionAssessmentSettings _unconfiguredSettings() =>
    const InstitutionAssessmentSettings(
      educationalPolicyConfigured: false,
      acceptableScoreDifference: null,
      blitzTimerStartMode: null,
      studentResultReleaseMode: null,
      parentResultReleaseMode: null,
      timezone: 'Asia/Tashkent',
      learningMaterialMaxMb: 25,
      studentSubmissionMaxMb: 15,
      platformLearningMaterialMaxMb: 25,
      platformStudentSubmissionMaxMb: 15,
      homeworkNormalAttempts: 3,
      blitzNormalAttempts: 1,
      blitzMaxAdditionalExceptionAttempts: 1,
    );

InstitutionAssessmentSettings _partiallyConfiguredSettings() =>
    InstitutionAssessmentSettings(
      educationalPolicyConfigured: false,
      acceptableScoreDifference: ExactAssessmentDecimal.parseUserInput('7.5'),
      blitzTimerStartMode: BlitzTimerStartMode.individual,
      studentResultReleaseMode: null,
      parentResultReleaseMode: ParentResultReleaseMode.withStudent,
      timezone: 'Asia/Tashkent',
      learningMaterialMaxMb: 20,
      studentSubmissionMaxMb: 10,
      platformLearningMaterialMaxMb: 25,
      platformStudentSubmissionMaxMb: 15,
      homeworkNormalAttempts: 3,
      blitzNormalAttempts: 1,
      blitzMaxAdditionalExceptionAttempts: 1,
    );
