import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../shared/widgets/app_action_buttons.dart';
import '../../shared/widgets/app_section_card.dart';

enum AccountEntryMode { signIn, register }

class AccountEntryScreen extends StatefulWidget {
  const AccountEntryScreen({
    super.key,
    required this.onSignIn,
    required this.onRegister,
  });

  final Future<String?> Function(String email) onSignIn;
  final Future<String?> Function({
    required String email,
    required String displayName,
  })
  onRegister;

  @override
  State<AccountEntryScreen> createState() => _AccountEntryScreenState();
}

class _AccountEntryScreenState extends State<AccountEntryScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  AccountEntryMode _mode = AccountEntryMode.signIn;
  String? _message;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isRegistering = _mode == AccountEntryMode.register;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
          children: [
            Text(
              'AI Nutrition Companion',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Enter your local account to continue.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.mutedInk),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppSectionCard(
              title: isRegistering ? 'Register' : 'Sign in',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SegmentedButton<AccountEntryMode>(
                    segments: const [
                      ButtonSegment(
                        value: AccountEntryMode.signIn,
                        label: Text('Sign in'),
                        icon: Icon(Icons.login),
                      ),
                      ButtonSegment(
                        value: AccountEntryMode.register,
                        label: Text('Register'),
                        icon: Icon(Icons.person_add_alt_1),
                      ),
                    ],
                    selected: {_mode},
                    onSelectionChanged: (selection) {
                      setState(() {
                        _mode = selection.single;
                        _message = null;
                      });
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    key: const Key('account-email-field'),
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      hintText: 'you@example.com',
                    ),
                  ),
                  if (isRegistering) ...[
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      key: const Key('account-name-field'),
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      autofillHints: const [AutofillHints.name],
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        hintText: 'Your name',
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  AppPrimaryButton(
                    label: isRegistering ? 'Register' : 'Sign in',
                    icon: isRegistering ? Icons.person_add_alt_1 : Icons.login,
                    onPressed: _isSubmitting ? null : _submit,
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _message!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'This V1 account is stored on this device and gates access to Today, Kitchen, and Me.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.mutedInk),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final displayName = _nameController.text.trim();
    if (!_looksLikeEmail(email)) {
      setState(() {
        _message = 'Enter the email for your local account.';
      });
      return;
    }
    if (_mode == AccountEntryMode.register && displayName.isEmpty) {
      setState(() {
        _message = 'Enter your name to register.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _message = null;
    });

    final error = _mode == AccountEntryMode.register
        ? await widget.onRegister(email: email, displayName: displayName)
        : await widget.onSignIn(email);

    if (!mounted) {
      return;
    }
    setState(() {
      _isSubmitting = false;
      _message = error;
    });
  }
}

bool _looksLikeEmail(String email) {
  final trimmed = email.trim();
  return trimmed.contains('@') && trimmed.contains('.');
}
