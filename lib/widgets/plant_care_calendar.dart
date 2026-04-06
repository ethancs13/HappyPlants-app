import 'package:flutter/material.dart';
import 'package:happy_plants/models/care_log.dart';
import 'package:happy_plants/models/plant.dart';
import 'package:happy_plants/repositories/care_log_repository.dart';
import 'package:happy_plants/repositories/plant_repository.dart';
import 'package:happy_plants/theme/app_theme.dart';

// ── Time slots ────────────────────────────────────────────────────────────────

enum _Slot { morning, afternoon, evening }

extension _SlotX on _Slot {
  String get label => switch (this) {
        _Slot.morning => 'AM',
        _Slot.afternoon => 'PM',
        _Slot.evening => 'Eve',
      };

  int get defaultHour => switch (this) {
        _Slot.morning => 9,
        _Slot.afternoon => 14,
        _Slot.evening => 19,
      };

  static _Slot fromHour(int hour) {
    if (hour < 12) return _Slot.morning;
    if (hour < 18) return _Slot.afternoon;
    return _Slot.evening;
  }
}

// ── Palette ───────────────────────────────────────────────────────────────────

const _waterColor = Color(0xFF4A9BE8);
const _fertColor = Color(0xFF5B8A5F);
const _waterBg = Color(0xFFCDE3F8);
const _fertBg = Color(0xFFCEE3C8);
const _scheduledBg = Color(0xFFE5F5EA);
const _emptyBg = Color(0xFFF0EDE5);

const _pickerColors = [
  Color(0xFF4A9BE8), // blue
  Color(0xFF5B8A5F), // forest green
  Color(0xFFD4A844), // golden
  Color(0xFFD96B4A), // orange
  Color(0xFFAD5F9A), // purple
  Color(0xFFE05555), // red
];

const _pickerEmojis = ['💧', '🌱', '✂️', '🌞', '🌿', '🪴', '🐛', '💊'];

// ── Main widget ───────────────────────────────────────────────────────────────

class PlantCareCalendar extends StatefulWidget {
  final Plant plant;
  final List<CareLog> logs;
  final VoidCallback onRefresh;

  const PlantCareCalendar({
    super.key,
    required this.plant,
    required this.logs,
    required this.onRefresh,
  });

  @override
  State<PlantCareCalendar> createState() => _PlantCareCalendarState();
}

class _PlantCareCalendarState extends State<PlantCareCalendar> {
  static const _pastDays = 14;
  static const _futureDays = 21;
  static const _totalDays = _pastDays + 1 + _futureDays;
  static const _colW = 46.0;
  static const _rowH = 52.0;
  static const _headerH = 40.0;
  static const _labelW = 46.0;

  final _scroll = ScrollController();
  late final DateTime _today;
  late final DateTime _start;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _today = DateTime(now.year, now.month, now.day);
    _start = _today.subtract(const Duration(days: _pastDays));
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToToday());
  }

  void _scrollToToday() {
    if (!_scroll.hasClients) return;
    final viewport = _scroll.position.viewportDimension;
    final target = _pastDays * _colW - (viewport - _colW) / 2;
    _scroll.jumpTo(target.clamp(0.0, _scroll.position.maxScrollExtent));
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  // "yyyy-MM-dd|slotName" → logs in that cell
  Map<String, List<CareLog>> get _logMap {
    final m = <String, List<CareLog>>{};
    for (final log in widget.logs) {
      final k = '${_dk(log.date)}|${_SlotX.fromHour(log.date.hour).name}';
      (m[k] ??= []).add(log);
    }
    return m;
  }

  // Dates of future scheduled waterings within the visible window
  Set<String> get _scheduled {
    final result = <String>{};
    final last = widget.plant.lastWateredDate;
    if (last == null) return result;
    final interval = widget.plant.wateringIntervalDays;
    var d = DateTime(last.year, last.month, last.day)
        .add(Duration(days: interval));
    final limit = _today.add(const Duration(days: _futureDays + 1));
    while (!d.isAfter(limit)) {
      result.add(_dk(d));
      d = d.add(Duration(days: interval));
    }
    return result;
  }

  String _dk(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  DateTime _dayAt(int i) => _start.add(Duration(days: i));

  @override
  Widget build(BuildContext context) {
    final logMap = _logMap;
    final scheduled = _scheduled;

    return SizedBox(
      height: _headerH + _Slot.values.length * _rowH,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fixed time-label column
          SizedBox(
            width: _labelW,
            child: Column(
              children: [
                SizedBox(height: _headerH),
                ..._Slot.values.map((s) => SizedBox(
                      height: _rowH,
                      child: Center(
                        child: Text(
                          s.label,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    )),
              ],
            ),
          ),
          // Scrollable day grid
          Expanded(
            child: SingleChildScrollView(
              controller: _scroll,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: _totalDays * _colW,
                child: Column(
                  children: [
                    // Day header row
                    SizedBox(
                      height: _headerH,
                      child: Row(
                        children: List.generate(_totalDays, (i) {
                          final day = _dayAt(i);
                          return _DayHeader(
                            day: day,
                            isToday: day == _today,
                            width: _colW,
                          );
                        }),
                      ),
                    ),
                    // One row per time slot
                    ..._Slot.values.map((slot) => SizedBox(
                          height: _rowH,
                          child: Row(
                            children: List.generate(_totalDays, (i) {
                              final day = _dayAt(i);
                              final dayStr = _dk(day);
                              final key = '$dayStr|${slot.name}';
                              final cellLogs = logMap[key] ?? [];
                              final isFuture = day.isAfter(_today);
                              final isScheduled = scheduled.contains(dayStr) &&
                                  slot == _Slot.morning &&
                                  isFuture;

                              return _CalendarCell(
                                width: _colW,
                                height: _rowH,
                                logs: cellLogs,
                                isScheduled: isScheduled,
                                isToday: day == _today,
                                isFuture: isFuture,
                                // Tap on future non-scheduled cells does nothing
                                onTap: isFuture && !isScheduled
                                    ? null
                                    : () => _onTap(day, slot, cellLogs),
                                onLongPress: isFuture
                                    ? null
                                    : () => _onLongPress(day, slot, cellLogs),
                              );
                            }),
                          ),
                        )),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onTap(
      DateTime day, _Slot slot, List<CareLog> existing) async {
    final refresh = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _QuickLogSheet(
        day: day,
        slot: slot,
        plant: widget.plant,
        existing: existing,
      ),
    );
    if (refresh == true && mounted) widget.onRefresh();
  }

  Future<void> _onLongPress(
      DateTime day, _Slot slot, List<CareLog> existing) async {
    final refresh = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CustomLogSheet(
        day: day,
        slot: slot,
        plant: widget.plant,
        existing: existing,
      ),
    );
    if (refresh == true && mounted) widget.onRefresh();
  }
}

// ── Day header cell ───────────────────────────────────────────────────────────

class _DayHeader extends StatelessWidget {
  final DateTime day;
  final bool isToday;
  final double width;

  const _DayHeader(
      {required this.day, required this.isToday, required this.width});

  @override
  Widget build(BuildContext context) {
    const dowLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final dow = dowLabels[day.weekday - 1];
    return SizedBox(
      width: width,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            dow,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isToday ? AppColors.darkOlive : AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 3),
          Container(
            width: 22,
            height: 22,
            decoration: isToday
                ? const BoxDecoration(
                    color: AppColors.darkOlive, shape: BoxShape.circle)
                : null,
            child: Center(
              child: Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isToday ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Calendar cell ─────────────────────────────────────────────────────────────

class _CalendarCell extends StatelessWidget {
  final double width;
  final double height;
  final List<CareLog> logs;
  final bool isScheduled;
  final bool isToday;
  final bool isFuture;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _CalendarCell({
    required this.width,
    required this.height,
    required this.logs,
    required this.isScheduled,
    required this.isToday,
    required this.isFuture,
    required this.onTap,
    required this.onLongPress,
  });

  static Color _parseHex(String hex) {
    final clean = hex.replaceFirst('#', '');
    return Color(int.parse('FF$clean', radix: 16));
  }

  Color _bgColor() {
    if (logs.isEmpty) {
      if (isScheduled) return _scheduledBg;
      return _emptyBg;
    }
    final last = logs.last;
    if (last.color != null) {
      return _parseHex(last.color!).withValues(alpha: 0.25);
    }
    return last.type == CareType.watering ? _waterBg : _fertBg;
  }

  @override
  Widget build(BuildContext context) {
    final bg = _bgColor();
    final hasLog = logs.isNotEmpty;
    final last = hasLog ? logs.last : null;

    BoxBorder? border;
    if (isToday && !hasLog) {
      border = Border.all(color: AppColors.darkOlive, width: 1.5);
    } else if (isScheduled && !hasLog) {
      border = Border.all(
          color: AppColors.statusGreen.withValues(alpha: 0.5), width: 1);
    }

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        width: width,
        height: height,
        margin: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(7),
          border: border,
        ),
        child: hasLog
            ? _logContent(last!)
            : isScheduled
                ? const Center(
                    child: Icon(Icons.water_drop_outlined,
                        size: 14, color: AppColors.statusGreen),
                  )
                : null,
      ),
    );
  }

  Widget _logContent(CareLog log) {
    Widget icon;
    if (log.emoji != null && log.emoji!.isNotEmpty) {
      icon = Text(log.emoji!, style: const TextStyle(fontSize: 18));
    } else {
      final iconData =
          log.type == CareType.watering ? Icons.water_drop : Icons.eco;
      final iconColor = log.color != null
          ? _parseHex(log.color!)
          : (log.type == CareType.watering ? _waterColor : _fertColor);
      icon = Icon(iconData, size: 17, color: iconColor);
    }

    if (logs.length == 1) return Center(child: icon);

    return Stack(
      children: [
        Center(child: icon),
        Positioned(
          top: 2,
          right: 3,
          child: Text(
            '+${logs.length - 1}',
            style: const TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w800,
              color: AppColors.textMuted,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Quick log sheet (tap) ─────────────────────────────────────────────────────

class _QuickLogSheet extends StatefulWidget {
  final DateTime day;
  final _Slot slot;
  final Plant plant;
  final List<CareLog> existing;

  const _QuickLogSheet({
    required this.day,
    required this.slot,
    required this.plant,
    required this.existing,
  });

  @override
  State<_QuickLogSheet> createState() => _QuickLogSheetState();
}

class _QuickLogSheetState extends State<_QuickLogSheet> {
  bool _saving = false;

  String _label() {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    const dow = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final d = widget.day;
    return '${dow[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}'
        ' — ${widget.slot.label}';
  }

  Future<void> _log(CareType type) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final logDate = DateTime(widget.day.year, widget.day.month,
          widget.day.day, widget.slot.defaultHour);
      final repo = await CareLogRepository.create();
      await repo.insert(
          CareLog(plantId: widget.plant.id!, type: type, date: logDate));
      await _maybeUpdatePlant(type, logDate);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(CareLog log) async {
    final repo = await CareLogRepository.create();
    await repo.delete(log.id!);
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _maybeUpdatePlant(CareType type, DateTime logDate) async {
    if (logDate.isAfter(DateTime.now())) return;
    final plantRepo = await PlantRepository.create();
    final current = await plantRepo.getById(widget.plant.id!);
    if (current == null) return;
    final isWater = type == CareType.watering;
    final prev =
        isWater ? current.lastWateredDate : current.lastFertilizedDate;
    if (prev == null || logDate.isAfter(prev)) {
      await plantRepo.update(isWater
          ? current.copyWith(lastWateredDate: logDate)
          : current.copyWith(lastFertilizedDate: logDate));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _handle(),
            Text(_label(), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            // Existing logs with delete
            if (widget.existing.isNotEmpty) ...[
              ...widget.existing.map((log) {
                final isWater = log.type == CareType.watering;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: log.emoji != null
                      ? Text(log.emoji!,
                          style: const TextStyle(fontSize: 22))
                      : Icon(
                          isWater ? Icons.water_drop : Icons.eco,
                          color: isWater ? _waterColor : _fertColor,
                          size: 22,
                        ),
                  title: Text(
                    isWater ? 'Watered' : 'Fertilized',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  subtitle: log.notes != null
                      ? Text(log.notes!,
                          style: Theme.of(context).textTheme.bodyMedium)
                      : null,
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: AppColors.statusRed, size: 20),
                    onPressed: () => _delete(log),
                  ),
                );
              }),
              const Divider(height: 24),
            ],
            // Quick log buttons
            if (_saving)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: CircularProgressIndicator(),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: _TypeBtn(
                      label: 'Watering',
                      icon: Icons.water_drop,
                      color: _waterColor,
                      bg: _waterBg,
                      onTap: () => _log(CareType.watering),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TypeBtn(
                      label: 'Fertilizing',
                      icon: Icons.eco,
                      color: _fertColor,
                      bg: _fertBg,
                      onTap: () => _log(CareType.fertilizing),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ── Custom log sheet (long-press) ─────────────────────────────────────────────

class _CustomLogSheet extends StatefulWidget {
  final DateTime day;
  final _Slot slot;
  final Plant plant;
  final List<CareLog> existing;

  const _CustomLogSheet({
    required this.day,
    required this.slot,
    required this.plant,
    required this.existing,
  });

  @override
  State<_CustomLogSheet> createState() => _CustomLogSheetState();
}

class _CustomLogSheetState extends State<_CustomLogSheet> {
  CareType _type = CareType.watering;
  String? _emoji;
  Color? _color;
  final _notesCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  String _dateLabel() {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    const dow = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final d = widget.day;
    return '${dow[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}'
        ' — ${widget.slot.label}';
  }

  String _hexColor(Color c) {
    final r = (c.r * 255).round().toRadixString(16).padLeft(2, '0');
    final g = (c.g * 255).round().toRadixString(16).padLeft(2, '0');
    final b = (c.b * 255).round().toRadixString(16).padLeft(2, '0');
    return '#$r$g$b'.toUpperCase();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final logDate = DateTime(widget.day.year, widget.day.month,
          widget.day.day, widget.slot.defaultHour);
      final repo = await CareLogRepository.create();
      await repo.insert(CareLog(
        plantId: widget.plant.id!,
        type: _type,
        date: logDate,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        emoji: _emoji,
        color: _color != null ? _hexColor(_color!) : null,
      ));
      // Update plant's last care date
      if (!logDate.isAfter(DateTime.now())) {
        final plantRepo = await PlantRepository.create();
        final current = await plantRepo.getById(widget.plant.id!);
        if (current != null) {
          final isWater = _type == CareType.watering;
          final prev =
              isWater ? current.lastWateredDate : current.lastFertilizedDate;
          if (prev == null || logDate.isAfter(prev)) {
            await plantRepo.update(isWater
                ? current.copyWith(lastWateredDate: logDate)
                : current.copyWith(lastFertilizedDate: logDate));
          }
        }
      }
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: _handle()),
              Text('Custom entry',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(_dateLabel(),
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 20),
              // Existing logs
              if (widget.existing.isNotEmpty) ...[
                Text('Logged', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 6),
                ...widget.existing.map((log) => _ExistingLogTile(log: log)),
                const Divider(height: 24),
              ],
              // Type
              Text('Type', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 8),
              Row(
                children: [
                  _TypeChip(
                    label: 'Watering',
                    selected: _type == CareType.watering,
                    color: _waterColor,
                    onTap: () => setState(() => _type = CareType.watering),
                  ),
                  const SizedBox(width: 8),
                  _TypeChip(
                    label: 'Fertilizing',
                    selected: _type == CareType.fertilizing,
                    color: _fertColor,
                    onTap: () => setState(() => _type = CareType.fertilizing),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Emoji
              Text('Emoji', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _EmojiOption(
                    value: null,
                    selected: _emoji == null,
                    onTap: () => setState(() => _emoji = null),
                  ),
                  ..._pickerEmojis.map((e) => _EmojiOption(
                        value: e,
                        selected: _emoji == e,
                        onTap: () => setState(() => _emoji = e),
                      )),
                ],
              ),
              const SizedBox(height: 20),
              // Color
              Text('Color', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 8),
              Row(
                children: [
                  _ColorDot(
                    color: null,
                    selected: _color == null,
                    onTap: () => setState(() => _color = null),
                  ),
                  ..._pickerColors.map((c) => _ColorDot(
                        color: c,
                        selected: _color == c,
                        onTap: () => setState(() => _color = c),
                      )),
                ],
              ),
              const SizedBox(height: 20),
              // Notes
              Text('Notes (optional)',
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 8),
              TextField(
                controller: _notesCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'e.g. Used liquid fertilizer',
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save Entry'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Reusable small widgets ────────────────────────────────────────────────────

Widget _handle() => Container(
      width: 36,
      height: 4,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.divider,
        borderRadius: BorderRadius.circular(2),
      ),
    );

class _ExistingLogTile extends StatefulWidget {
  final CareLog log;
  const _ExistingLogTile({required this.log});

  @override
  State<_ExistingLogTile> createState() => _ExistingLogTileState();
}

class _ExistingLogTileState extends State<_ExistingLogTile> {
  Future<void> _delete() async {
    final repo = await CareLogRepository.create();
    await repo.delete(widget.log.id!);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final log = widget.log;
    final isWater = log.type == CareType.watering;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: log.emoji != null
          ? Text(log.emoji!, style: const TextStyle(fontSize: 20))
          : Icon(isWater ? Icons.water_drop : Icons.eco,
              color: isWater ? _waterColor : _fertColor, size: 20),
      title: Text(isWater ? 'Watered' : 'Fertilized',
          style: Theme.of(context).textTheme.bodyLarge),
      subtitle: log.notes != null
          ? Text(log.notes!, style: Theme.of(context).textTheme.bodyMedium)
          : null,
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline,
            color: AppColors.statusRed, size: 20),
        onPressed: _delete,
      ),
    );
  }
}

class _TypeBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color bg;
  final VoidCallback onTap;

  const _TypeBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.bg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _TypeChip(
      {required this.label,
      required this.selected,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : AppColors.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? color : AppColors.divider,
              width: selected ? 2 : 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : AppColors.textMuted,
            fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _EmojiOption extends StatelessWidget {
  final String? value;
  final bool selected;
  final VoidCallback onTap;

  const _EmojiOption(
      {required this.value, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color:
              selected ? AppColors.statusGreenBg : AppColors.cardBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: selected ? AppColors.forest : AppColors.divider),
        ),
        child: Center(
          child: value != null
              ? Text(value!, style: const TextStyle(fontSize: 20))
              : const Text('—',
                  style: TextStyle(color: AppColors.textMuted)),
        ),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  final Color? color;
  final bool selected;
  final VoidCallback onTap;

  const _ColorDot(
      {required this.color, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: color ?? AppColors.cardBg,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? AppColors.textPrimary
                : Colors.transparent,
            width: 2.5,
          ),
        ),
        child: color == null
            ? const Center(
                child: Text('—',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textMuted)))
            : null,
      ),
    );
  }
}
