import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_map_app/core/models/app_photo.dart';
import 'package:my_map_app/core/models/memory_pin.dart';
import 'package:my_map_app/core/models/trip_memory.dart';
import 'package:my_map_app/core/services/share_service.dart';
import 'package:my_map_app/screens/memories/memory_detail_screen.dart';

void main() {
  test(
    'ShareService: 位置共有ONのピンのみを抽出し、ローカルパスを含まない公開用共有URLとエンコードデータを生成すること',
    () async {
      final publicPin = MemoryPin(
        id: 'pin_public',
        teamId: 'daily',
        placeName: '鎌倉 鶴岡八幡宮',
        address: '神奈川県鎌倉市雪ノ下2-1-31',
        prefecture: '神奈川県',
        latitude: 35.3261,
        longitude: 139.5561,
        mapNormalizedPosition: const Offset(0.5, 0.5),
        startTime: '10:00',
        endTime: '11:30',
        rating: 5,
        comment: '本宮からの景色が最高でした',
        photoLabels: const ['本宮'],
        photos: const [
          AppPhoto(
            id: 'ph_1',
            label: '本宮',
            url: 'https://example.com/photo1.jpg',
            localPath: '/private/var/mobile/Containers/secret_path.jpg',
          ),
        ],
        shareLocation: true,
      );

      final privatePin = MemoryPin(
        id: 'pin_private',
        teamId: 'daily',
        placeName: '非公開の自宅付近',
        address: '東京都渋谷区1-1-1',
        prefecture: '東京都',
        latitude: 35.6580,
        longitude: 139.7016,
        mapNormalizedPosition: const Offset(0.5, 0.5),
        startTime: '18:00',
        endTime: '19:00',
        rating: 3,
        comment: '非公開メモ',
        photoLabels: const [],
        shareLocation: false,
      );

      final memory = TripMemory(
        id: 'trip_kamakura_1',
        teamId: 'daily',
        title: '鎌倉フォトウォーク',
        startDate: DateTime(2026, 11, 8),
        endDate: DateTime(2026, 11, 8),
        pins: [publicPin, privatePin],
        routePoints: [
          RoutePoint(
            latitude: 35.3191,
            longitude: 139.5504,
            timestamp: DateTime(2026, 11, 8, 9, 45),
          ),
          RoutePoint(
            latitude: 35.3261,
            longitude: 139.5561,
            timestamp: DateTime(2026, 11, 8, 10, 0),
          ),
        ],
      );

      final payload = ShareService.instance.buildSharePayload(
        shareId: 'sh_trip_kamakura_1',
        memory: memory,
        pins: [publicPin],
      );

      final payloadPins = payload['pins'] as List<dynamic>;
      expect(payloadPins.length, 1);
      final firstPin = payloadPins.first as Map<String, dynamic>;
      expect(firstPin['placeName'], '鎌倉 鶴岡八幡宮');
      final firstPhotos = firstPin['photos'] as List<dynamic>;
      expect(firstPhotos.length, 1);
      final firstPhotoMap = firstPhotos.first as Map<String, dynamic>;
      expect(firstPhotoMap['url'], 'https://example.com/photo1.jpg');
      // 端末固有の localPath が公開ペイロードに含まれていないこと
      expect(firstPhotoMap.containsKey('localPath'), isFalse);

      final result = await ShareService.instance.createShareLink(memory);
      expect(result.shareId, 'sh_trip_kamakura_1');
      expect(result.sharedSpotCount, 1);
      expect(result.shareUrl, contains('/share/sh_trip_kamakura_1'));

      // 生成されたURLをパースしてクエリパラメータを検証
      final parsedUri = Uri.parse(result.shareUrl);
      expect(parsedUri.queryParameters['g'], 'daily');
      expect(parsedUri.queryParameters['t'], 'trip_kamakura_1');
      final encodedD = parsedUri.queryParameters['d'];
      expect(encodedD, isNotNull);
      expect(encodedD!.isNotEmpty, isTrue);

      // Base64URLデコードして中身がサーバー側仕様と完全一致するか検証
      final normalizedB64 = base64Url.normalize(encodedD);
      final decodedJson = utf8.decode(base64Url.decode(normalizedB64));
      final decodedMap = jsonDecode(decodedJson) as Map<String, dynamic>;
      expect(decodedMap['t'], '鎌倉フォトウォーク');
      expect((decodedMap['rp'] as List<dynamic>).length, 2);
      final decodedPins = decodedMap['p'] as List<dynamic>;
      expect(decodedPins.length, 1);
      expect((decodedPins.first as Map<String, dynamic>)['n'], '鎌倉 鶴岡八幡宮');

      expect(result.summaryText, contains('【鎌倉フォトウォーク】'));
      expect(result.summaryText, contains('鎌倉 鶴岡八幡宮'));
      expect(result.summaryText.contains('非公開の自宅付近'), isFalse);
    },
  );

  test(
    'ShareService: ローカルファイルのみの写真（ゲスト利用時など）もData URLに変換して共有ペイロードに含められること',
    () async {
      final tempFile = File(
        '${Directory.systemTemp.path}/test_share_photo.jpg',
      );
      await tempFile.writeAsBytes([0xFF, 0xD8, 0xFF, 0xD9]);
      addTearDown(() {
        if (tempFile.existsSync()) {
          tempFile.deleteSync();
        }
      });

      final pinWithLocalPhoto = MemoryPin(
        id: 'pin_local',
        teamId: 'daily',
        placeName: '江ノ島カフェ',
        address: '神奈川県藤沢市江の島',
        prefecture: '神奈川県',
        latitude: 35.3000,
        longitude: 139.4800,
        mapNormalizedPosition: const Offset(0.5, 0.5),
        startTime: '14:00',
        endTime: '15:00',
        rating: 4,
        comment: '海が見える席でコーヒー',
        photoLabels: const ['コーヒー'],
        photos: [
          AppPhoto(
            id: 'local_ph_1',
            label: 'コーヒー',
            localPath: tempFile.path,
            isFromGooglePhotos: false,
          ),
        ],
      );

      final memory = TripMemory(
        id: 'trip_enoshima',
        teamId: 'daily',
        title: '江ノ島カフェ巡り',
        startDate: DateTime(2026, 11, 9),
        endDate: DateTime(2026, 11, 9),
        pins: [pinWithLocalPhoto],
      );

      final result = await ShareService.instance.createShareLink(memory);
      expect(result.sharedSpotCount, 1);
      expect(result.shareUrl, contains('/share/sh_trip_enoshima'));
    },
  );

  testWidgets('MemoryDetailScreen: 共有ボタンを押すとCloud Run共有マップURLが発行・表示されること', (
    WidgetTester tester,
  ) async {
    final pin = MemoryPin(
      id: 'pin_1',
      teamId: 'daily',
      placeName: '東京タワー',
      address: '東京都港区芝公園4-2-8',
      prefecture: '東京都',
      latitude: 35.6586,
      longitude: 139.7454,
      mapNormalizedPosition: const Offset(0.5, 0.5),
      startTime: '15:00',
      endTime: '17:00',
      rating: 5,
      comment: '展望台からの夜景が綺麗でした。',
      photoLabels: const ['夜景'],
    );

    final memory = TripMemory(
      id: 'trip_tokyo_tower',
      teamId: 'daily',
      title: '東京タワー散歩',
      startDate: DateTime(2026, 11, 9),
      endDate: DateTime(2026, 11, 9),
      pins: [pin],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MemoryDetailScreen(memory: memory, onDelete: (_) {}),
      ),
    );

    // 右上の紙飛行機（共有）アイコンをタップ
    await tester.tap(find.byIcon(Icons.send_outlined));
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    expect(find.text('「東京タワー散歩」を共有'), findsOneWidget);
    expect(find.byKey(const Key('generated_share_url_text')), findsOneWidget);
    expect(find.byKey(const Key('copy_share_url_button')), findsOneWidget);
    expect(find.byKey(const Key('open_share_web_map_button')), findsOneWidget);
    expect(find.byKey(const Key('copy_share_summary_button')), findsOneWidget);
  });
}
