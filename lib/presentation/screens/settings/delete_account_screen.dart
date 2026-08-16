import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/ambient_scaffold.dart';
import '../../providers/auth_provider.dart';
import '../../providers/driver_profile_provider.dart';
import '../../providers/trips_provider.dart';
import '../../widgets/brand_buttons.dart';
import '../../widgets/input_field.dart';
import 'widgets/form_notice.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _acknowledged = false;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _password.addListener(() => setState(() {}));
    _confirm.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<AuthProvider>().clearMessages(),
    );
  }

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _acknowledged &&
      _password.text.isNotEmpty &&
      _confirm.text.trim().toUpperCase() == 'DELETE';

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This removes your RAASTA account and every trip stored on this '
          'device. It cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep account'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.alert),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final auth = context.read<AuthProvider>();
    final trips = context.read<TripsProvider>();
    final driver = context.read<DriverProfileProvider>();

    final ok = await auth.deleteAccount(_password.text);
    if (!ok || !mounted) return;

    await trips.clear();
    await driver.clear();
    if (!mounted) return;

    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.welcome, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final auth = context.watch<AuthProvider>();

    return AmbientScaffold(
      appBar: AppBar(title: const Text('Delete account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const FormNotice.error(
                'Deleting removes your account, driver details and trip '
                'history permanently. This cannot be undone.',
              ),
              const SizedBox(height: 20),
              _AcknowledgeTile(
                value: _acknowledged,
                onChanged: (value) => setState(() => _acknowledged = value),
              ),
              const SizedBox(height: 14),
              InputField(
                controller: _password,
                hint: 'Confirm with your password',
                prefixIcon: Icons.lock_outline_rounded,
                obscureText: _obscure,
                suffix: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: p.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              InputField(
                controller: _confirm,
                hint: 'Type DELETE to confirm',
                prefixIcon: Icons.warning_amber_rounded,
                textCapitalization: TextCapitalization.characters,
              ),
              if (auth.error != null) ...[
                const SizedBox(height: 14),
                FormNotice.error(auth.error!),
              ],
              const SizedBox(height: 24),
              DangerButton(
                label: 'Permanently delete account',
                loading: auth.isBusy,
                onPressed: _canSubmit ? _submit : null,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AcknowledgeTile extends StatelessWidget {
  const _AcknowledgeTile({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Material(
      color: p.surface,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onChanged(!value),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: p.border),
          ),
          child: Row(
            children: [
              Checkbox(
                value: value,
                onChanged: (next) => onChanged(next ?? false),
                activeColor: AppColors.alert,
              ),
              Expanded(
                child: Text(
                  'I understand this is permanent',
                  style: GoogleFonts.dmSans(
                    fontSize: 13.5,
                    color: p.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
