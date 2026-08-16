import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_palette.dart';

/// Seven-day hazard bars with the current day highlighted.
class WeekBars extends StatelessWidget {
  const WeekBars({
    super.key,
    required this.values,
    required this.labels,
    this.height = 96,
  });

  final List<int> values;
  final List<String> labels;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final peak = values.fold<int>(0, (max, v) => v > max ? v : max);

    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: _Bar(
                value: values[i],
                peak: peak,
                label: i < labels.length ? labels[i] : '',
                isToday: i == values.length - 1,
                palette: p,
              ),
            ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.value,
    required this.peak,
    required this.label,
    required this.isToday,
    required this.palette,
  });

  final int value;
  final int peak;
  final String label;
  final bool isToday;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final ratio = peak == 0 ? 0.0 : value / peak;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          value == 0 ? '' : '$value',
          style: GoogleFonts.dmSans(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: palette.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: ratio),
                duration: const Duration(milliseconds: 650),
                curve: Curves.easeOutCubic,
                builder: (context, t, _) {
                  final barHeight = 6 + (constraints.maxHeight - 6) * t;
                  return Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: 14,
                      height: barHeight,
                      decoration: BoxDecoration(
                        gradient: value == 0
                            ? null
                            : LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  palette.brand,
                                  palette.brand.withValues(alpha: 0.55),
                                ],
                              ),
                        color: value == 0 ? palette.surfaceAlt : null,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 11,
            fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
            color: isToday ? palette.brand : palette.textSecondary,
          ),
        ),
      ],
    );
  }
}
