import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/constants/routes.dart';
import '../../core/navigation/auth_navigator.dart';
import '../../core/theme/app_palette.dart';
import '../../core/utils/validators.dart';
import '../../data/services/auth_service.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_shell.dart';
import '../widgets/brand_buttons.dart';
import '../widgets/firebase_setup_banner.dart';
import '../widgets/input_field.dart';

/// Landing screen: centred login form (email, password, Google).
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _obscure = true;
  bool _emailBusy = false;
  bool _googleBusy = false;

  bool get _busy => _emailBusy || _googleBusy;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signInEmail() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _emailBusy = true);
    final auth = context.read<AuthProvider>();
    final ok = await auth.signIn(
      email: _email.text,
      password: _password.text,
    );
    if (!mounted) return;
    setState(() => _emailBusy = false);

    if (ok) {
      await AuthNavigator.afterAuth(context, auth, isNewUser: false);
    } else if (auth.error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(auth.error!)));
    }
  }

  Future<void> _signInGoogle() async {
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

    return AuthShell(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
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
                    const SizedBox(height: 28),
                    const FirebaseSetupBanner(),
                    InputField(
                      controller: _email,
                      label: 'Email',
                      hint: 'Enter your email',
                      prefixIcon: Icons.mail_outline_rounded,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: Validators.email,
                      enabled: !_busy,
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
                      onFieldSubmitted: (_) => _signInEmail(),
                      enabled: !_busy,
                      suffix: IconButton(
                        onPressed: _busy
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
                        onPressed: _busy
                            ? null
                            : () => Navigator.of(context).pushNamed(
                                  AppRoutes.forgotPassword,
                                ),
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
                    const SizedBox(height: 8),
                    GradientButton(
                      label: 'Sign in',
                      loading: _emailBusy,
                      onPressed: _busy ? null : _signInEmail,
                    ),
                    const SizedBox(height: 22),
                    const LabelledDivider(label: 'or'),
                    const SizedBox(height: 16),
                    GoogleSignInButton(
                      loading: _googleBusy,
                      onPressed: _busy ? null : _signInGoogle,
                    ),
                    const SizedBox(height: 24),
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
                          onTap: _busy
                              ? null
                              : () => Navigator.of(context).pushNamed(
                                    AppRoutes.signup,
                                  ),
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
        },
      ),
    );
  }
}
