import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _isReminderEnabled = true;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 8, minute: 0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18, color: AppColors.text),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('알림 설정', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold, fontSize: 17)),
      ),
      body: Column(
        children: [
          _buildToggleItem('매일 사락 알림', '지정한 시간에 사락할 시간을 알려드려요.', _isReminderEnabled, (val) {
            setState(() => _isReminderEnabled = val);
          }),
          if (_isReminderEnabled) ...[
            const Divider(height: 1, indent: 20, endIndent: 20, color: AppColors.border),
            _buildTimePickerItem('사락 시간', _reminderTime, () async {
              final picked = await showTimePicker(context: context, initialTime: _reminderTime);
              if (picked != null) setState(() => _reminderTime = picked);
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildToggleItem(String title, String subtitle, bool value, Function(bool) onChanged) {
    return Container(
      padding: const EdgeInsets.all(20),
      color: AppColors.bgCard,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.text)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Switch.adaptive(value: value, onChanged: onChanged, activeColor: AppColors.primary),
        ],
      ),
    );
  }

  Widget _buildTimePickerItem(String title, TimeOfDay time, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        color: AppColors.bgCard,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.text)),
            Text(time.format(context), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primary)),
          ],
        ),
      ),
    );
  }
}