import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_error_codes.dart';
import '../../../../core/network/api_failure.dart';
import '../../application/auth_password_change_result.dart';
import '../../application/auth_session_controller.dart';
import '../auth_error_banner.dart';
import '../auth_failure_messages.dart';
import '../auth_form_shell.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  static const _minimumPasswordLength = 8;
  static const _maximumPasswordLength = 255;

  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmationController = TextEditingController();
  final _currentPasswordFocusNode = FocusNode();
  final _newPasswordFocusNode = FocusNode();
  final _confirmationFocusNode = FocusNode();

  String? _accountError;
  String? _currentPasswordServerError;
  String? _newPasswordServerError;
  String? _confirmationServerError;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmation = true;
  bool _isSubmitting = false;
  bool _awaitingSessionRefresh = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmationController.dispose();
    _currentPasswordFocusNode.dispose();
    _newPasswordFocusNode.dispose();
    _confirmationFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inputsEnabled = !_isSubmitting && !_awaitingSessionRefresh;

    return AuthFormShell(
      title: 'Change password',
      subtitle: 'Password change is required before normal access.',
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.enter): () {
            if (_awaitingSessionRefresh) {
              _retrySessionRefresh();
            } else if (!_isSubmitting) {
              _submit();
            }
          },
        },
        child: Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_accountError != null) ...[
                  AuthErrorBanner(message: _accountError!),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  key: const Key('currentPasswordField'),
                  controller: _currentPasswordController,
                  focusNode: _currentPasswordFocusNode,
                  enabled: inputsEnabled,
                  obscureText: _obscureCurrentPassword,
                  autofillHints: const [AutofillHints.password],
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Current password',
                    border: const OutlineInputBorder(),
                    suffixIcon: _PasswordVisibilityButton(
                      isObscured: _obscureCurrentPassword,
                      onPressed: inputsEnabled
                          ? () {
                              setState(() {
                                _obscureCurrentPassword =
                                    !_obscureCurrentPassword;
                              });
                            }
                          : null,
                    ),
                  ),
                  validator: _validateCurrentPassword,
                  onChanged: (_) =>
                      _clearServerErrorsForField(_PasswordField.current),
                  onFieldSubmitted: (_) => _newPasswordFocusNode.requestFocus(),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('newPasswordField'),
                  controller: _newPasswordController,
                  focusNode: _newPasswordFocusNode,
                  enabled: inputsEnabled,
                  obscureText: _obscureNewPassword,
                  autofillHints: const [AutofillHints.newPassword],
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'New password',
                    border: const OutlineInputBorder(),
                    suffixIcon: _PasswordVisibilityButton(
                      isObscured: _obscureNewPassword,
                      onPressed: inputsEnabled
                          ? () {
                              setState(() {
                                _obscureNewPassword = !_obscureNewPassword;
                              });
                            }
                          : null,
                    ),
                  ),
                  validator: _validateNewPassword,
                  onChanged: (_) =>
                      _clearServerErrorsForField(_PasswordField.newPassword),
                  onFieldSubmitted: (_) =>
                      _confirmationFocusNode.requestFocus(),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('confirmPasswordField'),
                  controller: _confirmationController,
                  focusNode: _confirmationFocusNode,
                  enabled: inputsEnabled,
                  obscureText: _obscureConfirmation,
                  autofillHints: const [AutofillHints.newPassword],
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: 'Confirm new password',
                    border: const OutlineInputBorder(),
                    suffixIcon: _PasswordVisibilityButton(
                      isObscured: _obscureConfirmation,
                      onPressed: inputsEnabled
                          ? () {
                              setState(() {
                                _obscureConfirmation = !_obscureConfirmation;
                              });
                            }
                          : null,
                    ),
                  ),
                  validator: _validateConfirmation,
                  onChanged: (_) =>
                      _clearServerErrorsForField(_PasswordField.confirmation),
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 24),
                if (_awaitingSessionRefresh)
                  FilledButton.icon(
                    key: const Key('retrySessionRefreshButton'),
                    onPressed: _isSubmitting ? null : _retrySessionRefresh,
                    icon: _isSubmitting
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    label: Text(_isSubmitting ? 'Refreshing' : 'Retry refresh'),
                  )
                else
                  FilledButton.icon(
                    key: const Key('changePasswordButton'),
                    onPressed: _isSubmitting ? null : _submit,
                    icon: _isSubmitting
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.lock_reset),
                    label: Text(
                      _isSubmitting ? 'Changing password' : 'Change password',
                    ),
                  ),
                const SizedBox(height: 12),
                TextButton.icon(
                  key: const Key('changePasswordLogoutButton'),
                  onPressed: _isSubmitting ? null : _signOut,
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _validateCurrentPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Current password is required.';
    }

    return _currentPasswordServerError;
  }

  String? _validateNewPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'New password is required.';
    }

    if (value.length < _minimumPasswordLength) {
      return 'New password must be at least 8 characters.';
    }

    if (value.length > _maximumPasswordLength) {
      return 'New password must be 255 characters or fewer.';
    }

    if (value == _currentPasswordController.text) {
      return 'New password must be different from current password.';
    }

    return _newPasswordServerError;
  }

  String? _validateConfirmation(String? value) {
    if (value == null || value.isEmpty) {
      return 'Confirm new password is required.';
    }

    if (value != _newPasswordController.text) {
      return 'Confirm new password must match new password.';
    }

    return _confirmationServerError;
  }

  Future<void> _submit() async {
    if (_isSubmitting || _awaitingSessionRefresh) {
      return;
    }

    setState(() {
      _isSubmitting = false;
      _clearPresentedFailure();
    });
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      _focusFirstInvalidField();
      return;
    }

    setState(() {
      _isSubmitting = true;
    });
    final result = await ref
        .read(authSessionControllerProvider.notifier)
        .changePassword(
          currentPassword: _currentPasswordController.text,
          newPassword: _newPasswordController.text,
          newPasswordConfirmation: _confirmationController.text,
        );

    if (!mounted) {
      return;
    }

    _handleResult(result);
  }

  Future<void> _retrySessionRefresh() async {
    if (_isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _clearPresentedFailure();
    });
    final result = await ref
        .read(authSessionControllerProvider.notifier)
        .retryPasswordChangeSessionRefresh();

    if (!mounted) {
      return;
    }

    _handleResult(result);
  }

  Future<void> _signOut() {
    return ref.read(authSessionControllerProvider.notifier).signOut();
  }

  void _handleResult(AuthPasswordChangeResult result) {
    setState(() {
      _isSubmitting = false;
    });

    if (result.isSuperseded) {
      return;
    }

    if (result.isSuccess) {
      _clearPasswordValues();
      setState(() {
        _awaitingSessionRefresh = false;
      });
      return;
    }

    final failure = result.failure;
    if (failure == null) {
      return;
    }

    if (result.canRetrySessionRefresh) {
      _clearPasswordValues();
    }

    _applyFailure(
      failure,
      awaitingSessionRefresh: result.canRetrySessionRefresh,
    );
  }

  void _applyFailure(
    ApiFailure failure, {
    required bool awaitingSessionRefresh,
  }) {
    setState(() {
      _awaitingSessionRefresh = awaitingSessionRefresh;
      _currentPasswordServerError = firstFieldError(
        failure,
        'current_password',
      );
      _newPasswordServerError = firstFieldError(failure, 'new_password');
      _confirmationServerError = firstFieldError(
        failure,
        'new_password_confirmation',
      );
      if (failure.serverCode == ApiErrorCodes.currentPasswordInvalid &&
          _currentPasswordServerError == null) {
        _currentPasswordServerError = authFailureMessage(failure);
      }
      _accountError = authFailureMessage(failure);
    });
    if (!awaitingSessionRefresh) {
      _formKey.currentState?.validate();
      _focusFirstInvalidField();
    }
  }

  void _clearServerErrorsForField(_PasswordField field) {
    if (_accountError == null &&
        _currentPasswordServerError == null &&
        _newPasswordServerError == null &&
        _confirmationServerError == null) {
      return;
    }

    setState(() {
      _accountError = null;
      switch (field) {
        case _PasswordField.current:
          _currentPasswordServerError = null;
          break;
        case _PasswordField.newPassword:
          _newPasswordServerError = null;
          break;
        case _PasswordField.confirmation:
          _confirmationServerError = null;
          break;
      }
    });
  }

  void _clearPresentedFailure() {
    _accountError = null;
    _currentPasswordServerError = null;
    _newPasswordServerError = null;
    _confirmationServerError = null;
  }

  void _clearPasswordValues() {
    _currentPasswordController.clear();
    _newPasswordController.clear();
    _confirmationController.clear();
  }

  void _focusFirstInvalidField() {
    if (_currentPasswordController.text.isEmpty ||
        _currentPasswordServerError != null) {
      _currentPasswordFocusNode.requestFocus();
      return;
    }

    if (_newPasswordController.text.isEmpty ||
        _newPasswordController.text.length < _minimumPasswordLength ||
        _newPasswordController.text.length > _maximumPasswordLength ||
        _newPasswordController.text == _currentPasswordController.text ||
        _newPasswordServerError != null) {
      _newPasswordFocusNode.requestFocus();
      return;
    }

    if (_confirmationController.text.isEmpty ||
        _confirmationController.text != _newPasswordController.text ||
        _confirmationServerError != null) {
      _confirmationFocusNode.requestFocus();
    }
  }
}

enum _PasswordField { current, newPassword, confirmation }

class _PasswordVisibilityButton extends StatelessWidget {
  const _PasswordVisibilityButton({
    required this.isObscured,
    required this.onPressed,
  });

  final bool isObscured;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: isObscured ? 'Show password' : 'Hide password',
      onPressed: onPressed,
      icon: Icon(
        isObscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
      ),
    );
  }
}
