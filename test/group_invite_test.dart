import 'package:flutter_test/flutter_test.dart';
import 'package:my_map_app/core/models/team_group.dart';
import 'package:my_map_app/core/services/group_service.dart';

void main() {
  group('招待コード（英数大文字8文字）の検証・生成テスト', () {
    test('generateInviteCode は英数大文字8桁を生成し、バリデーションを通過する', () {
      for (int i = 0; i < 20; i++) {
        final code = TeamGroup.generateInviteCode();
        expect(code.length, 8);
        expect(TeamGroup.isValidInviteCode(code), isTrue);
      }
    });

    test('isValidInviteCode の境界値テスト', () {
      expect(TeamGroup.isValidInviteCode('ABCDEF12'), isTrue);
      expect(TeamGroup.isValidInviteCode('abcdef12'), isTrue); // 小文字も正規化されてOK
      expect(TeamGroup.isValidInviteCode('ABC12'), isFalse); // 短い
      expect(TeamGroup.isValidInviteCode('ABCDEF123'), isFalse); // 長い
      expect(TeamGroup.isValidInviteCode('ABC-EF12'), isFalse); // 記号NG
    });

    test('GroupService での招待コードによるグループ参加・作成テスト（ローカルフォールバック）', () async {
      final groupService = GroupService.instance;
      final created = await groupService.createGroup(
        name: 'ハッカソン開発合宿',
        creatorUid: 'user_001',
      );

      expect(created.name, 'ハッカソン開発合宿');
      expect(created.inviteCode.length, 8);
      expect(TeamGroup.isValidInviteCode(created.inviteCode), isTrue);

      // 別ユーザーが作成された招待コードで参加
      final joined = await groupService.joinGroupByInviteCode(
        inviteCode: created.inviteCode,
        userUid: 'user_002',
      );

      expect(joined.id, created.id);
      expect(joined.memberUids.contains('user_002'), isTrue);
      expect(joined.memberCount, 2);
    });
  });
}
