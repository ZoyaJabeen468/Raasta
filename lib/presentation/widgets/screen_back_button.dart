import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';

/// The app's single back affordance: a bordered circular icon button.
///
/// Used directly inside custom headers, or via [ScreenBackButton] when a
/// screen just needs a left-aligned back control above its content.
class BackCircle extends StatelessWidget {
  const BackCircle({super.key, this.onTap, this.icon = Icons.arrow_back_rounded});

  final VoidCallback? onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Semantics(
      button: true,
      label: 'Back',
      child: Material(
        color: p.surface,
        shape: CircleBorder(side: BorderSide(color: p.border)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap ?? () => Navigator.of(context).maybePop(),
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(icon, size: 20, color: p.textPrimary),
          ),
        ),
      ),
    );
  }
}

/// Left-aligned [BackCircle] for screens that don't use an [AppBar].
///
/// Renders nothing when there is no route to pop, so it can be dropped into
/// any screen without checking the navigation stack at each call site.
class ScreenBackButton extends StatelessWidget {
  const ScreenBackButton({super.key, this.onTap, this.bottomSpacing = 16});

  final VoidCallback? onTap;
  final double bottomSpacing;

  @override
  Widget build(BuildContext context) {
    if (!Navigator.of(context).canPop() && onTap == null) {
      return const SizedBox.shrink();
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomSpacing),
        child: BackCircle(onTap: onTap),
      ),
    );
  }
}
