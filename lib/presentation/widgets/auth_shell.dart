import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_palette.dart';
import '../../core/widgets/raasta_logo.dart';
import 'brand_buttons.dart';

/// Compact brand header + white form sheet used by Welcome, Login, and Sign up.
class AuthShell extends StatelessWidget {
  const AuthShell({
    super.key,
    required this.child,
    this.leading,
  });

  final Widget child;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final topPad = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: p.background,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(24, topPad + 14, 24, 28),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [p.washTop, p.brandSoft],
              ),
            ),
            child: Row(
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: 8),
                ],
                const RaastaLogo(size: 36),
                const SizedBox(width: 10),
                RaastaWordmark(fontSize: 16, color: p.brand),
              ],
            ),
          ),
          Expanded(
            child: Transform.translate(
              offset: const Offset(0, -16),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: p.shadow,
                      blurRadius: 18,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pill Google button used on sign in and sign up.
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({
    super.key,
    required this.loading,
    required this.onPressed,
  });

  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final enabled = onPressed != null && !loading;

    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: p.border),
        boxShadow: [
          BoxShadow(
            color: p.shadow,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(99),
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(99),
          child: loading
              ? Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.1,
                      color: p.brand,
                    ),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const GoogleGlyph(size: 20),
                    const SizedBox(width: 12),
                    Text(
                      'Sign in with Google',
                      style: GoogleFonts.dmSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: p.textPrimary,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
