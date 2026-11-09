import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_map_app/core/models/app_photo.dart';
import 'package:my_map_app/core/services/photo_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PhotoStorageService & AppPhoto 永続パス解決テスト', () {
    final photoStorage = PhotoStorageService.instance;

    test('PhotoStorageService.instance はシングルトンであること', () {
      expect(photoStorage, isNotNull);
      expect(photoStorage, same(PhotoStorageService.instance));
    });

    test('写真バイトデータを正常に保存し、実体ファイルが生成されること', () async {
      final dummyBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final savedPath = await photoStorage.savePhotoBytes(
        photoId: 'test_photo_123',
        bytes: dummyBytes,
      );

      final file = File(savedPath);
      expect(file.existsSync(), isTrue);
      expect(await file.readAsBytes(), equals(dummyBytes));

      // クリーンアップ
      if (file.existsSync()) {
        file.deleteSync();
      }
    });

    test('resolveLocalFile が直接パスおよび動的ファイル名解決で正しく実体ファイルを返すこと', () async {
      final dummyBytes = Uint8List.fromList([10, 20, 30]);
      final savedPath = await photoStorage.savePhotoBytes(
        photoId: 'resolvable_photo',
        bytes: dummyBytes,
      );
      final fileName = savedPath.split(RegExp(r'[/\\]')).last;

      // 1. 直接フルパスでの解決
      final resolvedDirect = photoStorage.resolveLocalFile(savedPath);
      expect(resolvedDirect, isNotNull);
      expect(resolvedDirect!.existsSync(), isTrue);

      // 2. iOSの再起動等で旧UUIDパスになった場合（親ディレクトリが偽のパス）のフォールバック解決
      final simulatedOldIosPath =
          '/var/mobile/Containers/Data/Application/OLD-UUID-1234/Documents/app_photos/$fileName';
      final resolvedFromOldPath = photoStorage.resolveLocalFile(
        simulatedOldIosPath,
      );
      expect(resolvedFromOldPath, isNotNull);
      expect(resolvedFromOldPath!.existsSync(), isTrue);
      expect(resolvedFromOldPath.path, equals(savedPath));

      // 3. AppPhoto 経由の localFile / hasLocalFile 解決
      final photoWithOldPath = AppPhoto(
        id: 'resolvable_photo',
        label: 'テスト写真',
        localPath: simulatedOldIosPath,
      );
      expect(photoWithOldPath.hasLocalFile, isTrue);
      expect(photoWithOldPath.localFile, isNotNull);
      expect(photoWithOldPath.localFile!.path, equals(savedPath));

      // クリーンアップ
      final file = File(savedPath);
      if (file.existsSync()) {
        file.deleteSync();
      }
    });

    test('存在しないファイルパスの場合は安全に null / false を返すこと', () {
      final nonExistentPath = '/invalid/path/completely_missing_photo_9999.jpg';
      final resolved = photoStorage.resolveLocalFile(nonExistentPath);
      expect(resolved, isNull);

      final photo = AppPhoto(
        id: 'missing_photo',
        label: '存在しない写真',
        localPath: nonExistentPath,
      );
      expect(photo.hasLocalFile, isFalse);
      expect(photo.localFile, isNull);
    });

    test('localPath が null または空文字の場合は安全に null / false を返すこと', () {
      expect(photoStorage.resolveLocalFile(null), isNull);
      expect(photoStorage.resolveLocalFile(''), isNull);

      const nullPhoto = AppPhoto(id: 'null_photo', label: 'null写真');
      expect(nullPhoto.hasLocalFile, isFalse);
      expect(nullPhoto.localFile, isNull);
    });
  });
}
