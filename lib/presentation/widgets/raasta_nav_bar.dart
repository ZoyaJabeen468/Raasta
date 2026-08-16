import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';

/// Floating bottom navigation with a raised centre action.
///
/// The FAB overlaps the top edge of the bar, so scroll views must reserve
/// [contentInset] of bottom padding to keep content clear of it.
class RaastaNavBar extends StatelessWidget {
  const RaastaNavBar({
    super.key,
    required this.index,
    required this.onChanged,
    required this.items,
    required this.centerIcon,
    required this.centerTooltip,
    required this.onCenterTap,
  });

  final int index;
  final ValueChanged<int> onChanged;
  final List<NavBarItem> items;
  final IconData centerIcon;
  final String centerTooltip;
  final VoidCallback onCenterTap;

  /// Bottom padding a scroll view needs so its last item clears the bar.
  static const contentInset = 108.0;

  static const _barHeight = 68.0;
  static const _fabSize = 60.0;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return SizedBox(
      height: _barHeight + _fabSize / 2 + bottomInset,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            left: 12,
            right: 12,
            bottom: 0,
            child: Container(
              height: _barHeight + bottomInset,
              padding: EdgeInsets.only(bottom: bottomInset),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: p.border),
                boxShadow: [
                  BoxShadow(
                    color: p.shadow,
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    Expanded(
                      child: _NavItem(
                        item: items[i],
                        selected: i == index,
                        onTap: () => onChanged(i),
                      ),
                    ),
                    // Gap under the raised centre button.
                    if (i == items.length ~/ 2 - 1)
                      const SizedBox(width: _fabSize + 12),
                  ],
                ],
              ),
            ),
          ),
          Positioned(
            top: 0,
            child: Tooltip(
              message: centerTooltip,
              child: Semantics(
                button: true,
                label: centerTooltip,
                child: GestureDetector(
                  onTap: onCenterTap,
                  child: Container(
                    width: _fabSize,
                    height: _fabSize,
                    decoration: BoxDecoration(
                      gradient: AppColors.driveGradient,
                      shape: BoxShape.circle,
                      border: Border.all(color: p.washBottom, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.teal.withValues(alpha: 0.42),
                          blurRadius: 18,
                          offset: const Offset(0, 7),
                        ),
                      ],
                    ),
                    child: Icon(
                      centerIcon,
                      color: AppColors.white,
                      size: 27,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

@immutable
class NavBarItem {
  const NavBarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final NavBarItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final tint = selected ? p.brand : p.textSecondary;

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: selected ? p.brandSoft : Colors.transparent,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Icon(
                selected ? item.activeIcon : item.icon,
                size: 21,
                color: tint,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: tint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
