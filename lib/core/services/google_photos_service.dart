import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/app_photo.dart';
import 'auth_service.dart';
import 'photo_storage_service.dart';

/// Google Photos Picker API 関連のエラー区分
enum GooglePhotosErrorType {
  notSignedIn,
  scopeNotGranted,
  userCancelled,
  apiDisabled,
  notTestUser,
  sessionExpired,
  pollingTimeout,
  networkError,
  rateLimited,
  serverError,
  noPhotosSelected,
  unknown,
}

/// Google Photos Picker の実行結果クラス
class GooglePhotosPickerResult {
  const GooglePhotosPickerResult.success(this.photos)
    : isSuccess = true,
      errorType = null,
      message = '写真を取得しました';

  const GooglePhotosPickerResult.failure({
    required this.errorType,
    required this.message,
  }) : isSuccess = false,
       photos = const [];

  final bool isSuccess;
  final List<AppPhoto> photos;
  final GooglePhotosErrorType? errorType;
  final String? message;
}

/// Picker セッション情報
class PickerSession {
  const PickerSession({
    required this.id,
    required this.pickerUri,
    this.mediaItemsSet = false,
    this.pollIntervalSeconds = 5,
    this.timeoutSeconds = 300,
  });

  final String id;
  final String pickerUri;
  final bool mediaItemsSet;
  final int pollIntervalSeconds;
  final int timeoutSeconds;

  factory PickerSession.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String? ?? '';
    final pickerUri = json['pickerUri'] as String? ?? '';
    final mediaItemsSet = json['mediaItemsSet'] as bool? ?? false;

    int pollInterval = 5;
    int timeout = 300;

    final pollingConfig = json['pollingConfig'] as Map<String, dynamic>?;
    if (pollingConfig != null) {
      final intervalStr = pollingConfig['pollInterval'] as String?;
      if (intervalStr != null) {
        final secMatch = RegExp(r'^(\d+)s$').firstMatch(intervalStr);
        if (secMatch != null) {
          pollInterval = int.tryParse(secMatch.group(1)!) ?? 5;
        }
      }
      final timeoutStr = pollingConfig['timeoutIn'] as String?;
      if (timeoutStr != null) {
        final secMatch = RegExp(r'^(\d+)s$').firstMatch(timeoutStr);
        if (secMatch != null) {
          timeout = int.tryParse(secMatch.group(1)!) ?? 300;
        }
      }
    }

    return PickerSession(
      id: id,
      pickerUri: pickerUri,
      mediaItemsSet: mediaItemsSet,
      pollIntervalSeconds: pollInterval > 0 ? pollInterval : 5,
      timeoutSeconds: timeout > 0 ? timeout : 300,
    );
  }
}

/// Google Photos Picker API連携サービス
///
/// 2025年3月31日仕様変更に対応し、廃止された旧Photos Library API（日付検索）ではなく、
/// Google Photos Picker API (https://photospicker.googleapis.com/v1) を使用して
/// ユーザーが選択した写真を取得する。
class GooglePhotosService {
  GooglePhotosService._();
  static final GooglePhotosService instance = GooglePhotosService._();

  static const String _baseUrl = 'https://photospicker.googleapis.com/v1';

  /// 現在アクティブなセッション（多重セッション防止用）
  PickerSession? _activeSession;
  PickerSession? get activeSession => _activeSession;

  /// セッションポーリングのキャンセル用フラグ
  bool _isCancelled = false;

  /// 現在のセッションが進行中かどうか
  bool get hasActiveSession => _activeSession != null;

  /// 1. セッションを作成する
  Future<PickerSession> createSession({required String accessToken}) async {
    final client = HttpClient();
    try {
      final uri = Uri.parse('$_baseUrl/sessions');
      final request = await client.postUrl(uri);
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer $accessToken',
      );
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.write(jsonEncode(<String, dynamic>{}));

      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        _handleApiError(response.statusCode, body);
      }

      final data = jsonDecode(body) as Map<String, dynamic>;
      final session = PickerSession.fromJson(data);
      if (session.id.isEmpty || session.pickerUri.isEmpty) {
        throw const GooglePhotosCustomException(
          GooglePhotosErrorType.unknown,
          'セッションの初期化情報が不完全です。',
        );
      }
      _activeSession = session;
      _isCancelled = false;
      return session;
    } on IOException {
      throw const GooglePhotosCustomException(
        GooglePhotosErrorType.networkError,
        'ネットワークに接続できません。通信環境を確認してください。',
      );
    } finally {
      client.close();
    }
  }

  /// 2. Picker URIを外部ブラウザまたはGoogleフォトアプリで開く
  Future<bool> launchPickerUri(String pickerUri) async {
    final uri = Uri.parse(pickerUri);
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      return launched;
    } catch (e) {
      debugPrint('Failed to launch pickerUri: $e');
      return false;
    }
  }

  /// 3. セッションの状態を確認する（単発GET）
  Future<PickerSession> getSession({
    required String sessionId,
    required String accessToken,
  }) async {
    final client = HttpClient();
    try {
      final uri = Uri.parse('$_baseUrl/sessions/$sessionId');
      final request = await client.getUrl(uri);
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer $accessToken',
      );

      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        _handleApiError(response.statusCode, body);
      }

      final data = jsonDecode(body) as Map<String, dynamic>;
      final session = PickerSession.fromJson(data);
      _activeSession = session;
      return session;
    } on IOException {
      throw const GooglePhotosCustomException(
        GooglePhotosErrorType.networkError,
        'セッション状態取得中にネットワークエラーが発生しました。',
      );
    } finally {
      client.close();
    }
  }

  /// 4. ユーザーの写真選択完了（mediaItemsSet == true）までポーリングする
  Future<PickerSession> pollUntilReady({
    required String sessionId,
    required String accessToken,
    int? customPollIntervalSeconds,
    int? customTimeoutSeconds,
  }) async {
    int intervalSec = customPollIntervalSeconds ?? 5;
    final timeoutSec = customTimeoutSeconds ?? 300;
    final deadline = DateTime.now().add(Duration(seconds: timeoutSec));

    while (DateTime.now().isBefore(deadline)) {
      if (_isCancelled) {
        throw const GooglePhotosCustomException(
          GooglePhotosErrorType.userCancelled,
          '写真の選択がキャンセルされました。',
        );
      }

      try {
        final session = await getSession(
          sessionId: sessionId,
          accessToken: accessToken,
        );

        intervalSec = customPollIntervalSeconds ?? session.pollIntervalSeconds;

        if (session.mediaItemsSet) {
          return session;
        }
      } on GooglePhotosCustomException catch (e) {
        // Androidのバックグラウンド移行時の接続切断(Software caused connection abort)や電波瞬断はリトライ
        if (e.type == GooglePhotosErrorType.networkError) {
          debugPrint('一時的な通信切断を検知しました。ポーリングを再試行します: ${e.message}');
        } else {
          rethrow;
        }
      }

      await Future<void>.delayed(Duration(seconds: intervalSec));
    }

    throw const GooglePhotosCustomException(
      GooglePhotosErrorType.pollingTimeout,
      '写真選択の待機時間がタイムアウトしました。再度お試しください。',
    );
  }

  /// 5. 選択されたメディアアイテムを取得する（ページング対応）
  Future<List<AppPhoto>> fetchMediaItems({
    required String sessionId,
    required String accessToken,
  }) async {
    final List<AppPhoto> photos = [];
    String? pageToken;
    final client = HttpClient();

    try {
      do {
        final queryParams = <String, String>{
          'sessionId': sessionId,
          'pageSize': '100',
        };
        if (pageToken != null && pageToken.isNotEmpty) {
          queryParams['pageToken'] = pageToken;
        }

        final uri = Uri.parse(
          '$_baseUrl/mediaItems',
        ).replace(queryParameters: queryParams);
        final request = await client.getUrl(uri);
        request.headers.set(
          HttpHeaders.authorizationHeader,
          'Bearer $accessToken',
        );

        final response = await request.close();
        final body = await response.transform(utf8.decoder).join();

        if (response.statusCode != 200) {
          _handleApiError(response.statusCode, body);
        }

        final data = jsonDecode(body) as Map<String, dynamic>;
        final items = data['mediaItems'] as List<dynamic>?;

        if (items != null) {
          for (final item in items) {
            final photo = _parseMediaItem(item as Map<String, dynamic>);
            if (photo != null) {
              photos.add(photo);
            }
          }
        }

        pageToken = data['nextPageToken'] as String?;
      } while (pageToken != null && pageToken.isNotEmpty);

      return photos;
    } on IOException {
      throw const GooglePhotosCustomException(
        GooglePhotosErrorType.networkError,
        '写真一覧の取得中にネットワークエラーが発生しました。',
      );
    } finally {
      client.close();
    }
  }

  /// 6. セッションを破棄（クリーンアップ）する
  Future<void> deleteSession({
    required String sessionId,
    required String accessToken,
  }) async {
    final client = HttpClient();
    try {
      final uri = Uri.parse('$_baseUrl/sessions/$sessionId');
      final request = await client.deleteUrl(uri);
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer $accessToken',
      );
      final response = await request.close();
      await response.drain<void>();
    } catch (e) {
      debugPrint('Error deleting session: $e');
    } finally {
      client.close();
      if (_activeSession?.id == sessionId) {
        _activeSession = null;
      }
    }
  }

  /// セッションの明示的なキャンセル
  void cancelActiveFlow() {
    _isCancelled = true;
  }

  /// メディアアイテム要素を AppPhoto モデルに変換
  AppPhoto? _parseMediaItem(Map<String, dynamic> item) {
    final id =
        item['id'] as String? ?? 'gp_${DateTime.now().microsecondsSinceEpoch}';
    final mediaFile = item['mediaFile'] as Map<String, dynamic>?;

    final baseUrl =
        mediaFile?['baseUrl'] as String? ?? item['baseUrl'] as String?;
    final filename =
        mediaFile?['filename'] as String? ??
        item['filename'] as String? ??
        'Google Photo';

    DateTime? createTime;
    final timeStr =
        item['createTime'] as String? ??
        (item['mediaMetadata'] as Map<String, dynamic>?)?['creationTime']
            as String?;
    if (timeStr != null) {
      createTime = DateTime.tryParse(timeStr)?.toLocal();
    }

    return AppPhoto(
      id: id,
      label: filename,
      url: baseUrl != null ? '$baseUrl=w600-h600' : null,
      takenAt: createTime,
      isFromGooglePhotos: true,
    );
  }

  /// GoogleフォトのbaseUrlから画像をBearer認証付きでダウンロードし、一時ファイルとして保存する
  ///
  /// Google Photos Picker APIの画像URLはCDNサーバーへリダイレクト（302/307等）される場合があるため、
  /// リダイレクト追跡時にもBearer認証ヘッダーを保持して確実にバイトデータを取得する。
  Future<String?> downloadPhotoToTempFile({
    required String baseUrl,
    required String accessToken,
    required String id,
  }) async {
    final client = HttpClient();
    try {
      final initialUrl = baseUrl.contains('=') ? baseUrl : '$baseUrl=w800-h800';
      Uri currentUri = Uri.parse(initialUrl);

      HttpClientResponse? response;
      int redirectCount = 0;
      const maxRedirects = 5;

      while (redirectCount < maxRedirects) {
        final request = await client.getUrl(currentUri);
        request.headers.set(
          HttpHeaders.authorizationHeader,
          'Bearer $accessToken',
        );
        request.followRedirects = false;

        response = await request.close();

        if (response.isRedirect) {
          final location = response.headers.value(HttpHeaders.locationHeader);
          await response.drain<void>();
          if (location == null || location.isEmpty) {
            break;
          }
          currentUri = currentUri.resolve(location);
          redirectCount++;
          continue;
        }
        break;
      }

      if (response == null || response.statusCode != 200) {
        debugPrint(
          'Failed to download Google Photo: HTTP ${response?.statusCode}',
        );
        if (response != null) {
          await response.drain<void>();
        }
        return null;
      }

      final bytes = await consolidateHttpClientResponseBytes(response);
      final persistentPath = await PhotoStorageService.instance.savePhotoBytes(
        photoId: id,
        bytes: bytes,
      );
      return persistentPath;
    } catch (e) {
      debugPrint('Error downloading photo to temp file: $e');
      return null;
    } finally {
      client.close();
    }
  }

  /// HTTPステータスコードに応じたエラーハンドリング（機密情報は含めない）
  void _handleApiError(int statusCode, String responseBody) {
    debugPrint('GooglePhotosService HTTP Error: $statusCode');

    String reasonMessage = '';
    try {
      final parsed = jsonDecode(responseBody) as Map<String, dynamic>?;
      final error = parsed?['error'] as Map<String, dynamic>?;
      reasonMessage = error?['message'] as String? ?? '';
    } catch (_) {}

    switch (statusCode) {
      case 401:
        throw const GooglePhotosCustomException(
          GooglePhotosErrorType.notSignedIn,
          '認証の有効期限が切れています。再度サインインしてください。',
        );
      case 403:
        if (reasonMessage.contains('has not been used') ||
            reasonMessage.contains('disabled')) {
          throw const GooglePhotosCustomException(
            GooglePhotosErrorType.apiDisabled,
            'Google Photos Picker APIがプロジェクトで有効化されていません。GCPの設定を確認してください。',
          );
        }
        if (reasonMessage.contains('ACCESS_TOKEN_SCOPE_INSUFFICIENT') ||
            reasonMessage.contains('insufficient authentication scopes')) {
          throw const GooglePhotosCustomException(
            GooglePhotosErrorType.scopeNotGranted,
            'Googleフォトへのアクセス権限が付与されていません。',
          );
        }
        throw const GooglePhotosCustomException(
          GooglePhotosErrorType.notTestUser,
          'アクセスが拒否されました。テストユーザーの登録状況または権限を確認してください。',
        );
      case 404:
      case 410:
        throw const GooglePhotosCustomException(
          GooglePhotosErrorType.sessionExpired,
          'セッションの有効期限が切れました。再度写真を選択してください。',
        );
      case 429:
        throw const GooglePhotosCustomException(
          GooglePhotosErrorType.rateLimited,
          'リクエストが制限されました。時間をおいて再度お試しください。',
        );
      default:
        if (statusCode >= 500) {
          throw const GooglePhotosCustomException(
            GooglePhotosErrorType.serverError,
            'Googleフォトサーバーで一時的なエラーが発生しました。',
          );
        }
        throw GooglePhotosCustomException(
          GooglePhotosErrorType.unknown,
          'Googleフォト通信エラーが発生しました (HTTP $statusCode)。',
        );
    }
  }

  /// Picker選択フローを一括実行するヘルパーメソッド
  Future<GooglePhotosPickerResult> pickPhotosFromGooglePhotos({
    void Function(String message)? onProgress,
  }) async {
    // 1. Googleアカウントログイン状態の確認（サイレントサインイン復元を含む）
    final googleUser = await AuthService.instance.ensureGoogleUser();

    if (googleUser == null) {
      return const GooglePhotosPickerResult.failure(
        errorType: GooglePhotosErrorType.notSignedIn,
        message: 'Googleアカウントにログインしていません。設定またはログイン画面からサインインしてください。',
      );
    }

    // 2. 段階的認可（Incremental Auth）でPickerスコープを要求
    onProgress?.call('Googleフォトのアクセス権限を確認中...');
    final scopeResult = await AuthService.instance
        .requestPhotoPickerScopeDetailed();
    if (scopeResult != ScopeRequestResult.granted) {
      if (scopeResult == ScopeRequestResult.cancelled) {
        return const GooglePhotosPickerResult.failure(
          errorType: GooglePhotosErrorType.userCancelled,
          message: '写真選択（Google認可）がキャンセルされました。',
        );
      }
      if (scopeResult == ScopeRequestResult.denied) {
        return const GooglePhotosPickerResult.failure(
          errorType: GooglePhotosErrorType.scopeNotGranted,
          message: 'Googleフォトのアクセス権限が許可されませんでした。写真を選択するには権限を許可してください。',
        );
      }
      return const GooglePhotosPickerResult.failure(
        errorType: GooglePhotosErrorType.unknown,
        message: 'Googleフォトの認可処理に失敗しました。時間をおいて再度お試しください。',
      );
    }

    // 3. アクセストークンの取得
    final accessToken = await AuthService.instance.getGoogleAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      return const GooglePhotosPickerResult.failure(
        errorType: GooglePhotosErrorType.notSignedIn,
        message: '認証アクセストークンを取得できませんでした。再度ログインしてください。',
      );
    }

    // 4. セッション作成
    PickerSession? session;
    try {
      onProgress?.call('Googleフォト選択画面を準備中...');
      session = await createSession(accessToken: accessToken);

      // 5. 外部ブラウザ / Googleフォトアプリで pickerUri を開く
      final launched = await launchPickerUri(session.pickerUri);
      if (!launched) {
        return const GooglePhotosPickerResult.failure(
          errorType: GooglePhotosErrorType.unknown,
          message: '写真選択画面を開けませんでした。ブラウザの設定等を確認してください。',
        );
      }

      // 6. ポーリングで写真選択完了を待機
      onProgress?.call('Googleフォトで写真を選択してください...');
      final readySession = await pollUntilReady(
        sessionId: session.id,
        accessToken: accessToken,
      );

      if (!readySession.mediaItemsSet) {
        return const GooglePhotosPickerResult.failure(
          errorType: GooglePhotosErrorType.userCancelled,
          message: '写真が選択されませんでした。',
        );
      }

      // 7. 選択されたメディアアイテムの一覧を取得
      onProgress?.call('写真一覧を取得中...');
      final items = await fetchMediaItems(
        sessionId: readySession.id,
        accessToken: accessToken,
      );

      if (items.isEmpty) {
        return const GooglePhotosPickerResult.failure(
          errorType: GooglePhotosErrorType.noPhotosSelected,
          message: '写真は選択されませんでした（0件）。',
        );
      }

      // 8. Google Photos Picker APIのbaseUrlはOAuth認証ヘッダーが必須かつ一時的（最大60分）なため、
      // 端末キャッシュへダウンロードして確実・即座にプレビュー表示できるようにする
      onProgress?.call('写真データをダウンロード中...');
      final downloadedPhotos = <AppPhoto>[];
      for (int i = 0; i < items.length; i++) {
        final photo = items[i];
        if (items.length > 1) {
          onProgress?.call('写真をダウンロード中 (${i + 1}/${items.length})...');
        }
        if (photo.url != null && photo.url!.isNotEmpty) {
          final localPath = await downloadPhotoToTempFile(
            baseUrl: photo.url!,
            accessToken: accessToken,
            id: photo.id,
          );
          if (localPath != null) {
            downloadedPhotos.add(photo.copyWith(localPath: localPath));
            continue;
          }
        }
        downloadedPhotos.add(photo);
      }

      return GooglePhotosPickerResult.success(downloadedPhotos);
    } on GooglePhotosCustomException catch (e) {
      return GooglePhotosPickerResult.failure(
        errorType: e.type,
        message: e.message,
      );
    } on IOException {
      return const GooglePhotosPickerResult.failure(
        errorType: GooglePhotosErrorType.networkError,
        message: 'ネットワーク通信エラーが発生しました。通信環境を確認し、再度お試しください。',
      );
    } catch (e) {
      debugPrint('GooglePhotosService unexpected error: $e');
      return const GooglePhotosPickerResult.failure(
        errorType: GooglePhotosErrorType.unknown,
        message: '写真選択処理中にエラーが発生しました。再度お試しください。',
      );
    } finally {
      // 8. 使用済みセッションを削除クリーンアップ
      if (session != null) {
        await deleteSession(sessionId: session.id, accessToken: accessToken);
      }
    }
  }
}

/// 内部例外クラス
class GooglePhotosCustomException implements Exception {
  const GooglePhotosCustomException(this.type, this.message);
  final GooglePhotosErrorType type;
  final String message;

  @override
  String toString() => 'GooglePhotosCustomException: $message ($type)';
}
