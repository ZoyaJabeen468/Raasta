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

class _LanguageScreenState extends State<LanguageScreen> {
  LanguagePreference _selected = LanguagePreference.bilingual;
  final _tts = TtsService();
  bool _speaking = false;
  bool _saving = false;

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
              'Install Urdu in Settings → System → Language & input → '
              'Text-to-speech → install voice data.',
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

    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const ScreenBackButton(),
                      Text(
                        'Voice language',
                        style: GoogleFonts.sora(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: p.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'How should alerts sound?',
                        style: GoogleFonts.dmSans(
                          fontSize: 15,
                          color: p.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 28),
                      for (final lang in LanguagePreference.values)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _LanguageOption(
                            language: lang,
                            selected: _selected == lang,
                            recommended:
                                lang == LanguagePreference.bilingual,
                            onTap: () => _select(lang),
                          ),
                        ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _speaking ? null : _testVoice,
                        icon: Icon(
                          _speaking
                              ? Icons.volume_up_rounded
                              : Icons.play_arrow_rounded,
                        ),
                        label: Text(
                          _speaking ? 'Playing…' : 'Test voice alert',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: p.brand,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
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

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.language,
    required this.selected,
    required this.recommended,
    required this.onTap,
  });

  final LanguagePreference language;
  final bool selected;
  final bool recommended;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final bg = selected ? p.brand : p.surface;
    final fg = selected ? AppColors.white : p.textPrimary;
    final muted = selected
        ? AppColors.white.withValues(alpha: 0.85)
        : p.textSecondary;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? p.brand : p.border,
              width: selected ? 1.8 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_off_rounded,
                color: selected ? AppColors.white : p.textSecondary,
              ),
              const SizedBox(width: 14),
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
                            color: fg,
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
                              color: selected
                                  ? AppColors.white.withValues(alpha: 0.22)
                                  : p.brandSoft,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              'Recommended',
                              style: GoogleFonts.dmSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: selected ? AppColors.white : p.brand,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      language.samplePhrase,
                      style: GoogleFonts.dmSans(
                        fontSize: 12.5,
                        color: muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
