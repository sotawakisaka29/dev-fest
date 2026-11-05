import 'package:flutter/material.dart';
import '../../../../core/models/team_group.dart';
import '../../../../core/theme/app_theme.dart';

/// アイデアシート「招待する」ボタンおよびメンバー招待モーダル（MVP機能④ グループ機能）
class InviteButton extends StatelessWidget {
  const InviteButton({super.key, required this.selectedTeam});

  final TeamGroup selectedTeam;

  void _showInviteSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.pureWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '「${selectedTeam.name}」へメンバーを招待',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkGrey,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '招待されたメンバーのみがこのグループの訪問場所・写真・思い出を閲覧・追加できます。',
                  style: TextStyle(fontSize: 13, color: AppTheme.primaryGrey),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceGrey,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.lightGrey),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.link,
                        size: 18,
                        color: AppTheme.primaryGrey,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'https://mymap.example.com/invite/${selectedTeam.id}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.darkGrey,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('「${selectedTeam.name}」の招待リンクを発行しました'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.mail_outline, size: 18),
                    label: const Text('招待リンクをコピーして送る'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _showInviteSheet(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mail_outline, size: 24, color: AppTheme.darkGrey),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.only(bottom: 2),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppTheme.darkGrey, width: 1.2),
                ),
              ),
              child: const Text(
                '招待する',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.darkGrey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
