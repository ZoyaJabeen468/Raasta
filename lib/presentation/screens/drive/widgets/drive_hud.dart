import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/speed_band.dart';

/// Compact glass HUD over the viewfinder: speed, limit, trip metrics.
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
    final pad = compact ? 12.0 : 14.0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(pad, pad, pad, compact ? 10 : 12),
      decoration: BoxDecoration(
        color: const Color(0xCC12171C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        children: [
          _SpeedRow(
            speedKph: speedKph,
            speedLimitKph: speedLimitKph,
            band: band,
            compact: compact,
          ),
          SizedBox(height: compact ? 8 : 10),
          if (arming)
            _ArmingRow(compact: compact, onStartNow: onStartNow)
          else
            Text(
              usingGps
                  ? _bandLabel(band)
                  : 'Simulated speed · enable location for GPS',
              style: GoogleFonts.dmSans(
                color: Colors.white60,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          SizedBox(height: compact ? 10 : 12),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
          SizedBox(height: compact ? 10 : 12),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  icon: Icons.schedule_outlined,
                  label: 'Time',
                  value: Format.duration(elapsedSeconds),
                  compact: compact,
                ),
              ),
              _VertRule(),
              Expanded(
                child: _Metric(
                  icon: Icons.straighten_outlined,
                  label: 'Distance',
                  value: Format.distance(distanceMeters),
                  compact: compact,
                ),
              ),
              _VertRule(),
              Expanded(
                child: _Metric(
                  icon: Icons.warning_amber_outlined,
                  label: 'Hazards',
                  value: '$hazardCount',
                  tint: hazardCount > 0 ? AppColors.amber : null,
                  compact: compact,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _bandLabel(SpeedBand band) {
    return switch (band) {
      SpeedBand.safe => 'Within limit',
      SpeedBand.caution => 'Near limit',
      SpeedBand.over => 'Over limit',
    };
  }
}

class _SpeedRow extends StatelessWidget {
  const _SpeedRow({
    required this.speedKph,
    required this.speedLimitKph,
    required this.band,
    required this.compact,
  });

  final double speedKph;
  final int speedLimitKph;
  final SpeedBand band;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tint = band.color;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '${speedKph.round()}',
          style: GoogleFonts.sora(
            color: tint,
            fontSize: compact ? 34 : 42,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 6, bottom: 6),
          child: Text(
            'km/h',
            style: GoogleFonts.dmSans(
              color: tint.withValues(alpha: 0.85),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'LIMIT',
                style: GoogleFonts.dmSans(
                  color: Colors.white54,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$speedLimitKph',
                style: GoogleFonts.sora(
                  color: Colors.white,
                  fontSize: compact ? 16 : 18,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ArmingRow extends StatelessWidget {
  const _ArmingRow({required this.compact, this.onStartNow});

  final bool compact;
  final VoidCallback? onStartNow;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          compact
              ? 'Scanning · tap Start below'
              : 'Scanning · trip starts above ${DriveHudConstants.tripStartHint} km/h',
          textAlign: TextAlign.center,
          style: GoogleFonts.dmSans(
            color: Colors.white60,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (onStartNow != null) ...[
          const SizedBox(height: 10),
          GestureDetector(
            onTap: onStartNow,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.teal,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Start trip now',
                style: GoogleFonts.dmSans(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Shared constants referenced by the HUD subtitle without importing provider.
abstract final class DriveHudConstants {
  static const tripStartHint = 5;
}

class _VertRule extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      color: Colors.white.withValues(alpha: 0.08),
    );
  }
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
        Icon(icon, size: compact ? 14 : 15, color: color.withValues(alpha: 0.75)),
        SizedBox(height: compact ? 3 : 4),
        Text(
          value,
          style: GoogleFonts.sora(
            color: color,
            fontSize: compact ? 13 : 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          style: GoogleFonts.dmSans(
            color: Colors.white54,
            fontSize: 10.5,
          ),
        ),
      ],
    );
  }
}
