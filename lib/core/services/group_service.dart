import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../models/memory_pin.dart';
import '../models/team_group.dart';
import '../models/trip_memory.dart';

/// グループ（部屋）管理・招待コード参加・部屋データ（ピン・思い出）のDB保持を処理するサービス
class GroupService {
  GroupService._();
  static final GroupService instance = GroupService._();

  bool get isFirebaseInitialized => Firebase.apps.isNotEmpty;

  FirebaseFirestore? get _firestore {
    if (!isFirebaseInitialized) return null;
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  // Firebase未接続環境/テスト環境用のローカル保持データ
  final List<TeamGroup> _localFallbackGroups = List.from(TeamGroup.sampleTeams);
  final Map<String, List<MemoryPin>> _localGroupPins = {};
  final Map<String, List<TripMemory>> _localGroupMemories = {};
  final Set<String> _ensuringPersonalGroupUids = {};

  final StreamController<List<TeamGroup>> _fallbackStreamController =
      StreamController<List<TeamGroup>>.broadcast();

  /// グループ一覧で必ず「MyMap」（isPersonal == true）を先頭に配置して返すヘルパー
  List<TeamGroup> _sortWithPersonalFirst(
    List<TeamGroup> groups,
    String userUid,
  ) {
    final defaultId = 'daily_$userUid';
    final hasPersonal = groups.any((g) => g.isPersonal);
    final result = List<TeamGroup>.from(groups);
    if (!hasPersonal) {
      result.insert(
        0,
        TeamGroup(
          id: defaultId,
          name: 'MyMap',
          memberCount: 1,
          inviteCode: '',
          ownerUid: userUid,
          memberUids: [userUid],
          isPersonal: true,
        ),
      );
    } else {
      result.sort((a, b) {
        if (a.isPersonal == b.isPersonal) return 0;
        return a.isPersonal ? -1 : 1;
      });
    }
    return result;
  }

  /// ログインユーザーのデフォルト個人部屋（「MyMap」）が存在しない場合にDBへ作成する
  Future<TeamGroup> ensureDefaultPersonalGroup(String userUid) async {
    final defaultId = 'daily_$userUid';
    final personalGroup = TeamGroup(
      id: defaultId,
      name: 'MyMap',
      memberCount: 1,
      inviteCode: '',
      ownerUid: userUid,
      memberUids: [userUid],
      isPersonal: true,
      createdAt: DateTime.now(),
    );

    final db = _firestore;
    if (db == null) {
      final existingIndex = _localFallbackGroups.indexWhere(
        (g) => g.id == defaultId || (g.isPersonal && g.ownerUid == userUid),
      );
      if (existingIndex != -1) {
        return _localFallbackGroups[existingIndex];
      }
      _localFallbackGroups.insert(0, personalGroup);
      return personalGroup;
    }

    try {
      final docRef = db.collection('groups').doc(defaultId);
      final docSnap = await docRef.get();
      if (docSnap.exists && docSnap.data() != null) {
        return TeamGroup.fromFirestore(docSnap.id, docSnap.data()!);
      }
      await docRef.set(personalGroup.toFirestore());
      return personalGroup;
    } catch (e) {
      debugPrint('Failed to ensure personal group in Firestore: $e');
      return personalGroup;
    }
  }

  /// ユーザーが参加しているグループ（部屋）一覧のストリーム
  Stream<List<TeamGroup>> watchUserGroups(String userUid) {
    final db = _firestore;
    if (db == null) {
      final userGroups = _localFallbackGroups
          .where((g) => g.memberUids.contains(userUid))
          .toList();
      if (userGroups.isEmpty) {
        final personal = TeamGroup(
          id: 'daily_$userUid',
          name: 'MyMap',
          memberCount: 1,
          inviteCode: '',
          ownerUid: userUid,
          memberUids: [userUid],
          isPersonal: true,
          createdAt: DateTime.now(),
        );
        _localFallbackGroups.add(personal);
        return Stream.value([personal]);
      }
      return Stream.value(_sortWithPersonalFirst(userGroups, userUid));
    }

    try {
      return db
          .collection('groups')
          .where('memberUids', arrayContains: userUid)
          .snapshots()
          .map((snapshot) {
            final groups = snapshot.docs
                .map((doc) => TeamGroup.fromFirestore(doc.id, doc.data()))
                .toList();
            final hasPersonal = groups.any((g) => g.isPersonal);
            if (!hasPersonal && !_ensuringPersonalGroupUids.contains(userUid)) {
              _ensuringPersonalGroupUids.add(userUid);
              ensureDefaultPersonalGroup(userUid).whenComplete(() {
                _ensuringPersonalGroupUids.remove(userUid);
              });
            }
            return _sortWithPersonalFirst(groups, userUid);
          })
          .handleError((error) {
            debugPrint('Firestore watch error: $error. Falling back to local.');
            return _sortWithPersonalFirst(_localFallbackGroups, userUid);
          });
    } catch (e) {
      debugPrint('Firestore stream error: $e');
      return Stream.value(
        _sortWithPersonalFirst(_localFallbackGroups, userUid),
      );
    }
  }

  /// 新規グループの作成（英数大文字8文字の招待コードを自動発行）
  Future<TeamGroup> createGroup({
    required String name,
    required String creatorUid,
  }) async {
    final inviteCode = TeamGroup.generateInviteCode();
    final newGroup = TeamGroup(
      id: 'group_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      memberCount: 1,
      inviteCode: inviteCode,
      ownerUid: creatorUid,
      memberUids: [creatorUid],
      createdAt: DateTime.now(),
    );

    final db = _firestore;
    if (db == null) {
      _localFallbackGroups.add(newGroup);
      _fallbackStreamController.add(List.unmodifiable(_localFallbackGroups));
      return newGroup;
    }

    try {
      final docRef = await db.collection('groups').add(newGroup.toFirestore());
      return newGroup.copyWith(id: docRef.id);
    } catch (e) {
      debugPrint('Firestore create group error: $e. Saving to local fallback.');
      _localFallbackGroups.add(newGroup);
      _fallbackStreamController.add(List.unmodifiable(_localFallbackGroups));
      return newGroup;
    }
  }

  /// 英数大文字8文字の招待コードでグループに参加
  Future<TeamGroup> joinGroupByInviteCode({
    required String inviteCode,
    required String userUid,
  }) async {
    final normalizedCode = inviteCode.trim().toUpperCase();
    if (!TeamGroup.isValidInviteCode(normalizedCode)) {
      throw Exception('招待コードは英大文字・数字8文字で入力してください。');
    }

    final db = _firestore;
    if (db == null) {
      // ローカルサンプルから検索（個人用のMyMapは招待対象外）
      final index = _localFallbackGroups.indexWhere(
        (g) => !g.isPersonal && g.inviteCode.toUpperCase() == normalizedCode,
      );
      if (index == -1) {
        throw Exception('該当する招待コードのグループが見つかりませんでした。');
      }
      final target = _localFallbackGroups[index];
      if (!target.memberUids.contains(userUid)) {
        final updated = target.copyWith(
          memberCount: target.memberCount + 1,
          memberUids: [...target.memberUids, userUid],
        );
        _localFallbackGroups[index] = updated;
        _fallbackStreamController.add(List.unmodifiable(_localFallbackGroups));
        return updated;
      }
      return target;
    }

    try {
      final querySnapshot = await db
          .collection('groups')
          .where('inviteCode', isEqualTo: normalizedCode)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        throw Exception('招待コード（$normalizedCode）に一致するグループが見つかりません。');
      }

      final doc = querySnapshot.docs.first;
      final group = TeamGroup.fromFirestore(doc.id, doc.data());
      if (group.isPersonal) {
        throw Exception('個人用グループ（MyMap）には参加できません。');
      }

      if (!group.memberUids.contains(userUid)) {
        await doc.reference.update({
          'memberUids': FieldValue.arrayUnion([userUid]),
        });
        return group.copyWith(
          memberCount: group.memberCount + 1,
          memberUids: [...group.memberUids, userUid],
        );
      }

      return group;
    } catch (e) {
      debugPrint('Firestore join error: $e');
      rethrow;
    }
  }

  /// 指定したグループ（部屋）のピン一覧をDBから取得する
  Future<List<MemoryPin>> fetchGroupPins(String groupId) async {
    final db = _firestore;
    if (db == null) {
      return List<MemoryPin>.from(_localGroupPins[groupId] ?? const []);
    }

    try {
      final snapshot = await db
          .collection('groups')
          .doc(groupId)
          .collection('pins')
          .get();
      return snapshot.docs
          .map((doc) => MemoryPin.fromFirestore(doc.id, doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Firestore fetchGroupPins error: $e');
      return List<MemoryPin>.from(_localGroupPins[groupId] ?? const []);
    }
  }

  /// ピンを部屋のDBに保存する
  Future<void> savePin(MemoryPin pin) async {
    final localList = _localGroupPins.putIfAbsent(
      pin.teamId,
      () => <MemoryPin>[],
    );
    localList.removeWhere((p) => p.id == pin.id);
    localList.add(pin);

    final db = _firestore;
    if (db == null) return;

    try {
      await db
          .collection('groups')
          .doc(pin.teamId)
          .collection('pins')
          .doc(pin.id)
          .set(pin.toFirestore());
    } catch (e) {
      debugPrint('Firestore savePin error: $e');
    }
  }

  /// 指定したグループ（部屋）の旅行思い出一覧をDBから取得する
  Future<List<TripMemory>> fetchGroupMemories(String groupId) async {
    final db = _firestore;
    if (db == null) {
      return List<TripMemory>.from(_localGroupMemories[groupId] ?? const []);
    }

    try {
      final snapshot = await db
          .collection('groups')
          .doc(groupId)
          .collection('memories')
          .get();
      return snapshot.docs
          .map((doc) => TripMemory.fromFirestore(doc.id, doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Firestore fetchGroupMemories error: $e');
      return List<TripMemory>.from(_localGroupMemories[groupId] ?? const []);
    }
  }

  /// 旅行思い出を部屋のDBに保存する
  Future<void> saveMemory(TripMemory memory) async {
    final localList = _localGroupMemories.putIfAbsent(
      memory.teamId,
      () => <TripMemory>[],
    );
    localList.removeWhere((m) => m.id == memory.id);
    localList.insert(0, memory);

    final db = _firestore;
    if (db == null) return;

    try {
      await db
          .collection('groups')
          .doc(memory.teamId)
          .collection('memories')
          .doc(memory.id)
          .set(memory.toFirestore());
    } catch (e) {
      debugPrint('Firestore saveMemory error: $e');
    }
  }

  /// 旅行思い出を部屋のDBから削除する
  Future<void> deleteMemory(String groupId, String memoryId) async {
    _localGroupMemories[groupId]?.removeWhere((m) => m.id == memoryId);

    final db = _firestore;
    if (db == null) return;

    try {
      await db
          .collection('groups')
          .doc(groupId)
          .collection('memories')
          .doc(memoryId)
          .delete();
    } catch (e) {
      debugPrint('Firestore deleteMemory error: $e');
    }
  }
}
