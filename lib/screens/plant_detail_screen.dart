import 'dart:io';
import 'dart:math';
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
          _refreshLogs();
          _actionPending = false;
        });
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

    if (mounted) setState(_refreshPhotos);
  }

  Future<void> _showAddPhotoSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.cardBg,
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
      backgroundColor: AppColors.cardBg,
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
                  if (mounted) setState(_refreshPhotos);
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
                if (mounted) setState(_refreshPhotos);
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
        backgroundColor: AppColors.cardBg,
        title: const Text(
          'Delete plant?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'This will permanently remove ${_plant.name} and all its care history.',
          style: const TextStyle(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textMuted),
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

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final overdue = _plant.isOverdueForWater;

    return Scaffold(
      backgroundColor: AppColors.cream,
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
                              color: AppColors.cardBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.textMuted.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.add_a_photo_outlined,
                                      color: AppColors.textMuted, size: 28),
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
                                      color: AppColors.cardBg,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: AppColors.textMuted
                                            .withValues(alpha: 0.2),
                                      ),
                                    ),
                                    child: const Icon(Icons.add,
                                        color: AppColors.textMuted, size: 28),
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
                                          color: AppColors.cardBg,
                                          child: const Icon(
                                              Icons.broken_image_outlined,
                                              color: AppColors.textMuted),
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
                  Text('Care Schedule',
                      style: Theme.of(context).textTheme.titleMedium),
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
                  const _SoilSection(),
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
      color: AppColors.brown,
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
        color: AppColors.cardBg,
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
                foregroundColor: AppColors.cream,
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
        isWatering ? AppColors.statusGreenBg : const Color(0xFFECEDD5);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
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

class _SoilSection extends StatelessWidget {
  const _SoilSection();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 320,
      width: double.infinity,
      child: CustomPaint(painter: _SoilPainter()),
    );
  }
}

class _SoilPainter extends CustomPainter {
  static final _rng = Random(7);

  static final _rocks = List.generate(28, (_) => (
    dx: _rng.nextDouble(),
    dy: _rng.nextDouble(),
    w: 8.0 + _rng.nextDouble() * 22,
    h: 5.0 + _rng.nextDouble() * 14,
    dark: _rng.nextBool(),
  ));

  static final _dots = List.generate(60, (_) => (
    dx: _rng.nextDouble(),
    dy: _rng.nextDouble(),
    r: 1.0 + _rng.nextDouble() * 2,
  ));

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF5C3517),
    );

    final topEdge = Path()..moveTo(0, 0);
    final rng2 = Random(13);
    double x = 0;
    while (x < size.width) {
      final cp1x = x + 15;
      final cp1y = rng2.nextDouble() * 18;
      final cp2x = x + 30;
      final cp2y = rng2.nextDouble() * 18;
      final ex = (x + 40).clamp(0, size.width).toDouble();
      final ey = rng2.nextDouble() * 14;
      topEdge.cubicTo(cp1x, cp1y, cp2x, cp2y, ex, ey);
      x += 40;
    }
    topEdge.lineTo(size.width, 0);
    topEdge.close();
    canvas.drawPath(topEdge, Paint()..color = const Color(0xFF3B2009));

    canvas.drawPath(
      _wavyLayer(size, size.height * 0.38, Random(3)),
      Paint()..color = const Color(0xFF7A4F28),
    );
    canvas.drawPath(
      _wavyLayer(size, size.height * 0.68, Random(19)),
      Paint()..color = const Color(0xFF9B6B3A),
    );

    for (final r in _rocks) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(r.dx * size.width, r.dy * size.height),
          width: r.w,
          height: r.h,
        ),
        Paint()
          ..color =
              r.dark ? const Color(0xFF8A7060) : const Color(0xFFB09878),
      );
    }

    final dotPaint = Paint()..color = const Color(0x33200E00);
    for (final d in _dots) {
      canvas.drawCircle(
        Offset(d.dx * size.width, d.dy * size.height),
        d.r,
        dotPaint,
      );
    }
  }

  Path _wavyLayer(Size size, double topY, Random rng) {
    final path = Path()..moveTo(0, topY);
    double x = 0;
    while (x < size.width) {
      final ex = (x + 40).clamp(0, size.width).toDouble();
      path.quadraticBezierTo(
        x + 20,
        topY + rng.nextDouble() * 20 - 10,
        ex,
        topY + rng.nextDouble() * 12 - 6,
      );
      x += 40;
    }
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
