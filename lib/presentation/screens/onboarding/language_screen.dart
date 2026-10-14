import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/language_preference.dart';
import '../../../data/services/tts_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/brand_buttons.dart';
import '../../widgets/glass_tile.dart';
import '../../widgets/line_icon.dart';
import '../../widgets/screen_back_button.dart';

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  LanguagePreference _selected = LanguagePreference.bilingual;
  final _tts = TtsService();
  bool _speaking = false;
  bool _saving = false;

  static const _shellGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF083936), Color(0xFF062E2B)],
  );

  @override
  void dispose() {
    _tts.stop();
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
    final options = LanguagePreference.values;

    return Theme(
      data: AppTheme.dark(),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: AppColors.forest,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        child: Scaffold(
          backgroundColor: AppColors.forest,
          body: DecoratedBox(
            decoration: const BoxDecoration(gradient: _shellGradient),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
                child: Column(
                  children: [
                    const SizedBox(
                      height: 44,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: ScreenBackButton(bottomSpacing: 0),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Voice alerts',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: AppColors.white,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Spoken alerts use the phone speaker. No microphone is needed.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.white.withValues(alpha: 0.68),
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Expanded(
                      child: ListView(
                        children: [
                          for (var i = 0; i < options.length; i++) ...[
                            _LanguageCard(
                              language: options[i],
                              selected: _selected == options[i],
                              recommended:
                                  options[i] == LanguagePreference.bilingual,
                              onTap: () => _select(options[i]),
                            ),
                            if (i < options.length - 1)
                              const SizedBox(height: 10),
                          ],
                          const SizedBox(height: 12),
                          _TestVoiceCard(
                            speaking: _speaking,
                            onTap: _speaking ? null : _testVoice,
                          ),
                          const SizedBox(height: 12),
                          GlassTile(
                            child: Text(
                              'You still get on-screen alerts if voice is off.',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                height: 1.4,
                                color: AppColors.white.withValues(alpha: 0.62),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    MintButton(
                      label: 'Continue',
                      loading: _saving,
                      onPressed: _continue,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
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
    return GlassTile(
      selected: selected,
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.white.withValues(alpha: 0.10),
              ),
            ),
            child: Text(
              _code,
              style: GoogleFonts.inter(
                fontSize: language == LanguagePreference.bilingual ? 11 : 13,
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.mint : AppColors.white,
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
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.white,
                      ),
                    ),
                    if (recommended) ...[
                      const SizedBox(width: 8),
                      const QuietChip(label: 'Recommended', emphasized: true),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.white.withValues(alpha: 0.62),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            selected ? Icons.check_rounded : Icons.circle_outlined,
            color: selected
                ? AppColors.mint
                : AppColors.white.withValues(alpha: 0.28),
            size: 20,
          ),
        ],
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
    return GlassTile(
      onTap: onTap,
      child: Row(
        children: [
          LineIconBox(
            kind: LineIconKind.speaker,
            accent: speaking,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  speaking ? 'Playing sample' : 'Test voice alert',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Hear how alerts will sound',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.white.withValues(alpha: 0.62),
                  ),
                ),
              ],
            ),
          ),
          if (speaking)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.mint,
              ),
            )
          else
            Icon(
              Icons.play_arrow_rounded,
              color: AppColors.mint.withValues(alpha: 0.9),
            ),
        ],
      ),
    );
  }
}
