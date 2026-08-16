import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// On wide screens (Chrome desktop), show a phone-sized frame so the UI
/// looks like a real Android app instead of a stretched webpage.
class AppViewport extends StatelessWidget {
  const AppViewport({super.key, required this.child});

  final Widget child;

  static const double phoneWidth = 390;
  static const double phoneHeight = 844;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return child;

    return LayoutBuilder(
      builder: (context, constraints) {
        final useFrame = constraints.maxWidth > phoneWidth + 48;

        if (!useFrame) return child;

        return ColoredBox(
          color: const Color(0xFF0A121C),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'RAASTA · phone preview',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.fog.withValues(alpha: 0.7),
                        letterSpacing: 0.8,
                      ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: phoneWidth,
                  height: phoneHeight.clamp(0, constraints.maxHeight - 64),
                  decoration: BoxDecoration(
                    color: AppColors.mist,
                    borderRadius: BorderRadius.circular(36),
                    border: Border.all(color: const Color(0xFF2A3A4A), width: 10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        blurRadius: 40,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      size: Size(
                        phoneWidth,
                        phoneHeight.clamp(0, constraints.maxHeight - 64),
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
    );
  }
}
