import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../auth/application/auth_session_controller.dart';
import '../application/institution_profile_controller.dart';
import '../application/institution_profile_state.dart';
import '../domain/institution_profile_update.dart';
import 'institution_profile_formatters.dart';

const _profilePadding = 24.0;
const _profileSpacing = 16.0;
const _profileMaxWidth = 920.0;

class InstitutionAdminProfileScreen extends ConsumerStatefulWidget {
  const InstitutionAdminProfileScreen({super.key});

  @override
  ConsumerState<InstitutionAdminProfileScreen> createState() =>
      _InstitutionAdminProfileScreenState();
}

class _InstitutionAdminProfileScreenState
    extends ConsumerState<InstitutionAdminProfileScreen> {
  final _nameController = TextEditingController();
  final _contactEmailController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();

  final _nameFocus = FocusNode();
  final _contactEmailFocus = FocusNode();
  final _contactPhoneFocus = FocusNode();
  final _addressFocus = FocusNode();
  final _descriptionFocus = FocusNode();

  InstitutionProfileViewStatus? _lastFocusStatus;
  InstitutionProfileEditField? _lastFocusField;

  @override
  void dispose() {
    _nameController.dispose();
    _contactEmailController.dispose();
    _contactPhoneController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    _nameFocus.dispose();
    _contactEmailFocus.dispose();
    _contactPhoneFocus.dispose();
    _addressFocus.dispose();
    _descriptionFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) {
      return const SizedBox.shrink();
    }

    final user = ref.watch(authSessionControllerProvider).user;
    final userId = user?.id;
    final institutionId = user?.institutionId;
    if (userId == null || institutionId == null) {
      return const SizedBox.shrink();
    }

    final providerKey = InstitutionProfileSessionKey(
      userId: userId,
      institutionId: institutionId,
    );
    final provider = institutionProfileControllerProvider(providerKey);
    final state = ref.watch(provider);
    _synchronizeFormControllers(state.form);
    _scheduleInvalidFieldFocus(state);

    final controller = ref.read(provider.notifier);

    return switch (state.status) {
      InstitutionProfileViewStatus.initial => const SizedBox.shrink(),
      InstitutionProfileViewStatus.loading =>
        const _InstitutionProfileLoading(),
      InstitutionProfileViewStatus.data ||
      InstitutionProfileViewStatus.confirmedDirectSuccess ||
      InstitutionProfileViewStatus.unconfirmedCurrentState =>
        _InstitutionProfileView(
          state: state,
          onRefresh: controller.refresh,
          onEdit: controller.beginEditing,
        ),
      InstitutionProfileViewStatus.editing ||
      InstitutionProfileViewStatus.submitting ||
      InstitutionProfileViewStatus.validationFailure ||
      InstitutionProfileViewStatus.mutationFailure ||
      InstitutionProfileViewStatus.reconciling => _InstitutionProfileEditView(
        state: state,
        nameController: _nameController,
        contactEmailController: _contactEmailController,
        contactPhoneController: _contactPhoneController,
        addressController: _addressController,
        descriptionController: _descriptionController,
        nameFocus: _nameFocus,
        contactEmailFocus: _contactEmailFocus,
        contactPhoneFocus: _contactPhoneFocus,
        addressFocus: _addressFocus,
        descriptionFocus: _descriptionFocus,
        onChanged: controller.updateField,
        onCancel: controller.cancelEditing,
        onSave: controller.submit,
      ),
      InstitutionProfileViewStatus.outcomeUnknown =>
        _InstitutionProfileOutcomeUnknown(
          isReloadInFlight: state.isReloadInFlight,
          onReload: controller.reloadAfterUnknownOutcome,
        ),
      InstitutionProfileViewStatus.loadError => _InstitutionProfileError(
        failure: state.failure!,
        operation: state.failureOperation!,
        isRetryInFlight: state.isRetryInFlight,
        onRetry: controller.retry,
      ),
    };
  }

  void _synchronizeFormControllers(InstitutionProfileEditFormValue? form) {
    if (form == null) {
      return;
    }

    _setTextIfDifferent(_nameController, form.name);
    _setTextIfDifferent(_contactEmailController, form.contactEmail);
    _setTextIfDifferent(_contactPhoneController, form.contactPhone);
    _setTextIfDifferent(_addressController, form.address);
    _setTextIfDifferent(_descriptionController, form.description);
  }

  void _scheduleInvalidFieldFocus(InstitutionProfileState state) {
    final field = state.focusField;
    if (field == null) {
      _lastFocusStatus = null;
      _lastFocusField = null;
      return;
    }
    if (_lastFocusStatus == state.status && _lastFocusField == field) {
      return;
    }

    _lastFocusStatus = state.status;
    _lastFocusField = field;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNodeFor(field).requestFocus();
      }
    });
  }

  FocusNode _focusNodeFor(InstitutionProfileEditField field) {
    return switch (field) {
      InstitutionProfileEditField.name => _nameFocus,
      InstitutionProfileEditField.contactEmail => _contactEmailFocus,
      InstitutionProfileEditField.contactPhone => _contactPhoneFocus,
      InstitutionProfileEditField.address => _addressFocus,
      InstitutionProfileEditField.description => _descriptionFocus,
    };
  }
}

class _InstitutionProfileLoading extends StatelessWidget {
  const _InstitutionProfileLoading();

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('institutionProfileLoading'),
      child: Semantics(
        label: 'Loading institution profile',
        liveRegion: true,
        child: const CircularProgressIndicator(),
      ),
    );
  }
}

class _InstitutionProfileView extends StatelessWidget {
  const _InstitutionProfileView({
    required this.state,
    required this.onRefresh,
    required this.onEdit,
  });

  final InstitutionProfileState state;
  final VoidCallback onRefresh;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final profile = state.profile!;

    return _ProfileScrollSurface(
      key: const Key('institutionProfileData'),
      children: [
        _ProfileHeading(
          actions: [
            OutlinedButton.icon(
              key: const Key('institutionProfileRefreshButton'),
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
            FilledButton.icon(
              key: const Key('institutionProfileEditButton'),
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit profile'),
            ),
          ],
        ),
        if (state.notice != null) ...[
          const SizedBox(height: _profileSpacing),
          _ProfileNotice(state: state),
        ],
        const SizedBox(height: _profileSpacing),
        _ProfileRow(
          label: 'Name',
          value: profile.name,
          valueKey: const Key('institutionProfileNameValue'),
        ),
        _ProfileRow(
          label: 'Type',
          value: formatInstitutionProfileType(profile.type),
          valueKey: const Key('institutionProfileTypeValue'),
        ),
        _ProfileRow(
          label: 'Status',
          value: formatInstitutionProfileStatus(profile.status),
          valueKey: const Key('institutionProfileStatusValue'),
        ),
        _ProfileRow(
          label: 'Contact email',
          value: formatInstitutionProfileOptional(profile.contactEmail),
          valueKey: const Key('institutionProfileContactEmailValue'),
        ),
        _ProfileRow(
          label: 'Contact phone',
          value: formatInstitutionProfileOptional(profile.contactPhone),
          valueKey: const Key('institutionProfileContactPhoneValue'),
        ),
        _ProfileRow(
          label: 'Address',
          value: formatInstitutionProfileOptional(profile.address),
          valueKey: const Key('institutionProfileAddressValue'),
        ),
        _ProfileRow(
          label: 'Description',
          value: formatInstitutionProfileOptional(profile.description),
          valueKey: const Key('institutionProfileDescriptionValue'),
        ),
        _ProfileRow(
          label: 'Created at',
          value: formatInstitutionProfileUtc(profile.createdAt),
          valueKey: const Key('institutionProfileCreatedAtValue'),
        ),
        _ProfileRow(
          label: 'Updated at',
          value: formatInstitutionProfileUtc(profile.updatedAt),
          valueKey: const Key('institutionProfileUpdatedAtValue'),
        ),
      ],
    );
  }
}

class _InstitutionProfileEditView extends StatelessWidget {
  const _InstitutionProfileEditView({
    required this.state,
    required this.nameController,
    required this.contactEmailController,
    required this.contactPhoneController,
    required this.addressController,
    required this.descriptionController,
    required this.nameFocus,
    required this.contactEmailFocus,
    required this.contactPhoneFocus,
    required this.addressFocus,
    required this.descriptionFocus,
    required this.onChanged,
    required this.onCancel,
    required this.onSave,
  });

  final InstitutionProfileState state;
  final TextEditingController nameController;
  final TextEditingController contactEmailController;
  final TextEditingController contactPhoneController;
  final TextEditingController addressController;
  final TextEditingController descriptionController;
  final FocusNode nameFocus;
  final FocusNode contactEmailFocus;
  final FocusNode contactPhoneFocus;
  final FocusNode addressFocus;
  final FocusNode descriptionFocus;
  final void Function(InstitutionProfileEditField field, String value)
  onChanged;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final profile = state.profile!;
    final isSubmitting =
        state.status == InstitutionProfileViewStatus.submitting;
    final isReconciling =
        state.status == InstitutionProfileViewStatus.reconciling;
    final isDisabled = isSubmitting || isReconciling;

    return _ProfileScrollSurface(
      key: const Key('institutionProfileEditForm'),
      children: [
        const _ProfileHeading(),
        const SizedBox(height: _profileSpacing),
        if (isReconciling) ...[
          Semantics(
            key: const Key('institutionProfileReconciling'),
            label: 'Verifying institution profile update',
            liveRegion: true,
            child: const Row(
              children: [
                SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('Verifying'),
              ],
            ),
          ),
          const SizedBox(height: _profileSpacing),
        ],
        _ReadOnlyContext(
          label: 'Type',
          value: formatInstitutionProfileType(profile.type),
        ),
        _ReadOnlyContext(
          label: 'Status',
          value: formatInstitutionProfileStatus(profile.status),
        ),
        const SizedBox(height: _profileSpacing),
        _ProfileTextField(
          fieldKey: const Key('institutionProfileNameField'),
          label: 'Name',
          controller: nameController,
          focusNode: nameFocus,
          enabled: !isDisabled,
          errorText: state.fieldErrors[InstitutionProfileEditField.name],
          onChanged: (value) =>
              onChanged(InstitutionProfileEditField.name, value),
        ),
        _ProfileTextField(
          fieldKey: const Key('institutionProfileContactEmailField'),
          label: 'Contact email',
          controller: contactEmailController,
          focusNode: contactEmailFocus,
          enabled: !isDisabled,
          keyboardType: TextInputType.emailAddress,
          errorText:
              state.fieldErrors[InstitutionProfileEditField.contactEmail],
          onChanged: (value) =>
              onChanged(InstitutionProfileEditField.contactEmail, value),
        ),
        _ProfileTextField(
          fieldKey: const Key('institutionProfileContactPhoneField'),
          label: 'Contact phone',
          controller: contactPhoneController,
          focusNode: contactPhoneFocus,
          enabled: !isDisabled,
          keyboardType: TextInputType.phone,
          errorText:
              state.fieldErrors[InstitutionProfileEditField.contactPhone],
          onChanged: (value) =>
              onChanged(InstitutionProfileEditField.contactPhone, value),
        ),
        _ProfileTextField(
          fieldKey: const Key('institutionProfileAddressField'),
          label: 'Address',
          controller: addressController,
          focusNode: addressFocus,
          enabled: !isDisabled,
          minLines: 2,
          maxLines: 5,
          errorText: state.fieldErrors[InstitutionProfileEditField.address],
          onChanged: (value) =>
              onChanged(InstitutionProfileEditField.address, value),
        ),
        _ProfileTextField(
          fieldKey: const Key('institutionProfileDescriptionField'),
          label: 'Description',
          controller: descriptionController,
          focusNode: descriptionFocus,
          enabled: !isDisabled,
          minLines: 3,
          maxLines: 8,
          errorText: state.fieldErrors[InstitutionProfileEditField.description],
          onChanged: (value) =>
              onChanged(InstitutionProfileEditField.description, value),
        ),
        if (state.formError != null) ...[
          Semantics(
            liveRegion: true,
            child: Text(
              state.formError!,
              key: const Key('institutionProfileFormError'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
          const SizedBox(height: _profileSpacing),
        ],
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.end,
          children: [
            OutlinedButton(
              key: const Key('institutionProfileCancelButton'),
              onPressed: isDisabled ? null : onCancel,
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('institutionProfileSaveButton'),
              onPressed: isDisabled ? null : onSave,
              child: Text(isSubmitting ? 'Saving' : 'Save changes'),
            ),
          ],
        ),
      ],
    );
  }
}

class _InstitutionProfileError extends StatelessWidget {
  const _InstitutionProfileError({
    required this.failure,
    required this.operation,
    required this.isRetryInFlight,
    required this.onRetry,
  });

  final ApiFailure failure;
  final InstitutionProfileFailureOperation operation;
  final bool isRetryInFlight;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _CenteredProfileMessage(
      key: const Key('institutionProfileError'),
      icon: Icons.error_outline,
      title: 'Profile unavailable',
      message: _profileFailureMessage(failure, operation),
      messageKey: const Key('institutionProfileErrorMessage'),
      action: FilledButton.icon(
        key: const Key('institutionProfileRetryButton'),
        onPressed: isRetryInFlight ? null : onRetry,
        icon: isRetryInFlight
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.refresh),
        label: Text(isRetryInFlight ? 'Retrying' : 'Retry'),
      ),
    );
  }
}

class _InstitutionProfileOutcomeUnknown extends StatelessWidget {
  const _InstitutionProfileOutcomeUnknown({
    required this.isReloadInFlight,
    required this.onReload,
  });

  final bool isReloadInFlight;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    return _CenteredProfileMessage(
      key: const Key('institutionProfileOutcomeUnknown'),
      icon: Icons.help_outline,
      title: 'Update outcome unknown',
      message:
          'The server result could not be verified. Reload the profile before making another change.',
      action: FilledButton.icon(
        key: const Key('institutionProfileReloadButton'),
        onPressed: isReloadInFlight ? null : onReload,
        icon: isReloadInFlight
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.refresh),
        label: Text(isReloadInFlight ? 'Reloading' : 'Reload profile'),
      ),
    );
  }
}

class _ProfileScrollSurface extends StatelessWidget {
  const _ProfileScrollSurface({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(_profilePadding),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _profileMaxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }
}

class _ProfileHeading extends StatelessWidget {
  const _ProfileHeading({this.actions = const []});

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Semantics(
          header: true,
          child: Text(
            'Institution Profile',
            key: const Key('institutionProfileHeading'),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
        if (actions.isNotEmpty)
          Wrap(spacing: 12, runSpacing: 12, children: actions),
      ],
    );
  }
}

class _ProfileNotice extends StatelessWidget {
  const _ProfileNotice({required this.state});

  final InstitutionProfileState state;

  @override
  Widget build(BuildContext context) {
    final statusKey = switch (state.status) {
      InstitutionProfileViewStatus.confirmedDirectSuccess => const Key(
        'institutionProfileConfirmedDirectSuccess',
      ),
      InstitutionProfileViewStatus.unconfirmedCurrentState => const Key(
        'institutionProfileUnconfirmedCurrentState',
      ),
      _ => null,
    };

    return Semantics(
      key: statusKey,
      liveRegion: true,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            state.notice!,
            key: const Key('institutionProfileNotice'),
          ),
        ),
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.label,
    required this.value,
    required this.valueKey,
  });

  final String label;
  final String value;
  final Key valueKey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          SelectableText(value, key: valueKey),
          const Divider(height: 20),
        ],
      ),
    );
  }
}

class _ReadOnlyContext extends StatelessWidget {
  const _ReadOnlyContext({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text('$label: $value'),
    );
  }
}

class _ProfileTextField extends StatelessWidget {
  const _ProfileTextField({
    required this.fieldKey,
    required this.label,
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.errorText,
    required this.onChanged,
    this.keyboardType,
    this.minLines = 1,
    this.maxLines = 1,
  });

  final Key fieldKey;
  final String label;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final String? errorText;
  final ValueChanged<String> onChanged;
  final TextInputType? keyboardType;
  final int minLines;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: _profileSpacing),
      child: TextField(
        key: fieldKey,
        controller: controller,
        focusNode: focusNode,
        enabled: enabled,
        keyboardType: keyboardType,
        minLines: minLines,
        maxLines: maxLines,
        textInputAction: maxLines == 1
            ? TextInputAction.next
            : TextInputAction.newline,
        decoration: InputDecoration(
          labelText: label,
          errorText: errorText,
          border: const OutlineInputBorder(),
        ),
        onChanged: onChanged,
      ),
    );
  }
}

class _CenteredProfileMessage extends StatelessWidget {
  const _CenteredProfileMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.action,
    this.messageKey,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget action;
  final Key? messageKey;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(_profilePadding),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Semantics(
            liveRegion: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  icon,
                  size: 42,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(message, key: messageKey, textAlign: TextAlign.center),
                const SizedBox(height: 20),
                action,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _profileFailureMessage(
  ApiFailure failure,
  InstitutionProfileFailureOperation operation,
) {
  if (operation == InstitutionProfileFailureOperation.mutation) {
    return switch (failure.serverCode) {
      ApiErrorCodes.authenticationRequired => 'Please sign in again.',
      ApiErrorCodes.passwordChangeRequired =>
        'Password change is required before profile editing.',
      ApiErrorCodes.userInactive => 'This account is inactive.',
      ApiErrorCodes.institutionInactive => 'This institution is inactive.',
      ApiErrorCodes.forbidden =>
        'You do not have permission to edit this institution profile.',
      ApiErrorCodes.resourceNotFound =>
        'The institution profile could not be found.',
      _ =>
        'The institution profile could not be updated. No changes were confirmed.',
    };
  }

  return switch (failure.serverCode) {
    ApiErrorCodes.authenticationRequired => 'Please sign in again.',
    ApiErrorCodes.passwordChangeRequired =>
      'Password change is required before profile access.',
    ApiErrorCodes.userInactive => 'This account is inactive.',
    ApiErrorCodes.institutionInactive => 'This institution is inactive.',
    ApiErrorCodes.forbidden =>
      'You do not have permission to view this institution profile.',
    ApiErrorCodes.resourceNotFound =>
      'The institution profile could not be found.',
    ApiErrorCodes.validationFailed =>
      'The profile request did not match the API contract.',
    _ => switch (failure.kind) {
      ApiFailureKind.connection =>
        'Could not reach the server. Check the connection and try again.',
      ApiFailureKind.timeout => 'The profile request timed out.',
      ApiFailureKind.invalidResponse =>
        'The server returned an unexpected institution profile response.',
      ApiFailureKind.cancelled => 'The profile request was cancelled.',
      ApiFailureKind.server ||
      ApiFailureKind.validation ||
      ApiFailureKind.unknown => 'The institution profile could not be loaded.',
    },
  };
}

void _setTextIfDifferent(TextEditingController controller, String value) {
  if (controller.text == value) {
    return;
  }

  controller.value = TextEditingValue(
    text: value,
    selection: TextSelection.collapsed(offset: value.length),
  );
}
