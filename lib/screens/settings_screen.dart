import 'package:flutter/material.dart';
import 'package:happy_plants/main.dart' show themeNotifier;
import 'package:happy_plants/repositories/plant_repository.dart';
import 'package:happy_plants/services/notification_service.dart';
import 'package:happy_plants/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 9, minute: 0);
  ThemeMode _themeMode = ThemeMode.system;

  static const _notificationsEnabledKey = 'notifications_enabled';
  static const _reminderHourKey = 'reminder_hour';
  static const _reminderMinuteKey = 'reminder_minute';
  static const _themeModeKey = 'theme_mode';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    final savedEnabled = prefs.getBool(_notificationsEnabledKey);
    final savedHour = prefs.getInt(_reminderHourKey);
    final savedMinute = prefs.getInt(_reminderMinuteKey);
    final savedTheme = prefs.getString(_themeModeKey);

    if (!mounted) return;
    setState(() {
      _notificationsEnabled = savedEnabled ?? true;
      if (savedHour != null && savedMinute != null) {
        _reminderTime = TimeOfDay(hour: savedHour, minute: savedMinute);
      }
      _themeMode = savedTheme == 'light'
          ? ThemeMode.light
          : savedTheme == 'dark'
              ? ThemeMode.dark
              : ThemeMode.system;
    });
  }

  Future<void> _setNotificationsEnabled(bool value) async {
    setState(() => _notificationsEnabled = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsEnabledKey, value);
    if (value) {
      final plants = await PlantRepository.create().then((r) => r.getAll());
      await NotificationService.rescheduleAll(
        plants,
        notifyHour: _reminderTime.hour,
        notifyMinute: _reminderTime.minute,
      );
    } else {
      await NotificationService.cancelAll();
    }
  }

  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
    );
    if (picked == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_reminderHourKey, picked.hour);
    await prefs.setInt(_reminderMinuteKey, picked.minute);
    if (_notificationsEnabled) {
      final plants = await PlantRepository.create().then((r) => r.getAll());
      await NotificationService.rescheduleAll(
          plants, notifyHour: picked.hour, notifyMinute: picked.minute);
    }
    if (!mounted) return;
    setState(() => _reminderTime = picked);
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    setState(() => _themeMode = mode);
    themeNotifier.value = mode;
    final prefs = await SharedPreferences.getInstance();
    final key = mode == ThemeMode.light
        ? 'light'
        : mode == ThemeMode.dark
            ? 'dark'
            : 'system';
    await prefs.setString(_themeModeKey, key);
  }

  Future<void> _sendTestNotification() async {
    await NotificationService.sendTestNotification();
  }

  @override
  Widget build(BuildContext context) {
    final col = context.col;
    return Scaffold(
      backgroundColor: col.bg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 12, bottom: 24),
              children: [
                const _SectionLabel('Appearance'),
                _AppearanceTile(
                  themeMode: _themeMode,
                  onChanged: _setThemeMode,
                ),
                const SizedBox(height: 8),
                Divider(indent: 20, endIndent: 20, color: col.divider),
                const SizedBox(height: 8),
                const _SectionLabel('Notifications'),
                _Tile(
                  icon: Icons.notifications_outlined,
                  title: 'Watering reminders',
                  subtitle: 'Notify me when a plant needs water',
                  trailing: Switch(
                    value: _notificationsEnabled,
                    onChanged: _setNotificationsEnabled,
                    activeThumbColor: AppColors.darkOlive,
                    activeTrackColor: AppColors.olive,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                _Tile(
                  icon: Icons.schedule_outlined,
                  title: 'Reminder time',
                  subtitle: _reminderTime.format(context),
                  onTap: _pickReminderTime,
                ),
                _Tile(
                  icon: Icons.notifications_active_outlined,
                  title: 'Send test notification',
                  subtitle: 'Check that reminders are working',
                  onTap: _sendTestNotification,
                ),
                const SizedBox(height: 8),
                Divider(indent: 20, endIndent: 20, color: col.divider),
                const SizedBox(height: 8),
                const _SectionLabel('About'),
                const _Tile(
                  icon: Icons.info_outline,
                  title: 'Version',
                  subtitle: '1.0.0',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      color: AppColors.darkOlive,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: 4,
        right: 20,
        bottom: 16,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.tan),
            onPressed: () => Navigator.pop(context),
          ),
          Text(
            'Settings',
            style: Theme.of(context)
                .textTheme
                .headlineLarge
                ?.copyWith(fontSize: 22),
          ),
        ],
      ),
    );
  }
}

// ── Appearance tile ───────────────────────────────────────────────────────────

class _AppearanceTile extends StatelessWidget {
  final ThemeMode themeMode;
  final void Function(ThemeMode) onChanged;

  const _AppearanceTile({required this.themeMode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final col = context.col;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: col.card,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.dark_mode_outlined, color: AppColors.darkOlive, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'Appearance',
                style: TextStyle(
                  color: col.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            _ThemeSegment(
              icon: Icons.brightness_auto,
              label: 'Auto',
              selected: themeMode == ThemeMode.system,
              onTap: () => onChanged(ThemeMode.system),
            ),
            const SizedBox(width: 6),
            _ThemeSegment(
              icon: Icons.light_mode_outlined,
              label: 'Light',
              selected: themeMode == ThemeMode.light,
              onTap: () => onChanged(ThemeMode.light),
            ),
            const SizedBox(width: 6),
            _ThemeSegment(
              icon: Icons.dark_mode_outlined,
              label: 'Dark',
              selected: themeMode == ThemeMode.dark,
              onTap: () => onChanged(ThemeMode.dark),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeSegment extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeSegment({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final col = context.col;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.darkOlive : col.bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColors.darkOlive : col.divider,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color: selected ? AppColors.tan : col.textMuted),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.tan : col.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: context.col.textMuted,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ── Settings tile ─────────────────────────────────────────────────────────────

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _Tile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final col = context.col;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: col.card,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        leading: Icon(icon, color: AppColors.darkOlive, size: 22),
        title: Text(
          title,
          style: TextStyle(
            color: col.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle!,
                style: TextStyle(color: col.textMuted, fontSize: 12),
              )
            : null,
        trailing: trailing ??
            (onTap != null
                ? Icon(Icons.chevron_right, color: col.textMuted, size: 18)
                : null),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
