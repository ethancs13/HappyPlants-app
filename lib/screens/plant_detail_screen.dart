import 'package:flutter/material.dart';
import 'package:happy_plants/models/care_log.dart';
import 'package:happy_plants/models/plant.dart';
import 'package:happy_plants/repositories/care_log_repository.dart';
import 'package:happy_plants/repositories/plant_repository.dart';
import 'package:happy_plants/theme/app_theme.dart';
import 'package:happy_plants/widgets/plant_widget.dart';

class PlantDetailScreen extends StatefulWidget {
  final Plant plant;

  const PlantDetailScreen({super.key, required this.plant});

  @override
  State<PlantDetailScreen> createState() => _PlantDetailScreenState();
}

class _PlantDetailScreenState extends State<PlantDetailScreen> {
  late Plant _plant;
  late Future<List<CareLog>> _logsFuture;
  bool _actionPending = false;

  @override
  void initState() {
    super.initState();
    _plant = widget.plant;
    _refreshLogs();
  }

  void _refreshLogs() {
    _logsFuture = CareLogRepository.create()
        .then((repo) => repo.getByPlantId(_plant.id!));
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
    await logRepo.deleteByPlantId(_plant.id!);
    await plantRepo.delete(_plant.id!);

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final overdue = _plant.isOverdueForWater;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context, overdue),
          Expanded(
            child: SingleChildScrollView(
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
                  Text(
                    'Care History',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<List<CareLog>>(
                    future: _logsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final logs = snapshot.data ?? [];
                      if (logs.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            'No care logged yet',
                            style: Theme.of(context).textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                        );
                      }
                      return Column(
                        children: logs
                            .map((log) => _CareLogTile(log: log))
                            .toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool overdue) {
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

class _CareLogTile extends StatelessWidget {
  final CareLog log;

  const _CareLogTile({required this.log});

  @override
  Widget build(BuildContext context) {
    final isWatering = log.type == CareType.watering;
    final label = isWatering ? 'Watered' : 'Fertilized';
    final color = isWatering ? AppColors.statusGreen : AppColors.olive;
    final bgColor = isWatering ? AppColors.statusGreenBg : const Color(0xFFECEDD5);

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
