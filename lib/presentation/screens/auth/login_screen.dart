import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/routes.dart';
import '../../../core/navigation/auth_navigator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/validators.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/auth_header.dart';
import '../../widgets/firebase_setup_banner.dart';
import '../../widgets/brand_buttons.dart';
import '../../widgets/input_field.dart';
import '../../widgets/social_sign_in.dart';

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
                Text(
                  'Welcome back',
                  style: GoogleFonts.sora(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: p.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sign in to pick up where you left off.',
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    color: p.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                const FirebaseSetupBanner(),
                const SocialSignIn(),
                InputField(
                  controller: _email,
                  hint: 'Email',
                  prefixIcon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: Validators.email,
                ),
                const SizedBox(height: 14),
                InputField(
                  controller: _password,
                  hint: 'Password',
                  prefixIcon: Icons.lock_outline_rounded,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  validator: Validators.password,
                  onFieldSubmitted: (_) => _submit(),
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
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      auth.clearMessages();
                      Navigator.of(context).pushNamed(
                        AppRoutes.forgotPassword,
                      );
                    },
                    child: const Text('Forgot password?'),
                  ),
                ),
                if (auth.error != null) ...[
                  Text(
                    auth.error!,
                    style: const TextStyle(color: AppColors.alert),
                  ),
                  const SizedBox(height: 12),
                ],
                GradientButton(
                  label: 'Sign in',
                  loading: auth.isBusy,
                  onPressed: _submit,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'New to RAASTA? ',
                      style: GoogleFonts.dmSans(color: p.textSecondary),
                    ),
                    GestureDetector(
                      onTap: auth.isBusy
                          ? null
                          : () {
                              auth.clearMessages();
                              Navigator.of(context).pushReplacementNamed(
                                AppRoutes.signup,
                              );
                            },
                      child: Text(
                        'Create one',
                        style: GoogleFonts.dmSans(
                          color: p.brand,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
