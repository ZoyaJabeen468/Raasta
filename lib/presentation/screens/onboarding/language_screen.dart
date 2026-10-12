import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../data/models/language_preference.dart';
import '../../../data/services/tts_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/brand_buttons.dart';
import '../../widgets/screen_back_button.dart';

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen>
    with SingleTickerProviderStateMixin {
  LanguagePreference _selected = LanguagePreference.bilingual;
  final _tts = TtsService();
  bool _speaking = false;
  bool _saving = false;
  late final AnimationController _enter;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
  }

  @override
  void dispose() {
    _tts.stop();
    _enter.dispose();
    super.dispose();
  }

  Future<void> _select(LanguagePreference lang) async {
    setState(() => _selected = lang);
    await _testVoice();
  }

  Future<void> _testVoice() async {
    setState(() => _speaking = true);
    try {
      final ok = await _tts.speakSample(_selected);
      if (!mounted) return;
      if (!ok &&
          (_selected == LanguagePreference.urdu ||
              _selected == LanguagePreference.bilingual)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Urdu voice not found on this phone. '
              'Install Urdu in Settings then Text-to-speech voice data.',
            ),
            duration: Duration(seconds: 6),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _speaking = false);
    }
  }

  Future<void> _continue() async {
    setState(() => _saving = true);
    await context.read<AuthProvider>().completeOnboarding(_selected);
    if (!mounted) return;
    await context.read<SettingsProvider>().setLanguage(_selected);
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final options = LanguagePreference.values;

    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const ScreenBackButton(),
                      const SizedBox(height: 8),
                      Text(
                        'Voice alerts',
                        style: GoogleFonts.sora(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: p.textPrimary,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Choose how hazard alerts should sound.',
                        style: GoogleFonts.dmSans(
                          fontSize: 14.5,
                          color: p.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),
                      for (var i = 0; i < options.length; i++) ...[
                        _Staggered(
                          controller: _enter,
                          index: i,
                          child: _LanguageCard(
                            language: options[i],
                            selected: _selected == options[i],
                            recommended:
                                options[i] == LanguagePreference.bilingual,
                            onTap: () => _select(options[i]),
                          ),
                        ),
                        if (i < options.length - 1) const SizedBox(height: 10),
                      ],
                      const SizedBox(height: 18),
                      _Staggered(
                        controller: _enter,
                        index: 3,
                        child: _TestVoiceCard(
                          speaking: _speaking,
                          onTap: _speaking ? null : _testVoice,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _Staggered(
                        controller: _enter,
                        index: 4,
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: p.brandSoft,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                size: 18,
                                color: p.brand,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'No mic? You still get on-screen alerts.',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 12.5,
                                    color: p.textPrimary,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              GradientButton(
                label: 'Continue',
                loading: _saving,
                onPressed: _continue,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Staggered extends StatelessWidget {
  const _Staggered({
    required this.controller,
    required this.index,
    required this.child,
  });

  final AnimationController controller;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final start = 0.06 + index * 0.12;
    final anim = CurvedAnimation(
      parent: controller,
      curve: Interval(
        start.clamp(0.0, 0.8),
        (start + 0.35).clamp(0.0, 1.0),
        curve: Curves.easeOutCubic,
      ),
    );
    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.07),
          end: Offset.zero,
        ).animate(anim),
        child: child,
      ),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  const _LanguageCard({
    required this.language,
    required this.selected,
    required this.recommended,
    required this.onTap,
  });

  final LanguagePreference language;
  final bool selected;
  final bool recommended;
  final VoidCallback onTap;

  String get _code {
    switch (language) {
      case LanguagePreference.english:
        return 'EN';
      case LanguagePreference.urdu:
        return 'UR';
      case LanguagePreference.bilingual:
        return 'Both';
    }
  }

  String get _subtitle {
    switch (language) {
      case LanguagePreference.english:
        return 'Alerts in English only';
      case LanguagePreference.urdu:
        return 'Alerts in Urdu only';
      case LanguagePreference.bilingual:
        return 'English then Urdu';
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            color: selected ? p.brand.withValues(alpha: 0.08) : p.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? p.brand : p.border,
              width: selected ? 1.6 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: p.shadow,
                blurRadius: selected ? 14 : 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? p.brand : p.brandSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  _code,
                  style: GoogleFonts.sora(
                    fontSize: language == LanguagePreference.bilingual ? 12 : 14,
                    fontWeight: FontWeight.w700,
                    color: selected ? AppColors.white : p.brand,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          language.label,
                          style: GoogleFonts.dmSans(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: p.textPrimary,
                          ),
                        ),
                        if (recommended) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: p.brandSoft,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              'Recommended',
                              style: GoogleFonts.dmSans(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: p.brand,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _subtitle,
                      style: GoogleFonts.dmSans(
                        fontSize: 12.5,
                        color: p.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                  key: ValueKey(selected),
                  color: selected ? p.brand : p.border,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TestVoiceCard extends StatelessWidget {
  const _TestVoiceCard({required this.speaking, required this.onTap});

  final bool speaking;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Material(
      color: p.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: p.border),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: p.brandSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  speaking
                      ? Icons.graphic_eq_rounded
                      : Icons.volume_up_outlined,
                  color: p.brand,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      speaking ? 'Playing sample…' : 'Test voice alert',
                      style: GoogleFonts.dmSans(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: p.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Hear how alerts will sound',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: p.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (speaking)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: p.brand,
                  ),
                )
              else
                Icon(Icons.play_arrow_rounded, color: p.brand),
            ],
          ),
        ),
      ),
    );
  }
}
