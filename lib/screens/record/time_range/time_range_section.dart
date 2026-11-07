import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// 記録画面の日時（日付＋時間帯）指定セクション
///
/// Googleフォトと連携し、ここで選択された日時に応じて自動で写真を取得する。
class TimeRangeSection extends StatelessWidget {
  const TimeRangeSection({
    super.key,
    required this.selectedDate,
    required this.startTime,
    required this.endTime,
    required this.onDateChanged,
    required this.onStartTimeChanged,
    required this.onEndTimeChanged,
    this.isLoadingPhotos = false,
  });

  final DateTime selectedDate;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final ValueChanged<DateTime> onDateChanged;
  final ValueChanged<TimeOfDay> onStartTimeChanged;
  final ValueChanged<TimeOfDay> onEndTimeChanged;
  final bool isLoadingPhotos;

  String _formatTime(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatDate(DateTime date) {
    const weekdays = ['月', '火', '水', '木', '金', '土', '日'];
    final weekday = weekdays[date.weekday - 1];
    return '${date.year}年${date.month}月${date.day}日 ($weekday)';
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: '撮影日を選択',
      confirmText: '決定',
      cancelText: 'キャンセル',
    );
    if (picked != null) {
      onDateChanged(picked);
    }
  }

  Future<void> _pickTime(
    BuildContext context,
    TimeOfDay initial,
    ValueChanged<TimeOfDay> onPicked,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: '撮影時間を選択',
      confirmText: '決定',
      cancelText: 'キャンセル',
    );
    if (picked != null) {
      onPicked(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 日付選択行
        Row(
          children: [
            const Text(
              '日付',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.darkGrey,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _pickDate(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceGrey,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.lightGrey),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 16,
                            color: AppTheme.primaryGrey,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatDate(selectedDate),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.darkGrey,
                            ),
                          ),
                        ],
                      ),
                      const Icon(
                        Icons.arrow_drop_down,
                        color: AppTheme.mediumGrey,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // 時間帯選択行
        Row(
          children: [
            const Text(
              '時間',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.darkGrey,
              ),
            ),
            const SizedBox(width: 16),
            _TimeButton(
              label: _formatTime(startTime),
              onTap: () => _pickTime(context, startTime, onStartTimeChanged),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                '〜',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkGrey,
                ),
              ),
            ),
            _TimeButton(
              label: _formatTime(endTime),
              onTap: () => _pickTime(context, endTime, onEndTimeChanged),
            ),
            if (isLoadingPhotos) ...[
              const SizedBox(width: 12),
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.darkGrey,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.surfaceGrey,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.lightGrey),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppTheme.darkGrey,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }
}
