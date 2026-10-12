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

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _googleBusy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final ok = await auth.signIn(
      email: _email.text,
      password: _password.text,
    );
    if (!mounted) return;
    if (ok) {
      await AuthNavigator.afterAuth(context, auth, isNewUser: false);
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
                'Sign in',
                textAlign: TextAlign.center,
                style: GoogleFonts.sora(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: p.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Welcome back. Sign in to continue.',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontSize: 14.5,
                  color: p.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              const FirebaseSetupBanner(),
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
                hint: 'Enter your password',
                prefixIcon: Icons.lock_outline_rounded,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                validator: Validators.loginPassword,
                onFieldSubmitted: (_) => _submit(),
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
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: busy
                      ? null
                      : () {
                          auth.clearMessages();
                          Navigator.of(context).pushNamed(
                            AppRoutes.forgotPassword,
                          );
                        },
                  style: TextButton.styleFrom(
                    foregroundColor: p.brand,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 2,
                      vertical: 2,
                    ),
                    minimumSize: const Size(0, 34),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Forgot password?',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              if (auth.error != null) ...[
                Text(
                  auth.error!,
                  style: GoogleFonts.dmSans(
                    color: AppColors.alert,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 10),
              ],
              GradientButton(
                label: 'Sign in',
                loading: auth.isBusy,
                onPressed: busy ? null : _submit,
              ),
              const SizedBox(height: 18),
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
                    'No account? ',
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
                              AppRoutes.signup,
                            );
                          },
                    child: Text(
                      'Create an account',
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
