import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/ambient_scaffold.dart';
import '../../../core/widgets/raasta_logo.dart';
import '../../widgets/app_card.dart';

class InfoSection {
  const InfoSection({required this.title, required this.body});

  final String title;
  final String body;
}

/// Reusable reader for About / FAQ / Privacy content.
class InfoScreen extends StatelessWidget {
  const InfoScreen({
    super.key,
    required this.title,
    required this.sections,
    this.intro,
    this.showLogo = false,
    this.expandable = false,
  });

  final String title;
  final String? intro;
  final List<InfoSection> sections;
  final bool showLogo;
  final bool expandable;

  static const about = InfoScreen(
    title: 'About RAASTA',
    showLogo: true,
    intro:
        'RAASTA is a driver assistance app. It watches the road through your '
        'phone camera and warns you about hazards before you reach them.',
    sections: [
      InfoSection(
        title: 'What it does',
        body:
            'Detects potholes, speed bumps, cracks, people and animals in '
            'real time, then speaks a warning so your eyes stay on the road.',
      ),
      InfoSection(
        title: 'Road signs',
        body:
            'Sign recognition is tuned for Pakistani road signage and reads '
            'them out in Urdu, alongside the English alert.',
      ),
      InfoSection(
        title: 'On-device detection',
        body:
            'Detection runs on your phone, so alerts stay instant and your '
            'trip history is kept private on your device.',
      ),
      InfoSection(
        title: 'The project',
        body:
            'RAASTA is a final year project focused on making everyday '
            'driving safer with on-device computer vision.',
      ),
    ],
  );

  static const faq = InfoScreen(
    title: 'FAQ',
    expandable: true,
    sections: [
      InfoSection(
        title: 'How should I mount my phone?',
        body:
            'Place the phone in a windscreen or dashboard mount with the rear '
            'camera facing the road ahead. Keep the lens clear of wipers and '
            'stickers.',
      ),
      InfoSection(
        title: 'Does it use mobile data?',
        body:
            'No. Hazard detection runs on the device. Data is only used for '
            'signing in and syncing your account.',
      ),
      InfoSection(
        title: 'Why does it need location?',
        body:
            'Location lets RAASTA record where a hazard was found so trips '
            'and reports are meaningful. You can drive without it, but trip '
            'distance will be less accurate.',
      ),
      InfoSection(
        title: 'Can I get alerts in Urdu?',
        body:
            'Yes. Open Settings, choose Alert language, and pick Urdu or '
            'both languages together.',
      ),
      InfoSection(
        title: 'How is my safety score calculated?',
        body:
            'It starts at 100 and drops with the number of hazards you meet '
            'per kilometre, plus a small penalty for speeding events.',
      ),
      InfoSection(
        title: 'Will it drain my battery?',
        body:
            'Camera detection is power hungry. Keep the phone plugged in on '
            'longer drives.',
      ),
    ],
  );

  static const privacy = InfoScreen(
    title: 'Privacy policy',
    intro:
        'RAASTA is built to keep driving data on your phone. This page '
        'explains exactly what is stored and where.',
    sections: [
      InfoSection(
        title: 'What stays on your device',
        body:
            'Trips, hazard detections, driver details and app settings are '
            'stored locally and are never uploaded.',
      ),
      InfoSection(
        title: 'What we store in the cloud',
        body:
            'Only your account email and display name, handled by Firebase '
            'Authentication so you can sign in on another device.',
      ),
      InfoSection(
        title: 'Camera footage',
        body:
            'Video frames are processed in memory to detect hazards and are '
            'never recorded, saved or transmitted.',
      ),
      InfoSection(
        title: 'Deleting your data',
        body:
            'Settings › Delete account removes your account along with every '
            'trip and detail stored on this device.',
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return AmbientScaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            if (showLogo) ...[
              const Center(child: RaastaLogo(size: 76)),
              const SizedBox(height: 16),
              Center(
                child: RaastaWordmark(fontSize: 22, color: p.textPrimary),
              ),
              const SizedBox(height: 20),
            ],
            if (intro != null) ...[
              Text(
                intro!,
                style: GoogleFonts.dmSans(
                  fontSize: 14.5,
                  height: 1.55,
                  color: p.textSecondary,
                ),
              ),
              const SizedBox(height: 22),
            ],
            for (final section in sections) ...[
              expandable
                  ? _ExpandableSection(section: section)
                  : _PlainSection(section: section),
              const SizedBox(height: 12),
            ],
            if (showLogo) ...[
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'RAASTA · v0.3.0',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: p.textSecondary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PlainSection extends StatelessWidget {
  const _PlainSection({required this.section});

  final InfoSection section;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.title,
            style: GoogleFonts.sora(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: p.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            section.body,
            style: GoogleFonts.dmSans(
              fontSize: 14,
              height: 1.55,
              color: p.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpandableSection extends StatelessWidget {
  const _ExpandableSection({required this.section});

  final InfoSection section;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: p.brand,
          collapsedIconColor: p.textSecondary,
          title: Text(
            section.title,
            style: GoogleFonts.dmSans(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: p.textPrimary,
            ),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              section.body,
              style: GoogleFonts.dmSans(
                fontSize: 13.5,
                height: 1.55,
                color: p.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
