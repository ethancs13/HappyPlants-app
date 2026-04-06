import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:happy_plants/models/plant.dart';
import 'package:happy_plants/repositories/plant_repository.dart';
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
  bool _saving = false;

  bool get _isEditing => widget.plant != null;

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
        if (mounted) Navigator.pop(context, updated);
      } else {
        await repo.insert(Plant(
          name: _nameController.text.trim(),
          species: _speciesController.text.trim(),
          wateringIntervalDays: int.parse(_intervalController.text.trim()),
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          plantKey: _selectedPlantKey,
        ));
        if (mounted) Navigator.pop(context, true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
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
                        controller: _nameController,
                        label: 'Plant name',
                        hint: 'e.g. Living Room Monstera',
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 14),
                      _field(
                        controller: _speciesController,
                        label: 'Species',
                        hint: 'e.g. Monstera deliciosa',
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 14),
                      _field(
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
                        controller: _notesController,
                        label: 'Notes (optional)',
                        hint: 'Care tips, location, etc.',
                        maxLines: 3,
                      ),
                      const SizedBox(height: 24),
                      _sectionLabel('Choose an illustration (optional)'),
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
            onPressed: () => Navigator.pop(context),
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

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      );

  Widget _field({
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
        _sectionLabel(label),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          maxLines: maxLines,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }
}
