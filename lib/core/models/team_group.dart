import 'dart:math';

/// グループ（チーム）単位で思い出や訪問場所を共有するためのモデル（MVP機能④ グループ機能）
class TeamGroup {
  const TeamGroup({
    required this.id,
    required this.name,
    required this.memberCount,
    this.inviteCode = '',
    this.ownerUid = '',
    this.memberUids = const [],
    this.isPersonal = false,
    this.createdAt,
  });

  final String id;
  final String name;
  final int memberCount;
  final String inviteCode; // 英数大文字8文字の招待コード
  final String ownerUid;
  final List<String> memberUids;
  final bool isPersonal;
  final DateTime? createdAt;

  /// 英数大文字8文字の招待コードを生成（誤読しやすい 0, O, 1, I を除外した文字セット）
  static String generateInviteCode() {
    const chars = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
    final random = Random.secure();
    return List.generate(8, (_) => chars[random.nextInt(chars.length)]).join();
  }

  /// 招待コードのバリデーション（英大文字・数字8文字）
  static bool isValidInviteCode(String code) {
    final trimmed = code.trim().toUpperCase();
    return RegExp(r'^[A-Z0-9]{8}$').hasMatch(trimmed);
  }

  TeamGroup copyWith({
    String? id,
    String? name,
    int? memberCount,
    String? inviteCode,
    String? ownerUid,
    List<String>? memberUids,
    bool? isPersonal,
    DateTime? createdAt,
  }) {
    return TeamGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      memberCount: memberCount ?? this.memberCount,
      inviteCode: inviteCode ?? this.inviteCode,
      ownerUid: ownerUid ?? this.ownerUid,
      memberUids: memberUids ?? this.memberUids,
      isPersonal: isPersonal ?? this.isPersonal,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'inviteCode': inviteCode,
      'ownerUid': ownerUid,
      'memberUids': memberUids,
      'isPersonal': isPersonal,
      'createdAt':
          createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
    };
  }

  factory TeamGroup.fromFirestore(String id, Map<String, dynamic> data) {
    final members =
        (data['memberUids'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        <String>[];
    DateTime? created;
    if (data['createdAt'] is String) {
      created = DateTime.tryParse(data['createdAt'] as String);
    }

    final isPersonalGroup =
        (data['isPersonal'] as bool? ?? false) || id.startsWith('daily');
    final rawName = data['name'] as String? ?? '名称未設定';

    return TeamGroup(
      id: id,
      name: isPersonalGroup ? 'MyMap' : rawName,
      memberCount: isPersonalGroup
          ? 1
          : (members.isNotEmpty ? members.length : 1),
      inviteCode: isPersonalGroup ? '' : (data['inviteCode'] as String? ?? ''),
      ownerUid: data['ownerUid'] as String? ?? '',
      memberUids: members,
      isPersonal: isPersonalGroup,
      createdAt: created,
    );
  }

  static const List<TeamGroup> sampleTeams = [
    TeamGroup(
      id: 'daily',
      name: 'MyMap',
      memberCount: 1,
      inviteCode: '',
      isPersonal: true,
    ),
    TeamGroup(
      id: 'hakone_trip',
      name: '箱根・伊豆温泉旅',
      memberCount: 4,
      inviteCode: 'HKN2026T',
    ),
    TeamGroup(
      id: 'cafe_club',
      name: '週末カフェ巡り部',
      memberCount: 3,
      inviteCode: 'CAFE9999',
    ),
  ];
}
