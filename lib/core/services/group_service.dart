import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../models/team_group.dart';

/// グループ管理および英数大文字8文字の招待コードによる参加を処理するサービス（MVP機能④）
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

  // Firebase未接続環境/テスト環境用のローカルグループ保持
  final List<TeamGroup> _localFallbackGroups = List.from(TeamGroup.sampleTeams);
  final StreamController<List<TeamGroup>> _fallbackStreamController =
      StreamController<List<TeamGroup>>.broadcast();

  /// ユーザーが参加しているグループ一覧のストリーム
  Stream<List<TeamGroup>> watchUserGroups(String userUid) {
    final db = _firestore;
    if (db == null) {
      return Stream.value(_localFallbackGroups);
    }

    try {
      return db
          .collection('groups')
          .where('memberUids', arrayContains: userUid)
          .snapshots()
          .map((snapshot) {
            if (snapshot.docs.isEmpty) {
              return _localFallbackGroups;
            }
            return snapshot.docs
                .map((doc) => TeamGroup.fromFirestore(doc.id, doc.data()))
                .toList();
          })
          .handleError((error) {
            debugPrint('Firestore watch error: $error. Falling back to local.');
            return _localFallbackGroups;
          });
    } catch (e) {
      debugPrint('Firestore stream error: $e');
      return Stream.value(_localFallbackGroups);
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
      // ローカルサンプルから検索
      final index = _localFallbackGroups.indexWhere(
        (g) => g.inviteCode.toUpperCase() == normalizedCode,
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
}
