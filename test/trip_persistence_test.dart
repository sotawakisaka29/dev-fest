import 'package:flutter_test/flutter_test.dart';
import 'package:my_map_app/core/models/app_photo.dart';
import 'package:my_map_app/core/models/memory_pin.dart';
import 'package:my_map_app/core/models/trip_memory.dart';
import 'package:my_map_app/core/services/group_service.dart';
import 'package:my_map_app/core/services/trip_service.dart';

void main() {
  group('写真・ピン・旅行モデルのシリアライズ・デシリアライズ検証', () {
    test('AppPhoto toMap と fromMap が可逆であること', () {
      final now = DateTime(2026, 11, 9, 0, 30);
      final photo = AppPhoto(
        id: 'photo_test_1',
        label: 'テスト写真',
        url: 'https://example.com/test.jpg',
        localPath: '/local/test.jpg',
        takenAt: now,
        isFromGooglePhotos: true,
      );

      final map = photo.toMap();
      final restored = AppPhoto.fromMap(map);

      expect(restored.id, photo.id);
      expect(restored.label, photo.label);
      expect(restored.url, photo.url);
      expect(restored.localPath, photo.localPath);
      expect(restored.takenAt, photo.takenAt);
      expect(restored.isFromGooglePhotos, photo.isFromGooglePhotos);
    });

    test('MemoryPin toFirestore と fromFirestore が可逆であること', () {
      final recordedDate = DateTime(2026, 10, 20);
      final pin = MemoryPin(
        id: 'pin_test_100',
        teamId: 'team_alpha',
        placeName: '東京タワー',
        address: '東京都港区芝公園4-2-8',
        prefecture: '東京都',
        latitude: 35.6586,
        longitude: 139.7454,
        mapNormalizedPosition: const Offset(0.65, 0.55),
        startTime: '10:00',
        endTime: '12:00',
        rating: 5,
        comment: '夜景が綺麗でした。',
        photoLabels: const ['展望台', '夜景'],
        photos: [
          AppPhoto(
            id: 'ph_1',
            label: '展望台',
            url: 'https://example.com/tower.jpg',
            isFromGooglePhotos: true,
          ),
        ],
        recordedDate: recordedDate,
        tripId: 'trip_kanto',
        shareLocation: true,
        isRouteWaypointOnly: false,
      );

      final firestoreData = pin.toFirestore();
      final restored = MemoryPin.fromFirestore('pin_test_100', firestoreData);

      expect(restored.id, pin.id);
      expect(restored.teamId, pin.teamId);
      expect(restored.placeName, pin.placeName);
      expect(restored.address, pin.address);
      expect(restored.prefecture, pin.prefecture);
      expect(restored.latitude, pin.latitude);
      expect(restored.longitude, pin.longitude);
      expect(restored.rating, pin.rating);
      expect(restored.comment, pin.comment);
      expect(restored.photoLabels, ['展望台', '夜景']);
      expect(restored.photos.length, 1);
      expect(restored.photos.first.url, 'https://example.com/tower.jpg');
      expect(restored.tripId, 'trip_kanto');
    });

    test('TripMemory toFirestore と fromFirestore が可逆であること', () {
      final pin = MemoryPin(
        id: 'pin_test_sub',
        teamId: 'team_alpha',
        placeName: '鎌倉大仏',
        address: '神奈川県鎌倉市長谷4-2-28',
        prefecture: '神奈川県',
        latitude: 35.3167,
        longitude: 139.5361,
        mapNormalizedPosition: const Offset(0.62, 0.63),
        startTime: '13:00',
        endTime: '14:00',
        rating: 4,
        comment: '迫力がありました。',
        photoLabels: const ['大仏前写真'],
      );

      final trip = TripMemory(
        id: 'trip_kamakura',
        teamId: 'team_alpha',
        title: '秋の鎌倉日帰り散策',
        startDate: DateTime(2026, 11, 1),
        endDate: DateTime(2026, 11, 1),
        pins: [pin],
        customDistanceKm: 15.5,
      );

      final firestoreData = trip.toFirestore();
      final restored = TripMemory.fromFirestore('trip_kamakura', firestoreData);

      expect(restored.id, trip.id);
      expect(restored.teamId, trip.teamId);
      expect(restored.title, '秋の鎌倉日帰り散策');
      expect(restored.pins.length, 1);
      expect(restored.pins.first.placeName, '鎌倉大仏');
      expect(restored.customDistanceKm, 15.5);
    });
  });

  group('TripService 共同編集・フォールバック機能の検証', () {
    final tripService = TripService.instance;

    test('ピンの新規保存と更新（編集）が反映されること', () async {
      const groupId = 'test_group_editing';
      final pin = MemoryPin(
        id: 'pin_edit_test',
        teamId: groupId,
        placeName: '初期スポット名',
        address: '東京都千代田区',
        prefecture: '東京都',
        latitude: 35.6895,
        longitude: 139.6917,
        mapNormalizedPosition: const Offset(0.66, 0.56),
        startTime: '10:00',
        endTime: '11:00',
        rating: 3,
        comment: '最初のコメント',
        photoLabels: const [],
      );

      await tripService.savePin(pin);

      // ピンを編集
      final editedPin = pin.copyWith(
        placeName: '編集後のスポット名',
        rating: 5,
        comment: '更新された最高のコメント！',
      );
      await tripService.savePin(editedPin);

      // watchPins の最新値を確認
      final pins = await tripService.watchPins(groupId).first;
      final target = pins.firstWhere((p) => p.id == 'pin_edit_test');

      expect(target.placeName, '編集後のスポット名');
      expect(target.rating, 5);
      expect(target.comment, '更新された最高のコメント！');
    });

    test('旅行タイトルの編集（共同編集: パターンB）が即座に反映されること', () async {
      const groupId = 'test_group_trip_edit';
      final trip = TripMemory(
        id: 'trip_title_edit_test',
        teamId: groupId,
        title: '元の旅行タイトル',
        startDate: DateTime(2026, 11, 5),
        endDate: DateTime(2026, 11, 6),
        pins: const [],
      );

      await tripService.saveTrip(trip);

      // 旅行タイトルを編集
      await tripService.updateTripTitle(
        groupId: groupId,
        tripId: 'trip_title_edit_test',
        newTitle: '更新後の旅行タイトル（共同編集済み）',
      );

      final trips = await tripService.watchTrips(groupId).first;
      final target = trips.firstWhere((t) => t.id == 'trip_title_edit_test');

      expect(target.title, '更新後の旅行タイトル（共同編集済み）');
    });

    test('旅行まとめの削除が正常に動作すること', () async {
      const groupId = 'test_group_delete';
      final trip = TripMemory(
        id: 'trip_delete_test',
        teamId: groupId,
        title: '削除予定の旅行',
        startDate: DateTime(2026, 11, 7),
        endDate: DateTime(2026, 11, 8),
        pins: const [],
      );

      await tripService.saveTrip(trip);
      await tripService.deleteTrip(groupId, 'trip_delete_test');

      final trips = await tripService.watchTrips(groupId).first;
      expect(trips.any((t) => t.id == 'trip_delete_test'), isFalse);
    });

    test(
      'GroupService.saveMemory 経由で追加された思い出も TripService.watchTrips に反映されること',
      () async {
        const groupId = 'test_group_friend_sync';
        final friendMemory = TripMemory(
          id: 'trip_friend_manual_1',
          teamId: groupId,
          title: '友人が追加した箱根の思い出',
          startDate: DateTime(2026, 11, 8, 9, 0),
          endDate: DateTime(2026, 11, 8, 20, 0),
          pins: const [],
        );

        await GroupService.instance.saveMemory(friendMemory);

        final trips = await tripService.watchTrips(groupId).first;
        final matched = trips
            .where((t) => t.id == 'trip_friend_manual_1')
            .firstOrNull;
        expect(matched, isNotNull);
        expect(matched!.title, '友人が追加した箱根の思い出');
      },
    );

    test('思い出作成後に友人が同じ旅行期間のスポット（ピン）を追加した場合、既存の思い出に自動反映されること', () async {
      const groupId = 'test_group_window_match';
      final trip = TripMemory(
        id: 'trip_window_1',
        teamId: groupId,
        title: '伊豆グループ旅行',
        startDate: DateTime(2026, 11, 9, 9, 0),
        endDate: DateTime(2026, 11, 9, 21, 0),
        pins: const [],
      );

      await tripService.saveTrip(trip);

      // 友人が旅行スタートを押さずに（tripId == null）、同じ日時のピンを記録した場合
      final friendPin = MemoryPin(
        id: 'pin_friend_izu',
        teamId: groupId,
        placeName: '熱海プリン',
        address: '静岡県熱海市田原本町3-14',
        prefecture: '静岡県',
        latitude: 35.1030,
        longitude: 139.0777,
        mapNormalizedPosition: const Offset(0.60, 0.65),
        startTime: '14:00',
        endTime: '15:00',
        rating: 5,
        comment: '友人が追加したプリンレビュー',
        photoLabels: const ['プリン'],
        recordedDate: DateTime(2026, 11, 9),
      );

      await tripService.savePin(friendPin);

      final trips = await tripService.watchTrips(groupId).first;
      final updatedTrip = trips.firstWhere((t) => t.id == 'trip_window_1');
      expect(updatedTrip.pins.any((p) => p.id == 'pin_friend_izu'), isTrue);
      expect(updatedTrip.pins.first.placeName, '熱海プリン');
    });

    test(
      'サブコレクション内のドキュメントの teamId が空または別IDでも親 groupId に正規化され件数が一致すること',
      () async {
        const parentGroupId = 'group_actual_parent';
        final rawFirestoreData = <String, dynamic>{
          'teamId': 'daily_wrong_id',
          'title': '別IDで保存されていた思い出',
          'startDate': '2026-11-09T09:00:00.000',
          'endDate': '2026-11-09T18:00:00.000',
          'pins': [
            {'id': 'pin_sub_1', 'teamId': '', 'placeName': '箱根神社'},
          ],
        };

        final restored = TripMemory.fromFirestore(
          'trip_legacy_1',
          rawFirestoreData,
          fallbackTeamId: parentGroupId,
        );

        expect(restored.teamId, parentGroupId);
        expect(restored.pins.first.teamId, parentGroupId);
      },
    );

    test('refreshGroupData / fetchTrips により思い出を開くたびに最新件数が同期されること', () async {
      const groupId = 'test_group_refresh_count';
      tripService.resetForTest();

      final t1 = TripMemory(
        id: 't1',
        teamId: groupId,
        title: '思い出1',
        startDate: DateTime(2026, 11, 1),
        endDate: DateTime(2026, 11, 1),
        pins: const [],
      );
      final t2 = TripMemory(
        id: 't2',
        teamId: groupId,
        title: '思い出2',
        startDate: DateTime(2026, 11, 2),
        endDate: DateTime(2026, 11, 2),
        pins: const [],
      );

      await tripService.saveTrip(t1);
      await tripService.saveTrip(t2);

      final fetched = await tripService.fetchTrips(groupId);
      expect(fetched.length, 2);

      // 削除後に fetchTrips を呼ぶと1件になり、さらに全削除すると0件になること
      await tripService.deleteTrip(groupId, 't1');
      final afterDelete1 = await tripService.fetchTrips(groupId);
      expect(afterDelete1.length, 1);

      await tripService.deleteTrip(groupId, 't2');
      final afterDeleteAll = await tripService.fetchTrips(groupId);
      expect(afterDeleteAll, isEmpty);
    });
  });
}
