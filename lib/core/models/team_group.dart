/// グループ（チーム）単位で思い出や訪問場所を共有するためのモデル
class TeamGroup {
  const TeamGroup({
    required this.id,
    required this.name,
    required this.memberCount,
    this.isPersonal = false,
  });

  final String id;
  final String name;
  final int memberCount;
  final bool isPersonal;

  static const List<TeamGroup> sampleTeams = [
    TeamGroup(id: 'daily', name: '日常', memberCount: 1, isPersonal: true),
    TeamGroup(id: 'hakone_trip', name: '箱根・伊豆温泉旅', memberCount: 4),
    TeamGroup(id: 'cafe_club', name: '週末カフェ巡り部', memberCount: 3),
  ];
}
