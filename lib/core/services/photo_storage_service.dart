import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// 端末ローカルにおける写真実体の永続保存および
/// iOSサンドボックス再起動（UUID変化）に耐性を持つパス解決サービス
class PhotoStorageService {
  PhotoStorageService._();
  static final PhotoStorageService instance = PhotoStorageService._();

  Directory? _cachedPhotosDir;

  /// アプリの永続ドキュメント領域配下の写真保存ディレクトリ（`{Documents}/app_photos`）を取得
  Future<Directory> getPhotosDirectory() async {
    if (_cachedPhotosDir != null && _cachedPhotosDir!.existsSync()) {
      return _cachedPhotosDir!;
    }

    try {
      final docDir = await getApplicationDocumentsDirectory();
      final photosDir = Directory('${docDir.path}/app_photos');
      if (!photosDir.existsSync()) {
        await photosDir.create(recursive: true);
      }
      _cachedPhotosDir = photosDir;
      return photosDir;
    } catch (e) {
      debugPrint(
        'Failed to get application documents directory: $e. Falling back to systemTemp.',
      );
      final fallbackDir = Directory('${Directory.systemTemp.path}/app_photos');
      if (!fallbackDir.existsSync()) {
        await fallbackDir.create(recursive: true);
      }
      _cachedPhotosDir = fallbackDir;
      return fallbackDir;
    }
  }

  /// 写真バイトデータを永続ディレクトリへ保存し、その絶対パスを返す
  Future<String> savePhotoBytes({
    required String photoId,
    required Uint8List bytes,
  }) async {
    final dir = await getPhotosDirectory();
    final sanitizedId = photoId.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    final file = File('${dir.path}/gphoto_$sanitizedId.jpg');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  /// 指定されたローカルパスから実体ファイルを安全に解決する
  ///
  /// - 指定パスにファイルが存在すればそのまま返却
  /// - iOSでアプリ再起動によりサンドボックスUUIDが変化した場合でも、
  ///   ファイル名を取り出して現在の永続ディレクトリ内から実体ファイルを検索・特定する
  File? resolveLocalFile(String? localPath) {
    if (localPath == null || localPath.trim().isEmpty) return null;

    final trimmed = localPath.trim();
    final directFile = File(trimmed);
    if (directFile.existsSync()) {
      return directFile;
    }

    // パスからファイル名を抽出（Unix/Windows両対応）
    final fileName = trimmed.split(RegExp(r'[/\\]')).last;
    if (fileName.isEmpty) return null;

    // 1. キャッシュ済みディレクトリがあればその配下を検索
    if (_cachedPhotosDir != null) {
      final candidate = File('${_cachedPhotosDir!.path}/$fileName');
      if (candidate.existsSync()) {
        return candidate;
      }
    }

    // 2. 一時ディレクトリ（過去のキャッシュ）も探索
    final tempCandidate = File('${Directory.systemTemp.path}/$fileName');
    if (tempCandidate.existsSync()) {
      return tempCandidate;
    }

    return null;
  }
}
