import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_route_paths.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/application/auth_session_state.dart';
import '../application/platform_institution_create_controller.dart';
import '../application/platform_institution_create_state.dart';
import '../domain/platform_institution.dart';
import '../domain/platform_institution_create.dart';
import 'platform_dashboard_formatters.dart';

const _pageSpacing = 24.0;
const _sectionSpacing = 20.0;
const _fieldSpacing = 16.0;
const _formMaxWidth = 760.0;

class PlatformOwnerInstitutionCreateScreen extends ConsumerStatefulWidget {
  const PlatformOwnerInstitutionCreateScreen({super.key});

  @override
  ConsumerState<PlatformOwnerInstitutionCreateScreen> createState() {
    return _PlatformOwnerInstitutionCreateScreenState();
  }
}

class _PlatformOwnerInstitutionCreateScreenState
    extends ConsumerState<PlatformOwnerInstitutionCreateScreen> {
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
  final _statusFocusNode = FocusNode();

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
    _statusFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionControllerProvider);
    final user = session.user;
    final createKey =
        session.status == AuthSessionStatus.authenticated && user != null
        ? PlatformInstitutionCreateKey(
            sessionUserId: user.id,
            sessionInstanceId: identityHashCode(user),
          )
        : null;
    final state = createKey == null
        ? const PlatformInstitutionCreateState.editing()
        : ref.watch(platformInstitutionCreateControllerProvider(createKey));

    _syncControllers(state.form);
    _handleStateEffects(createKey, state);

    return SingleChildScrollView(
      key: const Key('platformInstitutionCreateSurface'),
      padding: const EdgeInsets.all(_pageSpacing),
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _formMaxWidth),
          child: _InstitutionCreateForm(
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
            statusFocusNode: _statusFocusNode,
            onBack: () => _goBack(context, state),
            onCancel: () => _goBack(context, state),
            onCheckInstitutions: () {
              context.go(AppRoutePaths.platformOwnerInstitutions);
            },
            onNameChanged: createKey == null
                ? null
                : ref
                      .read(
                        platformInstitutionCreateControllerProvider(
                          createKey,
                        ).notifier,
                      )
                      .updateName,
            onTypeChanged: createKey == null
                ? null
                : ref
                      .read(
                        platformInstitutionCreateControllerProvider(
                          createKey,
                        ).notifier,
                      )
                      .updateType,
            onEmailChanged: createKey == null
                ? null
                : ref
                      .read(
                        platformInstitutionCreateControllerProvider(
                          createKey,
                        ).notifier,
                      )
                      .updateContactEmail,
            onPhoneChanged: createKey == null
                ? null
                : ref
                      .read(
                        platformInstitutionCreateControllerProvider(
                          createKey,
                        ).notifier,
                      )
                      .updateContactPhone,
            onAddressChanged: createKey == null
                ? null
                : ref
                      .read(
                        platformInstitutionCreateControllerProvider(
                          createKey,
                        ).notifier,
                      )
                      .updateAddress,
            onDescriptionChanged: createKey == null
                ? null
                : ref
                      .read(
                        platformInstitutionCreateControllerProvider(
                          createKey,
                        ).notifier,
                      )
                      .updateDescription,
            onStatusChanged: createKey == null
                ? null
                : ref
                      .read(
                        platformInstitutionCreateControllerProvider(
                          createKey,
                        ).notifier,
                      )
                      .updateStatus,
            onSubmit: createKey == null
                ? null
                : () {
                    ref
                        .read(
                          platformInstitutionCreateControllerProvider(
                            createKey,
                          ).notifier,
                        )
                        .submit();
                  },
          ),
        ),
      ),
    );
  }

  void _syncControllers(PlatformInstitutionCreateFormValue form) {
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
    PlatformInstitutionCreateKey? key,
    PlatformInstitutionCreateState state,
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
        state.status != PlatformInstitutionCreateStatus.success ||
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
            key: const Key('platformInstitutionCreateSuccessSnackBar'),
            content: Text(result.message),
            action: SnackBarAction(
              label: 'View institution',
              onPressed: () {
                router.go(
                  AppRoutePaths.platformOwnerInstitutionDetailLocation(
                    result.id,
                  ),
                );
              },
            ),
          ),
        );
      router.go(AppRoutePaths.platformOwnerInstitutions);
    });
  }

  void _focusField(PlatformInstitutionCreateField field) {
    final node = switch (field) {
      PlatformInstitutionCreateField.name => _nameFocusNode,
      PlatformInstitutionCreateField.type => _typeFocusNode,
      PlatformInstitutionCreateField.contactEmail => _emailFocusNode,
      PlatformInstitutionCreateField.contactPhone => _phoneFocusNode,
      PlatformInstitutionCreateField.address => _addressFocusNode,
      PlatformInstitutionCreateField.description => _descriptionFocusNode,
      PlatformInstitutionCreateField.status => _statusFocusNode,
    };

    node.requestFocus();
  }

  Future<void> _goBack(
    BuildContext context,
    PlatformInstitutionCreateState state,
  ) async {
    if (state.form.isDirty &&
        state.status != PlatformInstitutionCreateStatus.success) {
      final shouldLeave = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard institution draft?'),
          content: const Text(
            'Unsaved institution details will be lost when you leave this form.',
          ),
          actions: [
            TextButton(
              key: const Key('platformInstitutionCreateStayButton'),
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Stay'),
            ),
            FilledButton(
              key: const Key('platformInstitutionCreateDiscardButton'),
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

    context.go(AppRoutePaths.platformOwnerInstitutions);
  }
}

class _InstitutionCreateForm extends StatelessWidget {
  const _InstitutionCreateForm({
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
    required this.statusFocusNode,
    required this.onBack,
    required this.onCancel,
    required this.onCheckInstitutions,
    required this.onNameChanged,
    required this.onTypeChanged,
    required this.onEmailChanged,
    required this.onPhoneChanged,
    required this.onAddressChanged,
    required this.onDescriptionChanged,
    required this.onStatusChanged,
    required this.onSubmit,
  });

  final PlatformInstitutionCreateState state;
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
  final FocusNode statusFocusNode;
  final VoidCallback onBack;
  final VoidCallback onCancel;
  final VoidCallback onCheckInstitutions;
  final ValueChanged<String>? onNameChanged;
  final ValueChanged<PlatformInstitutionType?>? onTypeChanged;
  final ValueChanged<String>? onEmailChanged;
  final ValueChanged<String>? onPhoneChanged;
  final ValueChanged<String>? onAddressChanged;
  final ValueChanged<String>? onDescriptionChanged;
  final ValueChanged<PlatformInstitutionStatus?>? onStatusChanged;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final canSubmit = state.canSubmit && onSubmit != null;
    final canEdit =
        !state.isSubmitting &&
        state.status != PlatformInstitutionCreateStatus.success &&
        state.status != PlatformInstitutionCreateStatus.outcomeUnknown;

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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const Key('platformInstitutionCreateBackButton'),
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back to Institutions'),
                ),
              ),
              const SizedBox(height: _sectionSpacing),
              Text(
                'Create Institution',
                key: const Key('platformInstitutionCreateHeading'),
                style: textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Inactive Institutions block normal Institution-user access without deleting data.',
                key: Key('platformInstitutionCreateStatusHelp'),
              ),
              const SizedBox(height: _sectionSpacing),
              if (state.formError != null) ...[
                _FormMessage(state: state),
                const SizedBox(height: _fieldSpacing),
              ],
              TextField(
                key: const Key('platformInstitutionCreateNameField'),
                controller: nameController,
                focusNode: nameFocusNode,
                decoration: InputDecoration(
                  labelText: 'Institution name *',
                  errorText: state.errorTextFor(
                    PlatformInstitutionCreateField.name,
                  ),
                  border: const OutlineInputBorder(),
                ),
                maxLength: PlatformInstitutionCreateFormValue.nameMaxLength,
                maxLengthEnforcement: MaxLengthEnforcement.none,
                textInputAction: TextInputAction.next,
                onChanged: onNameChanged,
                enabled: canEdit,
                onSubmitted: (_) => typeFocusNode.requestFocus(),
              ),
              const SizedBox(height: _fieldSpacing),
              _RequiredDropdown<PlatformInstitutionType>(
                key: const Key('platformInstitutionCreateTypeField'),
                focusNode: typeFocusNode,
                label: 'Institution type *',
                value: state.form.type,
                errorText: state.errorTextFor(
                  PlatformInstitutionCreateField.type,
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
                key: const Key('platformInstitutionCreateEmailField'),
                controller: emailController,
                focusNode: emailFocusNode,
                decoration: InputDecoration(
                  labelText: 'Contact email',
                  errorText: state.errorTextFor(
                    PlatformInstitutionCreateField.contactEmail,
                  ),
                  border: const OutlineInputBorder(),
                ),
                maxLength:
                    PlatformInstitutionCreateFormValue.contactEmailMaxLength,
                maxLengthEnforcement: MaxLengthEnforcement.none,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                onChanged: onEmailChanged,
                enabled: canEdit,
                onSubmitted: (_) => phoneFocusNode.requestFocus(),
              ),
              const SizedBox(height: _fieldSpacing),
              TextField(
                key: const Key('platformInstitutionCreatePhoneField'),
                controller: phoneController,
                focusNode: phoneFocusNode,
                decoration: InputDecoration(
                  labelText: 'Contact phone',
                  errorText: state.errorTextFor(
                    PlatformInstitutionCreateField.contactPhone,
                  ),
                  border: const OutlineInputBorder(),
                ),
                maxLength:
                    PlatformInstitutionCreateFormValue.contactPhoneMaxLength,
                maxLengthEnforcement: MaxLengthEnforcement.none,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                onChanged: onPhoneChanged,
                enabled: canEdit,
                onSubmitted: (_) => addressFocusNode.requestFocus(),
              ),
              const SizedBox(height: _fieldSpacing),
              TextField(
                key: const Key('platformInstitutionCreateAddressField'),
                controller: addressController,
                focusNode: addressFocusNode,
                decoration: InputDecoration(
                  labelText: 'Address',
                  errorText: state.errorTextFor(
                    PlatformInstitutionCreateField.address,
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
                key: const Key('platformInstitutionCreateDescriptionField'),
                controller: descriptionController,
                focusNode: descriptionFocusNode,
                decoration: InputDecoration(
                  labelText: 'Description / notes',
                  errorText: state.errorTextFor(
                    PlatformInstitutionCreateField.description,
                  ),
                  border: const OutlineInputBorder(),
                ),
                minLines: 3,
                maxLines: 6,
                textInputAction: TextInputAction.newline,
                onChanged: onDescriptionChanged,
                enabled: canEdit,
              ),
              const SizedBox(height: _fieldSpacing),
              _RequiredDropdown<PlatformInstitutionStatus>(
                key: const Key('platformInstitutionCreateStatusField'),
                focusNode: statusFocusNode,
                label: 'Status *',
                value: state.form.status,
                errorText: state.errorTextFor(
                  PlatformInstitutionCreateField.status,
                ),
                items: [
                  for (final status in PlatformInstitutionStatus.values)
                    DropdownMenuItem(
                      value: status,
                      child: Text(platformInstitutionStatusLabel(status)),
                    ),
                ],
                onChanged: canEdit ? onStatusChanged : null,
              ),
              const SizedBox(height: _sectionSpacing),
              Wrap(
                key: const Key('platformInstitutionCreateActions'),
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton.icon(
                    key: const Key('platformInstitutionCreateSubmitButton'),
                    onPressed: canSubmit ? onSubmit : null,
                    icon: state.isSubmitting
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: Text(
                      state.isSubmitting
                          ? 'Creating institution'
                          : 'Create Institution',
                    ),
                  ),
                  OutlinedButton.icon(
                    key: const Key('platformInstitutionCreateCancelButton'),
                    onPressed: state.isSubmitting ? null : onCancel,
                    icon: const Icon(Icons.close),
                    label: const Text('Cancel'),
                  ),
                  if (state.isOutcomeUnknown)
                    TextButton.icon(
                      key: const Key(
                        'platformInstitutionCreateCheckInstitutionsButton',
                      ),
                      onPressed: onCheckInstitutions,
                      icon: const Icon(Icons.business_outlined),
                      label: const Text('Check Institutions'),
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
      hint: const Text('Choose one'),
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

  final PlatformInstitutionCreateState state;

  @override
  Widget build(BuildContext context) {
    final isUnknown =
        state.status == PlatformInstitutionCreateStatus.outcomeUnknown;
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        key: Key(
          isUnknown
              ? 'platformInstitutionCreateUnknownMessage'
              : 'platformInstitutionCreateFormError',
        ),
        decoration: BoxDecoration(
          border: Border.all(
            color: isUnknown ? colorScheme.primary : colorScheme.error,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            isUnknown
                ? 'Submission outcome unknown. The request may have completed, and duplicate Institution names are possible. Check Institutions before submitting again.'
                : state.formError!,
          ),
        ),
      ),
    );
  }
}

class _SubmitIntent extends Intent {
  const _SubmitIntent();
}
