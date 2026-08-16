import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/validators.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/auth_header.dart';
import '../../widgets/brand_buttons.dart';
import '../../widgets/input_field.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _sent = false;
  int _cooldown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _cooldown = 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_cooldown <= 1) {
        t.cancel();
        setState(() => _cooldown = 0);
      } else {
        setState(() => _cooldown -= 1);
      }
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (_cooldown > 0) return;

    final auth = context.read<AuthProvider>();
    final ok = await auth.sendPasswordReset(_email.text);
    if (!mounted) return;
    if (ok) {
      setState(() => _sent = true);
      _startCooldown();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AuthHeader(),
                const SizedBox(height: 28),
                if (_sent) ...[
                  Container(
                    width: 72,
                    height: 72,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.safe.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Icon(
                      Icons.mark_email_read_rounded,
                      size: 34,
                      color: AppColors.safe,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Check your inbox',
                    style: GoogleFonts.sora(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: p.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'We sent a reset link to ${_email.text.trim()}. '
                    'Open it on this phone, then come back to sign in.',
                    style: GoogleFonts.dmSans(
                      fontSize: 15,
                      height: 1.45,
                      color: p.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 28),
                  GradientButton(
                    label: 'Back to sign in',
                    icon: Icons.login_rounded,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: (_cooldown > 0 || auth.isBusy) ? null : _submit,
                    child: Text(
                      _cooldown > 0
                          ? 'Resend in ${_cooldown}s'
                          : 'Resend link',
                    ),
                  ),
                ] else ...[
                  Text(
                    'Forgot password',
                    style: GoogleFonts.sora(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: p.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'We’ll email you a reset link.',
                    style: GoogleFonts.dmSans(
                      fontSize: 15,
                      color: p.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 28),
                  InputField(
                    controller: _email,
                    hint: 'Email',
                    prefixIcon: Icons.mail_outline_rounded,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    validator: Validators.email,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  if (auth.error != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      auth.error!,
                      style: const TextStyle(color: AppColors.alert),
                    ),
                  ],
                  const SizedBox(height: 24),
                  GradientButton(
                    label: 'Send reset link',
                    loading: auth.isBusy,
                    onPressed: _submit,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
