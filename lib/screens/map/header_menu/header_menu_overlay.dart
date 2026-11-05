import 'package:flutter/material.dart';
import '../../../core/models/team_group.dart';
import '../../../core/theme/app_theme.dart';
import 'invite/invite_button.dart';
import 'share/share_button.dart';
import 'team_selector/team_selector_dropdown.dart';
import 'trip_action/trip_action_button.dart';

/// アイデアシート「触ってない間だけ出る」上部ヘッダーメニュー
///
/// チーム名プルダウンと3つの機能ボタン（旅行スタート/記録・招待する・共有する）を集約する。
class HeaderMenuOverlay extends StatelessWidget {
  const HeaderMenuOverlay({
    super.key,
    required this.visible,
    required this.teams,
    required this.selectedTeam,
    required this.isTripActive,
    required this.pinCount,
    required this.onTeamSelected,
    required this.onCreateTeam,
    required this.onToggleTrip,
    required this.onOpenRecord,
    required this.onOpenAuth,
  });

  final bool visible;
  final List<TeamGroup> teams;
  final TeamGroup selectedTeam;
  final bool isTripActive;
  final int pinCount;
  final ValueChanged<TeamGroup> onTeamSelected;
  final ValueChanged<String> onCreateTeam;
  final VoidCallback onToggleTrip;
  final VoidCallback onOpenRecord;
  final VoidCallback onOpenAuth;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        opacity: visible ? 1.0 : 0.0,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: AppTheme.pureWhite.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.lightGrey),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TeamSelectorDropdown(
                      teams: teams,
                      selectedTeam: selectedTeam,
                      onTeamSelected: onTeamSelected,
                      onCreateTeam: onCreateTeam,
                    ),
                  ),
                  if (isTripActive)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.darkGrey,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        '旅行ルート記録中',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.pureWhite,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  IconButton(
                    tooltip: 'アカウント・認証設定',
                    onPressed: onOpenAuth,
                    icon: const Icon(
                      Icons.account_circle_outlined,
                      color: AppTheme.darkGrey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TripActionButton(
                    isTripActive: isTripActive,
                    onToggleTrip: onToggleTrip,
                    onOpenRecord: onOpenRecord,
                  ),
                  InviteButton(selectedTeam: selectedTeam),
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
