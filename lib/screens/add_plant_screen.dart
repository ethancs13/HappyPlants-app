import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:happy_plants/models/plant.dart';
import 'package:happy_plants/models/plant_photo.dart';
import 'package:happy_plants/repositories/plant_photo_repository.dart';
import 'package:happy_plants/repositories/plant_repository.dart';
import 'package:happy_plants/services/notification_service.dart';
import 'package:happy_plants/theme/app_theme.dart';
import 'package:happy_plants/widgets/plant_picker.dart';

class AddPlantScreen extends StatefulWidget {
  /// When non-null the screen is in edit mode.
  final Plant? plant;

  const AddPlantScreen({super.key, this.plant});

  @override
  State<AddPlantScreen> createState() => _AddPlantScreenState();
}

class _AddPlantScreenState extends State<AddPlantScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _speciesController = TextEditingController();
  final _intervalController = TextEditingController();
  final _notesController = TextEditingController();
  String? _selectedPlantKey;
  XFile? _pickedPhoto;
  final _imagePicker = ImagePicker();
  bool _saving = false;

  bool get _isEditing => widget.plant != null;

  bool get _hasUnsavedChanges {
    if (!_isEditing) return false;
    final p = widget.plant!;
    return _nameController.text.trim() != p.name ||
        _speciesController.text.trim() != p.species ||
        _intervalController.text.trim() != p.wateringIntervalDays.toString() ||
        _notesController.text.trim() != (p.notes ?? '') ||
        _selectedPlantKey != p.plantKey;
  }

  Future<void> _handleBackPress() async {
    if (!_hasUnsavedChanges) {
      Navigator.pop(context);
      return;
    }
    final col = context.col;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: col.card,
        title: Text(
          'Unsaved changes',
          style: TextStyle(color: col.textPrimary),
        ),
        content: Text(
          'You have unsaved changes. Save before leaving?',
          style: TextStyle(color: col.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: Text('Discard', style: TextStyle(color: col.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: const Text('Save',
                style: TextStyle(color: AppColors.darkOlive)),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (result == 'discard') Navigator.pop(context);
    if (result == 'save') await _save();
  }

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final p = widget.plant!;
      _nameController.text = p.name;
      _speciesController.text = p.species;
      _intervalController.text = p.wateringIntervalDays.toString();
      _notesController.text = p.notes ?? '';
      _selectedPlantKey = p.plantKey;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _speciesController.dispose();
    _intervalController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picked = await _imagePicker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (picked != null && mounted) setState(() => _pickedPhoto = picked);
  }

  Future<void> _showPhotoPicker() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: context.col.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from library'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source != null) await _pickPhoto(source);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final repo = await PlantRepository.create();
      if (_isEditing) {
        final updated = widget.plant!.copyWith(
          name: _nameController.text.trim(),
          species: _speciesController.text.trim(),
          wateringIntervalDays: int.parse(_intervalController.text.trim()),
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          plantKey: _selectedPlantKey,
        );
        await repo.update(updated);
        await NotificationService.scheduleWateringReminder(updated);
        if (mounted) Navigator.pop(context, updated);
      } else {
        final newPlant = Plant(
          name: _nameController.text.trim(),
          species: _speciesController.text.trim(),
          wateringIntervalDays: int.parse(_intervalController.text.trim()),
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          plantKey: _selectedPlantKey,
        );
        final newId = await repo.insert(newPlant);
        if (_pickedPhoto != null) {
          try {
            final appDir = await getApplicationDocumentsDirectory();
            final photosDir = Directory(p.join(appDir.path, 'plant_photos'));
            if (!await photosDir.exists()) await photosDir.create(recursive: true);
            final fileName =
                '${newId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
            final destPath = p.join(photosDir.path, fileName);
            await File(destPath).writeAsBytes(await _pickedPhoto!.readAsBytes());
            final photoRepo = await PlantPhotoRepository.create();
            await photoRepo.insert(PlantPhoto(
              plantId: newId,
              filePath: destPath,
              dateTaken: DateTime.now(),
              isCover: true,
            ));
          } catch (_) {
            // Photo save failed — plant is still created, just without a photo.
          }
        }
        await NotificationService.scheduleWateringReminder(
            newPlant.copyWith(id: newId));
        if (mounted) Navigator.pop(context, true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBackPress();
      },
      child: Scaffold(
        backgroundColor: context.col.bg,
        body: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _field(
                          context: context,
                          controller: _nameController,
                          label: 'Plant name',
                          hint: 'e.g. Living Room Monstera',
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                        const SizedBox(height: 14),
                        _field(
                          context: context,
                          controller: _speciesController,
                          label: 'Species',
                          hint: 'e.g. Monstera deliciosa',
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                        const SizedBox(height: 14),
                        _field(
                          context: context,
                          controller: _intervalController,
                          label: 'Water every (days)',
                          hint: 'e.g. 7',
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Required';
                            final n = int.tryParse(v.trim());
                            if (n == null || n < 1) return 'Enter a number >= 1';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        _field(
                          context: context,
                          controller: _notesController,
                          label: 'Notes (optional)',
                          hint: 'Care tips, location, etc.',
                          maxLines: 3,
                        ),
                        const SizedBox(height: 24),
                        _sectionLabel(context, 'Cover photo (optional)'),
                        const SizedBox(height: 10),
                        _buildPhotoPicker(context),
                        const SizedBox(height: 24),
                        _sectionLabel(context, 'Choose an illustration (optional)'),
                        const SizedBox(height: 10),
                        PlantPicker(
                          selectedKey: _selectedPlantKey,
                          onSelected: (key) => setState(() {
                            _selectedPlantKey =
                                _selectedPlantKey == key ? null : key;
                          }),
                        ),
                        const SizedBox(height: 28),
                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _saving ? null : _save,
                            child: _saving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.tan,
                                    ),
                                  )
                                : Text(_isEditing ? 'Save Changes' : 'Add Plant'),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      color: AppColors.darkOlive,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 8,
        right: 20,
        bottom: 20,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.tan),
            onPressed: _handleBackPress,
          ),
          const SizedBox(width: 4),
          Text(
            _isEditing ? 'Edit Plant' : 'Add Plant',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoPicker(BuildContext context) {
    return GestureDetector(
      onTap: _showPhotoPicker,
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: context.col.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.col.divider),
        ),
        clipBehavior: Clip.hardEdge,
        child: _pickedPhoto != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(File(_pickedPhoto!.path), fit: BoxFit.cover),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => setState(() => _pickedPhoto = null),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close,
                            size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_outlined,
                      size: 32, color: context.col.textMuted),
                  const SizedBox(height: 8),
                  Text('Tap to add a photo',
                      style: TextStyle(
                          color: context.col.textMuted, fontSize: 13)),
                ],
              ),
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) => Text(
        text,
        style: TextStyle(
          color: context.col.textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      );

  Widget _field({
    required BuildContext context,
    required TextEditingController controller,
    required String label,
    required String hint,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(context, label),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          maxLines: maxLines,
          style: TextStyle(color: context.col.textPrimary, fontSize: 14),
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }
}
