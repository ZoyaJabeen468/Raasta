import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/navigation/auth_navigator.dart';
import '../../data/services/auth_service.dart';
import '../providers/auth_provider.dart';
import 'brand_buttons.dart';

/// The "Continue with …" block shared by welcome, login and signup.
class SocialSignIn extends StatefulWidget {
  const SocialSignIn({super.key, this.dividerLabel = 'or continue with email'});

  final String dividerLabel;

  @override
  State<SocialSignIn> createState() => _SocialSignInState();
}

class _SocialSignInState extends State<SocialSignIn> {
  SocialProvider? _pending;

  Future<void> _go(SocialProvider provider) async {
    setState(() => _pending = provider);

    final auth = context.read<AuthProvider>();
    final ok = await auth.signInWithProvider(provider);

    if (!mounted) return;
    setState(() => _pending = null);

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
    final busy = _pending != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: SocialButton(
                label: 'Google',
                glyph: const GoogleGlyph(),
                loading: _pending == SocialProvider.google,
                onPressed: busy ? null : () => _go(SocialProvider.google),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SocialButton(
                label: 'Facebook',
                glyph: const FacebookGlyph(),
                loading: _pending == SocialProvider.facebook,
                onPressed: busy ? null : () => _go(SocialProvider.facebook),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        LabelledDivider(label: widget.dividerLabel),
        const SizedBox(height: 22),
      ],
    );
  }
}
