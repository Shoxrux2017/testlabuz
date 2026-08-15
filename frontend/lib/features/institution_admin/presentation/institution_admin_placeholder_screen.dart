import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_route_paths.dart';
import '../application/institution_user_create_controller.dart';
import '../application/institution_user_create_state.dart';
import '../domain/institution_user.dart';
import '../domain/institution_user_create.dart';
import 'institution_admin_user_detail_screen.dart';
import 'institution_admin_users_screen.dart';

const _placeholderPadding = 24.0;
const _placeholderMaxWidth = 720.0;

class InstitutionAdminUsersPlaceholderScreen extends StatelessWidget {
  const InstitutionAdminUsersPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const InstitutionAdminUsersScreen();
  }
}

class InstitutionAdminUserCreatePlaceholderScreen
    extends ConsumerStatefulWidget {
  const InstitutionAdminUserCreatePlaceholderScreen({super.key});

  @override
  ConsumerState<InstitutionAdminUserCreatePlaceholderScreen> createState() =>
      _InstitutionAdminUserCreateScreenState();
}

class _InstitutionAdminUserCreateScreenState
    extends ConsumerState<InstitutionAdminUserCreatePlaceholderScreen> {
  late final TextEditingController _fullNameController;
  late final TextEditingController _loginNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _passwordController;
  late final FocusNode _roleFocusNode;
  late final FocusNode _fullNameFocusNode;
  late final FocusNode _loginNameFocusNode;
  late final FocusNode _emailFocusNode;
  late final FocusNode _phoneFocusNode;
  late final FocusNode _passwordFocusNode;
  var _obscurePassword = true;
  var _handledPasswordWipeGeneration = 0;
  InstitutionUserCreateField? _handledFirstError;
  String? _handledSuccessUserId;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController();
    _loginNameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _passwordController = TextEditingController();
    _roleFocusNode = FocusNode();
    _fullNameFocusNode = FocusNode();
    _loginNameFocusNode = FocusNode();
    _emailFocusNode = FocusNode();
    _phoneFocusNode = FocusNode();
    _passwordFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _clearControllers();
    _fullNameController.dispose();
    _loginNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _roleFocusNode.dispose();
    _fullNameFocusNode.dispose();
    _loginNameFocusNode.dispose();
    _emailFocusNode.dispose();
    _phoneFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(institutionUserCreateControllerProvider);
    final controller = ref.read(
      institutionUserCreateControllerProvider.notifier,
    );
    _handleEffects(state);
    _syncControllers(state.form);

    return PopScope(
      canPop: !state.isBusy,
      child: FocusTraversalGroup(
        policy: WidgetOrderTraversalPolicy(),
        child: Semantics(
          key: const Key('institutionAdminUserCreateScreen'),
          container: true,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(_placeholderPadding),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: _placeholderMaxWidth,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Create User',
                      key: const Key('institutionUserCreateHeading'),
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 20),
                    if (state.isUnknown)
                      _UnknownCreateOutcome(
                        possibleMatch:
                            state.status ==
                            InstitutionUserCreateStatus.unknownPossibleMatch,
                        onReviewUsers: () {
                          controller.leaveRoute();
                          _clearControllers();
                          context.goNamed(AppRouteNames.institutionAdminUsers);
                        },
                      )
                    else
                      AutofillGroup(
                        child: _CreateUserForm(
                          state: state,
                          fullNameController: _fullNameController,
                          loginNameController: _loginNameController,
                          emailController: _emailController,
                          phoneController: _phoneController,
                          passwordController: _passwordController,
                          roleFocusNode: _roleFocusNode,
                          fullNameFocusNode: _fullNameFocusNode,
                          loginNameFocusNode: _loginNameFocusNode,
                          emailFocusNode: _emailFocusNode,
                          phoneFocusNode: _phoneFocusNode,
                          passwordFocusNode: _passwordFocusNode,
                          obscurePassword: _obscurePassword,
                          onRoleChanged: controller.updateRole,
                          onFullNameChanged: controller.updateFullName,
                          onLoginNameChanged: controller.updateLoginName,
                          onEmailChanged: controller.updateEmail,
                          onPhoneChanged: controller.updatePhone,
                          onPasswordChanged: (_) =>
                              controller.clearPasswordError(),
                          onTogglePasswordVisibility: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                          onCancel: state.isBusy
                              ? null
                              : () {
                                  controller.leaveRoute();
                                  _clearControllers();
                                  context.goNamed(
                                    AppRouteNames.institutionAdminUsers,
                                  );
                                },
                          onSubmit: state.canSubmit ? _submit : null,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _submit() {
    ref
        .read(institutionUserCreateControllerProvider.notifier)
        .submit(password: _passwordController.text);
  }

  void _handleEffects(InstitutionUserCreateState state) {
    if (_handledPasswordWipeGeneration != state.passwordWipeGeneration) {
      _handledPasswordWipeGeneration = state.passwordWipeGeneration;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _passwordController.clear();
        }
      });
    }

    final firstError = state.firstErrorField;
    if (firstError != null && firstError != _handledFirstError) {
      _handledFirstError = firstError;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _focusNodeFor(firstError).requestFocus();
        }
      });
    } else if (firstError == null) {
      _handledFirstError = null;
    }

    final userId = state.confirmedUserId;
    if (userId != null && userId != _handledSuccessUserId) {
      _handledSuccessUserId = userId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _clearControllers();
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            const SnackBar(
              key: Key('institutionUserCreateSuccessSnackBar'),
              content: Text('User created successfully.'),
            ),
          );
        context.goNamed(
          AppRouteNames.institutionAdminUserDetail,
          pathParameters: {
            AppRoutePaths.institutionAdminUserIdParameter: userId,
          },
        );
      });
    }
  }

  void _syncControllers(InstitutionUserCreateFormValue form) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _setText(_fullNameController, form.fullName);
      _setText(_loginNameController, form.loginName);
      _setText(_emailController, form.email);
      _setText(_phoneController, form.phone);
    });
  }

  void _setText(TextEditingController controller, String value) {
    if (controller.text == value) {
      return;
    }
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  FocusNode _focusNodeFor(InstitutionUserCreateField field) {
    return switch (field) {
      InstitutionUserCreateField.role => _roleFocusNode,
      InstitutionUserCreateField.fullName => _fullNameFocusNode,
      InstitutionUserCreateField.loginName => _loginNameFocusNode,
      InstitutionUserCreateField.email => _emailFocusNode,
      InstitutionUserCreateField.phone => _phoneFocusNode,
      InstitutionUserCreateField.password => _passwordFocusNode,
    };
  }

  void _clearControllers() {
    _fullNameController.clear();
    _loginNameController.clear();
    _emailController.clear();
    _phoneController.clear();
    _passwordController.clear();
  }
}

class _CreateUserForm extends StatelessWidget {
  const _CreateUserForm({
    required this.state,
    required this.fullNameController,
    required this.loginNameController,
    required this.emailController,
    required this.phoneController,
    required this.passwordController,
    required this.roleFocusNode,
    required this.fullNameFocusNode,
    required this.loginNameFocusNode,
    required this.emailFocusNode,
    required this.phoneFocusNode,
    required this.passwordFocusNode,
    required this.obscurePassword,
    required this.onRoleChanged,
    required this.onFullNameChanged,
    required this.onLoginNameChanged,
    required this.onEmailChanged,
    required this.onPhoneChanged,
    required this.onPasswordChanged,
    required this.onTogglePasswordVisibility,
    required this.onCancel,
    required this.onSubmit,
  });

  final InstitutionUserCreateState state;
  final TextEditingController fullNameController;
  final TextEditingController loginNameController;
  final TextEditingController emailController;
  final TextEditingController phoneController;
  final TextEditingController passwordController;
  final FocusNode roleFocusNode;
  final FocusNode fullNameFocusNode;
  final FocusNode loginNameFocusNode;
  final FocusNode emailFocusNode;
  final FocusNode phoneFocusNode;
  final FocusNode passwordFocusNode;
  final bool obscurePassword;
  final ValueChanged<InstitutionUserRole?> onRoleChanged;
  final ValueChanged<String> onFullNameChanged;
  final ValueChanged<String> onLoginNameChanged;
  final ValueChanged<String> onEmailChanged;
  final ValueChanged<String> onPhoneChanged;
  final ValueChanged<String> onPasswordChanged;
  final VoidCallback onTogglePasswordVisibility;
  final VoidCallback? onCancel;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    final canEdit = state.canEdit;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.formError case final message?) ...[
          _CreateFormMessage(
            key: const Key('institutionUserCreateFormError'),
            message: message,
            isError: true,
          ),
          const SizedBox(height: 16),
        ],
        if (state.isBusy) ...[
          const _CreateFormMessage(
            key: Key('institutionUserCreateBusy'),
            message: 'Creating user',
            isError: false,
          ),
          const SizedBox(height: 16),
        ],
        DropdownButtonFormField<InstitutionUserRole>(
          key: const Key('institutionUserCreateRoleField'),
          focusNode: roleFocusNode,
          initialValue: state.form.role,
          items: const [
            DropdownMenuItem(
              value: InstitutionUserRole.teacher,
              child: Text('Teacher'),
            ),
            DropdownMenuItem(
              value: InstitutionUserRole.student,
              child: Text('Student'),
            ),
            DropdownMenuItem(
              value: InstitutionUserRole.parent,
              child: Text('Parent'),
            ),
          ],
          onChanged: canEdit ? onRoleChanged : null,
          decoration: InputDecoration(
            labelText: 'Role',
            errorText: state.errorTextFor(InstitutionUserCreateField.role),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          key: const Key('institutionUserCreateFullNameField'),
          controller: fullNameController,
          focusNode: fullNameFocusNode,
          enabled: canEdit,
          autofocus: true,
          textInputAction: TextInputAction.next,
          onChanged: onFullNameChanged,
          onSubmitted: (_) => loginNameFocusNode.requestFocus(),
          decoration: InputDecoration(
            labelText: 'Full name',
            errorText: state.errorTextFor(InstitutionUserCreateField.fullName),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          key: const Key('institutionUserCreateLoginNameField'),
          controller: loginNameController,
          focusNode: loginNameFocusNode,
          enabled: canEdit,
          textInputAction: TextInputAction.next,
          onChanged: onLoginNameChanged,
          onSubmitted: (_) => emailFocusNode.requestFocus(),
          decoration: InputDecoration(
            labelText: 'Login name',
            errorText: state.errorTextFor(InstitutionUserCreateField.loginName),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          key: const Key('institutionUserCreateEmailField'),
          controller: emailController,
          focusNode: emailFocusNode,
          enabled: canEdit,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          onChanged: onEmailChanged,
          onSubmitted: (_) => phoneFocusNode.requestFocus(),
          decoration: InputDecoration(
            labelText: 'Email (optional)',
            errorText: state.errorTextFor(InstitutionUserCreateField.email),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          key: const Key('institutionUserCreatePhoneField'),
          controller: phoneController,
          focusNode: phoneFocusNode,
          enabled: canEdit,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          onChanged: onPhoneChanged,
          onSubmitted: (_) => passwordFocusNode.requestFocus(),
          decoration: InputDecoration(
            labelText: 'Phone (optional)',
            errorText: state.errorTextFor(InstitutionUserCreateField.phone),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          key: const Key('institutionUserCreatePasswordField'),
          controller: passwordController,
          focusNode: passwordFocusNode,
          enabled: canEdit,
          obscureText: obscurePassword,
          autocorrect: false,
          enableSuggestions: false,
          autofillHints: const [AutofillHints.newPassword],
          textInputAction: TextInputAction.done,
          onChanged: onPasswordChanged,
          onSubmitted: (_) {
            if (onSubmit != null) {
              onSubmit!();
            }
          },
          decoration: InputDecoration(
            labelText: 'Initial password',
            helperText: 'The user must change this password at first login.',
            errorText: state.errorTextFor(InstitutionUserCreateField.password),
            suffixIcon: IconButton(
              key: const Key('institutionUserCreatePasswordVisibilityButton'),
              tooltip: obscurePassword ? 'Show password' : 'Hide password',
              onPressed: canEdit ? onTogglePasswordVisibility : null,
              icon: Icon(
                obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 12,
          runSpacing: 12,
          children: [
            TextButton(
              key: const Key('institutionUserCreateCancelButton'),
              onPressed: onCancel,
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              key: const Key('institutionUserCreateSubmitButton'),
              onPressed: onSubmit,
              icon: state.isBusy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.person_add_outlined),
              label: Text(state.isBusy ? 'Creating user' : 'Create User'),
            ),
          ],
        ),
      ],
    );
  }
}

class _CreateFormMessage extends StatelessWidget {
  const _CreateFormMessage({
    required super.key,
    required this.message,
    required this.isError,
  });

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = isError ? colorScheme.error : colorScheme.primary;

    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(
                isError ? Icons.error_outline : Icons.hourglass_top,
                color: color,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnknownCreateOutcome extends StatelessWidget {
  const _UnknownCreateOutcome({
    required this.possibleMatch,
    required this.onReviewUsers,
  });

  final bool possibleMatch;
  final VoidCallback onReviewUsers;

  @override
  Widget build(BuildContext context) {
    final message = possibleMatch
        ? 'A matching user is visible, but the app cannot confirm that this request created it. Review Users before trying again.'
        : 'The request may have completed. Review Users before trying again.';

    return Semantics(
      key: const Key('institutionUserCreateUnknownOutcome'),
      liveRegion: true,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.primary),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Creation outcome unknown',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(message),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  key: const Key('institutionUserCreateReviewUsersButton'),
                  onPressed: onReviewUsers,
                  child: const Text('Review Users'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class InstitutionAdminUserDetailPlaceholderScreen extends StatelessWidget {
  const InstitutionAdminUserDetailPlaceholderScreen({
    required this.userId,
    super.key,
  });

  final String userId;

  @override
  Widget build(BuildContext context) {
    return InstitutionAdminUserDetailScreen(userId: userId);
  }
}

class InstitutionAdminSettingsPlaceholderScreen extends StatelessWidget {
  const InstitutionAdminSettingsPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _InstitutionAdminPlaceholder(
      placeholderKey: Key('institutionAdminSettingsPlaceholder'),
      message:
          'Assessment settings and understanding categories will be implemented in S03-FE-008 and S03-FE-009.',
    );
  }
}

class _InstitutionAdminPlaceholder extends StatelessWidget {
  const _InstitutionAdminPlaceholder({
    required this.placeholderKey,
    required this.message,
  });

  final Key placeholderKey;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(_placeholderPadding),
        child: ConstrainedBox(
          key: placeholderKey,
          constraints: const BoxConstraints(maxWidth: _placeholderMaxWidth),
          child: Text(message, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
