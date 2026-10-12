import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/routes.dart';
import '../../../core/navigation/auth_navigator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/validators.dart';
import '../../../data/services/auth_service.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/auth_shell.dart';
import '../../widgets/brand_buttons.dart';
import '../../widgets/firebase_setup_banner.dart';
import '../../widgets/input_field.dart';
import '../../widgets/screen_back_button.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _googleBusy = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final ok = await auth.signUp(
      name: _name.text,
      email: _email.text,
      password: _password.text,
    );
    if (!mounted) return;
    if (ok) {
      await AuthNavigator.afterAuth(context, auth, isNewUser: true);
    }
  }

  Future<void> _google() async {
    setState(() => _googleBusy = true);
    final auth = context.read<AuthProvider>();
    final ok = await auth.signInWithProvider(SocialProvider.google);
    if (!mounted) return;
    setState(() => _googleBusy = false);
    if (ok) {
      await AuthNavigator.afterAuth(
        context,
        auth,
        isNewUser: auth.isNewAccount,
      );
    } else if (auth.error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(auth.error!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final auth = context.watch<AuthProvider>();
    final busy = auth.isBusy || _googleBusy;

    return AuthShell(
      leading: BackCircle(
        onTap: () => Navigator.of(context).maybePop(),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 28),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Sign up',
                textAlign: TextAlign.center,
                style: GoogleFonts.sora(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: p.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Create your account to get started.',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontSize: 14.5,
                  color: p.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),
              const FirebaseSetupBanner(),
              InputField(
                controller: _name,
                label: 'Full name',
                hint: 'Enter your name',
                prefixIcon: Icons.person_outline_rounded,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                validator: Validators.name,
                enabled: !busy,
              ),
              const SizedBox(height: 14),
              InputField(
                controller: _email,
                label: 'Email',
                hint: 'Enter your email',
                prefixIcon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: Validators.email,
                enabled: !busy,
              ),
              const SizedBox(height: 14),
              InputField(
                controller: _password,
                label: 'Password',
                hint: 'Create a password',
                prefixIcon: Icons.lock_outline_rounded,
                obscureText: _obscure,
                textInputAction: TextInputAction.next,
                validator: Validators.password,
                enabled: !busy,
                suffix: IconButton(
                  onPressed: busy
                      ? null
                      : () => setState(() => _obscure = !_obscure),
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
                controller: _confirm,
                label: 'Confirm password',
                hint: 'Re-enter your password',
                prefixIcon: Icons.lock_outline_rounded,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                validator: (v) =>
                    Validators.confirmPassword(v, _password.text),
                onFieldSubmitted: (_) => _submit(),
                enabled: !busy,
              ),
              if (auth.error != null) ...[
                const SizedBox(height: 12),
                Text(
                  auth.error!,
                  style: GoogleFonts.dmSans(
                    color: AppColors.alert,
                    fontSize: 13,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              GradientButton(
                label: 'Sign up',
                loading: auth.isBusy,
                onPressed: busy ? null : _submit,
              ),
              const SizedBox(height: 22),
              const LabelledDivider(label: 'or'),
              const SizedBox(height: 16),
              GoogleSignInButton(
                loading: _googleBusy,
                onPressed: busy ? null : _google,
              ),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Already have an account? ',
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      color: p.textSecondary,
                    ),
                  ),
                  GestureDetector(
                    onTap: busy
                        ? null
                        : () {
                            auth.clearMessages();
                            Navigator.of(context).pushReplacementNamed(
                              AppRoutes.login,
                            );
                          },
                    child: Text(
                      'Sign in',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: p.brand,
                      ),
                    ),
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
