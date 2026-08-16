import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/config/firebase_bootstrap.dart';
import '../../core/theme/app_colors.dart';

/// Dev-only reminder when Firebase keys are missing.
/// Hidden in release builds so demos look professional.
class FirebaseSetupBanner extends StatelessWidget {
  const FirebaseSetupBanner({super.key});

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();
    if (FirebaseBootstrap.ready) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 18,
            color: AppColors.amber,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Firebase is not configured yet, so sign up and sign in are '
              'disabled. Run flutterfire configure and restart the app.',
              style: GoogleFonts.dmSans(
                fontSize: 12.5,
                height: 1.45,
                color: AppColors.amber,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
