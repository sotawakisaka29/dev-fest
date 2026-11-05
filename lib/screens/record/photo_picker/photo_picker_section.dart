import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// アイデアシート「写真 追加や削除を可能に」セクション
///
/// 各写真カードの右上に「×」削除ボタンを配置し、新規追加も可能にする。
class PhotoPickerSection extends StatelessWidget {
  const PhotoPickerSection({
    super.key,
    required this.photos,
    required this.onAddPhoto,
    required this.onRemovePhotoAt,
  });

  final List<String> photos;
  final VoidCallback onAddPhoto;
  final ValueChanged<int> onRemovePhotoAt;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '写真',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.darkGrey,
              ),
            ),
            TextButton.icon(
              onPressed: onAddPhoto,
              icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
              label: const Text('写真を追加'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 112,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: photos.length + 1,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              if (index == photos.length) {
                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: onAddPhoto,
                  child: Container(
                    width: 96,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceGrey,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.lightGrey),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_rounded,
                          size: 28,
                          color: AppTheme.primaryGrey,
                        ),
                        SizedBox(height: 4),
                        Text(
                          '追加',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.primaryGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final label = photos[index];
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 96,
                    height: 112,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceGrey,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.mediumGrey),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.photo_outlined,
                          size: 28,
                          color: AppTheme.darkGrey,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          label,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.darkGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // アイデアシートの写真枠右上の「×」削除ボタン
                  Positioned(
                    right: 4,
                    top: 4,
                    child: InkWell(
                      onTap: () => onRemovePhotoAt(index),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: AppTheme.pureWhite,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.darkGrey),
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 14,
                          color: AppTheme.darkGrey,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
