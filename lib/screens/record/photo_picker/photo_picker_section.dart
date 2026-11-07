import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/models/app_photo.dart';
import '../../../../core/theme/app_theme.dart';

/// 写真選択・管理セクション（Googleフォト本番連携＆端末アルバム選択対応）
class PhotoPickerSection extends StatelessWidget {
  const PhotoPickerSection({
    super.key,
    required this.photos,
    required this.onAddPhoto,
    required this.onRemovePhotoAt,
    this.isLoading = false,
    this.onRefreshFromGooglePhotos,
  });

  final List<AppPhoto> photos;
  final VoidCallback onAddPhoto;
  final ValueChanged<int> onRemovePhotoAt;
  final bool isLoading;
  final VoidCallback? onRefreshFromGooglePhotos;

  Widget _buildPhotoImage(AppPhoto photo) {
    // 1. 端末アルバムから選択されたローカル写真の場合
    if (photo.localPath != null && photo.localPath!.isNotEmpty) {
      final file = File(photo.localPath!);
      return Image.file(
        file,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          color: AppTheme.lightGrey,
          child: const Center(
            child: Icon(Icons.broken_image_outlined, color: AppTheme.mediumGrey),
          ),
        ),
      );
    }

    // 2. GoogleフォトなどのリモートURL写真の場合
    if (photo.url != null && photo.url!.isNotEmpty) {
      return Image.network(
        photo.url!,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.mediumGrey,
              ),
            ),
          );
        },
        errorBuilder: (_, _, _) => Container(
          color: AppTheme.surfaceGrey,
          child: const Center(
            child: Icon(Icons.broken_image_outlined, color: AppTheme.mediumGrey),
          ),
        ),
      );
    }

    // 3. どちらもない場合のプレースホルダー
    return Container(
      color: AppTheme.lightGrey,
      child: const Center(
        child: Icon(Icons.photo_outlined, size: 28, color: AppTheme.primaryGrey),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ヘッダー行
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text(
                  '写真',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkGrey,
                  ),
                ),
                const SizedBox(width: 8),
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
                  child: Row(
                    children: [
                      const Icon(
                        Icons.photo_library_outlined,
                        size: 13,
                        color: AppTheme.primaryGrey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '合計 ${photos.length} 枚',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryGrey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Row(
              children: [
                if (onRefreshFromGooglePhotos != null)
                  TextButton.icon(
                    onPressed: isLoading ? null : onRefreshFromGooglePhotos,
                    icon: const Icon(Icons.sync, size: 16),
                    label: const Text('Googleフォト再取得', style: TextStyle(fontSize: 12)),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (isLoading)
          Container(
            height: 130,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppTheme.surfaceGrey,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.lightGrey),
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppTheme.darkGrey,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Googleフォトから写真を取得中...',
                    style: TextStyle(fontSize: 12, color: AppTheme.primaryGrey),
                  ),
                ],
              ),
            ),
          )
        else
          // 縦スクロール対応の3列グリッドレイアウト（先頭に手動追加カード）
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: photos.length + 1,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.82,
            ),
            itemBuilder: (context, index) {
              // 1番目（先頭）：手動追加ボタンカード（端末アルバムを開く）
              if (index == 0) {
                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: onAddPhoto,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceGrey,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.darkGrey,
                        width: 1.5,
                      ),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_rounded,
                          size: 32,
                          color: AppTheme.darkGrey,
                        ),
                        SizedBox(height: 6),
                        Text(
                          '写真を選択',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.darkGrey,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'アルバムから追加',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppTheme.primaryGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // 2番目以降：実際の写真カード（index - 1）
              final photoIndex = index - 1;
              final photo = photos[photoIndex];

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceGrey,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.lightGrey),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 写真プレビュー画像（ローカル or リモート）
                          Expanded(
                            child: _buildPhotoImage(photo),
                          ),
                          // 下部キャプション＆撮影時間
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 4,
                            ),
                            color: AppTheme.pureWhite,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      photo.isFromGooglePhotos
                                          ? Icons.cloud_done_rounded
                                          : Icons.phone_android_rounded,
                                      size: 11,
                                      color: photo.isFromGooglePhotos
                                          ? Colors.blueAccent
                                          : AppTheme.darkGrey,
                                    ),
                                    const SizedBox(width: 3),
                                    Expanded(
                                      child: Text(
                                        photo.label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.darkGrey,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (photo.takenAt != null)
                                  Text(
                                    '${photo.takenAt!.hour.toString().padLeft(2, '0')}:${photo.takenAt!.minute.toString().padLeft(2, '0')}',
                                    style: const TextStyle(
                                      fontSize: 9,
                                      color: AppTheme.mediumGrey,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 右上の「×」手動削除ボタン
                  Positioned(
                    right: -4,
                    top: -4,
                    child: InkWell(
                      onTap: () => onRemovePhotoAt(photoIndex),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: AppTheme.pureWhite,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppTheme.darkGrey,
                            width: 1.2,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 3,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 13,
                          color: AppTheme.darkGrey,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
      ],
    );
  }
}
