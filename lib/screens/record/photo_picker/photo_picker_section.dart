import 'package:flutter/material.dart';
import '../../../../core/models/app_photo.dart';
import '../../../../core/theme/app_theme.dart';

/// 写真選択・管理セクション（端末アルバム・Googleフォト選択の並行対応）
class PhotoPickerSection extends StatelessWidget {
  const PhotoPickerSection({
    super.key,
    required this.photos,
    required this.onAddFromGallery,
    required this.onPickFromGooglePhotos,
    required this.onRemovePhotoAt,
    this.isLoading = false,
    this.loadingMessage = 'Googleフォトを起動中...',
  });

  final List<AppPhoto> photos;
  final VoidCallback onAddFromGallery;
  final VoidCallback onPickFromGooglePhotos;
  final ValueChanged<int> onRemovePhotoAt;
  final bool isLoading;
  final String loadingMessage;

  Widget _buildPhotoImage(AppPhoto photo) {
    // 1. ローカル写真実体が存在する場合（端末アルバムまたはGoogleフォト永続キャッシュ）
    final localFile = photo.localFile;
    if (localFile != null && localFile.existsSync()) {
      return Image.file(
        localFile,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) {
          if (photo.url != null && photo.url!.isNotEmpty) {
            return Image.network(
              photo.url!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _buildBrokenPlaceholder(),
            );
          }
          return _buildBrokenPlaceholder();
        },
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
        errorBuilder: (_, _, _) => _buildBrokenPlaceholder(),
      );
    }

    // 3. どちらもない場合のプレースホルダー
    return Container(
      color: AppTheme.lightGrey,
      child: const Center(
        child: Icon(
          Icons.photo_outlined,
          size: 28,
          color: AppTheme.primaryGrey,
        ),
      ),
    );
  }

  Widget _buildBrokenPlaceholder() {
    return Container(
      color: AppTheme.surfaceGrey,
      child: const Center(
        child: Icon(Icons.broken_image_outlined, color: AppTheme.mediumGrey),
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
          ],
        ),
        const SizedBox(height: 12),

        // 写真追加アクションボタン群（端末アルバム + Googleフォト並行）
        Row(
          children: [
            // 端末アルバムから追加ボタン
            Expanded(
              child: OutlinedButton.icon(
                onPressed: isLoading ? null : onAddFromGallery,
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: const Text(
                  'アルバムから選択',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.darkGrey,
                  side: const BorderSide(color: AppTheme.darkGrey),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Googleフォトから選択ボタン
            Expanded(
              child: ElevatedButton.icon(
                onPressed: isLoading ? null : onPickFromGooglePhotos,
                icon: const Icon(Icons.add_photo_alternate, size: 18),
                label: const Text(
                  'Googleフォトから選択',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.darkGrey,
                  foregroundColor: AppTheme.pureWhite,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        if (isLoading)
          Container(
            height: 100,
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: AppTheme.surfaceGrey,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.lightGrey),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppTheme.darkGrey,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    loadingMessage,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.primaryGrey,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // 写真一覧グリッド（選択された写真のみ表示）
        if (photos.isEmpty && !isLoading)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              color: AppTheme.surfaceGrey,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.lightGrey),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.image_not_supported_outlined,
                  size: 36,
                  color: AppTheme.mediumGrey,
                ),
                SizedBox(height: 8),
                Text(
                  '写真がまだ追加されていません',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryGrey,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'アルバムまたはGoogleフォトから写真を追加できます',
                  style: TextStyle(fontSize: 10, color: AppTheme.mediumGrey),
                ),
              ],
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: photos.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.82,
            ),
            itemBuilder: (context, index) {
              final photo = photos[index];

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
                          Expanded(child: _buildPhotoImage(photo)),
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
                      onTap: () => onRemovePhotoAt(index),
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
