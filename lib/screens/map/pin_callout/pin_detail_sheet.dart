import 'package:flutter/material.dart';
import '../../../core/models/memory_pin.dart';
import '../../../core/theme/app_theme.dart';

/// ピン吹き出しの「詳細→」から表示されるボトムシート
class PinDetailSheet extends StatelessWidget {
  const PinDetailSheet({super.key, required this.pin, this.onEdit});

  final MemoryPin pin;
  final ValueChanged<MemoryPin>? onEdit;

  static Future<void> show(
    BuildContext context,
    MemoryPin pin, {
    ValueChanged<MemoryPin>? onEdit,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.pureWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => PinDetailSheet(pin: pin, onEdit: onEdit),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.lightGrey,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceGrey,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.lightGrey),
                  ),
                  child: Text(
                    pin.prefecture,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryGrey,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  pin.shareLocation
                      ? Icons.location_on_outlined
                      : Icons.location_off_outlined,
                  size: 15,
                  color: AppTheme.mediumGrey,
                ),
                const SizedBox(width: 4),
                Text(
                  pin.shareLocation ? '位置共有：ON' : '位置共有：OFF（非公開）',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.mediumGrey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    pin.placeName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkGrey,
                    ),
                  ),
                ),
                if (onEdit != null)
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: AppTheme.primaryGrey),
                    tooltip: 'スポットを編集',
                    onPressed: () {
                      Navigator.of(context).pop();
                      onEdit!(pin);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              pin.address,
              style: const TextStyle(fontSize: 13, color: AppTheme.primaryGrey),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                ...List.generate(5, (index) {
                  return Icon(
                    index < pin.rating
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    size: 22,
                    color: AppTheme.darkGrey,
                  );
                }),
                const SizedBox(width: 12),
                const Icon(
                  Icons.access_time,
                  size: 16,
                  color: AppTheme.mediumGrey,
                ),
                const SizedBox(width: 4),
                Text(
                  '${pin.startTime} 〜 ${pin.endTime}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.primaryGrey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surfaceGrey,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.lightGrey),
              ),
              child: Text(
                pin.comment.isEmpty ? '（口コミ・メモはありません）' : pin.comment,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.darkGrey,
                  height: 1.5,
                ),
              ),
            ),
            if (pin.photoLabels.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                '保存された写真',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryGrey,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 92,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: pin.photoLabels.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    return Container(
                      width: 96,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceGrey,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.lightGrey),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.image_outlined,
                            color: AppTheme.primaryGrey,
                            size: 28,
                          ),
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Text(
                              pin.photoLabels[index],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.darkGrey,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
