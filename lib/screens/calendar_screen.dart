import 'package:flutter/material.dart';
import 'package:happy_plants/models/care_log.dart';
import 'package:happy_plants/models/plant.dart';
import 'package:happy_plants/repositories/care_log_repository.dart';
import 'package:happy_plants/repositories/plant_repository.dart';
import 'package:happy_plants/theme/app_theme.dart';

// ── Constants ─────────────────────────────────────────────────────────────────

const _waterColor = Color(0xFF4A9BE8);
const _fertColor = Color(0xFF5B8A5F);

const _pickerColors = [
  Color(0xFF4A9BE8),
  Color(0xFF5B8A5F),
  Color(0xFFD4A844),
  Color(0xFFD96B4A),
  Color(0xFFAD5F9A),
  Color(0xFFE05555),
];

const _pickerEmojis = ['💧', '🌱', '✂️', '🌞', '🌿', '🪴', '🐛', '💊'];

const _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

const _weekdayLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

// ── Data model ────────────────────────────────────────────────────────────────

class _CalEvent {
  final CareLog log;
  final Plant plant;
  const _CalEvent({required this.log, required this.plant});
}

// ── CalendarScreen ────────────────────────────────────────────────────────────

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _month;
  List<_CalEvent> _events = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final plantRepo = await PlantRepository.create();
    final logRepo = await CareLogRepository.create();
    final plants = await plantRepo.getAll();
    final logs = await logRepo.getAll();

    final plantMap = {for (final p in plants) p.id!: p};
    final events = <_CalEvent>[];
    for (final log in logs) {
      final plant = plantMap[log.plantId];
      if (plant != null) events.add(_CalEvent(log: log, plant: plant));
    }
    if (mounted) {
      setState(() {
        _events = events;
        _loading = false;
      });
    }
  }

  Map<String, List<_CalEvent>> get _eventMap {
    final m = <String, List<_CalEvent>>{};
    for (final e in _events) {
      final k = _dateKey(e.log.date);
      (m[k] ??= []).add(e);
    }
    return m;
  }

  String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  void _prevMonth() =>
      setState(() => _month = DateTime(_month.year, _month.month - 1));

  void _nextMonth() =>
      setState(() => _month = DateTime(_month.year, _month.month + 1));

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(context),
        _buildWeekdayRow(),
        if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else
          Expanded(child: _buildMonthGrid()),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      color: AppColors.darkOlive,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 8,
        right: 8,
        bottom: 12,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: AppColors.tan),
            onPressed: _prevMonth,
          ),
          Expanded(
            child: Text(
              '${_monthNames[_month.month - 1]} ${_month.year}',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .headlineLarge
                  ?.copyWith(fontSize: 20),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: AppColors.tan),
            onPressed: _nextMonth,
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdayRow() {
    return Container(
      color: AppColors.darkOlive,
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: _weekdayLabels
            .map((l) => Expanded(
                  child: Text(
                    l,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.tan,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildMonthGrid() {
    final today = DateTime.now();
    final todayKey = _dateKey(today);
    final map = _eventMap;

    final firstWeekday = _month.weekday % 7; // 0 = Sunday
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final totalCells = firstWeekday + daysInMonth;
    final rows = (totalCells / 7).ceil();

    return SingleChildScrollView(
      child: Column(
        children: List.generate(rows, (row) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: List.generate(7, (col) {
                final cellIndex = row * 7 + col;
                final dayNum = cellIndex - firstWeekday + 1;

                if (dayNum < 1 || dayNum > daysInMonth) {
                  return Expanded(
                    child: Container(
                      decoration: const BoxDecoration(
                        color: AppColors.cream,
                        border: Border(
                          right: BorderSide(
                              color: AppColors.divider, width: 0.5),
                          bottom: BorderSide(
                              color: AppColors.divider, width: 0.5),
                        ),
                      ),
                    ),
                  );
                }

                final date =
                    DateTime(_month.year, _month.month, dayNum);
                final key = _dateKey(date);
                final isToday = key == todayKey;
                final events = map[key] ?? [];

                return Expanded(
                  child: _DayCell(
                    dayNum: dayNum,
                    isToday: isToday,
                    events: events,
                    onTap: () => _showDaySheet(context, date, events),
                  ),
                );
              }),
            ),
          );
        }),
      ),
    );
  }

  void _showDaySheet(
      BuildContext context, DateTime date, List<_CalEvent> events) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _DaySheet(
        date: date,
        events: events,
        onChanged: _load,
      ),
    );
  }
}

// ── Day Cell ──────────────────────────────────────────────────────────────────

class _DayCell extends StatelessWidget {
  final int dayNum;
  final bool isToday;
  final List<_CalEvent> events;
  final VoidCallback onTap;

  const _DayCell({
    required this.dayNum,
    required this.isToday,
    required this.events,
    required this.onTap,
  });

  Color _eventColor(_CalEvent e) {
    if (e.log.color != null) {
      try {
        final hex = e.log.color!.replaceFirst('#', '');
        return Color(int.parse('FF$hex', radix: 16));
      } catch (_) {}
    }
    return e.log.type == CareType.watering ? _waterColor : _fertColor;
  }

  @override
  Widget build(BuildContext context) {
    final visible = events.length > 3 ? events.sublist(0, 2) : events;
    final overflow = events.length > 3 ? events.length - 2 : 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 70),
        decoration: const BoxDecoration(
          color: AppColors.cream,
          border: Border(
            right: BorderSide(color: AppColors.divider, width: 0.5),
            bottom: BorderSide(color: AppColors.divider, width: 0.5),
          ),
        ),
        padding: const EdgeInsets.all(4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: isToday
                  ? const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.darkOlive,
                    )
                  : null,
              child: Center(
                child: Text(
                  '$dayNum',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isToday
                        ? FontWeight.w700
                        : FontWeight.w400,
                    color: isToday
                        ? Colors.white
                        : AppColors.textPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            ...List.generate(visible.length, (i) {
              final e = visible[i];
              final color = _eventColor(e);
              final label = e.log.emoji ??
                  (e.log.type == CareType.watering ? '💧' : '🌱');
              return Container(
                margin: const EdgeInsets.only(bottom: 2),
                padding: const EdgeInsets.symmetric(
                    horizontal: 3, vertical: 1),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(
                      color: color.withValues(alpha: 0.5), width: 0.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label,
                        style: const TextStyle(fontSize: 9)),
                    const SizedBox(width: 2),
                    Flexible(
                      child: Text(
                        e.plant.name,
                        style: TextStyle(
                          fontSize: 8,
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (overflow > 0)
              Container(
                margin: const EdgeInsets.only(bottom: 2),
                padding: const EdgeInsets.symmetric(
                    horizontal: 3, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  '+$overflow more',
                  style: const TextStyle(
                    fontSize: 8,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Day Sheet ─────────────────────────────────────────────────────────────────

class _DaySheet extends StatefulWidget {
  final DateTime date;
  final List<_CalEvent> events;
  final VoidCallback onChanged;

  const _DaySheet({
    required this.date,
    required this.events,
    required this.onChanged,
  });

  @override
  State<_DaySheet> createState() => _DaySheetState();
}

class _DaySheetState extends State<_DaySheet> {
  late List<_CalEvent> _events;

  @override
  void initState() {
    super.initState();
    _events = List.of(widget.events);
  }

  String _formatDate(DateTime d) {
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday',
    ];
    return '${days[d.weekday - 1]}, ${_monthNames[d.month - 1]} ${d.day}';
  }

  Color _eventColor(_CalEvent e) {
    if (e.log.color != null) {
      try {
        final hex = e.log.color!.replaceFirst('#', '');
        return Color(int.parse('FF$hex', radix: 16));
      } catch (_) {}
    }
    return e.log.type == CareType.watering ? _waterColor : _fertColor;
  }

  Future<void> _delete(_CalEvent e) async {
    final repo = await CareLogRepository.create();
    await repo.delete(e.log.id!);
    if (mounted) {
      setState(
          () => _events.removeWhere((x) => x.log.id == e.log.id));
    }
    widget.onChanged();
  }

  Future<void> _edit(_CalEvent e) async {
    final updated = await showDialog<CareLog>(
      context: context,
      builder: (ctx) => _EditLogDialog(event: e),
    );
    if (updated == null || !mounted) return;
    final repo = await CareLogRepository.create();
    await repo.update(updated);
    if (mounted) {
      setState(() {
        final idx =
            _events.indexWhere((x) => x.log.id == updated.id);
        if (idx != -1) {
          _events[idx] =
              _CalEvent(log: updated, plant: e.plant);
        }
      });
    }
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.75;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 10),
              child: Text(
                _formatDate(widget.date),
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            const Divider(height: 1, color: AppColors.divider),
            if (_events.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No events on this day',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: AppColors.textMuted, fontSize: 15),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _events.length,
                  separatorBuilder: (_, _) => const Divider(
                      height: 1, color: AppColors.divider),
                  itemBuilder: (_, i) => _EventTile(
                    event: _events[i],
                    color: _eventColor(_events[i]),
                    onEdit: () => _edit(_events[i]),
                    onDelete: () => _delete(_events[i]),
                  ),
                ),
              ),
            SizedBox(
                height: MediaQuery.of(context).padding.bottom + 8),
          ],
        ),
      ),
    );
  }
}

// ── Event Tile ────────────────────────────────────────────────────────────────

class _EventTile extends StatelessWidget {
  final _CalEvent event;
  final Color color;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _EventTile({
    required this.event,
    required this.color,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final log = event.log;
    final label = log.emoji ??
        (log.type == CareType.watering ? '💧' : '🌱');
    final typeLabel =
        log.type == CareType.watering ? 'Watering' : 'Fertilizing';
    final timeStr =
        '${log.date.hour.toString().padLeft(2, '0')}:'
        '${log.date.minute.toString().padLeft(2, '0')}';

    return Container(
      margin:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Row(
          children: [
            Text(label,
                style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.plant.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    '$typeLabel · $timeStr',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                  if (log.notes != null &&
                      log.notes!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        log.notes!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              color: AppColors.textMuted,
              onPressed: onEdit,
              tooltip: 'Edit',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              color: AppColors.statusRed,
              onPressed: onDelete,
              tooltip: 'Delete',
            ),
          ],
        ),
      ),
    );
  }
}

// ── Edit Log Dialog ───────────────────────────────────────────────────────────

class _EditLogDialog extends StatefulWidget {
  final _CalEvent event;
  const _EditLogDialog({required this.event});

  @override
  State<_EditLogDialog> createState() => _EditLogDialogState();
}

class _EditLogDialogState extends State<_EditLogDialog> {
  late CareType _type;
  late String? _emoji;
  late Color? _color;
  late TextEditingController _notes;

  @override
  void initState() {
    super.initState();
    final log = widget.event.log;
    _type = log.type;
    _emoji = log.emoji;
    _notes = TextEditingController(text: log.notes ?? '');
    _color = _parseColor(log.color);
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Color? _parseColor(String? hex) {
    if (hex == null) return null;
    try {
      return Color(
          int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));
    } catch (_) {
      return null;
    }
  }

  String? _colorToHex(Color? c) {
    if (c == null) return null;
    final value = c.toARGB32();
    return '#${(value & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.cream,
      title: const Text(
        'Edit Log',
        style: TextStyle(
            color: AppColors.textPrimary, fontSize: 18),
      ),
      contentPadding:
          const EdgeInsets.fromLTRB(20, 12, 20, 0),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionLabel('Care type'),
            const SizedBox(height: 6),
            Row(
              children: [
                _TypeChip(
                  label: '💧 Watering',
                  selected: _type == CareType.watering,
                  onTap: () =>
                      setState(() => _type = CareType.watering),
                ),
                const SizedBox(width: 8),
                _TypeChip(
                  label: '🌱 Fertilizing',
                  selected: _type == CareType.fertilizing,
                  onTap: () => setState(
                      () => _type = CareType.fertilizing),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _SectionLabel('Emoji'),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _pickerEmojis.map((e) {
                final sel = _emoji == e;
                return GestureDetector(
                  onTap: () =>
                      setState(() => _emoji = sel ? null : e),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: sel
                            ? AppColors.darkOlive
                            : AppColors.divider,
                        width: sel ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      color: sel
                          ? AppColors.darkOlive
                              .withValues(alpha: 0.1)
                          : null,
                    ),
                    child: Center(
                      child: Text(e,
                          style:
                              const TextStyle(fontSize: 18)),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            _SectionLabel('Color'),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: _pickerColors.map((c) {
                final sel =
                    _color?.toARGB32() == c.toARGB32();
                return GestureDetector(
                  onTap: () =>
                      setState(() => _color = sel ? null : c),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c,
                      border: sel
                          ? Border.all(
                              color: AppColors.textPrimary,
                              width: 2.5)
                          : Border.all(
                              color: Colors.transparent,
                              width: 2.5),
                    ),
                    child: sel
                        ? const Icon(Icons.check,
                            color: Colors.white, size: 16)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            _SectionLabel('Notes'),
            const SizedBox(height: 6),
            TextField(
              controller: _notes,
              maxLines: 2,
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Optional notes…',
                hintStyle: const TextStyle(
                    color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.cardBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                      color: AppColors.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                      color: AppColors.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                      color: AppColors.darkOlive, width: 1.5),
                ),
                contentPadding: const EdgeInsets.all(10),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel',
              style: TextStyle(color: AppColors.textMuted)),
        ),
        ElevatedButton(
          onPressed: () {
            final log = widget.event.log;
            Navigator.pop(
              context,
              CareLog(
                id: log.id,
                plantId: log.plantId,
                type: _type,
                date: log.date,
                notes: _notes.text.trim().isEmpty
                    ? null
                    : _notes.text.trim(),
                emoji: _emoji,
                color: _colorToHex(_color),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.darkOlive,
            foregroundColor: AppColors.tan,
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textMuted,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.darkOlive
              : AppColors.cardBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? AppColors.darkOlive
                : AppColors.divider,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: selected
                ? AppColors.tan
                : AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
