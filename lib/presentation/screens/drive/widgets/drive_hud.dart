import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/speed_band.dart';

/// Top status strip over the viewfinder: live speed, limit, time, distance.
class DriveHud extends StatelessWidget {
  const DriveHud({
    super.key,
    required this.speedKph,
    required this.speedLimitKph,
    required this.band,
    required this.elapsedSeconds,
    required this.distanceMeters,
    required this.hazardCount,
    this.usingGps = true,
    this.arming = false,
    this.compact = false,
    this.onStartNow,
  });

  final double speedKph;
  final int speedLimitKph;
  final SpeedBand band;
  final int elapsedSeconds;
  final double distanceMeters;
  final int hazardCount;
  final bool usingGps;
  final bool arming;
  final bool compact;
  final VoidCallback? onStartNow;

  @override
  Widget build(BuildContext context) {
    final metrics = Row(
      children: [
        Expanded(
          child: _Metric(
            icon: Icons.schedule_rounded,
            label: 'Time',
            value: Format.duration(elapsedSeconds),
            compact: compact,
          ),
        ),
        Expanded(
          child: _Metric(
            icon: Icons.straighten_rounded,
            label: 'Distance',
            value: Format.distance(distanceMeters),
            compact: compact,
          ),
        ),
        Expanded(
          child: _Metric(
            icon: Icons.warning_amber_rounded,
            label: 'Hazards',
            value: '$hazardCount',
            tint: hazardCount > 0 ? AppColors.amber : null,
            compact: compact,
          ),
        ),
      ],
    );

    return Column(
      children: [
        _Speedometer(
          speedKph: speedKph,
          speedLimitKph: speedLimitKph,
          band: band,
          usingGps: usingGps,
          arming: arming,
          compact: compact,
          onStartNow: onStartNow,
        ),
        SizedBox(height: compact ? 8 : 14),
        metrics,
      ],
    );
  }
}

class _Speedometer extends StatelessWidget {
  const _Speedometer({
    required this.speedKph,
    required this.speedLimitKph,
    required this.band,
    required this.usingGps,
    required this.arming,
    this.compact = false,
    this.onStartNow,
  });

  final double speedKph;
  final int speedLimitKph;
  final SpeedBand band;
  final bool usingGps;
  final bool arming;
  final bool compact;
  final VoidCallback? onStartNow;

  @override
  Widget build(BuildContext context) {
    final tint = band.color;
    final speedSize = compact ? 28.0 : 36.0;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 14 : 18,
        vertical: compact ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tint.withValues(alpha: 0.65), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: tint.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${speedKph.round()}',
                style: GoogleFonts.sora(
                  color: tint,
                  fontSize: speedSize,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'km/h',
                style: GoogleFonts.dmSans(
                  color: tint.withValues(alpha: 0.85),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 14),
              Container(
                width: 1,
                height: 28,
                color: Colors.white24,
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'LIMIT',
                    style: GoogleFonts.dmSans(
                      color: Colors.white54,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                  Text(
                    '$speedLimitKph',
                    style: GoogleFonts.sora(
                      color: Colors.white,
                      fontSize: compact ? 16 : 18,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: compact ? 6 : 8),
          if (arming) ...[
            Text(
              compact
                  ? 'Scanning · tap Start below'
                  : 'AI is scanning · trip starts above ${DriveHudConstants.tripStartHint} km/h',
              style: GoogleFonts.dmSans(
                color: Colors.white70,
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (onStartNow != null) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: onStartNow,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.teal.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    'Start trip now (demo)',
                    style: GoogleFonts.dmSans(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ] else
            Text(
              usingGps
                  ? _bandLabel(band)
                  : 'Simulated speed · enable location for GPS',
              style: GoogleFonts.dmSans(
                color: Colors.white70,
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }

  String _bandLabel(SpeedBand band) {
    switch (band) {
      case SpeedBand.safe:
        return 'Safe speed';
      case SpeedBand.caution:
        return 'Approaching limit';
      case SpeedBand.over:
        return 'Over speed limit';
    }
  }
}

/// Shared constants referenced by the HUD subtitle without importing provider.
abstract final class DriveHudConstants {
  static const tripStartHint = 5;
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    required this.label,
    required this.value,
    this.tint,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? tint;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = tint ?? Colors.white;

    return Column(
      children: [
        Icon(icon, size: compact ? 14 : 16, color: color.withValues(alpha: 0.85)),
        SizedBox(height: compact ? 3 : 5),
        Text(
          value,
          style: GoogleFonts.sora(
            color: color,
            fontSize: compact ? 13 : 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          style: GoogleFonts.dmSans(
            color: Colors.white60,
            fontSize: compact ? 10 : 11,
          ),
        ),
      ],
    );
  }
}
