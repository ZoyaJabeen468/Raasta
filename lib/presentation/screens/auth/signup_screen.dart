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
import '../../widgets/input_field.dart';
import '../../widgets/brand_buttons.dart';
import '../../widgets/password_rules_list.dart';
import '../../widgets/social_sign_in.dart';

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
                  'Create your account',
                  style: GoogleFonts.sora(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: p.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Just a few details and you are ready.',
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    color: p.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                const FirebaseSetupBanner(),
                const SocialSignIn(dividerLabel: 'or sign up with email'),
                InputField(
                  controller: _name,
                  hint: 'Full name',
                  prefixIcon: Icons.person_outline_rounded,
                  textInputAction: TextInputAction.next,
                  validator: Validators.name,
                ),
                const SizedBox(height: 14),
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
                  textInputAction: TextInputAction.next,
                  validator: Validators.password,
                  onChanged: (_) => setState(() {}),
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
                PasswordRulesList(password: _password.text),
                const SizedBox(height: 14),
                InputField(
                  controller: _confirm,
                  hint: 'Confirm password',
                  prefixIcon: Icons.lock_outline_rounded,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  validator: (v) =>
                      Validators.confirmPassword(v, _password.text),
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
                  label: 'Get started',
                  loading: auth.isBusy,
                  onPressed: _submit,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account? ',
                      style: GoogleFonts.dmSans(color: p.textSecondary),
                    ),
                    GestureDetector(
                      onTap: auth.isBusy
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
