import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_route_paths.dart';
import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/application/auth_session_state.dart';
import '../application/platform_institution_edit_controller.dart';
import '../application/platform_institution_edit_state.dart';
import '../domain/platform_institution.dart';
import '../domain/platform_institution_edit.dart';
import 'platform_dashboard_formatters.dart';

const _pageSpacing = 24.0;
const _sectionSpacing = 20.0;
const _fieldSpacing = 16.0;
const _formMaxWidth = 760.0;
const _panelRadius = 8.0;

class PlatformOwnerInstitutionEditScreen extends ConsumerStatefulWidget {
  const PlatformOwnerInstitutionEditScreen({
    required this.institutionId,
    super.key,
  });

  final String institutionId;

  @override
  ConsumerState<PlatformOwnerInstitutionEditScreen> createState() {
    return _PlatformOwnerInstitutionEditScreenState();
  }
}

class _PlatformOwnerInstitutionEditScreenState
    extends ConsumerState<PlatformOwnerInstitutionEditScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _descriptionController;

  final _nameFocusNode = FocusNode();
  final _typeFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();
  final _phoneFocusNode = FocusNode();
  final _addressFocusNode = FocusNode();
  final _descriptionFocusNode = FocusNode();

  var _handledSuccessId = '';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _addressController = TextEditingController();
    _descriptionController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    _nameFocusNode.dispose();
    _typeFocusNode.dispose();
    _emailFocusNode.dispose();
    _phoneFocusNode.dispose();
    _addressFocusNode.dispose();
    _descriptionFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionControllerProvider);
    final user = session.user;
    final editKey =
        session.status == AuthSessionStatus.authenticated && user != null
        ? PlatformInstitutionEditKey(
            sessionUserId: user.id,
            sessionInstanceId: identityHashCode(user),
            institutionId: widget.institutionId,
          )
        : null;
    final state = editKey == null
        ? const PlatformInstitutionEditState.initial()
        : ref.watch(platformInstitutionEditControllerProvider(editKey));

    _syncControllers(state.form);
    _handleStateEffects(editKey, state);

    return PopScope(
      canPop: !state.isDirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || !mounted || !state.isDirty) {
          return;
        }

        await _goBackToInstitution(context, state);
      },
      child: SingleChildScrollView(
        key: const Key('platformInstitutionEditSurface'),
        padding: const EdgeInsets.all(_pageSpacing),
        child: Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _formMaxWidth),
            child: _InstitutionEditBody(
              state: state,
              nameController: _nameController,
              emailController: _emailController,
              phoneController: _phoneController,
              addressController: _addressController,
              descriptionController: _descriptionController,
              nameFocusNode: _nameFocusNode,
              typeFocusNode: _typeFocusNode,
              emailFocusNode: _emailFocusNode,
              phoneFocusNode: _phoneFocusNode,
              addressFocusNode: _addressFocusNode,
              descriptionFocusNode: _descriptionFocusNode,
              onBackToInstitution: () => _goBackToInstitution(context, state),
              onBackToInstitutions: () {
                context.go(AppRoutePaths.platformOwnerInstitutions);
              },
              onCheckInstitution: () {
                context.go(
                  AppRoutePaths.platformOwnerInstitutionDetailLocation(
                    widget.institutionId,
                  ),
                );
              },
              onNameChanged: editKey == null
                  ? null
                  : ref
                        .read(
                          platformInstitutionEditControllerProvider(
                            editKey,
                          ).notifier,
                        )
                        .updateName,
              onTypeChanged: editKey == null
                  ? null
                  : ref
                        .read(
                          platformInstitutionEditControllerProvider(
                            editKey,
                          ).notifier,
                        )
                        .updateType,
              onEmailChanged: editKey == null
                  ? null
                  : ref
                        .read(
                          platformInstitutionEditControllerProvider(
                            editKey,
                          ).notifier,
                        )
                        .updateContactEmail,
              onPhoneChanged: editKey == null
                  ? null
                  : ref
                        .read(
                          platformInstitutionEditControllerProvider(
                            editKey,
                          ).notifier,
                        )
                        .updateContactPhone,
              onAddressChanged: editKey == null
                  ? null
                  : ref
                        .read(
                          platformInstitutionEditControllerProvider(
                            editKey,
                          ).notifier,
                        )
                        .updateAddress,
              onDescriptionChanged: editKey == null
                  ? null
                  : ref
                        .read(
                          platformInstitutionEditControllerProvider(
                            editKey,
                          ).notifier,
                        )
                        .updateDescription,
              onRetry: editKey == null
                  ? null
                  : () {
                      ref
                          .read(
                            platformInstitutionEditControllerProvider(
                              editKey,
                            ).notifier,
                          )
                          .retry();
                    },
              onSubmit: editKey == null
                  ? null
                  : () {
                      ref
                          .read(
                            platformInstitutionEditControllerProvider(
                              editKey,
                            ).notifier,
                          )
                          .submit();
                    },
            ),
          ),
        ),
      ),
    );
  }

  void _syncControllers(PlatformInstitutionEditFormValue? form) {
    if (form == null) {
      return;
    }

    _syncController(_nameController, form.name);
    _syncController(_emailController, form.contactEmail);
    _syncController(_phoneController, form.contactPhone);
    _syncController(_addressController, form.address);
    _syncController(_descriptionController, form.description);
  }

  void _syncController(TextEditingController controller, String text) {
    if (controller.text == text) {
      return;
    }

    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _handleStateEffects(
    PlatformInstitutionEditKey? key,
    PlatformInstitutionEditState state,
  ) {
    if (state.firstErrorField != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        _focusField(state.firstErrorField!);
      });
    }

    final result = state.result;
    if (key == null ||
        state.status != PlatformInstitutionEditStatus.success ||
        result == null ||
        _handledSuccessId == result.id) {
      return;
    }

    _handledSuccessId = result.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final router = GoRouter.of(context);
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            key: const Key('platformInstitutionEditSuccessSnackBar'),
            content: Text(result.message),
          ),
        );
      router.go(
        AppRoutePaths.platformOwnerInstitutionDetailLocation(result.id),
      );
    });
  }

  void _focusField(PlatformInstitutionEditField field) {
    final node = switch (field) {
      PlatformInstitutionEditField.name => _nameFocusNode,
      PlatformInstitutionEditField.type => _typeFocusNode,
      PlatformInstitutionEditField.contactEmail => _emailFocusNode,
      PlatformInstitutionEditField.contactPhone => _phoneFocusNode,
      PlatformInstitutionEditField.address => _addressFocusNode,
      PlatformInstitutionEditField.description => _descriptionFocusNode,
    };

    node.requestFocus();
  }

  Future<void> _goBackToInstitution(
    BuildContext context,
    PlatformInstitutionEditState state,
  ) async {
    if (state.isDirty &&
        state.status != PlatformInstitutionEditStatus.success) {
      final shouldLeave = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard institution edits?'),
          content: const Text(
            'Unsaved institution changes will be lost when you leave this form.',
          ),
          actions: [
            TextButton(
              key: const Key('platformInstitutionEditStayButton'),
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Stay'),
            ),
            FilledButton(
              key: const Key('platformInstitutionEditDiscardButton'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Discard'),
            ),
          ],
        ),
      );

      if (shouldLeave != true || !context.mounted) {
        return;
      }
    }

    context.go(
      AppRoutePaths.platformOwnerInstitutionDetailLocation(
        widget.institutionId,
      ),
    );
  }
}

class _InstitutionEditBody extends StatelessWidget {
  const _InstitutionEditBody({
    required this.state,
    required this.nameController,
    required this.emailController,
    required this.phoneController,
    required this.addressController,
    required this.descriptionController,
    required this.nameFocusNode,
    required this.typeFocusNode,
    required this.emailFocusNode,
    required this.phoneFocusNode,
    required this.addressFocusNode,
    required this.descriptionFocusNode,
    required this.onBackToInstitution,
    required this.onBackToInstitutions,
    required this.onCheckInstitution,
    required this.onNameChanged,
    required this.onTypeChanged,
    required this.onEmailChanged,
    required this.onPhoneChanged,
    required this.onAddressChanged,
    required this.onDescriptionChanged,
    required this.onRetry,
    required this.onSubmit,
  });

  final PlatformInstitutionEditState state;
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController phoneController;
  final TextEditingController addressController;
  final TextEditingController descriptionController;
  final FocusNode nameFocusNode;
  final FocusNode typeFocusNode;
  final FocusNode emailFocusNode;
  final FocusNode phoneFocusNode;
  final FocusNode addressFocusNode;
  final FocusNode descriptionFocusNode;
  final VoidCallback onBackToInstitution;
  final VoidCallback onBackToInstitutions;
  final VoidCallback onCheckInstitution;
  final ValueChanged<String>? onNameChanged;
  final ValueChanged<PlatformInstitutionType?>? onTypeChanged;
  final ValueChanged<String>? onEmailChanged;
  final ValueChanged<String>? onPhoneChanged;
  final ValueChanged<String>? onAddressChanged;
  final ValueChanged<String>? onDescriptionChanged;
  final VoidCallback? onRetry;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    return switch (state.status) {
      PlatformInstitutionEditStatus.initial ||
      PlatformInstitutionEditStatus.loading => const _InstitutionEditLoading(),
      PlatformInstitutionEditStatus.notFound => _InstitutionEditNotFound(
        onBack: onBackToInstitutions,
      ),
      PlatformInstitutionEditStatus.loadError => _InstitutionEditLoadError(
        failure: state.failure!,
        isRetryInFlight: state.isRetryInFlight,
        onBack: onBackToInstitutions,
        onRetry: onRetry,
      ),
      PlatformInstitutionEditStatus.accessDenied => _InstitutionEditDenied(
        onBack: onBackToInstitutions,
      ),
      PlatformInstitutionEditStatus.ready ||
      PlatformInstitutionEditStatus.submitting ||
      PlatformInstitutionEditStatus.validationFailure ||
      PlatformInstitutionEditStatus.failure ||
      PlatformInstitutionEditStatus.outcomeUnknown ||
      PlatformInstitutionEditStatus.success => _InstitutionEditForm(
        state: state,
        nameController: nameController,
        emailController: emailController,
        phoneController: phoneController,
        addressController: addressController,
        descriptionController: descriptionController,
        nameFocusNode: nameFocusNode,
        typeFocusNode: typeFocusNode,
        emailFocusNode: emailFocusNode,
        phoneFocusNode: phoneFocusNode,
        addressFocusNode: addressFocusNode,
        descriptionFocusNode: descriptionFocusNode,
        onBack: onBackToInstitution,
        onCancel: onBackToInstitution,
        onCheckInstitution: onCheckInstitution,
        onNameChanged: onNameChanged,
        onTypeChanged: onTypeChanged,
        onEmailChanged: onEmailChanged,
        onPhoneChanged: onPhoneChanged,
        onAddressChanged: onAddressChanged,
        onDescriptionChanged: onDescriptionChanged,
        onSubmit: onSubmit,
      ),
    };
  }
}

class _InstitutionEditLoading extends StatelessWidget {
  const _InstitutionEditLoading();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const Key('platformInstitutionEditLoading'),
      decoration: _panelDecoration(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 48,
          horizontal: _pageSpacing,
        ),
        child: Center(
          child: Semantics(
            label: 'Loading institution for editing',
            liveRegion: true,
            child: const CircularProgressIndicator(),
          ),
        ),
      ),
    );
  }
}

class _InstitutionEditForm extends StatelessWidget {
  const _InstitutionEditForm({
    required this.state,
    required this.nameController,
    required this.emailController,
    required this.phoneController,
    required this.addressController,
    required this.descriptionController,
    required this.nameFocusNode,
    required this.typeFocusNode,
    required this.emailFocusNode,
    required this.phoneFocusNode,
    required this.addressFocusNode,
    required this.descriptionFocusNode,
    required this.onBack,
    required this.onCancel,
    required this.onCheckInstitution,
    required this.onNameChanged,
    required this.onTypeChanged,
    required this.onEmailChanged,
    required this.onPhoneChanged,
    required this.onAddressChanged,
    required this.onDescriptionChanged,
    required this.onSubmit,
  });

  final PlatformInstitutionEditState state;
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController phoneController;
  final TextEditingController addressController;
  final TextEditingController descriptionController;
  final FocusNode nameFocusNode;
  final FocusNode typeFocusNode;
  final FocusNode emailFocusNode;
  final FocusNode phoneFocusNode;
  final FocusNode addressFocusNode;
  final FocusNode descriptionFocusNode;
  final VoidCallback onBack;
  final VoidCallback onCancel;
  final VoidCallback onCheckInstitution;
  final ValueChanged<String>? onNameChanged;
  final ValueChanged<PlatformInstitutionType?>? onTypeChanged;
  final ValueChanged<String>? onEmailChanged;
  final ValueChanged<String>? onPhoneChanged;
  final ValueChanged<String>? onAddressChanged;
  final ValueChanged<String>? onDescriptionChanged;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final detail = state.detail!;
    final form = state.form!;
    final canSubmit = state.canSubmit && onSubmit != null;
    final canEdit =
        !state.isSubmitting &&
        state.status != PlatformInstitutionEditStatus.success &&
        state.status != PlatformInstitutionEditStatus.outcomeUnknown;

    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter, control: true):
            _SubmitIntent(),
      },
      child: Actions(
        actions: {
          _SubmitIntent: CallbackAction<_SubmitIntent>(
            onInvoke: (_) {
              if (canSubmit) {
                onSubmit!();
              }

              return null;
            },
          ),
        },
        child: FocusTraversalGroup(
          child: Column(
            key: const Key('platformInstitutionEditForm'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const Key('platformInstitutionEditBackButton'),
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back to institution'),
                ),
              ),
              const SizedBox(height: _sectionSpacing),
              Text(
                'Edit basic information',
                key: const Key('platformInstitutionEditHeading'),
                style: textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              _StatusContext(status: detail.status),
              const SizedBox(height: _sectionSpacing),
              if (state.formError != null) ...[
                _FormMessage(state: state),
                const SizedBox(height: _fieldSpacing),
              ],
              TextField(
                key: const Key('platformInstitutionEditNameField'),
                controller: nameController,
                focusNode: nameFocusNode,
                decoration: InputDecoration(
                  labelText: 'Institution name *',
                  errorText: state.errorTextFor(
                    PlatformInstitutionEditField.name,
                  ),
                  border: const OutlineInputBorder(),
                ),
                maxLength: PlatformInstitutionEditFormValue.nameMaxLength,
                maxLengthEnforcement: MaxLengthEnforcement.none,
                textInputAction: TextInputAction.next,
                onChanged: onNameChanged,
                enabled: canEdit,
                onSubmitted: (_) => typeFocusNode.requestFocus(),
              ),
              const SizedBox(height: _fieldSpacing),
              _RequiredDropdown<PlatformInstitutionType>(
                key: const Key('platformInstitutionEditTypeField'),
                focusNode: typeFocusNode,
                label: 'Institution type *',
                value: form.type,
                errorText: state.errorTextFor(
                  PlatformInstitutionEditField.type,
                ),
                items: [
                  for (final type in PlatformInstitutionType.values)
                    DropdownMenuItem(
                      value: type,
                      child: Text(platformInstitutionTypeLabel(type)),
                    ),
                ],
                onChanged: canEdit ? onTypeChanged : null,
              ),
              const SizedBox(height: _fieldSpacing),
              TextField(
                key: const Key('platformInstitutionEditEmailField'),
                controller: emailController,
                focusNode: emailFocusNode,
                decoration: InputDecoration(
                  labelText: 'Contact email',
                  errorText: state.errorTextFor(
                    PlatformInstitutionEditField.contactEmail,
                  ),
                  border: const OutlineInputBorder(),
                ),
                maxLength:
                    PlatformInstitutionEditFormValue.contactEmailMaxLength,
                maxLengthEnforcement: MaxLengthEnforcement.none,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                onChanged: onEmailChanged,
                enabled: canEdit,
                onSubmitted: (_) => phoneFocusNode.requestFocus(),
              ),
              const SizedBox(height: _fieldSpacing),
              TextField(
                key: const Key('platformInstitutionEditPhoneField'),
                controller: phoneController,
                focusNode: phoneFocusNode,
                decoration: InputDecoration(
                  labelText: 'Contact phone',
                  errorText: state.errorTextFor(
                    PlatformInstitutionEditField.contactPhone,
                  ),
                  border: const OutlineInputBorder(),
                ),
                maxLength:
                    PlatformInstitutionEditFormValue.contactPhoneMaxLength,
                maxLengthEnforcement: MaxLengthEnforcement.none,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                onChanged: onPhoneChanged,
                enabled: canEdit,
                onSubmitted: (_) => addressFocusNode.requestFocus(),
              ),
              const SizedBox(height: _fieldSpacing),
              TextField(
                key: const Key('platformInstitutionEditAddressField'),
                controller: addressController,
                focusNode: addressFocusNode,
                decoration: InputDecoration(
                  labelText: 'Address',
                  errorText: state.errorTextFor(
                    PlatformInstitutionEditField.address,
                  ),
                  border: const OutlineInputBorder(),
                ),
                minLines: 3,
                maxLines: 6,
                textInputAction: TextInputAction.newline,
                onChanged: onAddressChanged,
                enabled: canEdit,
              ),
              const SizedBox(height: _fieldSpacing),
              TextField(
                key: const Key('platformInstitutionEditDescriptionField'),
                controller: descriptionController,
                focusNode: descriptionFocusNode,
                decoration: InputDecoration(
                  labelText: 'Description / notes',
                  errorText: state.errorTextFor(
                    PlatformInstitutionEditField.description,
                  ),
                  border: const OutlineInputBorder(),
                ),
                minLines: 3,
                maxLines: 6,
                textInputAction: TextInputAction.newline,
                onChanged: onDescriptionChanged,
                enabled: canEdit,
              ),
              const SizedBox(height: _sectionSpacing),
              Wrap(
                key: const Key('platformInstitutionEditActions'),
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton.icon(
                    key: const Key('platformInstitutionEditSubmitButton'),
                    onPressed: canSubmit ? onSubmit : null,
                    icon: state.isSubmitting
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: Text(
                      state.isSubmitting ? 'Saving changes' : 'Save changes',
                    ),
                  ),
                  OutlinedButton.icon(
                    key: const Key('platformInstitutionEditCancelButton'),
                    onPressed: state.isSubmitting ? null : onCancel,
                    icon: const Icon(Icons.close),
                    label: const Text('Cancel'),
                  ),
                  if (state.isOutcomeUnknown)
                    TextButton.icon(
                      key: const Key(
                        'platformInstitutionEditCheckInstitutionButton',
                      ),
                      onPressed: onCheckInstitution,
                      icon: const Icon(Icons.business_outlined),
                      label: const Text('Check institution'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusContext extends StatelessWidget {
  const _StatusContext({required this.status});

  final PlatformInstitutionStatus status;

  @override
  Widget build(BuildContext context) {
    final label = platformInstitutionStatusLabel(status);
    final color = switch (status) {
      PlatformInstitutionStatus.active => Theme.of(context).colorScheme.primary,
      PlatformInstitutionStatus.inactive => Theme.of(context).colorScheme.error,
    };

    return Semantics(
      label: 'Institution status: $label',
      child: Wrap(
        key: const Key('platformInstitutionEditStatusContext'),
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('Status', style: Theme.of(context).textTheme.labelLarge),
          Chip(
            key: const Key('platformInstitutionEditStatusChip'),
            avatar: Icon(Icons.circle, size: 10, color: color),
            label: Text(label),
          ),
        ],
      ),
    );
  }
}

class _RequiredDropdown<T> extends StatelessWidget {
  const _RequiredDropdown({
    required super.key,
    required this.focusNode,
    required this.label,
    required this.value,
    required this.errorText,
    required this.items,
    required this.onChanged,
  });

  final FocusNode focusNode;
  final String label;
  final T? value;
  final String? errorText;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      focusNode: focusNode,
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        errorText: errorText,
        border: const OutlineInputBorder(),
      ),
      items: items,
      onChanged: onChanged,
    );
  }
}

class _FormMessage extends StatelessWidget {
  const _FormMessage({required this.state});

  final PlatformInstitutionEditState state;

  @override
  Widget build(BuildContext context) {
    final isUnknown =
        state.status == PlatformInstitutionEditStatus.outcomeUnknown;
    final isNoChange = state.formError == 'No changes to save.';
    final colorScheme = Theme.of(context).colorScheme;
    final borderColor = isUnknown || isNoChange
        ? colorScheme.primary
        : colorScheme.error;

    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        key: Key(
          isUnknown
              ? 'platformInstitutionEditUnknownMessage'
              : isNoChange
              ? 'platformInstitutionEditNoChangesMessage'
              : 'platformInstitutionEditFormError',
        ),
        decoration: BoxDecoration(
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(_panelRadius),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            isUnknown
                ? 'Update outcome unknown. The request may have completed. Check institution before saving again.'
                : state.formError!,
          ),
        ),
      ),
    );
  }
}

class _InstitutionEditNotFound extends StatelessWidget {
  const _InstitutionEditNotFound({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return _CenteredEditMessage(
      keyName: 'platformInstitutionEditNotFound',
      icon: Icons.search_off,
      title: 'Institution not found',
      message: 'The requested institution could not be found.',
      trailing: TextButton.icon(
        key: const Key('platformInstitutionEditBackToInstitutionsButton'),
        onPressed: onBack,
        icon: const Icon(Icons.arrow_back),
        label: const Text('Back to Institutions'),
      ),
    );
  }
}

class _InstitutionEditDenied extends StatelessWidget {
  const _InstitutionEditDenied({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return _CenteredEditMessage(
      keyName: 'platformInstitutionEditAccessDenied',
      icon: Icons.lock_outline,
      title: 'Institution editing unavailable',
      message: 'You do not have permission to edit this institution.',
      trailing: TextButton.icon(
        key: const Key('platformInstitutionEditDeniedBackButton'),
        onPressed: onBack,
        icon: const Icon(Icons.arrow_back),
        label: const Text('Back to Institutions'),
      ),
    );
  }
}

class _InstitutionEditLoadError extends StatelessWidget {
  const _InstitutionEditLoadError({
    required this.failure,
    required this.isRetryInFlight,
    required this.onBack,
    required this.onRetry,
  });

  final ApiFailure failure;
  final bool isRetryInFlight;
  final VoidCallback onBack;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return _CenteredEditMessage(
      keyName: 'platformInstitutionEditError',
      icon: Icons.error_outline,
      title: 'Institution edit unavailable',
      message: _institutionEditLoadFailureMessage(failure),
      trailing: Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.center,
        children: [
          TextButton.icon(
            key: const Key('platformInstitutionEditErrorBackButton'),
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back),
            label: const Text('Back to Institutions'),
          ),
          FilledButton.icon(
            key: const Key('platformInstitutionEditRetryButton'),
            onPressed: isRetryInFlight ? null : onRetry,
            icon: isRetryInFlight
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            label: Text(isRetryInFlight ? 'Retrying' : 'Retry'),
          ),
        ],
      ),
    );
  }
}

class _CenteredEditMessage extends StatelessWidget {
  const _CenteredEditMessage({
    required this.keyName,
    required this.icon,
    required this.title,
    required this.message,
    required this.trailing,
  });

  final String keyName;
  final IconData icon;
  final String title;
  final String message;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: Key(keyName),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: DecoratedBox(
          decoration: _panelDecoration(context),
          child: Padding(
            padding: const EdgeInsets.all(_pageSpacing),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  icon,
                  size: 40,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  key: Key('${keyName}Message'),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Align(alignment: Alignment.center, child: trailing),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

BoxDecoration _panelDecoration(BuildContext context) {
  return BoxDecoration(
    border: Border.all(color: Theme.of(context).dividerColor),
    borderRadius: BorderRadius.circular(_panelRadius),
  );
}

String _institutionEditLoadFailureMessage(ApiFailure failure) {
  return switch (failure.serverCode) {
    ApiErrorCodes.authenticationRequired => 'Please sign in again.',
    ApiErrorCodes.passwordChangeRequired =>
      'Password change is required before institution editing.',
    ApiErrorCodes.userInactive => 'This account is inactive.',
    ApiErrorCodes.institutionInactive => 'This institution is inactive.',
    ApiErrorCodes.forbidden =>
      'You do not have permission to edit this institution.',
    ApiErrorCodes.validationFailed =>
      'The institution edit request did not match the API contract.',
    _ => switch (failure.kind) {
      ApiFailureKind.connection =>
        'Could not reach the server. Check the connection and try again.',
      ApiFailureKind.timeout => 'The institution edit request timed out.',
      ApiFailureKind.invalidResponse =>
        'The server returned an unexpected institution detail response.',
      ApiFailureKind.cancelled => 'The institution edit request was cancelled.',
      ApiFailureKind.unknown ||
      ApiFailureKind.server ||
      ApiFailureKind.validation => 'The institution could not be loaded.',
    },
  };
}

class _SubmitIntent extends Intent {
  const _SubmitIntent();
}
