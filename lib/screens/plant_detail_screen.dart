import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:happy_plants/models/care_log.dart';
import 'package:happy_plants/models/plant.dart';
import 'package:happy_plants/models/plant_photo.dart';
import 'package:happy_plants/repositories/care_log_repository.dart';
import 'package:happy_plants/repositories/plant_photo_repository.dart';
import 'package:happy_plants/repositories/plant_repository.dart';
import 'package:happy_plants/screens/add_plant_screen.dart';
import 'package:happy_plants/services/notification_service.dart';
import 'package:happy_plants/theme/app_theme.dart';
import 'package:happy_plants/widgets/plant_care_calendar.dart';
import 'package:happy_plants/widgets/plant_widget.dart';

class PlantDetailScreen extends StatefulWidget {
  final Plant plant;

  const PlantDetailScreen({super.key, required this.plant});

  @override
  State<PlantDetailScreen> createState() => _PlantDetailScreenState();
}

class _PlantDetailScreenState extends State<PlantDetailScreen> {
  late Plant _plant;
  List<CareLog> _logs = [];
  List<PlantPhoto> _photos = [];
  bool _actionPending = false;
  final _picker = ImagePicker();
  final _pageScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _plant = widget.plant;
    _refreshLogs();
    _refreshPhotos();
  }

  @override
  void dispose() {
    _pageScroll.dispose();
    super.dispose();
  }

  Future<void> _refreshLogs() async {
    final repo = await CareLogRepository.create();
    final logs = await repo.getByPlantId(_plant.id!);
    if (mounted) setState(() => _logs = logs);
  }

  Future<void> _refreshPhotos() async {
    final repo = await PlantPhotoRepository.create();
    final photos = await repo.getByPlantId(_plant.id!);
    if (mounted) setState(() => _photos = photos);
  }

  Future<void> _logCare(CareType type) async {
    if (_actionPending) return;
    setState(() => _actionPending = true);
    try {
      final now = DateTime.now();
      final logRepo = await CareLogRepository.create();
      await logRepo.insert(CareLog(
        plantId: _plant.id!,
        type: type,
        date: now,
      ));

      final plantRepo = await PlantRepository.create();
      final updated = type == CareType.watering
          ? _plant.copyWith(lastWateredDate: now)
          : _plant.copyWith(lastFertilizedDate: now);
      await plantRepo.update(updated);

      if (mounted) {
        setState(() {
          _plant = updated;
          _actionPending = false;
        });
        _refreshLogs();
      }
      if (type == CareType.watering) {
        await NotificationService.scheduleWateringReminder(updated);
      }
    } catch (_) {
      if (mounted) setState(() => _actionPending = false);
    }
  }

  Future<void> _addPhoto(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (picked == null || !mounted) return;

    final appDir = await getApplicationDocumentsDirectory();
    final photosDir = Directory(p.join(appDir.path, 'plant_photos'));
    if (!await photosDir.exists()) await photosDir.create(recursive: true);

    final fileName =
        '${_plant.id}_${DateTime.now().millisecondsSinceEpoch}${p.extension(picked.path)}';
    final destPath = p.join(photosDir.path, fileName);
    await File(picked.path).copy(destPath);

    final photoRepo = await PlantPhotoRepository.create();
    final allPhotos = await photoRepo.getByPlantId(_plant.id!);
    final isFirst = allPhotos.isEmpty;

    await photoRepo.insert(PlantPhoto(
      plantId: _plant.id!,
      filePath: destPath,
      dateTaken: DateTime.now(),
      isCover: isFirst,
    ));

    if (mounted) _refreshPhotos();
  }

  Future<void> _toggleNotifications(bool value) async {
    final updated = _plant.copyWith(notificationsEnabled: value);
    final repo = await PlantRepository.create();
    await repo.update(updated);
    if (!mounted) return;
    setState(() => _plant = updated);
    if (value) {
      await NotificationService.scheduleWateringReminder(updated);
    } else {
      await NotificationService.cancelReminder(_plant.id!);
    }
  }

  Future<void> _toggleScheduleOnCalendar(bool value) async {
    var updated = _plant.copyWith(showScheduleOnCalendar: value);
    if (value && _plant.lastWateredDate == null) {
      final picked = await showDatePicker(
        context: context,
        initialDate: DateTime.now().add(Duration(days: _plant.wateringIntervalDays)),
        firstDate: DateTime.now().subtract(const Duration(days: 365)),
        lastDate: DateTime.now().add(const Duration(days: 365)),
        helpText: 'When should the first watering be?',
      );
      if (picked == null || !mounted) return;
      final anchor = DateTime(picked.year, picked.month, picked.day)
          .subtract(Duration(days: _plant.wateringIntervalDays));
      updated = updated.copyWith(lastWateredDate: anchor);
    }
    final repo = await PlantRepository.create();
    await repo.update(updated);
    if (mounted) setState(() => _plant = updated);
  }

  Future<void> _rescheduleWatering(DateTime newNextWateringDate) async {
    final anchor = DateTime(
      newNextWateringDate.year,
      newNextWateringDate.month,
      newNextWateringDate.day,
    ).subtract(Duration(days: _plant.wateringIntervalDays));
    final updated = _plant.copyWith(lastWateredDate: anchor);
    final repo = await PlantRepository.create();
    await repo.update(updated);
    if (mounted) setState(() => _plant = updated);
    await NotificationService.scheduleWateringReminder(updated);
  }

  Future<void> _showAddPhotoSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.col.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera, color: AppColors.darkOlive),
              title: const Text('Take photo'),
              onTap: () {
                Navigator.pop(context);
                _addPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppColors.darkOlive),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(context);
                _addPhoto(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPhotoOptions(PlantPhoto photo, List<PlantPhoto> allPhotos) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.col.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!photo.isCover)
              ListTile(
                leading: const Icon(Icons.star_outline, color: AppColors.darkOlive),
                title: const Text('Set as cover photo'),
                onTap: () async {
                  Navigator.pop(context);
                  final repo = await PlantPhotoRepository.create();
                  await repo.setCover(_plant.id!, photo.id!);
                  if (mounted) _refreshPhotos();
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.statusRed),
              title: const Text(
                'Delete photo',
                style: TextStyle(color: AppColors.statusRed),
              ),
              onTap: () async {
                Navigator.pop(context);
                final repo = await PlantPhotoRepository.create();
                await repo.delete(photo.id!);
                // Delete file from disk
                final file = File(photo.filePath);
                if (await file.exists()) await file.delete();
                if (mounted) _refreshPhotos();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editPlant() async {
    final updated = await Navigator.push<Plant>(
      context,
      MaterialPageRoute(builder: (_) => AddPlantScreen(plant: _plant)),
    );
    if (updated != null && mounted) {
      setState(() {
        _plant = updated;
      });
    }
  }

  Future<void> _deletePlant() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.col.card,
        title: Text(
          'Delete plant?',
          style: TextStyle(color: ctx.col.textPrimary),
        ),
        content: Text(
          'This will permanently remove ${_plant.name} and all its care history.',
          style: TextStyle(color: ctx.col.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: ctx.col.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.statusRed),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final plantRepo = await PlantRepository.create();
    final logRepo = await CareLogRepository.create();
    final photoRepo = await PlantPhotoRepository.create();
    await logRepo.deleteByPlantId(_plant.id!);
    await photoRepo.deleteByPlantId(_plant.id!);
    await plantRepo.delete(_plant.id!);
    await NotificationService.cancelReminder(_plant.id!);

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final overdue = _plant.isOverdueForWater;

    return Scaffold(
      backgroundColor: context.col.bg,
      body: SafeArea(
        top: false,
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context, overdue),
          Expanded(
            child: SingleChildScrollView(
              controller: _pageScroll,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                  _InfoCard(plant: _plant),
                  const SizedBox(height: 20),
                  _ActionButtons(
                    onWater: () => _logCare(CareType.watering),
                    onFertilize: () => _logCare(CareType.fertilizing),
                    pending: _actionPending,
                  ),
                  const SizedBox(height: 24),
                  // Photo journal
                  Row(
                    children: [
                      Text(
                        'Photo Journal',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(
                          Icons.add_a_photo_outlined,
                          color: AppColors.darkOlive,
                        ),
                        onPressed: _showAddPhotoSheet,
                        tooltip: 'Add photo',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _photos.isEmpty
                      ? GestureDetector(
                          onTap: _showAddPhotoSheet,
                          child: Container(
                            height: 90,
                            decoration: BoxDecoration(
                              color: context.col.card,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: context.col.textMuted.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.add_a_photo_outlined,
                                      color: context.col.textMuted, size: 28),
                                  const SizedBox(height: 6),
                                  Text('Tap to add your first photo',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium),
                                ],
                              ),
                            ),
                          ),
                        )
                      : SizedBox(
                          height: 110,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _photos.length + 1,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, i) {
                              if (i == _photos.length) {
                                return GestureDetector(
                                  onTap: _showAddPhotoSheet,
                                  child: Container(
                                    width: 90,
                                    decoration: BoxDecoration(
                                      color: context.col.card,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: context.col.textMuted
                                            .withValues(alpha: 0.2),
                                      ),
                                    ),
                                    child: Icon(Icons.add,
                                        color: context.col.textMuted, size: 28),
                                  ),
                                );
                              }
                              final photo = _photos[i];
                              return GestureDetector(
                                onTap: () => _openPhoto(photo),
                                onLongPress: () =>
                                    _showPhotoOptions(photo, _photos),
                                child: Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.file(
                                        File(photo.filePath),
                                        width: 90,
                                        height: 110,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) => Container(
                                          width: 90,
                                          height: 110,
                                          color: context.col.card,
                                          child: Icon(
                                              Icons.broken_image_outlined,
                                              color: context.col.textMuted),
                                        ),
                                      ),
                                    ),
                                    if (photo.isCover)
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: Container(
                                          padding: const EdgeInsets.all(3),
                                          decoration: const BoxDecoration(
                                              color: AppColors.darkOlive,
                                              shape: BoxShape.circle),
                                          child: const Icon(Icons.star,
                                              color: Colors.white, size: 12),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Text('Care Schedule',
                            style: Theme.of(context).textTheme.titleMedium),
                      ),
                      Icon(Icons.notifications_outlined,
                          size: 16, color: context.col.textMuted),
                      const SizedBox(width: 4),
                      Switch(
                        value: _plant.notificationsEnabled,
                        onChanged: _toggleNotifications,
                        activeThumbColor: AppColors.darkOlive,
                        activeTrackColor: AppColors.olive,
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.calendar_month,
                          size: 16, color: context.col.textMuted),
                      const SizedBox(width: 4),
                      Switch(
                        value: _plant.showScheduleOnCalendar,
                        onChanged: _toggleScheduleOnCalendar,
                        activeThumbColor: AppColors.darkOlive,
                        activeTrackColor: AppColors.olive,
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  PlantCareCalendar(
                    plant: _plant,
                    logs: _logs,
                    photos: _photos,
                    parentScrollController: _pageScroll,
                    onRefresh: () {
                      _refreshLogs();
                      _refreshPhotos();
                    },
                    onReschedule: _rescheduleWatering,
                  ),
                  const SizedBox(height: 24),
                  Text('Care History',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  if (_logs.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text('No care logged yet',
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center),
                    )
                  else
                    Column(
                      children:
                          _logs.map((log) => _CareLogTile(log: log)).toList(),
                    ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }

  void _openPhoto(PlantPhoto photo) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => _FullScreenPhoto(photo: photo),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool overdue) {
    final cover = _photos.where((p) => p.isCover).firstOrNull;

    if (cover != null && File(cover.filePath).existsSync()) {
      return _CoverPhotoHeader(
        plant: _plant,
        coverPhoto: cover,
        onBack: () => Navigator.pop(context, false),
        onEdit: _editPlant,
        onDelete: _deletePlant,
      );
    }

    return Container(
      color: context.col.plantSlotBg,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 8,
        right: 8,
        bottom: 0,
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.tan),
                onPressed: () => Navigator.pop(context, false),
              ),
              Expanded(
                child: Text(
                  _plant.name,
                  style: Theme.of(context).textTheme.headlineLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: AppColors.tan),
                onPressed: _editPlant,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.tan),
                onPressed: _deletePlant,
              ),
            ],
          ),
          const SizedBox(height: 8),
          PlantWidget(
            isHappy: !overdue,
            size: 150,
            plantKey: _plant.plantKey,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── Cover photo header ────────────────────────────────────────────────────────

class _CoverPhotoHeader extends StatelessWidget {
  final Plant plant;
  final PlantPhoto coverPhoto;
  final VoidCallback onBack;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CoverPhotoHeader({
    required this.plant,
    required this.coverPhoto,
    required this.onBack,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 240,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.file(
            File(coverPhoto.filePath),
            fit: BoxFit.cover,
          ),
          // Dark gradient for legibility
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.55),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.45),
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 4,
            left: 4,
            right: 4,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: onBack,
                ),
                Expanded(
                  child: Text(
                    plant.name,
                    style: Theme.of(context)
                        .textTheme
                        .headlineLarge
                        ?.copyWith(color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Colors.white),
                  onPressed: onEdit,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.white),
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Full-screen photo viewer ──────────────────────────────────────────────────

class _FullScreenPhoto extends StatelessWidget {
  final PlantPhoto photo;

  const _FullScreenPhoto({required this.photo});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Center(
          child: Hero(
            tag: 'photo_${photo.id}',
            child: InteractiveViewer(
              child: Image.file(
                File(photo.filePath),
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white54,
                  size: 64,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Info card ─────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final Plant plant;

  const _InfoCard({required this.plant});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.col.card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row(context, 'Species', plant.species),
          const SizedBox(height: 10),
          _row(context, 'Water every', '${plant.wateringIntervalDays} days'),
          if (plant.lastWateredDate != null) ...[
            const SizedBox(height: 10),
            _row(
              context,
              'Last watered',
              _formatDate(plant.lastWateredDate!),
            ),
          ],
          if (plant.lastFertilizedDate != null) ...[
            const SizedBox(height: 10),
            _row(
              context,
              'Last fertilized',
              _formatDate(plant.lastFertilizedDate!),
            ),
          ],
          if (plant.notes != null && plant.notes!.isNotEmpty) ...[
            const SizedBox(height: 10),
            _row(context, 'Notes', plant.notes!),
          ],
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

// ── Action buttons ────────────────────────────────────────────────────────────

class _ActionButtons extends StatelessWidget {
  final VoidCallback onWater;
  final VoidCallback onFertilize;
  final bool pending;

  const _ActionButtons({
    required this.onWater,
    required this.onFertilize,
    required this.pending,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: pending ? null : onWater,
              child: const Text('Log Watering'),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: pending ? null : onFertilize,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.olive,
                foregroundColor: context.col.bg,
              ),
              child: const Text('Log Fertilizing'),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Care log tile ─────────────────────────────────────────────────────────────

class _CareLogTile extends StatelessWidget {
  final CareLog log;

  const _CareLogTile({required this.log});

  @override
  Widget build(BuildContext context) {
    final isWatering = log.type == CareType.watering;
    final label = isWatering ? 'Watered' : 'Fertilized';
    final color = isWatering ? AppColors.statusGreen : AppColors.olive;
    final bgColor =
        isWatering ? context.col.statusGreenBg : const Color(0xFFECEDD5);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.col.card,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyLarge),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _formatDate(log.date),
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

// ── Soil section ──────────────────────────────────────────────────────────────

// class _SoilSection extends StatelessWidget {
//   const _SoilSection();

//   @override
//   Widget build(BuildContext context) {
//     return SizedBox(
//       height: 600,
//       width: double.infinity,
//       child: CustomPaint(painter: _SoilPainter()),
//     );
//   }
// }

// class _SoilPainter extends CustomPainter {
//   static final _specRng = Random(42);
//   static final _rockRng = Random(7);

//   // Transition specs spread across 0..1 (mapped to 0..transitionZone in paint).
//   // ty uses sqrt bias so more specs cluster near the bottom of the zone.
//   // Size (not opacity) encodes depth: tiny at top, larger at bottom.
//   static const _specColors = [
//     Color(0xFF5C3517), // dark brown
//     Color(0xFF7A4F28), // medium brown
//     Color(0xFF3B2009), // near-black earth
//   ];

//   static final _specs = List.generate(200, (_) {
//     final t = _specRng.nextDouble();
//     return (
//       tx: _specRng.nextDouble(),
//       ty: sqrt(t),
//       baseR: _specRng.nextDouble(),
//       ci: _specRng.nextInt(_specColors.length),
//     );
//   });

//   // Rocks — only in solid portion
//   static final _rocks = List.generate(26, (_) => (
//     tx: _rockRng.nextDouble(),
//     ty: 0.48 + _rockRng.nextDouble() * 0.52,
//     w: 7.0 + _rockRng.nextDouble() * 22,
//     h: 5.0 + _rockRng.nextDouble() * 13,
//     dark: _rockRng.nextBool(),
//   ));

//   // Fine texture dots — only in solid portion
//   static final _dots = List.generate(70, (_) => (
//     tx: _rockRng.nextDouble(),
//     ty: 0.48 + _rockRng.nextDouble() * 0.52,
//     r: 0.8 + _rockRng.nextDouble() * 1.8,
//   ));

//   // Solid soil starts at 48% of the widget height
//   static const _solidStart = 0.34;

//   @override
//   void paint(Canvas canvas, Size size) {
//     final solidY = size.height * _solidStart;

//     // ── Solid soil background ──────────────────────────────────────────
//     canvas.drawRect(
//       Rect.fromLTWH(0, solidY, size.width, size.height - solidY),
//       Paint()..color = const Color(0xFF5C3517),
//     );

//     // ── Sub-layers (4 layers, evenly spaced across solid portion) ──────
//     canvas.drawPath(
//       _wavyLayer(size, size.height * 0.60, Random(3)),
//       Paint()..color = const Color(0xFF6B3E1A),
//     );
//     canvas.drawPath(
//       _wavyLayer(size, size.height * 0.70, Random(19)),
//       Paint()..color = const Color(0xFF7A4F28),
//     );
//     canvas.drawPath(
//       _wavyLayer(size, size.height * 0.81, Random(7)),
//       Paint()..color = const Color(0xFF8E5F32),
//     );
//     canvas.drawPath(
//       _wavyLayer(size, size.height * 0.91, Random(31)),
//       Paint()..color = const Color(0xFF9B6B3A),
//     );

//     // ── Rocks ─────────────────────────────────────────────────────────
//     for (final r in _rocks) {
//       canvas.drawOval(
//         Rect.fromCenter(
//           center: Offset(r.tx * size.width, r.ty * size.height),
//           width: r.w,
//           height: r.h,
//         ),
//         Paint()
//           ..color =
//               r.dark ? const Color(0xFF8A7060) : const Color(0xFFB09878),
//       );
//     }

//     // ── Fine texture dots ──────────────────────────────────────────────
//     final dotPaint = Paint()..color = const Color(0x55200E00);
//     for (final d in _dots) {
//       canvas.drawCircle(
//         Offset(d.tx * size.width, d.ty * size.height),
//         d.r,
//         dotPaint,
//       );
//     }

//     // ── Transition specs ───────────────────────────────────────────────
//     // Zone extends from 0 to solidY + small overlap into solid.
//     // Size grows from ~0.4 px at top to ~5 px at solidY (quadratic).
//     // No opacity change — size alone creates the fade effect.
//     final specZoneH = solidY * 1.4;
//     final maxSpecR = size.width / 7;
//     final specPaint = Paint();
//     for (final s in _specs) {
//       final y = s.ty * specZoneH;
//       final depthT = (y / specZoneH).clamp(0.0, 1.0);
//       final r = (0.4 + s.baseR * (maxSpecR - 0.4)) * depthT * depthT;
//       if (r < 0.3) continue;
//       specPaint.color = _specColors[s.ci];
//       canvas.drawCircle(Offset(s.tx * size.width, y), r, specPaint);
//     }
//   }

//   Path _wavyLayer(Size size, double topY, Random rng) {
//     final path = Path()..moveTo(0, topY);
//     double x = 0;
//     while (x < size.width) {
//       final ex = (x + 40).clamp(0.0, size.width);
//       path.quadraticBezierTo(
//         x + 20,
//         topY + rng.nextDouble() * 22 - 11,
//         ex,
//         topY + rng.nextDouble() * 14 - 7,
//       );
//       x += 40;
//     }
//     path.lineTo(size.width, size.height);
//     path.lineTo(0, size.height);
//     path.close();
//     return path;
//   }

//   @override
//   bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
// }
