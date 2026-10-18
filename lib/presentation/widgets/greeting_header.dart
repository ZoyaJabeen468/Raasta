import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/widgets/raasta_logo.dart';

/// Floating pill top bar: brand on the left, compact actions on the right.
class PillAppBar extends StatelessWidget {
  const PillAppBar({
    super.key,
    this.actions = const [],
  });

  final List<PillBarAction> actions;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: p.border),
        boxShadow: [
          BoxShadow(
            color: p.shadow,
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          const RaastaLogo(size: 32),
          const SizedBox(width: 8),
          RaastaWordmark(fontSize: 14, color: p.brand),
          const Spacer(),
          for (var i = 0; i < actions.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            _PillIconButton(action: actions[i]),
          ],
        ],
      ),
    );
  }
}

@immutable
class PillBarAction {
  const PillBarAction({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.badgeCount,
    this.showDot = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final int? badgeCount;
  final bool showDot;
}

/// Kept for older call sites that still use [GreetingHeader] actions.
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
  final bool showDot;

  PillBarAction toPill() => PillBarAction(
        icon: icon,
        onTap: onTap,
        tooltip: tooltip,
        showDot: showDot,
      );
}

class _PillIconButton extends StatelessWidget {
  const _PillIconButton({required this.action});

  final PillBarAction action;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final badge = action.badgeCount;

    return Tooltip(
      message: action.tooltip,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: action.onTap,
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: 36,
                height: 36,
                child: Icon(action.icon, size: 18, color: p.textPrimary),
              ),
            ),
          ),
          if (action.showDot && badge == null)
            Positioned(
              top: 6,
              right: 7,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.alert,
                  shape: BoxShape.circle,
                  border: Border.all(color: p.surface, width: 1.5),
                ),
              ),
            ),
          if (badge != null && badge > 0)
            Positioned(
              top: 2,
              right: 2,
              child: Container(
                constraints: const BoxConstraints(minWidth: 16),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                height: 16,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.alert,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: p.surface, width: 1.5),
                ),
                child: Text(
                  badge > 9 ? '9+' : '$badge',
                  style: GoogleFonts.dmSans(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: AppColors.white,
                    height: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Legacy greeting card. Prefer [PillAppBar] + a welcome hero on Home.
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
    return PillAppBar(
      actions: [for (final a in actions) a.toPill()],
    );
  }
}
