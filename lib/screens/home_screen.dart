import 'package:flutter/material.dart';
import 'package:happy_plants/models/plant.dart';
import 'package:happy_plants/repositories/plant_repository.dart';
import 'package:happy_plants/theme/app_theme.dart';
import 'package:happy_plants/widgets/plant_card.dart';
import 'package:happy_plants/widgets/plant_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Plant>> _plantsFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _plantsFuture = PlantRepository.create().then((repo) => repo.getAll());
  }

  void _refresh() => setState(_load);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(onAddTap: _openAddPlant),
          Expanded(
            child: FutureBuilder<List<Plant>>(
              future: _plantsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final plants = snapshot.data ?? [];
                if (plants.isEmpty) return const _EmptyState();
                return _PlantList(
                  plants: plants,
                  onPlantTap: _openDetail,
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddPlant,
        backgroundColor: AppColors.darkOlive,
        foregroundColor: AppColors.tan,
        elevation: 3,
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }

  Future<void> _openAddPlant() async {
    final added = await Navigator.pushNamed(context, '/add');
    if (added == true) _refresh();
  }

  Future<void> _openDetail(Plant plant) async {
    final changed = await Navigator.pushNamed(
      context,
      '/detail',
      arguments: plant,
    );
    if (changed == true) _refresh();
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onAddTap;

  const _Header({required this.onAddTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.darkOlive,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 20,
        right: 20,
        bottom: 20,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'My Plants',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          GestureDetector(
            onTap: onAddTap,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.forest,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.add, color: AppColors.tan, size: 24),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const PlantWidget(isHappy: false, size: 100),
          const SizedBox(height: 24),
          Text(
            'No plants yet',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to add your first plant',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _PlantList extends StatelessWidget {
  final List<Plant> plants;
  final void Function(Plant) onPlantTap;

  const _PlantList({required this.plants, required this.onPlantTap});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: plants.length,
      separatorBuilder: (_, index) => const SizedBox(height: 12),
      itemBuilder: (context, i) => PlantCard(
        plant: plants[i],
        onTap: () => onPlantTap(plants[i]),
      ),
    );
  }
}
