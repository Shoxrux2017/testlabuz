import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_failure.dart';
import '../../application/auth_session_controller.dart';
import '../../application/auth_session_state.dart';
import '../auth_error_banner.dart';
import '../auth_failure_messages.dart';
import '../auth_form_shell.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  final _loginFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  String? _accountError;
  String? _loginServerError;
  String? _passwordServerError;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    _loginFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionControllerProvider);
    final isSubmitting = session.status == AuthSessionStatus.authenticating;

    return AuthFormShell(
      title: 'Sign in',
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.enter): () {
            if (!isSubmitting) {
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
                  key: const Key('loginField'),
                  controller: _loginController,
                  focusNode: _loginFocusNode,
                  enabled: !isSubmitting,
                  autofillHints: const [AutofillHints.username],
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Login',
                    border: OutlineInputBorder(),
                  ),
                  validator: _validateLogin,
                  onChanged: (_) =>
                      _clearServerErrorsForField(_AuthField.login),
                  onFieldSubmitted: (_) => _passwordFocusNode.requestFocus(),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('passwordField'),
                  controller: _passwordController,
                  focusNode: _passwordFocusNode,
                  enabled: !isSubmitting,
                  autofillHints: const [AutofillHints.password],
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      tooltip: _obscurePassword
                          ? 'Show password'
                          : 'Hide password',
                      onPressed: isSubmitting
                          ? null
                          : () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: _validatePassword,
                  onChanged: (_) =>
                      _clearServerErrorsForField(_AuthField.password),
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  key: const Key('signInButton'),
                  onPressed: isSubmitting ? null : _submit,
                  icon: isSubmitting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.login),
                  label: Text(isSubmitting ? 'Signing in' : 'Sign in'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _validateLogin(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Login is required.';
    }

    return _loginServerError;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required.';
    }

    return _passwordServerError;
  }

  Future<void> _submit() async {
    if (ref.read(authSessionControllerProvider).status ==
        AuthSessionStatus.authenticating) {
      return;
    }

    setState(_clearPresentedFailure);
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      _focusFirstInvalidField();
      return;
    }

    final login = _loginController.text.trim();
    final password = _passwordController.text;

    await ref
        .read(authSessionControllerProvider.notifier)
        .signIn(login: login, password: password);

    if (!mounted) {
      return;
    }

    final session = ref.read(authSessionControllerProvider);
    final failure = session.failure;
    if (session.status == AuthSessionStatus.unauthenticated &&
        failure != null) {
      _applyFailure(failure);
    }
  }

  void _applyFailure(ApiFailure failure) {
    setState(() {
      _loginServerError = firstFieldError(failure, 'login');
      _passwordServerError = firstFieldError(failure, 'password');
      _accountError = authFailureMessage(failure);
    });
    _formKey.currentState?.validate();
    _focusFirstInvalidField();
  }

  void _clearServerErrorsForField(_AuthField field) {
    if (_accountError == null &&
        _loginServerError == null &&
        _passwordServerError == null) {
      return;
    }

    setState(() {
      _accountError = null;
      switch (field) {
        case _AuthField.login:
          _loginServerError = null;
          break;
        case _AuthField.password:
          _passwordServerError = null;
          break;
      }
    });
  }

  void _clearPresentedFailure() {
    _accountError = null;
    _loginServerError = null;
    _passwordServerError = null;
  }

  void _focusFirstInvalidField() {
    if (_loginController.text.trim().isEmpty || _loginServerError != null) {
      _loginFocusNode.requestFocus();
      return;
    }

    if (_passwordController.text.isEmpty || _passwordServerError != null) {
      _passwordFocusNode.requestFocus();
    }
  }
}

enum _AuthField { login, password }
