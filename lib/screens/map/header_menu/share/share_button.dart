import 'package:flutter/material.dart';
import '../../../../core/models/team_group.dart';
import '../../../../core/theme/app_theme.dart';

/// アイデアシート「共有する」ボタンおよび公開範囲制御付きシェアシート（MVP機能⑤ シェア機能）
class ShareButton extends StatelessWidget {
  const ShareButton({
    super.key,
    required this.selectedTeam,
    required this.pinCount,
  });

  final TeamGroup selectedTeam;
  final int pinCount;

  void _showShareSheet(BuildContext context) {
    String selectedScope = 'group_only';
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.pureWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '「${selectedTeam.name}」のマップを共有',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkGrey,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '記録数：$pinCount件（公開範囲を指定して安全にシェアできます）',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.primaryGrey,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _ScopeOptionTile(
                      title: 'グループメンバーのみ（非公開）',
                      subtitle: '所属メンバー以外はアクセスできません',
                      isSelected: selectedScope == 'group_only',
                      onTap: () =>
                          setModalState(() => selectedScope = 'group_only'),
                    ),
                    const SizedBox(height: 8),
                    _ScopeOptionTile(
                      title: '共有リンクを知っている人のみ閲覧可能',
                      subtitle: '位置共有ONの記録のみWebビューア等で閲覧を許可します',
                      isSelected: selectedScope == 'link_viewer',
                      onTap: () =>
                          setModalState(() => selectedScope = 'link_viewer'),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                selectedScope == 'group_only'
                                    ? '公開範囲を「グループメンバーのみ」に設定しました'
                                    : '限定共有リンクを発行しました',
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.send_outlined, size: 18),
                        label: const Text('設定を保存してシェア'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  static const List<Shadow> _labelShadows = [
    Shadow(color: Colors.white, blurRadius: 8),
    Shadow(color: Colors.white, blurRadius: 14),
  ];

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _showShareSheet(context),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.send_outlined,
              size: 29,
              color: AppTheme.darkGrey,
              shadows: _labelShadows,
            ),
            SizedBox(height: 4),
            Text(
              '共有する',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.darkGrey,
                shadows: _labelShadows,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScopeOptionTile extends StatelessWidget {
  const _ScopeOptionTile({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.surfaceGrey : AppTheme.pureWhite,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.darkGrey : AppTheme.lightGrey,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked,
              size: 20,
              color: isSelected ? AppTheme.darkGrey : AppTheme.mediumGrey,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.darkGrey,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.primaryGrey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
