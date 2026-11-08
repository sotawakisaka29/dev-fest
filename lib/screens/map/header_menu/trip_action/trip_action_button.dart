import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// 旅行スタート（旅行名入力）⇔ 旅行中は「記録する」＋「旅行終了（まとめ作成）」を行うボタン
class TripActionButton extends StatelessWidget {
  const TripActionButton({
    super.key,
    required this.isTripActive,
    required this.onStartTrip,
    required this.onStopTrip,
    required this.onOpenRecord,
  });

  final bool isTripActive;
  final VoidCallback onStartTrip;
  final VoidCallback onStopTrip;
  final VoidCallback onOpenRecord;

  static const List<Shadow> _labelShadows = [
    Shadow(color: Colors.white, blurRadius: 8),
    Shadow(color: Colors.white, blurRadius: 14),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: isTripActive ? onOpenRecord : onStartTrip,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isTripActive
                      ? Icons.edit_location_alt_outlined
                      : Icons.flag_outlined,
                  size: 29,
                  color: AppTheme.darkGrey,
                  shadows: _labelShadows,
                ),
                const SizedBox(height: 4),
                Text(
                  isTripActive ? '記録する' : '旅行スタート',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.darkGrey,
                    shadows: _labelShadows,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 2),
        InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: isTripActive ? onStopTrip : onOpenRecord,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isTripActive
                      ? Icons.stop_circle_outlined
                      : Icons.edit_note_outlined,
                  size: 15,
                  color: isTripActive
                      ? AppTheme.accentPinRed
                      : AppTheme.primaryGrey,
                  shadows: _labelShadows,
                ),
                const SizedBox(width: 3),
                Text(
                  isTripActive ? '旅行終了' : 'すぐ記録',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isTripActive
                        ? AppTheme.accentPinRed
                        : AppTheme.primaryGrey,
                    decoration: TextDecoration.underline,
                    shadows: _labelShadows,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
