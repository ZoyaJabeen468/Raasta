import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/navigation/auth_navigator.dart';
import '../../data/services/auth_service.dart';
import '../providers/auth_provider.dart';
import 'auth_shell.dart';
import 'brand_buttons.dart';

/// Google-only social block for secondary auth flows.
class SocialSignIn extends StatefulWidget {
  const SocialSignIn({super.key, this.dividerLabel = 'Or'});

  final String dividerLabel;

  @override
  State<SocialSignIn> createState() => _SocialSignInState();
}

class _SocialSignInState extends State<SocialSignIn> {
  bool _pending = false;

  Future<void> _go() async {
    setState(() => _pending = true);

    final auth = context.read<AuthProvider>();
    final ok = await auth.signInWithProvider(SocialProvider.google);

    if (!mounted) return;
    setState(() => _pending = false);

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GoogleSignInButton(
          loading: _pending,
          onPressed: _pending ? null : _go,
        ),
        const SizedBox(height: 16),
        LabelledDivider(label: widget.dividerLabel),
        const SizedBox(height: 16),
      ],
    );
  }
}
