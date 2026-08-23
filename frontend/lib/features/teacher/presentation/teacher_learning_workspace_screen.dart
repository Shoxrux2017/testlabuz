import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/application/auth_session_state.dart';
import '../../auth/domain/auth_user.dart';
import '../../auth/domain/user_role.dart';
import '../application/teacher_group_list_controller.dart';
import '../application/teacher_topic_list_controller.dart';
import 'teacher_assigned_groups_section.dart';
import 'teacher_topics_section.dart';

const _workspaceBreakpoint = 1000.0;
const _pagePadding = 20.0;
const _compactPagePadding = 12.0;
const _sectionSpacing = 20.0;

class TeacherLearningWorkspaceScreen extends ConsumerStatefulWidget {
  const TeacherLearningWorkspaceScreen({super.key});

  @override
  ConsumerState<TeacherLearningWorkspaceScreen> createState() =>
      _TeacherLearningWorkspaceScreenState();
}

class _TeacherLearningWorkspaceScreenState
    extends ConsumerState<TeacherLearningWorkspaceScreen> {
  late final TextEditingController _groupSearchController;
  late final TextEditingController _topicSearchController;

  @override
  void initState() {
    super.initState();
    _groupSearchController = TextEditingController();
    _topicSearchController = TextEditingController();
  }

  @override
  void dispose() {
    _groupSearchController.dispose();
    _topicSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionControllerProvider);
    final surface = ref.watch(appDeviceSurfaceProvider);
    final user = session.user;
    if (session.status != AuthSessionStatus.authenticated || user == null) {
      return const _NeutralTeacherWorkspace();
    }
    if (!_hasEligibleTeacherSession(user, surface)) {
      return const _TeacherWorkspaceUnavailable();
    }

    final groupState = ref.watch(teacherGroupListControllerProvider);
    final topicState = ref.watch(teacherTopicListControllerProvider);
    _syncController(_groupSearchController, groupState.searchDraft);
    _syncController(_topicSearchController, topicState.searchDraft);
    ref.listen<String?>(
      teacherTopicListControllerProvider.select((state) => state.notice),
      (_, notice) {
        if (notice == null || !mounted) {
          return;
        }
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(notice)));
        ref.read(teacherTopicListControllerProvider.notifier).consumeNotice();
      },
    );

    return Scaffold(
      key: const Key('teacherLearningWorkspace'),
      body: SafeArea(
        child: FocusTraversalGroup(
          policy: WidgetOrderTraversalPolicy(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TeacherWorkspaceHeader(user: user),
              const Divider(height: 1),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final usesColumns =
                        constraints.maxWidth >= _workspaceBreakpoint;
                    final padding = constraints.maxWidth < 600
                        ? _compactPagePadding
                        : _pagePadding;
                    final groups = TeacherAssignedGroupsSection(
                      state: groupState,
                      searchController: _groupSearchController,
                    );
                    final topics = TeacherTopicsSection(
                      state: topicState,
                      searchController: _topicSearchController,
                    );

                    return SingleChildScrollView(
                      key: const Key('teacherWorkspaceScroll'),
                      padding: EdgeInsets.all(padding),
                      child: usesColumns
                          ? Row(
                              key: const Key('teacherWorkspaceWideLayout'),
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: groups),
                                const SizedBox(width: _sectionSpacing),
                                Expanded(child: topics),
                              ],
                            )
                          : Column(
                              key: const Key('teacherWorkspaceStackedLayout'),
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                groups,
                                const SizedBox(height: _sectionSpacing),
                                topics,
                              ],
                            ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _syncController(TextEditingController controller, String value) {
    if (controller.text == value) {
      return;
    }

    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }
}

bool _hasEligibleTeacherSession(AuthUser user, AppDeviceSurface surface) {
  final institutionId = user.institutionId;
  final institution = user.institution;

  return user.role == UserRole.teacher &&
      user.isActive &&
      !user.mustChangePassword &&
      institutionId != null &&
      institutionId.trim().isNotEmpty &&
      institution != null &&
      institution.id == institutionId &&
      institution.status == 'active' &&
      (surface == AppDeviceSurface.desktop ||
          surface == AppDeviceSurface.mobile);
}

class _TeacherWorkspaceHeader extends ConsumerWidget {
  const _TeacherWorkspaceHeader({required this.user});

  final AuthUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Wrap(
        key: const Key('teacherWorkspaceHeader'),
        spacing: 20,
        runSpacing: 12,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'TestLabUz',
                key: const Key('teacherProductName'),
                style: textTheme.titleMedium,
              ),
              Text(
                'Teacher',
                key: const Key('teacherRoleLabel'),
                style: textTheme.headlineSmall,
              ),
            ],
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Current user: ${user.fullName}',
                  key: const Key('teacherCurrentUser'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Institution: ${user.institution!.name}',
                  key: const Key('teacherInstitutionName'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          TextButton.icon(
            key: const Key('entryLogoutButton'),
            onPressed: () {
              unawaited(
                ref.read(authSessionControllerProvider.notifier).signOut(),
              );
            },
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}

class _NeutralTeacherWorkspace extends StatelessWidget {
  const _NeutralTeacherWorkspace();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(child: Center(child: CircularProgressIndicator())),
    );
  }
}

class _TeacherWorkspaceUnavailable extends ConsumerWidget {
  const _TeacherWorkspaceUnavailable();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Session route unavailable',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    key: const Key('entryLogoutButton'),
                    onPressed: () {
                      unawaited(
                        ref
                            .read(authSessionControllerProvider.notifier)
                            .signOut(),
                      );
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign out'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
