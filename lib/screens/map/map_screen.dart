import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/models/memory_pin.dart';
import '../../core/models/team_group.dart';
import '../../core/theme/app_theme.dart';
import '../auth/login/login_screen.dart';
import '../record/record_screen.dart';
import 'header_menu/header_menu_overlay.dart';
import 'map_canvas/interactive_map_canvas.dart';
import 'pin_callout/pin_detail_sheet.dart';
import 'prefecture_preview/prefecture_photo_preview.dart';

/// アイデアシート「メイン」画面の統合コンテナ
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final List<TeamGroup> _teams = List<TeamGroup>.from(TeamGroup.sampleTeams);
  late TeamGroup _selectedTeam = _teams.first;

  final List<MemoryPin> _allPins = List<MemoryPin>.from(
    MemoryPin.initialSamplePins,
  );

  MemoryPin? _selectedPin;
  bool _isTripActive = false;
  bool _isMapInteracting = false;
  bool _isPrefectureMode = false;
  String _currentUserName = 'DevFest User';
  Timer? _idleRestoreTimer;

  @override
  void initState() {
    super.initState();
    _selectedPin = _currentTeamPins.firstWhere(
      (p) => !p.isRouteWaypointOnly,
      orElse: () => _allPins.first,
    );
  }

  @override
  void dispose() {
    _idleRestoreTimer?.cancel();
    super.dispose();
  }

  List<MemoryPin> get _currentTeamPins {
    return _allPins.where((pin) => pin.teamId == _selectedTeam.id).toList();
  }

  void _handleMapInteraction(bool interacting) {
    _idleRestoreTimer?.cancel();
    if (interacting) {
      if (!_isMapInteracting) {
        setState(() => _isMapInteracting = true);
      }
    } else {
      // 指を離してから少し待って上部メニューを再表示（「触ってない間だけ出る」）
      _idleRestoreTimer = Timer(const Duration(milliseconds: 280), () {
        if (mounted && _isMapInteracting) {
          setState(() => _isMapInteracting = false);
        }
      });
    }
  }

  Future<void> _openRecordScreen() async {
    final newPin = await Navigator.of(context).push<MemoryPin>(
      MaterialPageRoute(builder: (_) => RecordScreen(teamId: _selectedTeam.id)),
    );
    if (newPin != null && mounted) {
      setState(() {
        _allPins.add(newPin);
        _selectedPin = newPin;
        _isPrefectureMode = false;
      });
    }
  }

  Future<void> _openAuthScreen() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => LoginScreen(
          currentUserName: _currentUserName,
          onSignInCompleted: (newName) {
            setState(() => _currentUserName = newName);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final teamPins = _currentTeamPins;

    return Scaffold(
      body: Stack(
        children: [
          // 1. 全画面マップ または 都道府県シルエット写真プレビュー
          Positioned.fill(
            child: _isPrefectureMode
                ? PrefecturePhotoPreview(
                    pins: teamPins,
                    onSelectPin: (pin) {
                      PinDetailSheet.show(context, pin);
                    },
                  )
                : InteractiveMapCanvas(
                    pins: teamPins,
                    selectedPin: _selectedPin,
                    showRouteLine: true,
                    onPinSelected: (pin) {
                      setState(() => _selectedPin = pin);
                    },
                    onOpenPinDetail: (pin) {
                      PinDetailSheet.show(context, pin);
                    },
                    onInteractionChanged: _handleMapInteraction,
                  ),
          ),

          // 2. 上部オーバーレイ（地図を触っていない間だけ表示）
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: HeaderMenuOverlay(
                visible: !_isMapInteracting,
                teams: _teams,
                selectedTeam: _selectedTeam,
                isTripActive: _isTripActive,
                pinCount: teamPins.where((p) => !p.isRouteWaypointOnly).length,
                onTeamSelected: (team) {
                  setState(() {
                    _selectedTeam = team;
                    final nextPins = _currentTeamPins
                        .where((p) => !p.isRouteWaypointOnly)
                        .toList();
                    _selectedPin = nextPins.isNotEmpty ? nextPins.first : null;
                  });
                },
                onCreateTeam: (teamName) {
                  final newTeam = TeamGroup(
                    id: 'team_${DateTime.now().millisecondsSinceEpoch}',
                    name: teamName,
                    memberCount: 1,
                  );
                  setState(() {
                    _teams.add(newTeam);
                    _selectedTeam = newTeam;
                    _selectedPin = null;
                  });
                },
                onToggleTrip: () {
                  setState(() => _isTripActive = !_isTripActive);
                },
                onOpenRecord: _openRecordScreen,
                onOpenAuth: _openAuthScreen,
              ),
            ),
          ),

          // 3. 右下：マップ表示 ⇔ 都道府県写真プレビュー切替ボタン（MVP機能⑥）
          Positioned(
            right: 16,
            bottom: 28,
            child: IgnorePointer(
              ignoring: _isMapInteracting,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 220),
                opacity: _isMapInteracting ? 0.0 : 1.0,
                child: FloatingActionButton.extended(
                  heroTag: 'toggle_view_mode',
                  backgroundColor: AppTheme.pureWhite,
                  foregroundColor: AppTheme.darkGrey,
                  elevation: 3,
                  onPressed: () {
                    setState(() => _isPrefectureMode = !_isPrefectureMode);
                  },
                  icon: Icon(
                    _isPrefectureMode
                        ? Icons.map_outlined
                        : Icons.grid_view_rounded,
                    size: 20,
                  ),
                  label: Text(
                    _isPrefectureMode ? 'マップ表示へ' : '都道府県フォト',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
