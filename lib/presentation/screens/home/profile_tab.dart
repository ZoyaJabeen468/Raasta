import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/config/firebase_bootstrap.dart';
import '../../../core/constants/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/achievement.dart';
import '../../../data/models/driver_details.dart';
import '../../../data/models/driver_tier.dart';
import '../../../data/models/trip_stats.dart';
import '../../providers/auth_provider.dart';
import '../../providers/driver_profile_provider.dart';
import '../../providers/trips_provider.dart';
import '../../widgets/app_card.dart';
import '../../widgets/raasta_nav_bar.dart';

/// Profile tab — identity, driver details, achievements and quick actions.
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final details = context.watch<DriverProfileProvider>().details;
    final stats = context.watch<TripsProvider>().stats;

    final user = auth.user;
    final name = (user?.name.trim().isNotEmpty ?? false)
        ? user!.name.trim()
        : 'Driver';

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, RaastaNavBar.contentInset),
        children: [
          _ProfileHero(
            name: name,
            email: user?.email ?? '',
            memberSince: user?.createdAt,
            photoPath: details.photoPath,
            stats: stats,
          ),
          const SizedBox(height: 22),
          const SectionHeading('Driver info'),
          _DriverInfoCard(details: details),
          const SizedBox(height: 22),
          const SectionHeading('Achievements'),
          _AchievementStrip(achievements: Achievement.evaluate(stats)),
          const SizedBox(height: 22),
          const SectionLabel('Account'),
          _ActionTile(
            icon: Icons.person_outline_rounded,
            title: 'Edit profile',
            subtitle: 'Name, photo, vehicle details',
            onTap: () => Navigator.of(context).pushNamed(AppRoutes.editProfile),
          ),
          const SizedBox(height: 10),
          _ActionTile(
            icon: Icons.settings_outlined,
            title: 'Settings',
            subtitle: 'Theme, voice, permissions, account',
            onTap: () => Navigator.of(context).pushNamed(AppRoutes.settings),
          ),
          const SizedBox(height: 22),
          const SectionLabel('More'),
          _ActionTile(
            icon: Icons.info_outline_rounded,
            title: 'About RAASTA',
            subtitle: 'What the app does and how',
            onTap: () => Navigator.of(context).pushNamed(AppRoutes.about),
          ),
          const SizedBox(height: 10),
          _ActionTile(
            icon: Icons.help_outline_rounded,
            title: 'Help & support',
            subtitle: 'FAQs and how RAASTA works',
            onTap: () => Navigator.of(context).pushNamed(AppRoutes.faq),
          ),
          const SizedBox(height: 10),
          _ActionTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy policy',
            subtitle: 'How your data is handled',
            onTap: () => Navigator.of(context).pushNamed(AppRoutes.privacy),
          ),
          const SizedBox(height: 22),
          OutlinedButton.icon(
            onPressed: () => _confirmSignOut(context),
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Log out'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.alert,
              side: BorderSide(color: AppColors.alert.withValues(alpha: 0.45)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('Your trips stay saved on this device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.alert),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    await auth.signOut();
    if (!context.mounted) return;
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.welcome, (_) => false);
  }
}

/// Gradient identity card: brand line, tier badge, avatar and a stats strip.
class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.name,
    required this.email,
    required this.memberSince,
    required this.photoPath,
    required this.stats,
  });

  final String name;
  final String email;
  final DateTime? memberSince;
  final String photoPath;
  final TripStats stats;

  @override
  Widget build(BuildContext context) {
    final tier = DriverTier.of(stats);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0C7A73), Color(0xFF16A79C)],
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: AppColors.teal.withValues(alpha: 0.32),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'RAASTA',
                style: GoogleFonts.sora(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.6,
                  color: AppColors.white.withValues(alpha: 0.85),
                ),
              ),
              const Spacer(),
              Tooltip(
                message: tier.nextGoal(stats),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(tier.icon, size: 14, color: AppColors.white),
                      const SizedBox(width: 5),
                      Text(
                        tier.label,
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              GestureDetector(
                onTap: () =>
                    Navigator.of(context).pushNamed(AppRoutes.editProfile),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ProfileAvatar(name: name, photoPath: photoPath, size: 66),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.photo_camera_rounded,
                          size: 13,
                          color: AppColors.tealDeep,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.sora(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.white,
                      ),
                    ),
                    if (email.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          color: AppColors.white.withValues(alpha: 0.82),
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          FirebaseBootstrap.ready
                              ? Icons.cloud_done_rounded
                              : Icons.phone_android_rounded,
                          size: 13,
                          color: AppColors.white.withValues(alpha: 0.8),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          FirebaseBootstrap.ready
                              ? 'Cloud-synced'
                              : 'On this device',
                          style: GoogleFonts.dmSans(
                            fontSize: 11.5,
                            color: AppColors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              tier.nextGoal(stats),
              style: GoogleFonts.dmSans(
                fontSize: 12.5,
                height: 1.35,
                color: AppColors.white.withValues(alpha: 0.88),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                _HeroStat(
                  value: '${stats.totalTrips}',
                  label: stats.totalTrips == 1 ? 'Trip' : 'Trips',
                ),
                const _HeroDivider(),
                _HeroStat(
                  value: Format.distance(stats.totalDistanceMeters),
                  label: 'Distance',
                ),
                const _HeroDivider(),
                _HeroStat(
                  value: stats.isEmpty ? '—' : '${stats.safetyScore}',
                  label: 'Score',
                ),
                const _HeroDivider(),
                _HeroStat(
                  value: memberSince == null
                      ? '—'
                      : '${memberSince!.year}',
                  label: 'Since',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.sora(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.dmSans(
              fontSize: 11,
              color: AppColors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroDivider extends StatelessWidget {
  const _HeroDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 30,
      color: AppColors.white.withValues(alpha: 0.22),
    );
  }
}

/// Circular avatar that falls back to initials when no photo is set.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.name,
    required this.photoPath,
    this.size = 64,
  });

  final String name;
  final String photoPath;
  final double size;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    if (parts.isEmpty) return 'D';
    return parts.take(2).map((w) => w[0].toUpperCase()).join();
  }

  /// Web picks return blob URLs, mobile returns real file paths.
  ImageProvider? get _image {
    if (photoPath.isEmpty) return null;
    if (kIsWeb) return NetworkImage(photoPath);
    return File(photoPath).existsSync() ? FileImage(File(photoPath)) : null;
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: image == null ? AppColors.driveGradient : null,
        shape: BoxShape.circle,
        image: image == null
            ? null
            : DecorationImage(image: image, fit: BoxFit.cover),
        boxShadow: [
          BoxShadow(
            color: AppColors.teal.withValues(alpha: 0.28),
            blurRadius: size * 0.3,
            offset: Offset(0, size * 0.1),
          ),
        ],
      ),
      child: image != null
          ? null
          : Text(
              _initials,
              style: GoogleFonts.sora(
                color: AppColors.white,
                fontSize: size * 0.34,
                fontWeight: FontWeight.w700,
              ),
            ),
    );
  }
}

class _DriverInfoCard extends StatelessWidget {
  const _DriverInfoCard({required this.details});

  final DriverDetails details;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    if (details.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        onTap: () => Navigator.of(context).pushNamed(AppRoutes.editProfile),
        child: Column(
          children: [
            Icon(Icons.badge_outlined, size: 28, color: p.textSecondary),
            const SizedBox(height: 12),
            Text(
              'No driver info yet',
              style: GoogleFonts.sora(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                color: p.textPrimary,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Add your age, experience and vehicle so alerts can be tuned '
              'to how you drive.',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: p.textSecondary,
                height: 1.45,
              ),
            ),
          ],
        ),
      );
    }

    final rows = <(IconData, String, String)>[
      if (details.age != null)
        (Icons.cake_outlined, 'Age', '${details.age} years'),
      if (details.experience != null)
        (
          Icons.timeline_rounded,
          'Experience',
          details.experience!.label,
        ),
      if (details.vehicle != null)
        (details.vehicle!.icon, 'Vehicle', details.vehicle!.label),
      if (details.vehicleModel.isNotEmpty)
        (Icons.build_outlined, 'Model', details.vehicleModel),
      if (details.plate.isNotEmpty)
        (Icons.confirmation_number_outlined, 'Plate', details.plate),
    ];

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Icon(rows[i].$1, size: 18, color: p.brand),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      rows[i].$2,
                      style: GoogleFonts.dmSans(
                        fontSize: 13.5,
                        color: p.textSecondary,
                      ),
                    ),
                  ),
                  Text(
                    rows[i].$3,
                    style: GoogleFonts.dmSans(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: p.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            if (i != rows.length - 1) Divider(color: p.border, height: 1),
          ],
        ],
      ),
    );
  }
}

class _AchievementStrip extends StatelessWidget {
  const _AchievementStrip({required this.achievements});

  final List<Achievement> achievements;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
      child: Column(
        children: [
          Row(
            children: [
              for (final item in achievements)
                Expanded(child: _Badge(achievement: item)),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '${achievements.where((a) => a.unlocked).length} of '
            '${achievements.length} unlocked',
            style: GoogleFonts.dmSans(fontSize: 12.5, color: p.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.achievement});

  final Achievement achievement;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final unlocked = achievement.unlocked;
    final tint = unlocked ? AppColors.amber : p.textSecondary;

    return Tooltip(
      message: achievement.requirement,
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 46,
                height: 46,
                child: CircularProgressIndicator(
                  value: unlocked ? 1 : achievement.progress,
                  strokeWidth: 3,
                  backgroundColor: p.surfaceAlt,
                  valueColor: AlwaysStoppedAnimation(
                    unlocked ? AppColors.amber : p.brand.withValues(alpha: 0.6),
                  ),
                ),
              ),
              Icon(
                achievement.icon,
                size: 20,
                color: unlocked ? tint : p.textSecondary.withValues(alpha: 0.6),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            achievement.label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: unlocked ? FontWeight.w700 : FontWeight.w500,
              color: unlocked ? p.textPrimary : p.textSecondary,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return AppCard(
      radius: 16,
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: p.brandSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 19, color: p.brand),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.dmSans(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: p.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.dmSans(
                    fontSize: 12.5,
                    color: p.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: p.textSecondary, size: 20),
        ],
      ),
    );
  }
}
