import 'package:flutter/material.dart';
import '../../../core/models/team_group.dart';
import '../../../core/theme/app_theme.dart';
import 'invite/invite_button.dart';
import 'share/share_button.dart';
import 'team_selector/team_selector_dropdown.dart';
import 'trip_action/trip_action_button.dart';

/// 1倍表示時のみ画面左上に表示されるスタイリッシュなヘッダーメニュー
///
/// 白いカード背景を廃止し、文字とアイコンのみを画面左上に集約する。
/// ボタン並び：旅行スタート（開始） / 思い出 / 招待する / 共有する
class HeaderMenuOverlay extends StatelessWidget {
  const HeaderMenuOverlay({
    super.key,
    required this.visible,
    required this.teams,
    required this.selectedTeam,
    required this.isTripActive,
    required this.activeTripTitle,
    required this.pinCount,
    required this.onTeamSelected,
    required this.onCreateTeam,
    required this.onJoinTeamByCode,
    required this.onStartTrip,
    required this.onStopTrip,
    required this.onOpenMemories,
    required this.onOpenRecord,
    required this.onOpenAuth,
  });

  final bool visible;
  final List<TeamGroup> teams;
  final TeamGroup selectedTeam;
  final bool isTripActive;
  final String? activeTripTitle;
  final int pinCount;
  final ValueChanged<TeamGroup> onTeamSelected;
  final ValueChanged<String> onCreateTeam;
  final ValueChanged<String> onJoinTeamByCode;
  final VoidCallback onStartTrip;
  final VoidCallback onStopTrip;
  final VoidCallback onOpenMemories;
  final VoidCallback onOpenRecord;
  final VoidCallback onOpenAuth;

  static const List<Shadow> _labelShadows = [
    Shadow(color: Colors.white, blurRadius: 8),
    Shadow(color: Colors.white, blurRadius: 14),
  ];

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        opacity: visible ? 1.0 : 0.0,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1段目：左上にチーム名プルダウン＋アカウントアイコン
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: TeamSelectorDropdown(
                      teams: teams,
                      selectedTeam: selectedTeam,
                      onTeamSelected: onTeamSelected,
                      onCreateTeam: onCreateTeam,
                      onJoinTeamByCode: onJoinTeamByCode,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                    tooltip: 'アカウント・認証設定',
                    onPressed: onOpenAuth,
                    icon: const Icon(
                      Icons.account_circle_outlined,
                      size: 28,
                      color: AppTheme.darkGrey,
                      shadows: _labelShadows,
                    ),
                  ),
                ],
              ),
              if (isTripActive) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.fiber_manual_record,
                        size: 12,
                        color: AppTheme.accentPinRed,
                        shadows: _labelShadows,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '旅行中: ${activeTripTitle ?? '名称未設定'}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.darkGrey,
                          shadows: _labelShadows,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              // 2段目：左上にまとまった4つのアクション（開始・思い出・招待・共有）
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TripActionButton(
                    isTripActive: isTripActive,
                    onStartTrip: onStartTrip,
                    onStopTrip: onStopTrip,
                    onOpenRecord: onOpenRecord,
                  ),
                  const SizedBox(width: 8),
                  _MemoriesHeaderButton(onTap: onOpenMemories),
                  const SizedBox(width: 8),
                  InviteButton(selectedTeam: selectedTeam),
                  const SizedBox(width: 8),
                  ShareButton(selectedTeam: selectedTeam, pinCount: pinCount),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 開始ボタンと招待ボタンの間に配置される「思い出」ボタン
class _MemoriesHeaderButton extends StatelessWidget {
  const _MemoriesHeaderButton({required this.onTap});

  final VoidCallback onTap;

  static const List<Shadow> _labelShadows = [
    Shadow(color: Colors.white, blurRadius: 8),
    Shadow(color: Colors.white, blurRadius: 14),
  ];

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_stories_outlined,
              size: 29,
              color: AppTheme.darkGrey,
              shadows: _labelShadows,
            ),
            SizedBox(height: 4),
            Text(
              '思い出',
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
