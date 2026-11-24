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

  final _loginEmail = TextEditingController(text: 'garv.client@example.com');
  final _loginPassword = TextEditingController(text: 'Client@123');

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

  Future<void> _showForgotPasswordDialog() async {
    final resetEmail = TextEditingController(text: _loginEmail.text);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Password'),
        content: TextField(
          controller: resetEmail,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Registered Email',
            hintText: 'name@example.com',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Password reset link sent to ${resetEmail.text.trim()}',
                  ),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Send Link'),
          ),
        ],
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
                  const SizedBox(height: 24),

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

                  const SizedBox(height: 18),
                  OutlinedButton.icon(
                    onPressed: vm.isLoading ? null : vm.signInDemo,
                    icon: const Icon(Icons.flash_on_rounded),
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
            decoration: const InputDecoration(
              labelText: 'Email Address',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _loginPassword,
            validator: Validators.password,
            obscureText: _obscureLogin,
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
              onPressed: _showForgotPasswordDialog,
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
            validator: Validators.password,
            obscureText: _obscureReg,
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
