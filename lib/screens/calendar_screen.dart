import 'dart:io';

import 'package:flutter/material.dart';
import 'package:happy_plants/models/care_log.dart';
import 'package:happy_plants/models/plant.dart';
import 'package:happy_plants/models/plant_photo.dart';
import 'package:happy_plants/repositories/care_log_repository.dart';
import 'package:happy_plants/repositories/plant_photo_repository.dart';
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

// ── Data models ───────────────────────────────────────────────────────────────

class _CalEvent {
  final CareLog log;
  final Plant plant;
  const _CalEvent({required this.log, required this.plant});
}

class _ScheduledCalEvent {
  final Plant plant;
  final DateTime date;
  const _ScheduledCalEvent({required this.plant, required this.date});
}

class _PhotoEvent {
  final PlantPhoto photo;
  final Plant plant;
  const _PhotoEvent({required this.photo, required this.plant});
}

// ── CalendarScreen ────────────────────────────────────────────────────────────

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => CalendarScreenState();
}

class CalendarScreenState extends State<CalendarScreen> {
  late DateTime _month;
  List<_CalEvent> _events = [];
  List<_ScheduledCalEvent> _scheduledEvents = [];
  List<_PhotoEvent> _photoEvents = [];
  bool _loading = true;    // full-screen spinner (first load)
  bool _refreshing = false; // header spinner (background refresh)
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _load();
  }

  /// Called externally (tab activated) — keeps existing data visible while refreshing.
  void reload() => _load(background: true);

  Future<void> _load({bool background = false}) async {
    if (background && _events.isNotEmpty) {
      setState(() => _refreshing = true);
    } else {
      setState(() { _loading = true; _refreshing = false; });
    }

    final plantRepo = await PlantRepository.create();
    final logRepo = await CareLogRepository.create();
    final photoRepo = await PlantPhotoRepository.create();
    final plants = await plantRepo.getAll();
    final logs = await logRepo.getAll();
    final photos = await photoRepo.getAll();

    final plantMap = {for (final p in plants) p.id!: p};

    final events = <_CalEvent>[];
    for (final log in logs) {
      final plant = plantMap[log.plantId];
      if (plant != null) events.add(_CalEvent(log: log, plant: plant));
    }

    final photoEvents = <_PhotoEvent>[];
    for (final photo in photos) {
      final plant = plantMap[photo.plantId];
      if (plant != null) photoEvents.add(_PhotoEvent(photo: photo, plant: plant));
    }

    // Compute projected scheduled waterings for opted-in plants
    final today = DateTime.now();
    final scheduledEvents = <_ScheduledCalEvent>[];
    for (final plant in plants) {
      if (!plant.showScheduleOnCalendar) continue;
      final last = plant.lastWateredDate;
      if (last == null) continue;
      final interval = plant.wateringIntervalDays;
      var d = DateTime(last.year, last.month, last.day)
          .add(Duration(days: interval));
      final limit = today.add(const Duration(days: 90));
      while (!d.isAfter(limit)) {
        if (!d.isBefore(DateTime(today.year, today.month, today.day))) {
          scheduledEvents.add(_ScheduledCalEvent(plant: plant, date: d));
        }
        d = d.add(Duration(days: interval));
      }
    }

    if (mounted) {
      setState(() {
        _events = events;
        _photoEvents = photoEvents;
        _scheduledEvents = scheduledEvents;
        _loading = false;
        _refreshing = false;
      });
    }
  }

  Map<String, List<_ScheduledCalEvent>> get _scheduledMap {
    final m = <String, List<_ScheduledCalEvent>>{};
    for (final e in _scheduledEvents) {
      final k = _dateKey(e.date);
      (m[k] ??= []).add(e);
    }
    return m;
  }

  Map<String, List<_PhotoEvent>> get _photoMap {
    final m = <String, List<_PhotoEvent>>{};
    for (final e in _photoEvents) {
      final k = _dateKey(e.photo.dateTaken);
      (m[k] ??= []).add(e);
    }
    return m;
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
        else ...[
          // Grid takes its natural height (no Expanded)
          _buildMonthGrid(),
          const Divider(height: 1, color: AppColors.divider),
          // Panel fills remaining space
          Expanded(child: _buildDayPanel()),
        ],
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
          if (_loading || _refreshing)
            const SizedBox(
              width: 40,
              height: 40,
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: AppColors.tan,
                    strokeWidth: 2,
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh, color: AppColors.tan),
              onPressed: _load,
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
    final schedMap = _scheduledMap;
    final photoMap = _photoMap;

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
                final scheduled = schedMap[key] ?? [];
                final photos = photoMap[key] ?? [];

                return Expanded(
                  child: _DayCell(
                    dayNum: dayNum,
                    isToday: isToday,
                    events: events,
                    scheduledEvents: scheduled,
                    photoEvents: photos,
                    isSelected: _selectedDate != null &&
                        _dateKey(_selectedDate!) == key,
                    onTap: () => _selectDay(date),
                  ),
                );
              }),
            ),
          );
        }),
      ),
    );
  }

  void _selectDay(DateTime date) =>
      setState(() => _selectedDate = date);

  Widget _buildDayPanel() {
    final sel = _selectedDate;
    if (sel == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.touch_app_outlined,
                size: 32, color: AppColors.divider),
            SizedBox(height: 8),
            Text(
              'Tap a day to see events',
              style: TextStyle(color: AppColors.textMuted, fontSize: 14),
            ),
          ],
        ),
      );
    }
    final key = _dateKey(sel);
    final events = _eventMap[key] ?? [];
    final scheduled = _scheduledMap[key] ?? [];
    final photos = _photoMap[key] ?? [];
    return _DayPanel(
      key: ValueKey(key),
      date: sel,
      events: events,
      scheduledEvents: scheduled,
      photoEvents: photos,
      onChanged: _load,
    );
  }
}

// ── Day Cell ──────────────────────────────────────────────────────────────────

class _DayCell extends StatelessWidget {
  final int dayNum;
  final bool isToday;
  final bool isSelected;
  final List<_CalEvent> events;
  final List<_ScheduledCalEvent> scheduledEvents;
  final List<_PhotoEvent> photoEvents;
  final VoidCallback onTap;

  const _DayCell({
    required this.dayNum,
    required this.isToday,
    required this.isSelected,
    required this.events,
    required this.scheduledEvents,
    required this.photoEvents,
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

  static const _schedGreen = Color(0xFF5B8A5F);

  @override
  Widget build(BuildContext context) {
    final visibleEvents =
        events.length > 2 ? events.sublist(0, 2) : events;
    final eventOverflow = events.length > 2 ? events.length - 2 : 0;
    final visibleSched =
        scheduledEvents.length > 2 ? scheduledEvents.sublist(0, 1) : scheduledEvents;
    final schedOverflow =
        scheduledEvents.length > 2 ? scheduledEvents.length - 1 : 0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 70),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.darkOlive.withValues(alpha: 0.07)
              : AppColors.cream,
          border: Border(
            right: const BorderSide(color: AppColors.divider, width: 0.5),
            bottom: const BorderSide(color: AppColors.divider, width: 0.5),
            top: isSelected
                ? const BorderSide(color: AppColors.darkOlive, width: 1.5)
                : BorderSide.none,
          ),
        ),
        padding: const EdgeInsets.all(4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Day number
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
                    fontWeight:
                        isToday ? FontWeight.w700 : FontWeight.w400,
                    color: isToday ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            // Actual logged events
            ...List.generate(visibleEvents.length, (i) {
              final e = visibleEvents[i];
              final color = _eventColor(e);
              final label = e.log.emoji ??
                  (e.log.type == CareType.watering ? '💧' : '🌱');
              return _chip(label, e.plant.name, color,
                  dashed: false);
            }),
            if (eventOverflow > 0)
              _overflowChip('+$eventOverflow'),
            // Scheduled (projected) events — dashed green border
            ...List.generate(visibleSched.length, (i) {
              final s = visibleSched[i];
              return _chip('💧', s.plant.name, _schedGreen,
                  dashed: true);
            }),
            if (schedOverflow > 0)
              _overflowChip('+$schedOverflow sched'),
            // Photo thumbnails
            if (photoEvents.isNotEmpty) _photoStrip(),
          ],
        ),
      ),
    );
  }

  Widget _photoStrip() {
    final visible = photoEvents.length > 3 ? photoEvents.sublist(0, 3) : photoEvents;
    final overflow = photoEvents.length > 3 ? photoEvents.length - 3 : 0;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ...visible.map((e) => Container(
                width: 14,
                height: 14,
                margin: const EdgeInsets.only(right: 1),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: const Color(0xFFCDD8E3),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: Image.file(
                    File(e.photo.filePath),
                    fit: BoxFit.cover,
                    errorBuilder: (_, e, s) => const Icon(
                      Icons.photo_camera,
                      size: 8,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              )),
          if (overflow > 0)
            Text(
              '+$overflow',
              style: const TextStyle(
                fontSize: 7,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }

  Widget _chip(String emoji, String name, Color color,
      {required bool dashed}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      decoration: BoxDecoration(
        color: dashed ? Colors.transparent : color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(3),
        border: dashed
            ? Border.all(
                color: color.withValues(alpha: 0.6),
                width: 0.8,
                strokeAlign: BorderSide.strokeAlignInside,
              )
            : Border.all(
                color: color.withValues(alpha: 0.5), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 9)),
          const SizedBox(width: 2),
          Flexible(
            child: Text(
              name,
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
  }

  Widget _overflowChip(String label) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.divider,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 8, color: AppColors.textMuted),
      ),
    );
  }
}

// ── Day Sheet ─────────────────────────────────────────────────────────────────

class _DayPanel extends StatefulWidget {
  final DateTime date;
  final List<_CalEvent> events;
  final List<_ScheduledCalEvent> scheduledEvents;
  final List<_PhotoEvent> photoEvents;
  final VoidCallback onChanged;

  const _DayPanel({
    super.key,
    required this.date,
    required this.events,
    required this.scheduledEvents,
    required this.photoEvents,
    required this.onChanged,
  });

  @override
  State<_DayPanel> createState() => _DayPanelState();
}

class _DayPanelState extends State<_DayPanel> {
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
    widget.onChanged();
  }

  Future<void> _reschedule(_ScheduledCalEvent s) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: s.date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Move next watering to…',
    );
    if (picked == null || !mounted) return;
    final anchor = DateTime(picked.year, picked.month, picked.day)
        .subtract(Duration(days: s.plant.wateringIntervalDays));
    final updated = s.plant.copyWith(lastWateredDate: anchor);
    final repo = await PlantRepository.create();
    await repo.update(updated);
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
    widget.onChanged();
  }

  void _viewPhotos(List<_PhotoEvent> photos, int initialIndex) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: _CalPhotoViewer(photos: photos, initialIndex: initialIndex),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final events = widget.events;
    final scheduled = widget.scheduledEvents;
    final photos = widget.photoEvents;
    final hasAny = events.isNotEmpty || scheduled.isNotEmpty || photos.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            _formatDate(widget.date),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        const Divider(height: 1, color: AppColors.divider),
        if (!hasAny)
          const Expanded(
            child: Center(
              child: Text(
                'No events on this day',
                style: TextStyle(color: AppColors.textMuted, fontSize: 14),
              ),
            ),
          )
        else
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 4, bottom: 16),
              children: [
                ...events.map((e) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _EventTile(
                          event: e,
                          color: _eventColor(e),
                          onEdit: () => _edit(e),
                          onDelete: () => _delete(e),
                        ),
                        const Divider(height: 1, color: AppColors.divider),
                      ],
                    )),
                if (scheduled.isNotEmpty) ...[
                  if (events.isNotEmpty) const SizedBox(height: 4),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 6, 16, 4),
                    child: Text(
                      'SCHEDULED',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  ...scheduled.map((s) => _ScheduledEventTile(
                        scheduled: s,
                        onReschedule: () => _reschedule(s),
                      )),
                ],
                if (photos.isNotEmpty) ...[
                  if (events.isNotEmpty || scheduled.isNotEmpty)
                    const SizedBox(height: 4),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 6, 16, 4),
                    child: Text(
                      'PHOTOS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(photos.length, (i) {
                        final e = photos[i];
                        return GestureDetector(
                          onTap: () => _viewPhotos(photos, i),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  File(e.photo.filePath),
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, err, s) => Container(
                                    width: 80,
                                    height: 80,
                                    color: AppColors.divider,
                                    child: const Icon(Icons.broken_image,
                                        size: 28, color: AppColors.textMuted),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 3),
                              SizedBox(
                                width: 80,
                                child: Text(
                                  e.plant.name,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textMuted,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
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

// ── Scheduled Event Tile ──────────────────────────────────────────────────────

class _ScheduledEventTile extends StatelessWidget {
  final _ScheduledCalEvent scheduled;
  final VoidCallback onReschedule;

  const _ScheduledEventTile({
    required this.scheduled,
    required this.onReschedule,
  });

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF5B8A5F);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: const Border(
          left: BorderSide(color: color, width: 3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Row(
          children: [
            const Text('💧', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    scheduled.plant.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Text(
                    'Scheduled watering',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              icon: const Icon(Icons.calendar_month, size: 14),
              label: const Text('Reschedule'),
              style: TextButton.styleFrom(
                foregroundColor: color,
                textStyle: const TextStyle(fontSize: 12),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              onPressed: onReschedule,
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

// ── Photo Viewer ──────────────────────────────────────────────────────────────

class _CalPhotoViewer extends StatefulWidget {
  final List<_PhotoEvent> photos;
  final int initialIndex;
  const _CalPhotoViewer({required this.photos, required this.initialIndex});

  @override
  State<_CalPhotoViewer> createState() => _CalPhotoViewerState();
}

class _CalPhotoViewerState extends State<_CalPhotoViewer> {
  late final PageController _page;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _page = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        PageView.builder(
          controller: _page,
          itemCount: widget.photos.length,
          onPageChanged: (i) => setState(() => _index = i),
          itemBuilder: (_, i) => InteractiveViewer(
            child: Image.file(
              File(widget.photos[i].photo.filePath),
              fit: BoxFit.contain,
              errorBuilder: (_, e, s) => const Center(
                child: Icon(Icons.broken_image, size: 64, color: Colors.white54),
              ),
            ),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        if (widget.photos.length > 1)
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.photos[_index].plant.name,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                Text(
                  '${_index + 1} / ${widget.photos.length}',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          )
        else
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                widget.photos[0].plant.name,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ),
      ],
    );
  }
}

