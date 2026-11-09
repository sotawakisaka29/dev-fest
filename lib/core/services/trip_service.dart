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

  MemoryPin? _safeParsePin(
    String docId,
    Map<String, dynamic> data,
    String groupId,
  ) {
    try {
      return MemoryPin.fromFirestore(docId, data, fallbackTeamId: groupId);
    } catch (e) {
      debugPrint('Failed to parse MemoryPin ($docId) in $groupId: $e');
      return null;
    }
  }

  TripMemory? _safeParseTrip(
    String docId,
    Map<String, dynamic> data,
    String groupId,
  ) {
    // 共有スナップショット用ドキュメント（sh_*）は思い出一覧の対象から除外
    if (docId.startsWith('sh_') || data.containsKey('shareId')) {
      return null;
    }
    try {
      return TripMemory.fromFirestore(docId, data, fallbackTeamId: groupId);
    } catch (e) {
      debugPrint('Failed to parse TripMemory ($docId) in $groupId: $e');
      return null;
    }
  }

  /// Firestore から指定グループの最新ピン一覧を明示的に取得（DBアクセス）して同期する
  Future<List<MemoryPin>> fetchPins(String groupId) async {
    final db = _firestore;
    if (db == null) {
      final local = List<MemoryPin>.unmodifiable(
        _localPins[groupId] ?? const [],
      );
      _getPinsController(groupId).add(local);
      return local;
    }

    try {
      final snapshot = await db
          .collection('groups')
          .doc(groupId)
          .collection('pins')
          .get();
      final pins = snapshot.docs
          .map((doc) => _safeParsePin(doc.id, doc.data(), groupId))
          .whereType<MemoryPin>()
          .toList();
      _localPins[groupId] = pins;
      final unmodifiable = List<MemoryPin>.unmodifiable(pins);
      _getPinsController(groupId).add(unmodifiable);
      return unmodifiable;
    } catch (e) {
      debugPrint('Firestore fetchPins error for $groupId: $e');
      return List<MemoryPin>.unmodifiable(_localPins[groupId] ?? const []);
    }
  }

  /// Firestore から指定グループの最新思い出（trips & memories）およびピンを明示的に取得（DBアクセス）して同期する
  Future<List<TripMemory>> fetchTrips(String groupId) async {
    final db = _firestore;
    if (db == null) {
      final localPins = _localPins[groupId] ?? const [];
      final localTrips = _mergePinsIntoTrips(
        List<TripMemory>.from(_localTrips[groupId] ?? const []),
        localPins,
      );
      _localTrips[groupId] = localTrips;
      final unmodifiable = List<TripMemory>.unmodifiable(localTrips);
      _getTripsController(groupId).add(unmodifiable);
      return unmodifiable;
    }

    try {
      final results = await Future.wait([
        db.collection('groups').doc(groupId).collection('trips').get(),
        db.collection('groups').doc(groupId).collection('memories').get(),
        db.collection('groups').doc(groupId).collection('pins').get(),
      ]);

      final tripsSnap = results[0];
      final memoriesSnap = results[1];
      final pinsSnap = results[2];

      final latestPins = pinsSnap.docs
          .map((doc) => _safeParsePin(doc.id, doc.data(), groupId))
          .whereType<MemoryPin>()
          .toList();
      _localPins[groupId] = latestPins;
      _getPinsController(groupId).add(List<MemoryPin>.unmodifiable(latestPins));

      final Map<String, TripMemory> mergedMap = {};
      for (final doc in memoriesSnap.docs) {
        final parsed = _safeParseTrip(doc.id, doc.data(), groupId);
        if (parsed != null) {
          mergedMap[doc.id] = parsed;
        }
      }
      for (final doc in tripsSnap.docs) {
        final parsed = _safeParseTrip(doc.id, doc.data(), groupId);
        if (parsed != null) {
          mergedMap[doc.id] = parsed;
        }
      }

      final combinedList = _mergePinsIntoTrips(
        mergedMap.values.toList(),
        latestPins,
      );
      combinedList.sort((a, b) => b.startDate.compareTo(a.startDate));

      _localTrips[groupId] = combinedList;
      final unmodifiable = List<TripMemory>.unmodifiable(combinedList);
      _getTripsController(groupId).add(unmodifiable);
      return unmodifiable;
    } catch (e) {
      debugPrint('Firestore fetchTrips error for $groupId: $e');
      return List<TripMemory>.unmodifiable(_localTrips[groupId] ?? const []);
    }
  }

  /// 指定グループの思い出・ピンを両方DBから最新取得してストリーム購読者全員へ即時反映する
  Future<void> refreshGroupData(String groupId) async {
    if (groupId.isEmpty) return;
    await fetchTrips(groupId);
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

    late final StreamController<List<MemoryPin>> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? firestoreSub;
    StreamSubscription<List<MemoryPin>>? localBusSub;

    controller = StreamController<List<MemoryPin>>.broadcast(
      onListen: () {
        // まず現在キャッシュされている値があれば即座に通知
        if (_localPins.containsKey(groupId) && !controller.isClosed) {
          controller.add(List<MemoryPin>.unmodifiable(_localPins[groupId]!));
        }

        localBusSub = _getPinsController(groupId).stream.listen((pins) {
          if (!controller.isClosed) {
            controller.add(List<MemoryPin>.unmodifiable(pins));
          }
        });

        try {
          firestoreSub = db
              .collection('groups')
              .doc(groupId)
              .collection('pins')
              .snapshots()
              .listen(
                (snapshot) {
                  final pins = snapshot.docs
                      .map((doc) => _safeParsePin(doc.id, doc.data(), groupId))
                      .whereType<MemoryPin>()
                      .toList();
                  _localPins[groupId] = pins;
                  if (!controller.isClosed) {
                    controller.add(List<MemoryPin>.unmodifiable(pins));
                  }
                },
                onError: (Object error) {
                  debugPrint(
                    'Firestore watchPins error: $error. Falling back to local.',
                  );
                  if (!controller.isClosed) {
                    controller.add(_localPins[groupId] ?? fallbackList);
                  }
                },
              );
        } catch (e) {
          debugPrint('Firestore watchPins stream error: $e');
          if (!controller.isClosed) {
            controller.add(fallbackList);
          }
        }
      },
      onCancel: () async {
        await firestoreSub?.cancel();
        await localBusSub?.cancel();
      },
    );

    return controller.stream;
  }

  /// 旅行まとめ内のピン一覧に、最新のピン情報（同IDの更新、またはtripId一致・期間一致のピン）をマージする
  List<TripMemory> _mergePinsIntoTrips(
    List<TripMemory> trips,
    List<MemoryPin> latestPins,
  ) {
    if (trips.isEmpty || latestPins.isEmpty) return trips;

    final pinById = {for (final p in latestPins) p.id: p};

    return trips.map((trip) {
      final Map<String, MemoryPin> mergedPinsMap = {};

      // 1. 旅行に既に含まれているピンを最新状態に更新
      for (final existingPin in trip.pins) {
        mergedPinsMap[existingPin.id] = pinById[existingPin.id] ?? existingPin;
      }

      // 2. tripId がこの旅行と一致するピン、または tripId 未設定で旅行期間に一致する同グループのピンを追加
      for (final pin in latestPins) {
        if (pin.teamId != trip.teamId) continue;
        final isExplicitMatch = pin.tripId != null && pin.tripId == trip.id;
        final isTimeWindowMatch =
            pin.tripId == null &&
            pin.matchesTimeWindow(trip.startDate, trip.endDate);
        if (isExplicitMatch || isTimeWindowMatch) {
          mergedPinsMap[pin.id] = pin;
        }
      }

      return trip.copyWith(pins: mergedPinsMap.values.toList());
    }).toList();
  }

  /// グループに紐づく旅行一覧のリアルタイムストリーム
  ///
  /// `/groups/{groupId}/trips` と旧 `/groups/{groupId}/memories` の両方を監視・統合し、
  /// さらに `/groups/{groupId}/pins` の最新ピン情報および `fetchTrips` による明示的DB取得結果とも同期する。
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

    late final StreamController<List<TripMemory>> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? tripsSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? memoriesSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? pinsSub;
    StreamSubscription<List<TripMemory>>? localBusSub;

    List<TripMemory> latestTripsDocs = const [];
    List<TripMemory> latestMemoriesDocs = const [];
    List<MemoryPin> latestPinsDocs = _localPins[groupId] ?? const [];
    bool hasReceivedTrips = false;
    bool hasReceivedMemories = false;

    void emitMerged() {
      if (controller.isClosed) return;
      if (!hasReceivedTrips && !hasReceivedMemories) return;

      final Map<String, TripMemory> mergedMap = {};
      // 旧 memories コレクションのドキュメントを先に登録
      for (final m in latestMemoriesDocs) {
        mergedMap[m.id] = m;
      }
      // 標準の trips コレクションのドキュメントで上書き（優先）
      for (final t in latestTripsDocs) {
        mergedMap[t.id] = t;
      }

      final combinedList = _mergePinsIntoTrips(
        mergedMap.values.toList(),
        latestPinsDocs,
      );
      combinedList.sort((a, b) => b.startDate.compareTo(a.startDate));

      _localTrips[groupId] = combinedList;
      controller.add(List<TripMemory>.unmodifiable(combinedList));
    }

    controller = StreamController<List<TripMemory>>.broadcast(
      onListen: () {
        if (_localTrips.containsKey(groupId) && !controller.isClosed) {
          controller.add(List<TripMemory>.unmodifiable(_localTrips[groupId]!));
        }

        localBusSub = _getTripsController(groupId).stream.listen((trips) {
          if (!controller.isClosed) {
            controller.add(List<TripMemory>.unmodifiable(trips));
          }
        });

        try {
          tripsSub = db
              .collection('groups')
              .doc(groupId)
              .collection('trips')
              .snapshots()
              .listen(
                (snapshot) {
                  hasReceivedTrips = true;
                  latestTripsDocs = snapshot.docs
                      .map((doc) => _safeParseTrip(doc.id, doc.data(), groupId))
                      .whereType<TripMemory>()
                      .toList();
                  emitMerged();
                },
                onError: (Object error) {
                  debugPrint('Firestore watchTrips(trips) error: $error');
                  if (!controller.isClosed) {
                    controller.add(_localTrips[groupId] ?? fallbackList);
                  }
                },
              );

          memoriesSub = db
              .collection('groups')
              .doc(groupId)
              .collection('memories')
              .snapshots()
              .listen(
                (snapshot) {
                  hasReceivedMemories = true;
                  latestMemoriesDocs = snapshot.docs
                      .map((doc) => _safeParseTrip(doc.id, doc.data(), groupId))
                      .whereType<TripMemory>()
                      .toList();
                  emitMerged();
                },
                onError: (Object error) {
                  debugPrint('Firestore watchTrips(memories) error: $error');
                },
              );

          pinsSub = db
              .collection('groups')
              .doc(groupId)
              .collection('pins')
              .snapshots()
              .listen(
                (snapshot) {
                  latestPinsDocs = snapshot.docs
                      .map((doc) => _safeParsePin(doc.id, doc.data(), groupId))
                      .whereType<MemoryPin>()
                      .toList();
                  _localPins[groupId] = latestPinsDocs;
                  emitMerged();
                },
                onError: (Object error) {
                  debugPrint('Firestore watchTrips(pins) error: $error');
                },
              );
        } catch (e) {
          debugPrint('Firestore watchTrips stream setup error: $e');
          if (!controller.isClosed) {
            controller.add(fallbackList);
          }
        }
      },
      onCancel: () async {
        await tripsSub?.cancel();
        await memoriesSub?.cancel();
        await pinsSub?.cancel();
        await localBusSub?.cancel();
      },
    );

    return controller.stream;
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

    // 旅行に含まれるピン（tripId 一致、ピンID含有、または期間一致）側の pins も更新
    final trips = _localTrips[pin.teamId] ?? [];
    bool tripUpdated = false;
    for (int i = 0; i < trips.length; i++) {
      final isMatchedTrip =
          (pin.tripId != null && trips[i].id == pin.tripId) ||
          trips[i].pins.any((p) => p.id == pin.id) ||
          (pin.tripId == null &&
              pin.matchesTimeWindow(trips[i].startDate, trips[i].endDate));
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
      final Set<String> targetTripIds = {};
      if (pin.tripId != null) {
        targetTripIds.add(pin.tripId!);
      }

      // trips コレクションおよび旧 memories コレクション上で該当ピンを含む・期間一致する旅行も検索
      for (final colName in const ['trips', 'memories']) {
        try {
          final allTripsSnapshot = await db
              .collection('groups')
              .doc(pin.teamId)
              .collection(colName)
              .get();
          for (final doc in allTripsSnapshot.docs) {
            final trip = _safeParseTrip(doc.id, doc.data(), pin.teamId);
            if (trip == null) continue;
            final containsPin = trip.pins.any((p) => p.id == pin.id);
            final matchesWindow =
                pin.tripId == null &&
                pin.matchesTimeWindow(trip.startDate, trip.endDate);
            if (doc.id == pin.tripId || containsPin || matchesWindow) {
              targetTripIds.add(doc.id);
              final updatedPins = trip.pins
                  .map((p) => p.id == pin.id ? pin : p)
                  .toList();
              if (!updatedPins.any((p) => p.id == pin.id)) {
                updatedPins.add(pin);
              }
              final updatedTrip = trip.copyWith(pins: updatedPins);
              await doc.reference.set(
                updatedTrip.toFirestore(),
                SetOptions(merge: true),
              );
            }
          }
        } catch (e) {
          debugPrint('Firestore $colName search/sync error: $e');
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

    // ローカルの旅行まとめ内からも当該ピンを除去
    final trips = _localTrips[groupId];
    if (trips != null) {
      bool tripUpdated = false;
      for (int i = 0; i < trips.length; i++) {
        if (trips[i].pins.any((p) => p.id == pinId)) {
          final updatedPins = trips[i].pins
              .where((p) => p.id != pinId)
              .toList();
          trips[i] = trips[i].copyWith(pins: updatedPins);
          tripUpdated = true;
        }
      }
      if (tripUpdated) {
        _getTripsController(groupId).add(List.unmodifiable(trips));
      }
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

      // Firestore 上の trips / memories 内の pins 配列からも除去
      for (final colName in const ['trips', 'memories']) {
        try {
          final snapshot = await db
              .collection('groups')
              .doc(groupId)
              .collection(colName)
              .get();
          for (final doc in snapshot.docs) {
            final trip = _safeParseTrip(doc.id, doc.data(), groupId);
            if (trip == null) continue;
            if (trip.pins.any((p) => p.id == pinId)) {
              final updatedPins = trip.pins
                  .where((p) => p.id != pinId)
                  .toList();
              await doc.reference.update({
                'pins': updatedPins
                    .map((p) => {'id': p.id, ...p.toFirestore()})
                    .toList(),
              });
            }
          }
        } catch (e) {
          debugPrint('Firestore deletePin sync in $colName error: $e');
        }
      }
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

    // 旅行に含まれるピンの tripId もローカルピン一覧へ反映
    if (trip.pins.isNotEmpty) {
      final pinList = _localPins.putIfAbsent(trip.teamId, () => []);
      bool pinsUpdated = false;
      for (final tripPin in trip.pins) {
        final normalizedPin = tripPin.tripId == null
            ? tripPin.copyWith(tripId: trip.id)
            : tripPin;
        final pIdx = pinList.indexWhere((p) => p.id == normalizedPin.id);
        if (pIdx >= 0) {
          pinList[pIdx] = normalizedPin;
          pinsUpdated = true;
        } else {
          pinList.add(normalizedPin);
          pinsUpdated = true;
        }
      }
      if (pinsUpdated) {
        _getPinsController(trip.teamId).add(List.unmodifiable(pinList));
      }
    }

    final db = _firestore;
    if (db == null) return;

    try {
      await db
          .collection('groups')
          .doc(trip.teamId)
          .collection('trips')
          .doc(trip.id)
          .set(trip.toFirestore(), SetOptions(merge: true));

      // 含まれる各ピンの tripId も pins コレクションへ同期保存
      for (final tripPin in trip.pins) {
        final normalizedPin = tripPin.tripId == null
            ? tripPin.copyWith(tripId: trip.id)
            : tripPin;
        await db
            .collection('groups')
            .doc(trip.teamId)
            .collection('pins')
            .doc(normalizedPin.id)
            .set(normalizedPin.toFirestore(), SetOptions(merge: true));
      }
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
      final tripDoc = await db
          .collection('groups')
          .doc(groupId)
          .collection('trips')
          .doc(tripId)
          .get();
      if (tripDoc.exists) {
        await tripDoc.reference.update({'title': newTitle});
      }

      // 旧 memories コレクションに存在する場合もタイトルを更新
      final legacyDoc = await db
          .collection('groups')
          .doc(groupId)
          .collection('memories')
          .doc(tripId)
          .get();
      if (legacyDoc.exists) {
        await legacyDoc.reference.update({'title': newTitle});
      }
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
      await db
          .collection('groups')
          .doc(groupId)
          .collection('memories')
          .doc(tripId)
          .delete();
    } catch (e) {
      debugPrint('Firestore deleteTrip error: $e');
    }
  }
}
