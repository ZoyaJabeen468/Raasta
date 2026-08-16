import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/config/firebase_bootstrap.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/ambient_scaffold.dart';
import '../../../data/models/driver_details.dart';
import '../../providers/auth_provider.dart';
import '../../providers/driver_profile_provider.dart';
import '../../widgets/app_card.dart';
import '../../widgets/brand_buttons.dart';
import '../../widgets/input_field.dart';
import 'profile_tab.dart' show ProfileAvatar;

/// Edit profile — display name plus optional driver and vehicle details.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _age = TextEditingController();
  final _plate = TextEditingController();
  final _model = TextEditingController();

  DrivingExperience? _experience;
  VehicleKind? _vehicle;
  String _photoPath = '';
  bool _saving = false;

  late final String _initialName;
  late final String _initialAge;
  late final String _initialPlate;
  late final String _initialModel;
  late final DrivingExperience? _initialExperience;
  late final VehicleKind? _initialVehicle;
  late final String _initialPhoto;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    final details = context.read<DriverProfileProvider>().details;

    _name.text = auth.user?.name ?? '';
    _age.text = details.age?.toString() ?? '';
    _plate.text = details.plate;
    _model.text = details.vehicleModel;
    _experience = details.experience;
    _vehicle = details.vehicle;
    _photoPath = details.photoPath;

    _initialName = _name.text;
    _initialAge = _age.text;
    _initialPlate = _plate.text;
    _initialModel = _model.text;
    _initialExperience = _experience;
    _initialVehicle = _vehicle;
    _initialPhoto = _photoPath;
  }

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    _plate.dispose();
    _model.dispose();
    super.dispose();
  }

  bool get _dirty =>
      _name.text != _initialName ||
      _age.text != _initialAge ||
      _plate.text != _initialPlate ||
      _model.text != _initialModel ||
      _experience != _initialExperience ||
      _vehicle != _initialVehicle ||
      _photoPath != _initialPhoto;

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('You have unsaved edits on this profile.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.alert),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _pickPhoto() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 720,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;
      setState(() => _photoPath = picked.path);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the photo library.')),
      );
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final auth = context.read<AuthProvider>();
    final driver = context.read<DriverProfileProvider>();

    await driver.save(
      DriverDetails(
        age: int.tryParse(_age.text.trim()),
        experience: _experience,
        vehicle: _vehicle,
        plate: _plate.text.trim(),
        vehicleModel: _model.text.trim(),
        photoPath: _photoPath,
      ),
    );

    var message = 'Profile saved';
    final newName = _name.text.trim();
    if (FirebaseBootstrap.ready && newName != (auth.user?.name ?? '')) {
      final ok = await auth.updateName(newName);
      if (!ok) message = auth.error ?? 'Saved locally, name update failed';
    }

    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final auth = context.watch<AuthProvider>();

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await _confirmDiscard();
        if (leave && context.mounted) Navigator.of(context).pop();
      },
      child: AmbientScaffold(
        appBar: AppBar(title: const Text('Edit profile')),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                Center(
                  child: Column(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          ProfileAvatar(
                            name: _name.text.isEmpty ? 'Driver' : _name.text,
                            photoPath: _photoPath,
                            size: 96,
                          ),
                          Positioned(
                            right: -2,
                            bottom: -2,
                            child: Material(
                              color: p.surface,
                              shape: const CircleBorder(),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: _pickPhoto,
                                child: Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: p.border),
                                  ),
                                  child: Icon(
                                    Icons.photo_camera_rounded,
                                    size: 17,
                                    color: p.brand,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton(
                            onPressed: _pickPhoto,
                            child: Text(
                              _photoPath.isEmpty
                                  ? 'Add a photo'
                                  : 'Change photo',
                            ),
                          ),
                          if (_photoPath.isNotEmpty)
                            TextButton(
                              onPressed: () =>
                                  setState(() => _photoPath = ''),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.alert,
                              ),
                              child: const Text('Remove'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const SectionLabel('Personal'),
                InputField(
                  controller: _name,
                  hint: 'Full name',
                  prefixIcon: Icons.person_outline_rounded,
                  textInputAction: TextInputAction.next,
                  validator: (value) =>
                      (value == null || value.trim().length < 2)
                      ? 'Enter your name'
                      : null,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                InputField(
                  controller: _age,
                  hint: 'Age (optional)',
                  prefixIcon: Icons.cake_outlined,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(2),
                  ],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return null;
                    final age = int.tryParse(value.trim());
                    if (age == null || age < 16 || age > 99) {
                      return 'Enter an age between 16 and 99';
                    }
                    return null;
                  },
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 22),
                const SectionLabel('Driving'),
                _ExperienceField(
                  value: _experience,
                  onChanged: (value) => setState(() => _experience = value),
                ),
                const SizedBox(height: 14),
                Text(
                  'Primary vehicle',
                  style: GoogleFonts.dmSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: p.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final kind in VehicleKind.values)
                      _VehicleChip(
                        kind: kind,
                        selected: _vehicle == kind,
                        onTap: () => setState(
                          () => _vehicle = _vehicle == kind ? null : kind,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                InputField(
                  controller: _model,
                  hint: 'Vehicle model (optional)',
                  prefixIcon: Icons.build_outlined,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                InputField(
                  controller: _plate,
                  hint: 'Number plate (optional)',
                  prefixIcon: Icons.confirmation_number_outlined,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 22),
                const SectionLabel('Account'),
                AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.mail_outline_rounded,
                        size: 18,
                        color: p.brand,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              auth.user?.email ?? 'Not signed in',
                              style: GoogleFonts.dmSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: p.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              auth.hasPasswordProvider
                                  ? 'Change your email from Settings › Account'
                                  : 'Signed in with Google / Facebook',
                              style: GoogleFonts.dmSans(
                                fontSize: 12,
                                color: p.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                GradientButton(
                  label: 'Save profile',
                  loading: _saving,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExperienceField extends StatelessWidget {
  const _ExperienceField({required this.value, required this.onChanged});

  final DrivingExperience? value;
  final ValueChanged<DrivingExperience?> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return DropdownButtonFormField<DrivingExperience>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        hintText: 'Driving experience',
        prefixIcon: Icon(
          Icons.timeline_rounded,
          size: 20,
          color: p.textSecondary,
        ),
      ),
      icon: Icon(Icons.expand_more_rounded, color: p.textSecondary),
      dropdownColor: p.surface,
      style: GoogleFonts.dmSans(fontSize: 14.5, color: p.textPrimary),
      items: [
        for (final option in DrivingExperience.values)
          DropdownMenuItem(value: option, child: Text(option.label)),
      ],
      onChanged: onChanged,
    );
  }
}

class _VehicleChip extends StatelessWidget {
  const _VehicleChip({
    required this.kind,
    required this.selected,
    required this.onTap,
  });

  final VehicleKind kind;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Material(
      color: selected ? p.brand : p.surface,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? p.brand : p.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                kind.icon,
                size: 17,
                color: selected ? AppColors.white : p.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                kind.label,
                style: GoogleFonts.dmSans(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: selected ? AppColors.white : p.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
