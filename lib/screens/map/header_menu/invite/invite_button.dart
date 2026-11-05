import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/models/team_group.dart';
import '../../../../core/theme/app_theme.dart';

/// アイデアシート「招待する」ボタンおよびメンバー招待モーダル（MVP機能④ グループ機能）
///
/// 英数大文字8文字の招待コードを表示・共有する。
class InviteButton extends StatelessWidget {
  const InviteButton({super.key, required this.selectedTeam});

  final TeamGroup selectedTeam;

  void _showInviteSheet(BuildContext context) {
    final inviteCode = selectedTeam.inviteCode.isNotEmpty
        ? selectedTeam.inviteCode
        : 'INVITE88';

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
                Row(
                  children: [
                    const Icon(
                      Icons.group_add_outlined,
                      color: AppTheme.darkGrey,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '「${selectedTeam.name}」へ招待',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.darkGrey,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  '下記の8文字の招待コードを仲間に共有してください。アプリ内でコードを入力するとグループに参加できます。',
                  style: TextStyle(fontSize: 13, color: AppTheme.primaryGrey),
                ),
                const SizedBox(height: 16),

                // 英数大文字8文字の招待コード表示カード
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceGrey,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.lightGrey, width: 1.5),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        '招待コード（英数大文字8桁）',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.mediumGrey,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        inviteCode,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.darkGrey,
                          letterSpacing: 4.0,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 招待コードをコピーするボタン
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.darkGrey,
                      foregroundColor: AppTheme.pureWhite,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: inviteCode));
                      if (sheetContext.mounted) {
                        Navigator.of(sheetContext).pop();
                      }
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('招待コード「$inviteCode」をクリップボードにコピーしました'),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('招待コードをコピー'),
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
