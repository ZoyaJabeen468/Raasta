import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/config/firebase_bootstrap.dart';
import '../../../core/constants/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../data/models/achievement.dart';
import '../../../data/models/driver_details.dart';
import '../../../data/models/driver_tier.dart';
import '../../../data/models/trip_stats.dart';
import '../../providers/auth_provider.dart';
import '../../providers/driver_profile_provider.dart';
import '../../providers/trips_provider.dart';
import '../../widgets/app_card.dart';
import '../../widgets/greeting_header.dart';
import '../../widgets/raasta_nav_bar.dart';

/// Profile tab: identity, driver details, achievements and account actions.
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final auth = context.watch<AuthProvider>();
    final details = context.watch<DriverProfileProvider>().details;
    final stats = context.watch<TripsProvider>().stats;

    final user = auth.user;
    final name = (user?.name.trim().isNotEmpty ?? false)
        ? user!.name.trim()
        : 'Driver';

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, RaastaNavBar.contentInset),
        children: [
          const PillAppBar(),
          const SizedBox(height: 12),
          Text(
            'Profile',
            style: GoogleFonts.sora(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: p.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          _IdentityCard(
            name: name,
            email: user?.email ?? '',
            photoPath: details.photoPath,
          ),
          const SizedBox(height: 16),
          Text(
            'Driver info',
            style: GoogleFonts.sora(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: p.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          _DriverInfoCard(details: details, stats: stats),
          const SizedBox(height: 16),
          Text(
            'Achievements',
            style: GoogleFonts.sora(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: p.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          _AchievementList(achievements: Achievement.evaluate(stats)),
          const SizedBox(height: 16),
          Text(
            'Account',
            style: GoogleFonts.sora(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: p.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          _ActionGroup(
            items: [
              _ActionItem(
                icon: Icons.person_outline_rounded,
                title: 'Edit profile',
                subtitle: 'Name, photo, and vehicle details',
                onTap: () =>
                    Navigator.of(context).pushNamed(AppRoutes.editProfile),
              ),
              _ActionItem(
                icon: Icons.settings_outlined,
                title: 'Settings',
                subtitle: 'Theme, voice, permissions, account',
                onTap: () =>
                    Navigator.of(context).pushNamed(AppRoutes.settings),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Legal and help',
            style: GoogleFonts.sora(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: p.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          _ActionGroup(
            items: [
              _ActionItem(
                icon: Icons.info_outline_rounded,
                title: 'About RAASTA',
                subtitle: 'What the app does and how',
                onTap: () => Navigator.of(context).pushNamed(AppRoutes.about),
              ),
              _ActionItem(
                icon: Icons.help_outline_rounded,
                title: 'Help and support',
                subtitle: 'FAQs and how RAASTA works',
                onTap: () => Navigator.of(context).pushNamed(AppRoutes.faq),
              ),
              _ActionItem(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy policy',
                subtitle: 'How your data is handled',
                onTap: () =>
                    Navigator.of(context).pushNamed(AppRoutes.privacy),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () => _confirmSignOut(context),
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: Text(
                'Log out',
                style: GoogleFonts.dmSans(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.alert,
                side: BorderSide(
                  color: AppColors.alert.withValues(alpha: 0.45),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
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

/// White identity card. Standing and totals live elsewhere.
class _IdentityCard extends StatelessWidget {
  const _IdentityCard({
    required this.name,
    required this.email,
    required this.photoPath,
  });

  final String name;
  final String email;
  final String photoPath;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return AppCard(
      radius: 14,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Row(
        children: [
          GestureDetector(
            onTap: () =>
                Navigator.of(context).pushNamed(AppRoutes.editProfile),
            child: ProfileAvatar(name: name, photoPath: photoPath, size: 56),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.sora(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: p.textPrimary,
                  ),
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      fontSize: 12.5,
                      color: p.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      FirebaseBootstrap.ready
                          ? Icons.cloud_done_outlined
                          : Icons.phone_android_outlined,
                      size: 14,
                      color: p.brand,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      FirebaseBootstrap.ready
                          ? 'Cloud-synced'
                          : 'On this device',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: p.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
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
  const _DriverInfoCard({required this.details, required this.stats});

  final DriverDetails details;
  final TripStats stats;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final tier = DriverTier.of(stats);

    final rows = <(IconData, String, String)>[
      (Icons.workspace_premium_outlined, 'Standing', tier.label),
      if (details.age != null)
        (Icons.cake_outlined, 'Age', '${details.age} years'),
      if (details.experience != null)
        (
          Icons.timeline_outlined,
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
      radius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onTap: details.isEmpty
          ? () => Navigator.of(context).pushNamed(AppRoutes.editProfile)
          : null,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            _InfoRow(
              icon: rows[i].$1,
              label: rows[i].$2,
              value: rows[i].$3,
            ),
            if (i != rows.length - 1)
              Divider(color: p.border.withValues(alpha: 0.9), height: 1),
          ],
          if (details.isEmpty) ...[
            Divider(color: p.border.withValues(alpha: 0.9), height: 1),
            _InfoRow(
              icon: Icons.badge_outlined,
              label: 'Details',
              value: 'Add age, experience, and vehicle',
              muted: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.muted = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Icon(icon, size: 18, color: p.brand),
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 13.5,
              color: p.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(
                fontSize: 13.5,
                fontWeight: muted ? FontWeight.w500 : FontWeight.w700,
                color: muted ? p.textSecondary : p.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementList extends StatelessWidget {
  const _AchievementList({required this.achievements});

  final List<Achievement> achievements;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final unlocked = achievements.where((a) => a.unlocked).length;

    return AppCard(
      radius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          for (var i = 0; i < achievements.length; i++) ...[
            _AchievementRow(achievement: achievements[i]),
            if (i != achievements.length - 1)
              Divider(color: p.border.withValues(alpha: 0.9), height: 1),
          ],
          Divider(color: p.border.withValues(alpha: 0.9), height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '$unlocked of ${achievements.length} unlocked',
                style: GoogleFonts.dmSans(
                  fontSize: 12.5,
                  color: p.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementRow extends StatelessWidget {
  const _AchievementRow({required this.achievement});

  final Achievement achievement;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final unlocked = achievement.unlocked;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Icon(
            achievement.icon,
            size: 18,
            color: unlocked ? p.brand : p.textSecondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              achievement.label,
              style: GoogleFonts.dmSans(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: p.textPrimary,
              ),
            ),
          ),
          Text(
            unlocked ? 'Unlocked' : 'In progress',
            style: GoogleFonts.dmSans(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: unlocked ? AppColors.safe : p.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionItem {
  const _ActionItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}

class _ActionGroup extends StatelessWidget {
  const _ActionGroup({required this.items});

  final List<_ActionItem> items;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return AppCard(
      radius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            _ActionRow(item: items[i]),
            if (i != items.length - 1)
              Divider(color: p.border.withValues(alpha: 0.9), height: 1),
          ],
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.item});

  final _ActionItem item;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return InkWell(
      onTap: item.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: p.brandSoft,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(item.icon, size: 18, color: p.brand),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: p.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    item.subtitle,
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
      ),
    );
  }
}
