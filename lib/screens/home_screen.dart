import 'dart:math';
import 'package:flutter/material.dart';
import 'package:happy_plants/models/plant.dart';
import 'package:happy_plants/repositories/plant_photo_repository.dart';
import 'package:happy_plants/repositories/plant_repository.dart';
import 'package:happy_plants/routes/circular_reveal_route.dart';
import 'package:happy_plants/screens/calendar_screen.dart';
import 'package:happy_plants/screens/chat_screen.dart';
import 'package:happy_plants/screens/settings_screen.dart';
import 'package:happy_plants/theme/app_theme.dart';
import 'package:happy_plants/widgets/plant_card.dart';
import 'package:happy_plants/widgets/plant_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  final _plantsTabKey = GlobalKey<_PlantsTabState>();
  final _calendarKey = GlobalKey<CalendarScreenState>();

  void _onTabTap(int i) {
    setState(() => _tab = i);
    if (i == 1) {
      // Reload calendar data whenever the tab is activated
      _calendarKey.currentState?.reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      floatingActionButton: _tab == 0
          ? FloatingActionButton(
              onPressed: _openAddPlant,
              backgroundColor: AppColors.darkOlive,
              foregroundColor: AppColors.tan,
              elevation: 3,
              child: const Icon(Icons.add, size: 28),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: _onTabTap,
        backgroundColor: AppColors.darkOlive,
        selectedItemColor: AppColors.tan,
        unselectedItemColor: AppColors.tan.withValues(alpha: 0.45),
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.local_florist),
            label: 'Plants',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: 'Calendar',
          ),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          _PlantsTab(key: _plantsTabKey),
          CalendarScreen(key: _calendarKey),
        ],
      ),
    );
  }

  Future<void> _openAddPlant() async {
    final added = await Navigator.pushNamed(context, '/add');
    if (added == true) _plantsTabKey.currentState?._refresh();
  }
}

// ── Plants Tab ────────────────────────────────────────────────────────────────

class _PlantsTab extends StatefulWidget {
  const _PlantsTab({super.key});

  @override
  State<_PlantsTab> createState() => _PlantsTabState();
}

typedef _HomeData = ({List<Plant> plants, Map<int, String> coverPhotos});

class _PlantsTabState extends State<_PlantsTab> {
  late Future<_HomeData> _dataFuture;
  final _chatBubbleKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _dataFuture = Future.wait([
      PlantRepository.create().then((r) => r.getAll()),
      PlantPhotoRepository.create().then((r) => r.getCoverPhotoMap()),
    ]).then((results) => (
          plants: results[0] as List<Plant>,
          coverPhotos: results[1] as Map<int, String>,
        ));
  }

  void _refresh() => setState(_load);

  void _openChat() {
    final box =
        _chatBubbleKey.currentContext?.findRenderObject() as RenderBox?;
    final center = box != null
        ? box.localToGlobal(Offset(box.size.width / 2, box.size.height / 2))
        : Offset(44, MediaQuery.of(context).size.height - 100);

    Navigator.of(context).push(
      CircularRevealRoute<void>(
        page: const ChatScreen(),
        center: center,
      ),
    );
  }

  Future<void> _openDetail(Plant plant) async {
    await Navigator.pushNamed(context, '/detail', arguments: plant);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Header(),
            Expanded(
              child: FutureBuilder<_HomeData>(
                future: _dataFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final plants = snapshot.data?.plants ?? [];
                  final coverPhotos = snapshot.data?.coverPhotos ?? {};
                  if (plants.isEmpty) return const _EmptyState();
                  return _PlantList(
                    plants: plants,
                    coverPhotos: coverPhotos,
                    onPlantTap: _openDetail,
                    onRefresh: () async => setState(_load),
                  );
                },
              ),
            ),
          ],
        ),
        Positioned(
          bottom: MediaQuery.of(context).viewPadding.bottom - 8,
          left: -8,
          child: _AIChatBubble(
            key: _chatBubbleKey,
            onTap: _openChat,
          ),
        ),
      ],
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.darkOlive,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: 20,
        right: 8,
        bottom: 16,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'My Plants',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppColors.tan),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
            tooltip: 'Settings',
          ),
        ],
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const PlantWidget(isHappy: true, size: 120, plantKey: 'plant_01'),
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

// ── AI Chat Bubble ────────────────────────────────────────────────────────────

class _AIChatBubble extends StatefulWidget {
  final VoidCallback onTap;

  const _AIChatBubble({super.key, required this.onTap});

  @override
  State<_AIChatBubble> createState() => _AIChatBubbleState();
}

class _AIChatBubbleState extends State<_AIChatBubble>
    with TickerProviderStateMixin {
  late final List<AnimationController> _rings;
  late final AnimationController _wavePhase;
  late final AnimationController _breathe;
  late final Animation<double> _breatheScale;

  @override
  void initState() {
    super.initState();

    // 3 staggered expanding rings — slow, earthy spread
    _rings = List.generate(
      3,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 16000),
      ),
    );
    _rings[0].repeat();
    Future.delayed(const Duration(milliseconds: 6000), () {
      if (mounted) _rings[1].repeat();
    });
    Future.delayed(const Duration(milliseconds: 11000), () {
      if (mounted) _rings[2].repeat();
    });

    // Slow wave rotation for the organic wobble
    _wavePhase = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 11000),
    )..repeat();

    // Subtle breathe on the main button
    _breathe = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 11000),
    )..repeat(reverse: true);
    _breatheScale = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _breathe, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    for (final c in _rings) {
      c.dispose();
    }
    _wavePhase.dispose();
    _breathe.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: SizedBox(
        width: 100,
        height: 100,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Wavy expanding rings
            for (int i = 0; i < 3; i++)
              AnimatedBuilder(
                animation: Listenable.merge([_rings[i], _wavePhase]),
                builder: (_, _) => CustomPaint(
                  size: const Size(100, 100),
                  painter: _WavyRingPainter(
                    progress: _rings[i].value,
                    wavePhase: _wavePhase.value * 2 * pi,
                    color: AppColors.forest,
                    baseRadius: 28,
                  ),
                ),
              ),
            // Breathing main button
            AnimatedBuilder(
              animation: _breathe,
              builder: (_, child) =>
                  Transform.scale(scale: _breatheScale.value, child: child),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.forest,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.forest.withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.eco, color: Colors.white, size: 26),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WavyRingPainter extends CustomPainter {
  final double progress;
  final double wavePhase;
  final Color color;
  final double baseRadius;

  const _WavyRingPainter({
    required this.progress,
    required this.wavePhase,
    required this.color,
    required this.baseRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = baseRadius + progress * baseRadius * 1.1;
    // Waves are most pronounced at the start, fade as ring expands
    final waveAmp = 2.5 * (1 - progress);
    // Fade out quickly — squared curve so opacity drops off fast early
    final opacity = 0.18 * pow(1 - progress, 2.5);
    if (opacity <= 0.005) return;

    final paint = Paint()
      ..color = color.withValues(alpha: opacity.toDouble())
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 + 0.8 * (1 - progress);

    const segments = 72;
    final path = Path();
    for (int i = 0; i <= segments; i++) {
      final angle = 2 * pi * i / segments;
      // Two overlapping sin waves at different frequencies for organic feel
      final wave = waveAmp * sin(wavePhase + angle * 5) +
          waveAmp * 0.4 * sin(wavePhase * 1.3 + angle * 8);
      final r = radius + wave;
      final x = center.dx + r * cos(angle);
      final y = center.dy + r * sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_WavyRingPainter old) =>
      old.progress != progress || old.wavePhase != wavePhase;
}

// ── Plant list ────────────────────────────────────────────────────────────────

class _PlantList extends StatelessWidget {
  final List<Plant> plants;
  final Map<int, String> coverPhotos;
  final void Function(Plant) onPlantTap;
  final Future<void> Function() onRefresh;

  const _PlantList({
    required this.plants,
    required this.coverPhotos,
    required this.onPlantTap,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.darkOlive,
      child: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: plants.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) => PlantCard(
          plant: plants[i],
          coverPhotoPath: coverPhotos[plants[i].id],
          onTap: () => onPlantTap(plants[i]),
        ),
      ),
    );
  }
}
