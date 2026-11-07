import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/app_photo.dart';

/// Google Photos 検索結果クラス
class GooglePhotosSearchResult {
  const GooglePhotosSearchResult({
    required this.success,
    required this.photos,
    required this.message,
    this.statusCode,
    this.totalInDay = 0,
  });

  final bool success;
  final List<AppPhoto> photos;
  final String message;
  final int? statusCode;
  final int totalInDay;
}

/// Google Photos API連携サービス
class GooglePhotosService {
  GooglePhotosService._();
  static final GooglePhotosService instance = GooglePhotosService._();

  static const String photosReadScope =
      'https://www.googleapis.com/auth/photoslibrary.readonly';

  /// 指定した日時範囲（開始日時〜終了日時）に撮影された写真を検索する
  Future<GooglePhotosSearchResult> searchPhotos({
    required DateTime start,
    required DateTime end,
    GoogleSignInAccount? currentUser,
  }) async {
    if (currentUser == null) {
      return const GooglePhotosSearchResult(
        success: false,
        photos: [],
        message: 'Googleアカウントにログインしていません。ログイン画面からサインインしてください。',
      );
    }

    try {
      final auth = await currentUser.authentication;
      final token = auth.accessToken;

      if (token == null || token.isEmpty) {
        return const GooglePhotosSearchResult(
          success: false,
          photos: [],
          message: 'アクセストークンを取得できませんでした。再度ログインをお試しください。',
        );
      }

      debugPrint('GooglePhotosService: AccessToken取得完了。API通信開始...');
      return await _fetchFromGooglePhotosApi(
        accessToken: token,
        start: start,
        end: end,
      );
    } catch (e) {
      debugPrint('GooglePhotosService Exception: $e');
      return GooglePhotosSearchResult(
        success: false,
        photos: [],
        message: '通信エラーが発生しました: $e',
      );
    }
  }

  /// Google Photos Library API (mediaItems:search) への実通信
  Future<GooglePhotosSearchResult> _fetchFromGooglePhotosApi({
    required String accessToken,
    required DateTime start,
    required DateTime end,
  }) async {
    if (kIsWeb) {
      return const GooglePhotosSearchResult(
        success: false,
        photos: [],
        message: 'Web環境では直接通信が制限されています。',
      );
    }

    final client = HttpClient();
    try {
      final uri = Uri.parse(
        'https://photoslibrary.googleapis.com/v1/mediaItems:search',
      );
      final request = await client.postUrl(uri);

      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $accessToken');
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');

      final payload = {
        'pageSize': 50,
        'filters': {
          'dateFilter': {
            'ranges': [
              {
                'startDate': {
                  'year': start.year,
                  'month': start.month,
                  'day': start.day,
                },
                'endDate': {
                  'year': end.year,
                  'month': end.month,
                  'day': end.day,
                },
              },
            ],
          },
        },
      };

      request.write(jsonEncode(payload));
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      final statusCode = response.statusCode;

      debugPrint('GooglePhotosService: HTTP $statusCode, Body: $responseBody');

      if (statusCode != 200) {
        String detailMessage = '';
        try {
          final errorData = jsonDecode(responseBody) as Map<String, dynamic>?;
          final error = errorData?['error'] as Map<String, dynamic>?;
          if (error != null) {
            final msg = error['message'] as String? ?? '';
            final status = error['status'] as String? ?? '';
            detailMessage = ' ($status: $msg)';
          }
        } catch (_) {
          detailMessage = ' ($responseBody)';
        }

        return GooglePhotosSearchResult(
          success: false,
          photos: [],
          statusCode: statusCode,
          message:
              '【エラー $statusCode】GoogleフォトAPIが拒否しました$detailMessage',
        );
      }

      final Map<String, dynamic> data = jsonDecode(responseBody);
      final List<dynamic>? items = data['mediaItems'];

      if (items == null || items.isEmpty) {
        return GooglePhotosSearchResult(
          success: true,
          photos: [],
          statusCode: 200,
          totalInDay: 0,
          message:
              '${start.year}年${start.month}月${start.day}日に撮影された写真はGoogleフォトに登録されていませんでした。',
        );
      }

      final List<AppPhoto> exactTimeMatches = [];
      final List<AppPhoto> allDayPhotos = [];

      final startMinutes = start.hour * 60 + start.minute;
      final endMinutes = end.hour * 60 + end.minute;

      for (final item in items) {
        final id = item['id'] as String? ?? '';
        final filename = item['filename'] as String? ?? 'Google Photo';
        final description = item['description'] as String?;
        final baseUrl = item['baseUrl'] as String?;

        DateTime? creationTime;
        final mediaMetadata = item['mediaMetadata'] as Map<String, dynamic>?;
        if (mediaMetadata != null && mediaMetadata['creationTime'] != null) {
          creationTime = DateTime.tryParse(mediaMetadata['creationTime'])?.toLocal();
        }

        final photo = AppPhoto(
          id: id,
          label: description ?? filename,
          url: baseUrl != null ? '$baseUrl=w600-h600' : null,
          takenAt: creationTime,
          isFromGooglePhotos: true,
        );

        allDayPhotos.add(photo);

        if (creationTime != null) {
          final itemMinutes = creationTime.hour * 60 + creationTime.minute;
          if (itemMinutes >= startMinutes && itemMinutes <= endMinutes) {
            exactTimeMatches.add(photo);
          }
        }
      }

      // 時間帯合致がある場合はそれを優先、ない場合は同日の全写真を提供
      if (exactTimeMatches.isNotEmpty) {
        return GooglePhotosSearchResult(
          success: true,
          photos: exactTimeMatches,
          statusCode: 200,
          totalInDay: allDayPhotos.length,
          message:
              '指定時間帯（${start.hour}:${start.minute.toString().padLeft(2, '0')}〜${end.hour}:${end.minute.toString().padLeft(2, '0')}）の写真 ${exactTimeMatches.length} 枚を取得しました！',
        );
      } else {
        return GooglePhotosSearchResult(
          success: true,
          // 時間帯には合致しなかったが同日に写真がある場合、その写真を表示
          photos: allDayPhotos,
          statusCode: 200,
          totalInDay: allDayPhotos.length,
          message:
              '指定時間帯の写真はありませんでしたが、同日に撮影された写真 ${allDayPhotos.length} 枚を取得しました。',
        );
      }
    } catch (e) {
      debugPrint('GooglePhotosService: Request Exception: $e');
      return GooglePhotosSearchResult(
        success: false,
        photos: [],
        message: '写真の検索中にエラーが発生しました: $e',
      );
    } finally {
      client.close();
    }
  }
}
