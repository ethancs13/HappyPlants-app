import 'package:flutter/material.dart';
import 'package:happy_plants/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // TODO: wire to NotificationService once feature/notifications is merged into main.
  bool _notificationsEnabled = true;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 9, minute: 0);

  static const _notificationsEnabledKey = 'notifications_enabled';
  static const _reminderHourKey = 'reminder_hour';
  static const _reminderMinuteKey = 'reminder_minute';
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

    if (!mounted) return;

    setState(() {
      _notificationsEnabled = savedEnabled ?? true;

      if (savedHour != null && savedMinute != null) {
        _reminderTime = TimeOfDay(hour: savedHour, minute: savedMinute);
      }
    });
  }

  Future<void> _setNotificationsEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsEnabledKey, value);

    if (!mounted) return;
    setState(() => _notificationsEnabled = value);
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

    if (!mounted) return;
    setState(() => _reminderTime = picked);
  }

  void _sendTestNotification() {
    // TODO: replace with NotificationService.sendTest() after merge
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Notifications coming soon — wire up after merge.'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 12, bottom: 24),
              children: [
                _SectionLabel('Notifications'),
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
                const Divider(
                  indent: 20,
                  endIndent: 20,
                  color: AppColors.divider,
                ),
                const SizedBox(height: 8),
                _SectionLabel('About'),
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
            style: Theme.of(
              context,
            ).textTheme.headlineLarge?.copyWith(fontSize: 22),
          ),
        ],
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
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textMuted,
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        leading: Icon(icon, color: AppColors.darkOlive, size: 22),
        title: Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle!,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              )
            : null,
        trailing:
            trailing ??
            (onTap != null
                ? const Icon(
                    Icons.chevron_right,
                    color: AppColors.textMuted,
                    size: 18,
                  )
                : null),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
