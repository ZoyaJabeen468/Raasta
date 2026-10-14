import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/raasta_logo.dart';
import 'brand_buttons.dart';

/// Dark teal auth chrome, matched to onboarding. Form layout is unchanged.
class AuthShell extends StatelessWidget {
  const AuthShell({
    super.key,
    required this.child,
    this.leading,
  });

  final Widget child;
  final Widget? leading;

  static const _overlay = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.forest,
    systemNavigationBarIconBrightness: Brightness.light,
  );

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.dark(),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: _overlay,
        child: Builder(
          builder: (context) {
            final p = context.palette;
            final topPad = MediaQuery.paddingOf(context).top;

            return Scaffold(
              backgroundColor: AppColors.forest,
              body: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: AppColors.splashGradient,
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(24, topPad + 14, 24, 12),
                      child: Row(
                        children: [
                          if (leading != null) ...[
                            leading!,
                            const SizedBox(width: 8),
                          ],
                          const RaastaLogo(
                            size: 40,
                            circular: true,
                            filled: false,
                          ),
                          const SizedBox(width: 10),
                          const RaastaWordmark(
                            fontSize: 16,
                            color: AppColors.white,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: p.surface.withValues(alpha: 0.92),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(AppRadii.xl),
                          ),
                          border: Border(
                            top: BorderSide(
                              color: AppColors.mint.withValues(alpha: 0.18),
                            ),
                          ),
                        ),
                        child: child,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
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
