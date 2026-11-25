import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import 'auth_view_model.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _signInKey = GlobalKey<FormState>();
  final _signUpKey = GlobalKey<FormState>();

  final _loginEmail = TextEditingController();
  final _loginPassword = TextEditingController();

  final _regName = TextEditingController();
  final _regEmail = TextEditingController();
  final _regPhone = TextEditingController();
  final _regCity = TextEditingController();
  final _regPassword = TextEditingController();
  final _regConfirmPassword = TextEditingController();

  bool _obscureLogin = true;
  bool _obscureReg = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginEmail.dispose();
    _loginPassword.dispose();
    _regName.dispose();
    _regEmail.dispose();
    _regPhone.dispose();
    _regCity.dispose();
    _regPassword.dispose();
    _regConfirmPassword.dispose();
    super.dispose();
  }

  Future<void> _showForgotPasswordDialog(AuthViewModel vm) async {
    final formKey = GlobalKey<FormState>();
    final resetEmail = TextEditingController(text: _loginEmail.text.trim());
    var isSending = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Reset Password'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enter your registered email address and we will send you a password reset link.',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: resetEmail,
                  validator: Validators.email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Registered Email',
                    hintText: 'name@example.com',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSending ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: isSending
                  ? null
                  : () async {
                      if (!(formKey.currentState?.validate() ?? false)) return;
                      setDialogState(() => isSending = true);
                      final err = await vm.sendPasswordReset(resetEmail.text);
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            err ??
                                'Password reset link sent to ${resetEmail.text.trim()}',
                          ),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
              child: isSending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Send Reset Link'),
            ),
          ],
        ),
      ),
    );
    resetEmail.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AuthViewModel>();
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Brand Hero
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.primary, AppColors.secondary],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.hub_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ServiceEpic',
                              style: textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'Smart Service Discovery & Escrow',
                              style: textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),

                  if (vm.errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: AppColors.error,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              vm.errorMessage!,
                              style: const TextStyle(color: AppColors.error),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: vm.clearError,
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Continue with Google CTA
                  OutlinedButton.icon(
                    onPressed: vm.isLoading ? null : vm.signInWithGoogle,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const _GoogleBadge(),
                    label: const Text(
                      'Continue with Google',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),

                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'OR',
                          style: textTheme.labelSmall?.copyWith(
                            color: colors.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          TabBar(
                            controller: _tabController,
                            tabs: const [
                              Tab(text: 'Sign In'),
                              Tab(text: 'Create Account'),
                            ],
                          ),
                          const SizedBox(height: 18),
                          AnimatedBuilder(
                            animation: _tabController,
                            builder: (context, _) {
                              if (_tabController.index == 0) {
                                return _buildSignInForm(vm);
                              }
                              return _buildSignUpForm(vm);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),
                  TextButton.icon(
                    onPressed: vm.isLoading ? null : vm.signInDemo,
                    icon: const Icon(Icons.flash_on_rounded, size: 18),
                    label: const Text('One-Tap Demo Client Login'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSignInForm(AuthViewModel vm) {
    return Form(
      key: _signInKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _loginEmail,
            validator: Validators.email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'Email Address',
              hintText: 'name@example.com',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _loginPassword,
            validator: Validators.password,
            obscureText: _obscureLogin,
            autofillHints: const [AutofillHints.password],
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureLogin
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () =>
                    setState(() => _obscureLogin = !_obscureLogin),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => _showForgotPasswordDialog(vm),
              child: const Text('Forgot Password?'),
            ),
          ),
          const SizedBox(height: 6),
          FilledButton(
            onPressed: vm.isLoading
                ? null
                : () {
                    if (_signInKey.currentState?.validate() ?? false) {
                      vm.signIn(
                        email: _loginEmail.text,
                        password: _loginPassword.text,
                      );
                    }
                  },
            child: vm.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Sign In'),
          ),
        ],
      ),
    );
  }

  Widget _buildSignUpForm(AuthViewModel vm) {
    return Form(
      key: _signUpKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _regName,
            validator: (v) =>
                Validators.requiredText(v, fieldName: 'Full name', minLength: 2),
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Full Name *',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _regEmail,
            validator: Validators.email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email Address *',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _regPhone,
            validator: Validators.phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone Number *',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _regCity,
            validator: Validators.location,
            decoration: const InputDecoration(
              labelText: 'City / Default Address *',
              prefixIcon: Icon(Icons.location_city_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _regPassword,
            validator: Validators.strongPassword,
            obscureText: _obscureReg,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Password *',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureReg
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () => setState(() => _obscureReg = !_obscureReg),
              ),
            ),
          ),
          if (_regPassword.text.isNotEmpty) ...[
            const SizedBox(height: 8),
            PasswordStrengthIndicator(password: _regPassword.text),
          ],
          const SizedBox(height: 12),
          TextFormField(
            controller: _regConfirmPassword,
            validator: (v) =>
                Validators.confirmPassword(v, _regPassword.text),
            obscureText: _obscureReg,
            decoration: const InputDecoration(
              labelText: 'Confirm Password *',
              prefixIcon: Icon(Icons.lock_reset_rounded),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: vm.isLoading
                ? null
                : () {
                    if (_signUpKey.currentState?.validate() ?? false) {
                      vm.signUp(
                        fullName: _regName.text,
                        email: _regEmail.text,
                        phone: _regPhone.text,
                        city: _regCity.text,
                        password: _regPassword.text,
                      );
                    }
                  },
            child: vm.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Create Account & Continue'),
          ),
        ],
      ),
    );
  }
}

class _GoogleBadge extends StatelessWidget {
  const _GoogleBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.lightBorder),
      ),
      child: const Text(
        'G',
        style: TextStyle(
          color: Color(0xFF4285F4),
          fontWeight: FontWeight.w900,
          fontSize: 14,
        ),
      ),
    );
  }
}

class PasswordStrengthIndicator extends StatelessWidget {
  const PasswordStrengthIndicator({super.key, required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final strength = PasswordStrength.evaluate(password);
    final color = switch (strength.metCount) {
      0 || 1 || 2 => AppColors.error,
      3 => AppColors.warning,
      4 => AppColors.info,
      _ => AppColors.success,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: strength.progress,
                  minHeight: 6,
                  color: color,
                  backgroundColor: color.withValues(alpha: 0.18),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              strength.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            _RuleCheck('8+ chars', strength.hasMinLength),
            _RuleCheck('A–Z', strength.hasUppercase),
            _RuleCheck('a–z', strength.hasLowercase),
            _RuleCheck('0–9', strength.hasDigit),
            _RuleCheck('Symbol', strength.hasSpecialChar),
          ],
        ),
      ],
    );
  }
}

class _RuleCheck extends StatelessWidget {
  const _RuleCheck(this.label, this.met);

  final String label;
  final bool met;

  @override
  Widget build(BuildContext context) {
    final color = met ? AppColors.success : Colors.grey;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          met ? Icons.check_circle_rounded : Icons.circle_outlined,
          size: 13,
          color: color,
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: met ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
