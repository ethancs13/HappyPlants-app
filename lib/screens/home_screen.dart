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

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  int _tab = 0;
  final _plantsTabKey = GlobalKey<_PlantsTabState>();
  final _calendarKey = GlobalKey<CalendarScreenState>();
  late final List<AnimationController> _hopControllers;
  late final List<Animation<double>> _hopAnims;

  @override
  void initState() {
    super.initState();
    _hopControllers = List.generate(
      2,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 300),
      ),
    );
    _hopAnims = _hopControllers.map((c) {
      return TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: 0, end: -7), weight: 40),
        TweenSequenceItem(tween: Tween(begin: -7, end: 2), weight: 30),
        TweenSequenceItem(tween: Tween(begin: 2, end: 0), weight: 30),
      ]).animate(CurvedAnimation(parent: c, curve: Curves.easeOut));
    }).toList();
  }

  @override
  void dispose() {
    for (final c in _hopControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _onTabTap(int i) {
    setState(() => _tab = i);
    _hopControllers[i].forward(from: 0);
    if (i == 1) {
      _calendarKey.currentState?.reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.col.bg,
      floatingActionButton: _tab == 0
          ? FloatingActionButton(
              onPressed: _openAddPlant,
              backgroundColor: AppColors.darkOlive,
              foregroundColor: AppColors.tan,
              elevation: 3,
              child: const Icon(Icons.add, size: 28),
            )
          : null,
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: BottomNavigationBar(
          currentIndex: _tab,
          onTap: _onTabTap,
          backgroundColor: AppColors.darkOlive,
          selectedItemColor: AppColors.tan,
          unselectedItemColor: AppColors.tan.withValues(alpha: 0.45),
          selectedFontSize: 12,
          unselectedFontSize: 12,
          items: [
            BottomNavigationBarItem(
              icon: AnimatedBuilder(
                animation: _hopAnims[0],
                builder: (_, child) => Transform.translate(
                  offset: Offset(0, _hopAnims[0].value),
                  child: child,
                ),
                child: const Icon(Icons.local_florist),
              ),
              label: 'Plants',
            ),
            BottomNavigationBarItem(
              icon: AnimatedBuilder(
                animation: _hopAnims[1],
                builder: (_, child) => Transform.translate(
                  offset: Offset(0, _hopAnims[1].value),
                  child: child,
                ),
                child: const Icon(Icons.calendar_month),
              ),
              label: 'Calendar',
            ),
          ],
        ),
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

  Future<void> _openChat() async {
    final box =
        _chatBubbleKey.currentContext?.findRenderObject() as RenderBox?;
    final center = box != null
        ? box.localToGlobal(Offset(box.size.width / 2, box.size.height / 2))
        : Offset(44, MediaQuery.of(context).size.height - 100);

    await Navigator.of(context).push(
      CircularRevealRoute<void>(
        page: const ChatScreen(),
        center: center,
      ),
    );
    _refresh();
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
  late final AnimationController _breathe;
  late final Animation<double> _breatheScale;

  void _startRing(int i) {
    _rings[i]
      ..reset()
      ..forward().then((_) {
        if (mounted) _startRing(i);
      });
  }

  @override
  void initState() {
    super.initState();

    // 3 staggered expanding rings
    _rings = List.generate(
      3,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 11000),
      ),
    );
    _startRing(0);
    Future.delayed(const Duration(milliseconds: 3700), () {
      if (mounted) _startRing(1);
    });
    Future.delayed(const Duration(milliseconds: 7400), () {
      if (mounted) _startRing(2);
    });

    // Breathe on the main button
    _breathe = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
    )..repeat(reverse: true);
    _breatheScale = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _breathe, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    for (final c in _rings) {
      c.dispose();
    }
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
            // Expanding rings
            for (int i = 0; i < 3; i++)
              AnimatedBuilder(
                animation: _rings[i],
                builder: (_, _) => CustomPaint(
                  size: const Size(100, 100),
                  painter: _RingPainter(
                    progress: _rings[i].value,
                    color: AppColors.forest,
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

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;

  const _RingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    // Start inside the button (radius 18) so ring slides out from behind it
    final radius = 18.0 + progress * 32.0;
    final fadeIn = (progress / 0.10).clamp(0.0, 1.0);
    final opacity = fadeIn * 0.32 * pow(1 - progress, 2.0);
    if (opacity <= 0.005) return;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color.withValues(alpha: opacity.toDouble())
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8 + 1.2 * (1 - progress),
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
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
