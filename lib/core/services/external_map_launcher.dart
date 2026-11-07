import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 登録されている住所・座標を元に外部の Google Maps アプリ（またはブラウザ版 Google Maps）を起動するサービス
class ExternalMapLauncher {
  ExternalMapLauncher._();

  static const MethodChannel _channel = MethodChannel(
    'com.devfest.mymap/external_launcher',
  );

  /// テスト環境から最後に要求されたクエリを検証できるように保持する
  @visibleForTesting
  static String? lastLaunchedQuery;

  /// 指定された住所（未設定時は場所名または緯度経度）で Google Maps アプリを起動する
  static Future<bool> openGoogleMapsForAddress(
    BuildContext context, {
    required String address,
    required String placeName,
    double? latitude,
    double? longitude,
  }) async {
    final String query = address.trim().isNotEmpty
        ? address.trim()
        : (placeName.trim().isNotEmpty
              ? placeName.trim()
              : '${latitude ?? ''},${longitude ?? ''}');

    lastLaunchedQuery = query;
    final String encodedQuery = Uri.encodeComponent(query);
    final String universalUrl =
        'https://www.google.com/maps/search/?api=1&query=$encodedQuery';

    try {
      // Android / iOS ネイティブの MethodChannel 経由で Google Maps アプリを起動
      final bool? launched = await _channel.invokeMethod<bool>(
        'openGoogleMaps',
        <String, dynamic>{
          'query': query,
          'encodedQuery': encodedQuery,
          'universalUrl': universalUrl,
          'latitude': latitude,
          'longitude': longitude,
        },
      );
      if (launched == true) {
        return true;
      }
    } on MissingPluginException {
      // デスクトップ環境やウィジェットテスト環境でのフォールバック
      if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
        try {
          if (Platform.isWindows) {
            await Process.run('cmd', ['/c', 'start', '', universalUrl]);
            return true;
          } else if (Platform.isMacOS) {
            await Process.run('open', [universalUrl]);
            return true;
          } else if (Platform.isLinux) {
            await Process.run('xdg-open', [universalUrl]);
            return true;
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Failed to launch Google Maps: $e');
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Google Maps を起動: $query'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
    return false;
  }
}

