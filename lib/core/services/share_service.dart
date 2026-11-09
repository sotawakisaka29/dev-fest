import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../models/app_photo.dart';
import '../models/memory_pin.dart';
import '../models/trip_memory.dart';
import 'storage_service.dart';

/// 共有リンク発行結果モデル
class ShareLinkResult {
  const ShareLinkResult({
    required this.shareId,
    required this.shareUrl,
    required this.summaryText,
    required this.sharedSpotCount,
    required this.syncedToServer,
  });

  final String shareId;
  final String shareUrl;
  final String summaryText;
  final int sharedSpotCount;

  /// Cloud Run（またはローカル共有サーバー）への直接登録が成功したかどうか
  final bool syncedToServer;
}

/// Cloud Run 上の閲覧専用Webマップビューアと連携して思い出共有リンクを生成・管理するサービス
class ShareService {
  ShareService._();
  static final ShareService instance = ShareService._();

  /// デフォルトの Cloud Run サービスベースURL
  /// （--dart-define=CLOUD_RUN_BASE_URL=... またはアプリ内設定から変更可能）
  static const String defaultCloudRunUrl = String.fromEnvironment(
    'CLOUD_RUN_BASE_URL',
    defaultValue:
        'https://my-map-share-viewer-717242936544.asia-northeast1.run.app',
  );

  /// ローカル検証用のベースURL
  static String get localDevBaseUrl {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080';
    }
    return 'http://localhost:8080';
  }

  String _customBaseUrl = defaultCloudRunUrl;
  bool _hasExplicitCustomUrl = const String.fromEnvironment(
    'CLOUD_RUN_BASE_URL',
  ).isNotEmpty;

  /// 現在設定されている Cloud Run ベースURL
  String get baseUrl => _customBaseUrl;

  /// Cloud Run ベースURLを実行時に更新する（末尾のスラッシュは正規化）
  void updateBaseUrl(String newUrl) {
    final trimmed = newUrl.trim();
    if (trimmed.isEmpty) {
      _customBaseUrl = defaultCloudRunUrl;
      _hasExplicitCustomUrl = false;
      return;
    }
    _customBaseUrl = trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
    _hasExplicitCustomUrl = true;
  }

  bool get _isFirebaseInitialized => Firebase.apps.isNotEmpty;

  FirebaseFirestore? get _firestore {
    if (!_isFirebaseInitialized) return null;
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  /// 指定された思い出（TripMemory）の公開用スナップショットを作成し、Cloud Run 共有URLを発行する
  Future<ShareLinkResult> createShareLink(
    TripMemory memory, {
    List<MemoryPin>? overridePins,
  }) async {
    final sourcePins = overridePins ?? memory.pins;
    // 位置共有が許可されているピンのみを抽出
    final shareablePins = sourcePins.where((p) => p.shareLocation).toList();

    // 1. ローカル写真がまだ Cloud Storage にアップロードされていない場合はアップロードを試行し、
    //    ゲストモード等で未アップロードの写真がある場合は Data URL フォールバックも用意する
    final List<MemoryPin> preparedPins = [];
    for (final pin in shareablePins) {
      List<AppPhoto> currentPhotos = TripMemory.photosForPin(pin);
      if (currentPhotos.isNotEmpty && _isFirebaseInitialized) {
        try {
          currentPhotos = await StorageService.instance.uploadPhotos(
            groupId: memory.teamId,
            photos: currentPhotos,
          );
        } catch (e) {
          debugPrint('Photo upload before share skipped: $e');
        }
      }

      // ローカル実体ファイルがあるがリモートURLがない写真を Data URL 化（2MB以下の場合）
      final List<AppPhoto> resolvedPhotos = [];
      for (final photo in currentPhotos) {
        resolvedPhotos.add(await _resolvePhotoUrlIfNeeded(photo));
      }

      preparedPins.add(pin.copyWith(photos: resolvedPhotos));
    }

    final shareId = 'sh_${memory.id}';
    final payload = buildSharePayload(
      shareId: shareId,
      memory: memory,
      pins: preparedPins,
    );

    // Firestore 保存用ペイロード（Data URL 以外の http/https 写真を中心に保存してドキュメント上限超過を防止）
    final firestorePayload = buildSharePayload(
      shareId: shareId,
      memory: memory,
      pins: preparedPins,
      includeDataUrls: false,
    );

    // 2. Firestore への共有スナップショット保存（グループ配下 memories およびトップレベル shares）
    final db = _firestore;
    if (db != null) {
      try {
        await db
            .collection('groups')
            .doc(memory.teamId)
            .collection('memories')
            .doc(shareId)
            .set(firestorePayload, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Firestore groups/memories share save warning: $e');
      }

      try {
        await db
            .collection('shares')
            .doc(shareId)
            .set(firestorePayload, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Firestore top-level shares save warning: $e');
      }
    }

    // 3. Cloud Run サーバー（および未デプロイ時はローカル開発サーバー）の /api/shares へ登録を試行
    String activeBaseUrl = _customBaseUrl;
    bool synced = await _postShareToServer(activeBaseUrl, payload);
    if (!synced && !_hasExplicitCustomUrl && activeBaseUrl != localDevBaseUrl) {
      final localSuccess = await _postShareToServer(localDevBaseUrl, payload);
      if (localSuccess) {
        activeBaseUrl = localDevBaseUrl;
        _customBaseUrl = localDevBaseUrl;
        synced = true;
      }
    }

    // 4. 共有URLの組み立て（Firestore 参照パラメータ + 軽量エンコードデータのフォールバック付き）
    final encodedData = encodeCompactPayload(memory, preparedPins);
    final queryParams = <String, String>{
      'g': memory.teamId,
      't': memory.id,
      if (encodedData.isNotEmpty) 'd': encodedData,
    };
    final queryString = queryParams.entries
        .map(
          (e) =>
              '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}',
        )
        .join('&');

    final shareUrl =
        '$activeBaseUrl/share/${Uri.encodeComponent(shareId)}?$queryString';

    final reviewPins = preparedPins
        .where((p) => !p.isRouteWaypointOnly)
        .toList();
    final spotNames = reviewPins.map((p) => p.placeName).join(' → ');

    final summaryText =
        '【${memory.title}】\n'
        '期間: ${memory.formattedDateRange} / 総移動距離: ${memory.formattedDistance}\n'
        '${spotNames.isNotEmpty ? '訪問スポット: $spotNames\n' : ''}'
        '思い出マップを見る（閲覧専用）:\n'
        '$shareUrl';

    return ShareLinkResult(
      shareId: shareId,
      shareUrl: shareUrl,
      summaryText: summaryText,
      sharedSpotCount: reviewPins.length,
      syncedToServer: synced,
    );
  }

  Future<AppPhoto> _resolvePhotoUrlIfNeeded(AppPhoto photo) async {
    final existingUrl = photo.url?.trim() ?? '';
    if (existingUrl.startsWith('http://') ||
        existingUrl.startsWith('https://') ||
        existingUrl.startsWith('data:image/')) {
      return photo;
    }

    try {
      final file = photo.localFile;
      if (file != null && file.existsSync()) {
        final length = await file.length();
        if (length > 0 && length <= 2 * 1024 * 1024) {
          final bytes = await file.readAsBytes();
          final b64 = base64Encode(bytes);
          return photo.copyWith(url: 'data:image/jpeg;base64,$b64');
        }
      }
    } catch (e) {
      debugPrint('Local photo data url encode skipped: $e');
    }
    return photo;
  }

  /// 公開用の安全なJSONペイロードを構築（端末内のローカルファイルパス等は除外）
  Map<String, dynamic> buildSharePayload({
    required String shareId,
    required TripMemory memory,
    required List<MemoryPin> pins,
    bool includeDataUrls = true,
  }) {
    return {
      'shareId': shareId,
      'tripId': memory.id,
      'teamId': memory.teamId,
      'title': memory.title,
      'startDate': memory.startDate.toIso8601String(),
      'endDate': memory.endDate.toIso8601String(),
      'formattedDateRange': memory.formattedDateRange,
      'formattedDistance': memory.formattedDistance,
      'customDistanceKm': memory.customDistanceKm,
      'createdAt': DateTime.now().toIso8601String(),
      'routePoints': memory.routePoints
          .map((rp) => {'lat': rp.latitude, 'lng': rp.longitude})
          .toList(),
      'pins': pins.map((pin) {
        final List<AppPhoto> pinPhotos = TripMemory.photosForPin(pin);
        final publicPhotos = pinPhotos
            .where((p) {
              final u = p.url?.trim() ?? '';
              if (u.startsWith('http://') || u.startsWith('https://')) {
                return true;
              }
              if (includeDataUrls && u.startsWith('data:image/')) {
                return true;
              }
              return false;
            })
            .map((p) => {'id': p.id, 'label': p.label, 'url': p.url})
            .toList();

        return {
          'id': pin.id,
          'placeName': pin.placeName,
          'address': pin.address,
          'prefecture': pin.prefecture,
          'latitude': pin.latitude,
          'longitude': pin.longitude,
          'startTime': pin.startTime,
          'endTime': pin.endTime,
          'rating': pin.rating,
          'comment': pin.comment,
          'photos': publicPhotos,
          'isRouteWaypointOnly': pin.isRouteWaypointOnly,
        };
      }).toList(),
    };
  }

  /// URLクエリパラメータ（?d=...）に埋め込むためのコンパクトなBase64URL文字列を生成
  String encodeCompactPayload(TripMemory memory, List<MemoryPin> pins) {
    try {
      final reviewPins = pins.where((p) => !p.isRouteWaypointOnly).toList();

      // ルート座標列を最大50点にサンプリングして軽量化
      final rawRoute = memory.routePoints;
      final List<List<double>> compactRoute = [];
      if (rawRoute.isNotEmpty) {
        final step = (rawRoute.length / 50).ceil().clamp(1, rawRoute.length);
        for (int i = 0; i < rawRoute.length; i += step) {
          compactRoute.add([
            double.parse(rawRoute[i].latitude.toStringAsFixed(5)),
            double.parse(rawRoute[i].longitude.toStringAsFixed(5)),
          ]);
        }
        final last = rawRoute.last;
        final lastPair = [
          double.parse(last.latitude.toStringAsFixed(5)),
          double.parse(last.longitude.toStringAsFixed(5)),
        ];
        if (compactRoute.isEmpty ||
            compactRoute.last[0] != lastPair[0] ||
            compactRoute.last[1] != lastPair[1]) {
          compactRoute.add(lastPair);
        }
      }

      final compactMap = <String, dynamic>{
        't': memory.title,
        'dr': memory.formattedDateRange,
        'dist': memory.formattedDistance,
        if (compactRoute.length >= 2) 'rp': compactRoute,
        'p': reviewPins.map((pin) {
          final publicUrls = TripMemory.photosForPin(pin)
              .map((ph) => ph.url)
              .whereType<String>()
              .where((u) => u.startsWith('http://') || u.startsWith('https://'))
              .take(3)
              .toList();

          return <String, dynamic>{
            'n': pin.placeName,
            if (pin.address.isNotEmpty) 'a': pin.address,
            if (pin.prefecture.isNotEmpty) 'pr': pin.prefecture,
            'la': double.parse(pin.latitude.toStringAsFixed(5)),
            'ln': double.parse(pin.longitude.toStringAsFixed(5)),
            if (pin.startTime.isNotEmpty) 'st': pin.startTime,
            if (pin.endTime.isNotEmpty) 'et': pin.endTime,
            if (pin.rating != null) 'r': pin.rating,
            if (pin.comment.isNotEmpty) 'c': pin.comment,
            if (publicUrls.isNotEmpty) 'ph': publicUrls,
          };
        }).toList(),
      };

      final jsonBytes = utf8.encode(jsonEncode(compactMap));
      return base64Url.encode(jsonBytes).replaceAll('=', '');
    } catch (e) {
      debugPrint('Compact payload encode error: $e');
      return '';
    }
  }

  Future<bool> _postShareToServer(
    String targetBaseUrl,
    Map<String, dynamic> payload,
  ) async {
    try {
      final uri = Uri.parse('$targetBaseUrl/api/shares');
      final client = HttpClient()
        ..connectionTimeout = const Duration(milliseconds: 1500);
      final request = await client
          .postUrl(uri)
          .timeout(const Duration(milliseconds: 1500));
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.add(utf8.encode(jsonEncode(payload)));
      final response = await request.close().timeout(
        const Duration(milliseconds: 2000),
      );
      await response.drain<void>();
      client.close();
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }
}
