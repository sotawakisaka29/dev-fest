import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../models/app_photo.dart';

/// Firebase Cloud Storage を用いた写真実体のアップロード・永続URL発行サービス
class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  bool get isFirebaseInitialized => Firebase.apps.isNotEmpty;

  FirebaseStorage? get _storage {
    if (!isFirebaseInitialized) return null;
    try {
      return FirebaseStorage.instance;
    } catch (_) {
      return null;
    }
  }

  /// 単一の写真ファイルを Cloud Storage（/groups/{groupId}/photos/{photoId}.jpg）へアップロード
  Future<String?> uploadFile({
    required String groupId,
    required String photoId,
    required File file,
  }) async {
    final storage = _storage;
    if (storage == null) {
      debugPrint('FirebaseStorage is not initialized. Skipping upload.');
      return null;
    }

    if (!file.existsSync()) {
      debugPrint('Local photo file does not exist: ${file.path}');
      return null;
    }

    try {
      final sanitizedId = photoId.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
      final ref = storage
          .ref()
          .child('groups')
          .child(groupId)
          .child('photos')
          .child('$sanitizedId.jpg');

      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'uploadedAt': DateTime.now().toIso8601String(),
          'groupId': groupId,
        },
      );

      final uploadTask = await ref.putFile(file, metadata);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('Firebase Storage upload error for photoId $photoId: $e');
      return null;
    }
  }

  /// 選択された写真リストを Cloud Storage へ一括アップロードし、永続ダウンロードURL付きの AppPhoto リストを返す
  ///
  /// - 既に Cloud Storage の永続URLを持つ写真はアップロードをスキップ
  /// - 端末アルバム写真および Googleフォト（キャッシュ済み）の両方に対応
  /// - アップロード失敗時やオフライン時は元のローカルパスを保持したままフォールバック
  Future<List<AppPhoto>> uploadPhotos({
    required String groupId,
    required List<AppPhoto> photos,
    void Function(int current, int total)? onProgress,
  }) async {
    final List<AppPhoto> result = [];
    final total = photos.length;

    for (int i = 0; i < photos.length; i++) {
      final photo = photos[i];
      onProgress?.call(i + 1, total);

      // 既に Firebase Storage の永続URLを持っている場合はスキップ
      if (photo.url != null &&
          photo.url!.contains('firebasestorage.googleapis.com')) {
        result.add(photo);
        continue;
      }

      // ローカルファイルが存在する場合にアップロード
      if (photo.localPath != null && photo.localPath!.isNotEmpty) {
        final file = File(photo.localPath!);
        if (file.existsSync()) {
          final downloadUrl = await uploadFile(
            groupId: groupId,
            photoId: photo.id.isNotEmpty
                ? photo.id
                : 'photo_${DateTime.now().millisecondsSinceEpoch}_$i',
            file: file,
          );

          if (downloadUrl != null && downloadUrl.isNotEmpty) {
            // 永続URLをセット
            result.add(photo.copyWith(url: downloadUrl));
            continue;
          }
        }
      }

      // アップロードできなかった場合は元の写真オブジェクトを維持
      result.add(photo);
    }

    return result;
  }
}
