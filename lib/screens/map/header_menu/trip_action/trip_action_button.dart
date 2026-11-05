import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// アイデアシート「旅行開始ボタン（仮）⇔ 開始すると予定追加（記録）ボタンに変わる」を実装するWidget
class TripActionButton extends StatelessWidget {
  const TripActionButton({
    super.key,
    required this.isTripActive,
    required this.onToggleTrip,
    required this.onOpenRecord,
  });

  final bool isTripActive;
  final VoidCallback onToggleTrip;
  final VoidCallback onOpenRecord;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: isTripActive ? onOpenRecord : onToggleTrip,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isTripActive
                      ? Icons.edit_outlined
                      : Icons.shopping_bag_outlined,
                  size: 24,
                  color: AppTheme.darkGrey,
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.only(bottom: 2),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: AppTheme.darkGrey, width: 1.2),
                    ),
                  ),
                  child: Text(
                    isTripActive ? '記録（予定追加）' : '旅行スタート',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.darkGrey,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        // 旅行開始前でもすぐ「記録」画面を試せるサブボタン / 旅行中は「旅行終了」切替リンク
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: isTripActive ? onToggleTrip : onOpenRecord,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isTripActive
                      ? Icons.stop_circle_outlined
                      : Icons.edit_note_outlined,
                  size: 13,
                  color: AppTheme.primaryGrey,
                ),
                const SizedBox(width: 2),
                Text(
                  isTripActive ? '旅行終了' : 'すぐ記録',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.primaryGrey,
                    decoration: TextDecoration.underline,
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
