import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/ambient_scaffold.dart';
import '../../../core/utils/validators.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/input_field.dart';
import '../../widgets/brand_buttons.dart';
import '../../widgets/password_rules_list.dart';
import 'widgets/form_notice.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _next.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<AuthProvider>().clearMessages(),
    );
  }

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final ok = await auth.changePassword(
      currentPassword: _current.text,
      newPassword: _next.text,
    );
    if (!mounted || !ok) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Password updated')));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final auth = context.watch<AuthProvider>();

    return AmbientScaffold(
      appBar: AppBar(title: const Text('Change password')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const FormNotice(
                  icon: Icons.shield_outlined,
                  message:
                      'Use at least 8 characters with uppercase, lowercase, '
                      'a number, and a special character.',
                ),
                const SizedBox(height: 20),
                InputField(
                  controller: _current,
                  hint: 'Current password',
                  prefixIcon: Icons.lock_outline_rounded,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.next,
                  validator: (value) => (value == null || value.isEmpty)
                      ? 'Enter your current password'
                      : null,
                  suffix: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: p.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                InputField(
                  controller: _next,
                  hint: 'New password',
                  prefixIcon: Icons.lock_reset_rounded,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.next,
                  validator: Validators.password,
                ),
                const SizedBox(height: 10),
                _StrengthMeter(password: _next.text),
                PasswordRulesList(password: _next.text),
                const SizedBox(height: 14),
                InputField(
                  controller: _confirm,
                  hint: 'Confirm new password',
                  prefixIcon: Icons.lock_outline_rounded,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  validator: (value) =>
                      Validators.confirmPassword(value, _next.text),
                ),
                if (auth.error != null) ...[
                  const SizedBox(height: 14),
                  FormNotice.error(auth.error!),
                ],
                const SizedBox(height: 24),
                GradientButton(
                  label: 'Update password',
                  loading: auth.isBusy,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StrengthMeter extends StatelessWidget {
  const _StrengthMeter({required this.password});

  final String password;

  ({double value, String label, Color color}) get _strength {
    if (password.isEmpty) {
      return (value: 0, label: 'Strength', color: AppColors.slate);
    }

    var score = 0;
    if (password.length >= 8) score++;
    if (password.length >= 12) score++;
    if (RegExp(r'[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'\d').hasMatch(password)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) score++;

    if (score <= 2) {
      return (value: 0.33, label: 'Weak', color: AppColors.alert);
    }
    if (score <= 3) {
      return (value: 0.66, label: 'Fair', color: AppColors.amber);
    }
    return (value: 1, label: 'Strong', color: AppColors.safe);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final strength = _strength;

    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: strength.value),
              duration: const Duration(milliseconds: 350),
              builder: (context, t, _) => LinearProgressIndicator(
                value: t,
                minHeight: 5,
                backgroundColor: p.surfaceAlt,
                valueColor: AlwaysStoppedAnimation(strength.color),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          strength.label,
          style: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: strength.color,
          ),
        ),
      ],
    );
  }
}
