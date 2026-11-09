import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_map_app/core/models/app_photo.dart';
import 'package:my_map_app/core/services/storage_service.dart';

void main() {
  group('StorageService 単体テスト（フォールバック・URL判定）', () {
    final storageService = StorageService.instance;

    test('StorageService.instance はシングルトンであること', () {
      expect(storageService, isNotNull);
      expect(storageService, same(StorageService.instance));
    });

    test('実在しないローカルファイルの場合は uploadFile が null を返し例外でクラッシュしないこと', () async {
      final nonExistentFile = File('/non_existent_path_12345/dummy.jpg');
      final result = await storageService.uploadFile(
        groupId: 'test_group',
        photoId: 'test_photo',
        file: nonExistentFile,
      );
      expect(result, isNull);
    });

    test('既に Firebase Storage 永続URLを持つ写真はアップロード処理をスキップしてそのまま保持されること', () async {
      final existingStoragePhoto = AppPhoto(
        id: 'photo_storage_1',
        label: '既にアップロード済みの写真',
        url:
            'https://firebasestorage.googleapis.com/v0/b/memory-map-a7406.firebasestorage.app/o/groups%2Ftest%2Fphotos%2Fphoto_1.jpg?alt=media',
        localPath: '/tmp/test.jpg',
        isFromGooglePhotos: false,
      );

      final photos = [existingStoragePhoto];
      final processed = await storageService.uploadPhotos(
        groupId: 'test_group',
        photos: photos,
      );

      expect(processed.length, 1);
      expect(processed.first.id, existingStoragePhoto.id);
      expect(processed.first.url, existingStoragePhoto.url);
    });

    test('Firebase 未初期化またはファイル未存在の写真は元の写真オブジェクトを安全に維持して返却すること', () async {
      final fallbackPhoto = AppPhoto(
        id: 'fallback_1',
        label: 'オフライン写真',
        localPath: '/local/test.jpg',
        isFromGooglePhotos: false,
      );

      final processed = await storageService.uploadPhotos(
        groupId: 'test_group',
        photos: [fallbackPhoto],
      );

      expect(processed.length, 1);
      expect(processed.first.id, fallbackPhoto.id);
      expect(processed.first.label, fallbackPhoto.label);
      expect(processed.first.localPath, fallbackPhoto.localPath);
    });
  });
}
