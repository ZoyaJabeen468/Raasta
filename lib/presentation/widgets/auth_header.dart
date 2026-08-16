import 'package:flutter/material.dart';

import '../../core/widgets/raasta_logo.dart';
import 'screen_back_button.dart';

/// Back control + brand mark shared by the auth screens.
class AuthHeader extends StatelessWidget {
  const AuthHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (Navigator.of(context).canPop()) const BackCircle(),
        const Spacer(),
        const RaastaLogo(size: 42),
      ],
    );
  }
}
