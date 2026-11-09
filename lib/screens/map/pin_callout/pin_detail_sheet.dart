import 'package:flutter/material.dart';
import '../../../core/models/memory_pin.dart';
import '../../../core/services/external_map_launcher.dart';
import '../../../core/theme/app_theme.dart';

/// ピン吹き出しの「詳細→」から表示されるボトムシート
class PinDetailSheet extends StatelessWidget {
  const PinDetailSheet({
    super.key,
    required this.pin,
    this.onDeletePin,
    this.onEdit,
  });

  final MemoryPin pin;
  final ValueChanged<MemoryPin>? onDeletePin;
  final ValueChanged<MemoryPin>? onEdit;

  static Future<void> show(
    BuildContext context,
    MemoryPin pin, {
    ValueChanged<MemoryPin>? onDeletePin,
    ValueChanged<MemoryPin>? onEdit,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.pureWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) =>
          PinDetailSheet(pin: pin, onDeletePin: onDeletePin, onEdit: onEdit),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('レビューを削除'),
          content: Text('「${pin.placeName}」のレビュー・ピンを削除してもよろしいですか？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: AppTheme.pureWhite,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('削除する'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && context.mounted) {
      Navigator.of(context).pop();
      onDeletePin?.call(pin);
    }
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
              crossAxisAlignment: CrossAxisAlignment.center,
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
                const SizedBox(width: 8),
                if (onDeletePin != null) ...[
                  InkWell(
                    key: const Key('delete_pin_button'),
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _confirmDelete(context),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Tooltip(
                        message: 'このレビューを削除',
                        child: Icon(
                          Icons.delete_outline,
                          size: 20,
                          color: AppTheme.darkGrey,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    ExternalMapLauncher.openGoogleMapsForAddress(
                      context,
                      address: pin.address,
                      placeName: pin.placeName,
                      latitude: pin.latitude,
                      longitude: pin.longitude,
                    );
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Tooltip(
                      message: 'Google Mapsで開く',
                      child: Icon(
                        Icons.north_east,
                        size: 20,
                        color: AppTheme.darkGrey,
                      ),
                    ),
                  ),
                ),
                if (onEdit != null)
                  IconButton(
                    icon: const Icon(
                      Icons.edit_outlined,
                      color: AppTheme.primaryGrey,
                    ),
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
                if (pin.rating != null && pin.rating! > 0) ...[
                  ...List.generate(5, (index) {
                    return Icon(
                      index < pin.rating!
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      size: 22,
                      color: AppTheme.darkGrey,
                    );
                  }),
                  const SizedBox(width: 12),
                ],
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
