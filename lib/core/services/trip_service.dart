import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../models/memory_pin.dart';
import '../models/trip_memory.dart';

/// 旅行情報（訪問ピン・旅行まとめ）の Firestore 永続化・リアルタイム監視・共同編集サービス
class TripService {
  TripService._() {
    _initLocalFallbacks();
  }
  static final TripService instance = TripService._();

  bool get isFirebaseInitialized => Firebase.apps.isNotEmpty;

  FirebaseFirestore? get _firestore {
    if (!isFirebaseInitialized) return null;
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  // グループIDごとのローカルフォールバック
  final Map<String, List<MemoryPin>> _localPins = {};
  final Map<String, List<TripMemory>> _localTrips = {};

  final Map<String, StreamController<List<MemoryPin>>> _pinsControllers = {};
  final Map<String, StreamController<List<TripMemory>>> _tripsControllers = {};

  void _initLocalFallbacks() {
    _localPins.clear();
    _localTrips.clear();
  }

  /// テスト用初期化リセット
  void resetForTest() {
    _initLocalFallbacks();
  }

  StreamController<List<MemoryPin>> _getPinsController(String groupId) {
    return _pinsControllers.putIfAbsent(
      groupId,
      () => StreamController<List<MemoryPin>>.broadcast(),
    );
  }

  StreamController<List<TripMemory>> _getTripsController(String groupId) {
    return _tripsControllers.putIfAbsent(
      groupId,
      () => StreamController<List<TripMemory>>.broadcast(),
    );
  }

  /// グループに紐づくピン一覧のリアルタイムストリーム
  Stream<List<MemoryPin>> watchPins(String groupId) {
    final db = _firestore;
    final fallbackList = List<MemoryPin>.unmodifiable(
      _localPins[groupId] ?? const [],
    );

    if (db == null) {
      // コントローラーの最新状態を流す
      final controller = _getPinsController(groupId);
      // 即時初期値を流す
      scheduleMicrotask(() {
        if (!controller.isClosed) {
          controller.add(List.unmodifiable(_localPins[groupId] ?? const []));
        }
      });
      return controller.stream;
    }

    try {
      return db
          .collection('groups')
          .doc(groupId)
          .collection('pins')
          .snapshots()
          .map((snapshot) {
            if (snapshot.docs.isEmpty) {
              // リモートがまだ空の場合は初期フォールバックを返す
              return _localPins[groupId] ?? const [];
            }
            return snapshot.docs.map((doc) {
              return MemoryPin.fromFirestore(doc.id, doc.data());
            }).toList();
          })
          .handleError((error) {
            debugPrint(
              'Firestore watchPins error: $error. Falling back to local.',
            );
            return fallbackList;
          });
    } catch (e) {
      debugPrint('Firestore watchPins stream error: $e');
      return Stream.value(fallbackList);
    }
  }

  /// グループに紐づく旅行一覧のリアルタイムストリーム
  Stream<List<TripMemory>> watchTrips(String groupId) {
    final db = _firestore;
    final fallbackList = List<TripMemory>.unmodifiable(
      _localTrips[groupId] ?? const [],
    );

    if (db == null) {
      final controller = _getTripsController(groupId);
      scheduleMicrotask(() {
        if (!controller.isClosed) {
          controller.add(List.unmodifiable(_localTrips[groupId] ?? const []));
        }
      });
      return controller.stream;
    }

    try {
      return db
          .collection('groups')
          .doc(groupId)
          .collection('trips')
          .snapshots()
          .map((snapshot) {
            if (snapshot.docs.isEmpty) {
              return _localTrips[groupId] ?? const [];
            }
            return snapshot.docs.map((doc) {
              return TripMemory.fromFirestore(doc.id, doc.data());
            }).toList();
          })
          .handleError((error) {
            debugPrint(
              'Firestore watchTrips error: $error. Falling back to local.',
            );
            return fallbackList;
          });
    } catch (e) {
      debugPrint('Firestore watchTrips stream error: $e');
      return Stream.value(fallbackList);
    }
  }

  /// ピンの作成・更新（グループ共同編集: パターンB）
  Future<void> savePin(MemoryPin pin) async {
    // ローカルフォールバック更新
    final list = _localPins.putIfAbsent(pin.teamId, () => []);
    final index = list.indexWhere((p) => p.id == pin.id);
    if (index >= 0) {
      list[index] = pin;
    } else {
      list.add(pin);
    }
    _getPinsController(pin.teamId).add(List.unmodifiable(list));

    // 旅行に含まれるピン（tripId 一致、またはピンIDが含まれる旅行）側の pins も更新
    final trips = _localTrips[pin.teamId] ?? [];
    bool tripUpdated = false;
    for (int i = 0; i < trips.length; i++) {
      final isMatchedTrip =
          (pin.tripId != null && trips[i].id == pin.tripId) ||
          trips[i].pins.any((p) => p.id == pin.id);
      if (isMatchedTrip) {
        final updatedPins = trips[i].pins
            .map((p) => p.id == pin.id ? pin : p)
            .toList();
        if (!updatedPins.any((p) => p.id == pin.id)) {
          updatedPins.add(pin);
        }
        trips[i] = trips[i].copyWith(pins: updatedPins);
        tripUpdated = true;
      }
    }
    if (tripUpdated) {
      _getTripsController(pin.teamId).add(List.unmodifiable(trips));
    }

    final db = _firestore;
    if (db == null) return;

    try {
      await db
          .collection('groups')
          .doc(pin.teamId)
          .collection('pins')
          .doc(pin.id)
          .set(pin.toFirestore(), SetOptions(merge: true));

      // 旅行ドキュメント内の pins 配列も同期更新
      final List<String> targetTripIds = [];
      if (pin.tripId != null) {
        targetTripIds.add(pin.tripId!);
      }

      // tripId が空の場合や念のため、Firestore 上で該当ピンを含む旅行も検索
      try {
        final allTripsSnapshot = await db
            .collection('groups')
            .doc(pin.teamId)
            .collection('trips')
            .get();
        for (final doc in allTripsSnapshot.docs) {
          if (!targetTripIds.contains(doc.id)) {
            final rawPins = doc.data()['pins'] as List<dynamic>? ?? [];
            final containsPin = rawPins.any((p) => p is Map && p['id'] == pin.id);
            if (containsPin) {
              targetTripIds.add(doc.id);
            }
          }
        }
      } catch (e) {
        debugPrint('Firestore trips search error: $e');
      }

      for (final tripId in targetTripIds) {
        final tripDoc = db
            .collection('groups')
            .doc(pin.teamId)
            .collection('trips')
            .doc(tripId);
        final snapshot = await tripDoc.get();
        if (snapshot.exists) {
          final tripData = snapshot.data();
          if (tripData != null) {
            final trip = TripMemory.fromFirestore(snapshot.id, tripData);
            final updatedPins = trip.pins
                .map((p) => p.id == pin.id ? pin : p)
                .toList();
            if (!updatedPins.any((p) => p.id == pin.id)) {
              updatedPins.add(pin);
            }
            await tripDoc.update({
              'pins': updatedPins
                  .map((p) => {'id': p.id, ...p.toFirestore()})
                  .toList(),
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Firestore savePin error: $e');
    }
  }

  /// ピンの削除
  Future<void> deletePin(String groupId, String pinId) async {
    final list = _localPins[groupId];
    if (list != null) {
      list.removeWhere((p) => p.id == pinId);
      _getPinsController(groupId).add(List.unmodifiable(list));
    }

    final db = _firestore;
    if (db == null) return;

    try {
      await db
          .collection('groups')
          .doc(groupId)
          .collection('pins')
          .doc(pinId)
          .delete();
    } catch (e) {
      debugPrint('Firestore deletePin error: $e');
    }
  }

  /// 旅行まとめの作成・保存
  Future<void> saveTrip(TripMemory trip) async {
    final list = _localTrips.putIfAbsent(trip.teamId, () => []);
    final index = list.indexWhere((t) => t.id == trip.id);
    if (index >= 0) {
      list[index] = trip;
    } else {
      list.insert(0, trip);
    }
    _getTripsController(trip.teamId).add(List.unmodifiable(list));

    final db = _firestore;
    if (db == null) return;

    try {
      await db
          .collection('groups')
          .doc(trip.teamId)
          .collection('trips')
          .doc(trip.id)
          .set(trip.toFirestore(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firestore saveTrip error: $e');
    }
  }

  /// 旅行タイトルの更新（共同編集: パターンB）
  Future<void> updateTripTitle({
    required String groupId,
    required String tripId,
    required String newTitle,
  }) async {
    final list = _localTrips[groupId];
    if (list != null) {
      final index = list.indexWhere((t) => t.id == tripId);
      if (index >= 0) {
        list[index] = list[index].copyWith(title: newTitle);
        _getTripsController(groupId).add(List.unmodifiable(list));
      }
    }

    final db = _firestore;
    if (db == null) return;

    try {
      await db
          .collection('groups')
          .doc(groupId)
          .collection('trips')
          .doc(tripId)
          .update({'title': newTitle});
    } catch (e) {
      debugPrint('Firestore updateTripTitle error: $e');
    }
  }

  /// 旅行まとめの削除
  Future<void> deleteTrip(String groupId, String tripId) async {
    final list = _localTrips[groupId];
    if (list != null) {
      list.removeWhere((t) => t.id == tripId);
      _getTripsController(groupId).add(List.unmodifiable(list));
    }

    final db = _firestore;
    if (db == null) return;

    try {
      await db
          .collection('groups')
          .doc(groupId)
          .collection('trips')
          .doc(tripId)
          .delete();
    } catch (e) {
      debugPrint('Firestore deleteTrip error: $e');
    }
  }
}
