import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_state.dart';
import 'package:testlabuz_client/features/auth/domain/auth_institution.dart';
import 'package:testlabuz_client/features/auth/domain/auth_user.dart';
import 'package:testlabuz_client/features/auth/domain/user_role.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_assessment_settings_repository_impl.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_understanding_categories_repository_impl.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_assessment_settings.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_assessment_settings_repository.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_understanding_categories.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_understanding_categories_repository.dart';
import 'package:testlabuz_client/features/institution_admin/presentation/institution_admin_settings_screen.dart';
import 'package:testlabuz_client/features/institution_admin/presentation/institution_understanding_categories_section.dart';

void main() {
  testWidgets('renders fixed identities, exact ranges and locked meanings', (
    tester,
  ) async {
    await _pumpSection(tester);

    expect(
      find.text('Understanding category status: Configured.'),
      findsOneWidget,
    );
    for (final definition in UnderstandingCategoryDefinition.values) {
      expect(
        find.text('${definition.sortOrder}. ${definition.label}'),
        findsOneWidget,
      );
      expect(find.text(definition.code), findsOneWidget);
    }
    expect(
      find.text(
        'All integer scores from 0 through 100 are covered exactly once.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('integer category_score'), findsOneWidget);
    expect(find.textContaining('It is not a low score'), findsOneWidget);
    expect(find.textContaining('never silently rewrite'), findsOneWidget);
  });

  testWidgets(
    'unconfigured state exposes eight blank fields and fixed final row',
    (tester) async {
      final repository = _CategoryRepository(
        configuration:
            InstitutionUnderstandingCategoryConfiguration.unconfigured(),
      );
      await _pumpSection(tester, categoryRepository: repository);

      expect(
        find.text('Understanding category status: Configuration required.'),
        findsOneWidget,
      );
      tester
          .widget<FilledButton>(
            find.byKey(const Key('understandingCategoriesEditButton')),
          )
          .onPressed!();
      await tester.pump();

      expect(find.byType(TextFormField), findsNWidgets(8));
      for (final field in InstitutionUnderstandingCategoryField.values) {
        expect(
          tester
              .widget<TextFormField>(
                find.byKey(Key('understandingCategory${field.name}Field')),
              )
              .controller!
              .text,
          isEmpty,
        );
      }
      expect(
        find.byKey(const Key('understandingCategoryNotCompletedReadOnly')),
        findsOneWidget,
      );
      expect(repository.updateCalls, 0);
    },
  );

  testWidgets(
    'validates raw integer input before sending and focuses first error',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final repository = _CategoryRepository();
      await _pumpSection(tester, categoryRepository: repository);
      tester
          .widget<FilledButton>(
            find.byKey(const Key('understandingCategoriesEditButton')),
          )
          .onPressed!();
      await tester.pump();
      final firstField = find.byKey(
        const Key('understandingCategoryunderstoodWellMinField'),
      );
      await tester.enterText(firstField, '01');
      tester
          .widget<FilledButton>(
            find.byKey(const Key('understandingCategoriesSaveButton')),
          )
          .onPressed!();
      await tester.pump();

      expect(
        find.text('Enter a whole number from 0 to 100 without leading zeroes.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('cover every integer score from 0 through 100'),
        findsOneWidget,
      );
      final editable = tester.widget<EditableText>(
        find.descendant(of: firstField, matching: find.byType(EditableText)),
      );
      expect(FocusManager.instance.primaryFocus, same(editable.focusNode));
      expect(repository.updateCalls, 0);
      semantics.dispose();
    },
  );

  testWidgets('matching direct success is announced after one replacement', (
    tester,
  ) async {
    final repository = _CategoryRepository();
    await _pumpSection(tester, categoryRepository: repository);
    tester
        .widget<FilledButton>(
          find.byKey(const Key('understandingCategoriesEditButton')),
        )
        .onPressed!();
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('understandingCategoryunderstoodWellMinField')),
      '87',
    );
    await tester.enterText(
      find.byKey(const Key('understandingCategorypartiallyUnderstoodMaxField')),
      '86',
    );
    tester
        .widget<FilledButton>(
          find.byKey(const Key('understandingCategoriesSaveButton')),
        )
        .onPressed!();
    await tester.pump();
    await tester.pump();

    expect(find.text('Understanding categories saved.'), findsOneWidget);
    expect(repository.updateCalls, 1);
    expect(repository.fetchCalls, 1);
  });

  testWidgets('category mutation stays independent from assessment controls', (
    tester,
  ) async {
    final completion =
        Completer<InstitutionUnderstandingCategoryConfiguration>();
    final categories = _CategoryRepository(updateCompletion: completion);
    await _pumpSettingsScreen(
      tester,
      categoryRepository: categories,
      assessmentRepository: _AssessmentRepository(),
    );
    tester
        .widget<FilledButton>(
          find.byKey(const Key('understandingCategoriesEditButton')),
        )
        .onPressed!();
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('understandingCategoryunderstoodWellMinField')),
      '87',
    );
    await tester.enterText(
      find.byKey(const Key('understandingCategorypartiallyUnderstoodMaxField')),
      '86',
    );
    tester
        .widget<FilledButton>(
          find.byKey(const Key('understandingCategoriesSaveButton')),
        )
        .onPressed!();
    await tester.pump();

    expect(categories.updateCalls, 1);
    expect(
      find.byKey(const Key('understandingCategoriesProgress')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('understandingCategoriesSaveButton')),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('assessmentSettingsEditButton')),
          )
          .onPressed,
      isNotNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const Key('assessmentSettingsRefreshButton')),
          )
          .onPressed,
      isNotNull,
    );
    completion.complete(_changedConfiguration());
    await tester.pump();
    await tester.pump();
  });

  testWidgets('load error exposes category-only Retry and recovers', (
    tester,
  ) async {
    final repository = _RecoveringCategoryRepository();
    await _pumpSection(tester, categoryRepository: repository);

    expect(
      find.text('Understanding categories could not be loaded.'),
      findsOneWidget,
    );
    tester
        .widget<FilledButton>(
          find.byKey(const Key('understandingCategoriesRetryButton')),
        )
        .onPressed!();
    await tester.pump();
    await tester.pump();

    expect(
      find.text('Understanding category status: Configured.'),
      findsOneWidget,
    );
    expect(repository.fetchCalls, 2);
  });

  testWidgets('matching reconciliation stays visibly unconfirmed', (
    tester,
  ) async {
    final repository = _UnknownCategoryRepository();
    await _pumpSection(tester, categoryRepository: repository);
    tester
        .widget<FilledButton>(
          find.byKey(const Key('understandingCategoriesEditButton')),
        )
        .onPressed!();
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('understandingCategoryunderstoodWellMinField')),
      '87',
    );
    await tester.enterText(
      find.byKey(const Key('understandingCategorypartiallyUnderstoodMaxField')),
      '86',
    );
    tester
        .widget<FilledButton>(
          find.byKey(const Key('understandingCategoriesSaveButton')),
        )
        .onPressed!();
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(
      find.text(
        'Current server categories match your submitted ranges, but this request result could not be confirmed.',
      ),
      findsOneWidget,
    );
    expect(find.text('Understanding categories saved.'), findsNothing);
    expect(repository.updateCalls, 1);
    expect(repository.fetchCalls, 2);
  });

  testWidgets('dirty category Refresh requires explicit discard', (
    tester,
  ) async {
    final repository = _CategoryRepository();
    await _pumpSection(tester, categoryRepository: repository);
    tester
        .widget<FilledButton>(
          find.byKey(const Key('understandingCategoriesEditButton')),
        )
        .onPressed!();
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('understandingCategoryunderstoodWellMinField')),
      '87',
    );
    await tester.pump();

    tester
        .widget<OutlinedButton>(
          find.byKey(const Key('understandingCategoriesEditRefreshButton')),
        )
        .onPressed!();
    await tester.pump();
    expect(find.text('Discard category changes?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Keep editing'));
    await tester.pumpAndSettle();
    expect(repository.fetchCalls, 1);

    tester
        .widget<OutlinedButton>(
          find.byKey(const Key('understandingCategoriesEditRefreshButton')),
        )
        .onPressed!();
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Discard and refresh'));
    await tester.pump();
    await tester.pump();

    expect(repository.fetchCalls, 2);
    expect(
      find.byKey(const Key('understandingCategoriesSummary')),
      findsOneWidget,
    );
    expect(repository.updateCalls, 0);
  });

  testWidgets('remains scrollable at 800x600 with text scale two', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpSection(tester, textScaler: const TextScaler.linear(2));
    tester
        .widget<FilledButton>(
          find.byKey(const Key('understandingCategoriesEditButton')),
        )
        .onPressed!();
    await tester.pump();

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const Key('understandingCategoriesCoverageSummary')),
      findsOneWidget,
    );
  });

  testWidgets('wide loading and configured states expose live semantics', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    final repository = _ControlledReadCategoryRepository();
    await _pumpSection(
      tester,
      categoryRepository: repository,
      textScaler: const TextScaler.linear(2),
    );

    expect(
      find.bySemanticsLabel('Loading understanding categories'),
      findsOneWidget,
    );
    repository.initialRead.complete(_configuration());
    await tester.pump();
    await tester.pump();

    expect(
      find.text('Understanding category status: Configured.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}

Future<void> _pumpSection(
  WidgetTester tester, {
  _CategoryRepository? categoryRepository,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authSessionControllerProvider.overrideWith(() => _AuthController()),
        appDeviceSurfaceProvider.overrideWithValue(AppDeviceSurface.desktop),
        institutionUnderstandingCategoriesRepositoryProvider.overrideWithValue(
          categoryRepository ?? _CategoryRepository(),
        ),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: textScaler),
          child: const Scaffold(
            body: SingleChildScrollView(
              padding: EdgeInsets.all(24),
              child: InstitutionUnderstandingCategoriesSection(
                routePath: '/institution-admin/settings',
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

Future<void> _pumpSettingsScreen(
  WidgetTester tester, {
  required _CategoryRepository categoryRepository,
  required _AssessmentRepository assessmentRepository,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authSessionControllerProvider.overrideWith(() => _AuthController()),
        appDeviceSurfaceProvider.overrideWithValue(AppDeviceSurface.desktop),
        institutionUnderstandingCategoriesRepositoryProvider.overrideWithValue(
          categoryRepository,
        ),
        institutionAssessmentSettingsRepositoryProvider.overrideWithValue(
          assessmentRepository,
        ),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: InstitutionAdminSettingsScreen(
            routePath: '/institution-admin/settings',
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

class _CategoryRepository
    implements InstitutionUnderstandingCategoriesRepository {
  _CategoryRepository({
    InstitutionUnderstandingCategoryConfiguration? configuration,
    this.updateCompletion,
  }) : configuration = configuration ?? _configuration();

  InstitutionUnderstandingCategoryConfiguration configuration;
  final Completer<InstitutionUnderstandingCategoryConfiguration>?
  updateCompletion;
  var fetchCalls = 0;
  var updateCalls = 0;

  @override
  Future<InstitutionUnderstandingCategoryConfiguration>
  fetchCategories() async {
    fetchCalls += 1;
    return configuration;
  }

  @override
  Future<InstitutionUnderstandingCategoryConfiguration> replaceCategories(
    InstitutionUnderstandingCategoryUpdateRequest request,
  ) async {
    updateCalls += 1;
    final pending = updateCompletion;
    if (pending != null) return pending.future;
    configuration = InstitutionUnderstandingCategoryConfiguration.configured([
      for (final item in request.categories)
        InstitutionUnderstandingCategory(
          definition: item.definition,
          minScore: item.minScore,
          maxScore: item.maxScore,
        ),
    ]);
    return configuration;
  }
}

class _RecoveringCategoryRepository extends _CategoryRepository {
  @override
  Future<InstitutionUnderstandingCategoryConfiguration>
  fetchCategories() async {
    fetchCalls += 1;
    if (fetchCalls == 1) throw StateError('controlled category read failure');
    return configuration;
  }
}

class _UnknownCategoryRepository extends _CategoryRepository {
  @override
  Future<InstitutionUnderstandingCategoryConfiguration>
  fetchCategories() async {
    fetchCalls += 1;
    return fetchCalls == 1 ? configuration : _changedConfiguration();
  }

  @override
  Future<InstitutionUnderstandingCategoryConfiguration> replaceCategories(
    InstitutionUnderstandingCategoryUpdateRequest request,
  ) async {
    updateCalls += 1;
    throw const InstitutionUnderstandingCategoriesUpdateOutcomeUnknownException();
  }
}

class _ControlledReadCategoryRepository extends _CategoryRepository {
  final initialRead =
      Completer<InstitutionUnderstandingCategoryConfiguration>();

  @override
  Future<InstitutionUnderstandingCategoryConfiguration> fetchCategories() {
    fetchCalls += 1;
    return initialRead.future;
  }
}

class _AssessmentRepository implements InstitutionAssessmentSettingsRepository {
  @override
  Future<InstitutionAssessmentSettings> fetchSettings() async => _assessment();

  @override
  Future<InstitutionAssessmentSettings> updateSettings(
    InstitutionAssessmentSettingsUpdateRequest request,
  ) async => _assessment();
}

class _AuthController extends AuthSessionController {
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

InstitutionAssessmentSettings _assessment() => InstitutionAssessmentSettings(
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

InstitutionUnderstandingCategoryConfiguration _configuration() =>
    InstitutionUnderstandingCategoryConfiguration.configured(const [
      InstitutionUnderstandingCategory(
        definition: UnderstandingCategoryDefinition.understoodWell,
        minScore: 86,
        maxScore: 100,
      ),
      InstitutionUnderstandingCategory(
        definition: UnderstandingCategoryDefinition.partiallyUnderstood,
        minScore: 71,
        maxScore: 85,
      ),
      InstitutionUnderstandingCategory(
        definition: UnderstandingCategoryDefinition.needsRevision,
        minScore: 51,
        maxScore: 70,
      ),
      InstitutionUnderstandingCategory(
        definition: UnderstandingCategoryDefinition.needsTeacherSupport,
        minScore: 0,
        maxScore: 50,
      ),
      InstitutionUnderstandingCategory(
        definition: UnderstandingCategoryDefinition.notCompleted,
        minScore: null,
        maxScore: null,
      ),
    ]);

InstitutionUnderstandingCategoryConfiguration _changedConfiguration() =>
    InstitutionUnderstandingCategoryConfiguration.configured(const [
      InstitutionUnderstandingCategory(
        definition: UnderstandingCategoryDefinition.understoodWell,
        minScore: 87,
        maxScore: 100,
      ),
      InstitutionUnderstandingCategory(
        definition: UnderstandingCategoryDefinition.partiallyUnderstood,
        minScore: 71,
        maxScore: 86,
      ),
      InstitutionUnderstandingCategory(
        definition: UnderstandingCategoryDefinition.needsRevision,
        minScore: 51,
        maxScore: 70,
      ),
      InstitutionUnderstandingCategory(
        definition: UnderstandingCategoryDefinition.needsTeacherSupport,
        minScore: 0,
        maxScore: 50,
      ),
      InstitutionUnderstandingCategory(
        definition: UnderstandingCategoryDefinition.notCompleted,
        minScore: null,
        maxScore: null,
      ),
    ]);
