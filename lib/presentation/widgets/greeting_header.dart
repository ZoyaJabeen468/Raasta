import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';

/// Floating greeting card that sits over the ambient wash.
///
/// Holds a brand tile, a time-aware greeting with the driver's name, and up
/// to two circular actions on the right.
class GreetingHeader extends StatelessWidget {
  const GreetingHeader({
    super.key,
    required this.name,
    this.leadingIcon = Icons.directions_car_filled_rounded,
    this.actions = const [],
  });

  final String name;
  final IconData leadingIcon;
  final List<HeaderAction> actions;

  static String greetingFor(DateTime now) {
    final hour = now.hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    if (hour < 21) return 'Good evening';
    return 'Good night';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            p.brand.withValues(alpha: 0.16),
            p.brand.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: p.brand.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: AppColors.driveGradient,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(leadingIcon, color: AppColors.white, size: 23),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  greetingFor(DateTime.now()),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    fontSize: 12.5,
                    color: p.textSecondary,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.sora(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: p.textPrimary,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
          for (final action in actions) ...[
            const SizedBox(width: 8),
            _ActionCircle(action: action),
          ],
        ],
      ),
    );
  }
}

/// One circular action in the [GreetingHeader].
@immutable
class HeaderAction {
  const HeaderAction({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.showDot = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  /// Draws an unread indicator on the top-right of the circle.
  final bool showDot;
}

class _ActionCircle extends StatelessWidget {
  const _ActionCircle({required this.action});

  final HeaderAction action;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Tooltip(
      message: action.tooltip,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: p.surface.withValues(alpha: 0.85),
            shape: CircleBorder(side: BorderSide(color: p.border)),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: action.onTap,
              child: SizedBox(
                width: 42,
                height: 42,
                child: Icon(action.icon, size: 19, color: p.textPrimary),
              ),
            ),
          ),
          if (action.showDot)
            Positioned(
              top: 2,
              right: 2,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: AppColors.alert,
                  shape: BoxShape.circle,
                  border: Border.all(color: p.surface, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
