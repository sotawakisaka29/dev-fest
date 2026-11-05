import 'package:flutter/material.dart';
import '../../../../core/models/team_group.dart';
import '../../../../core/theme/app_theme.dart';

/// アイデアシート「チーム名 ∨ プルダウンで別チームに」を実現するWidget（MVP機能④ グループ機能）
///
/// グループの切替、新規作成、および英数大文字8文字の招待コードによる参加をサポート。
class TeamSelectorDropdown extends StatelessWidget {
  const TeamSelectorDropdown({
    super.key,
    required this.teams,
    required this.selectedTeam,
    required this.onTeamSelected,
    required this.onCreateTeam,
    required this.onJoinTeamByCode,
  });

  final List<TeamGroup> teams;
  final TeamGroup selectedTeam;
  final ValueChanged<TeamGroup> onTeamSelected;
  final ValueChanged<String> onCreateTeam;
  final ValueChanged<String> onJoinTeamByCode;

  Future<void> _showCreateTeamDialog(BuildContext context) async {
    final controller = TextEditingController();
    final createdName = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('新しいグループを作成'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: '例：夏休み北海道旅行、グルメ部'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () {
                final text = controller.text.trim();
                if (text.isNotEmpty) {
                  Navigator.of(dialogContext).pop(text);
                }
              },
              child: const Text('作成'),
            ),
          ],
        );
      },
    );

    if (createdName != null && createdName.isNotEmpty) {
      onCreateTeam(createdName);
    }
  }

  Future<void> _showJoinTeamDialog(BuildContext context) async {
    final controller = TextEditingController();
    String? errorMessage;

    final inviteCode = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('招待コードでグループに参加'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '共有された英数大文字8桁の招待コードを入力してください。',
                    style: TextStyle(fontSize: 13, color: AppTheme.primaryGrey),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 8,
                    style: const TextStyle(
                      letterSpacing: 3.0,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                    decoration: InputDecoration(
                      hintText: '例：K7M9P2X4',
                      errorText: errorMessage,
                      counterText: '',
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (val) {
                      if (errorMessage != null) {
                        setDialogState(() => errorMessage = null);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('キャンセル'),
                ),
                FilledButton(
                  onPressed: () {
                    final code = controller.text.trim().toUpperCase();
                    if (!TeamGroup.isValidInviteCode(code)) {
                      setDialogState(() {
                        errorMessage = '英数大文字8文字で入力してください';
                      });
                      return;
                    }
                    Navigator.of(dialogContext).pop(code);
                  },
                  child: const Text('参加する'),
                ),
              ],
            );
          },
        );
      },
    );

    if (inviteCode != null && inviteCode.isNotEmpty) {
      onJoinTeamByCode(inviteCode);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // アイデアシート close-up 左側の縦インジケータ表現
        Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(teams.length.clamp(2, 5), (index) {
            final isCurrent =
                index < teams.length && teams[index].id == selectedTeam.id;
            return Container(
              width: 3,
              height: isCurrent ? 10 : 4,
              margin: const EdgeInsets.symmetric(vertical: 1.5),
              decoration: BoxDecoration(
                color: isCurrent ? AppTheme.darkGrey : AppTheme.lightGrey,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        ),
        const SizedBox(width: 10),
        PopupMenuButton<String>(
          tooltip: 'チーム（グループ）を切り替え',
          color: AppTheme.pureWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppTheme.lightGrey),
          ),
          onSelected: (value) {
            if (value == '__create_new__') {
              _showCreateTeamDialog(context);
              return;
            }
            if (value == '__join_by_code__') {
              _showJoinTeamDialog(context);
              return;
            }
            final matched = teams.firstWhere(
              (team) => team.id == value,
              orElse: () => selectedTeam,
            );
            onTeamSelected(matched);
          },
          itemBuilder: (context) => [
            ...teams.map(
              (team) => PopupMenuItem<String>(
                value: team.id,
                child: Row(
                  children: [
                    Icon(
                      team.isPersonal
                          ? Icons.person_outline
                          : Icons.groups_outlined,
                      size: 18,
                      color: team.id == selectedTeam.id
                          ? AppTheme.darkGrey
                          : AppTheme.mediumGrey,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            team.name,
                            style: TextStyle(
                              fontWeight: team.id == selectedTeam.id
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: AppTheme.darkGrey,
                            ),
                          ),
                          if (team.inviteCode.isNotEmpty)
                            Text(
                              'コード: ${team.inviteCode}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppTheme.mediumGrey,
                                letterSpacing: 1.0,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      '${team.memberCount}人',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.mediumGrey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem<String>(
              value: '__join_by_code__',
              child: Row(
                children: [
                  Icon(Icons.key_outlined, size: 18, color: AppTheme.darkGrey),
                  SizedBox(width: 10),
                  Text(
                    '招待コードで参加...',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.darkGrey,
                    ),
                  ),
                ],
              ),
            ),
            const PopupMenuItem<String>(
              value: '__create_new__',
              child: Row(
                children: [
                  Icon(Icons.add, size: 18, color: AppTheme.darkGrey),
                  SizedBox(width: 10),
                  Text(
                    '新規グループを作成...',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.darkGrey,
                    ),
                  ),
                ],
              ),
            ),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    selectedTeam.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkGrey,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 26,
                  color: AppTheme.darkGrey,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
