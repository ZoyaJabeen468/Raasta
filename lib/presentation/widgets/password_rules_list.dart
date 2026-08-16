import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/utils/validators.dart';

/// Live checklist under the password field on sign-up / change-password.
class PasswordRulesList extends StatelessWidget {
  const PasswordRulesList({super.key, required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final rules = Validators.passwordRules(password);

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        children: [
          for (final rule in rules)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(
                    rule.met
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked,
                    size: 16,
                    color: rule.met ? AppColors.safe : p.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      rule.label,
                      style: GoogleFonts.dmSans(
                        fontSize: 12.5,
                        color: rule.met ? AppColors.safe : p.textSecondary,
                        fontWeight:
                            rule.met ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
