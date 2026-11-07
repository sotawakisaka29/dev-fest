import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/models/memory_pin.dart';
import '../../core/models/team_group.dart';
import '../../core/models/trip_memory.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/group_service.dart';
import '../../core/theme/app_theme.dart';
import '../auth/login/login_screen.dart';
import '../memories/memories_list_screen.dart';
import '../record/record_screen.dart';
import 'header_menu/header_menu_overlay.dart';
import 'map_canvas/interactive_map_canvas.dart';
import 'pin_callout/pin_detail_sheet.dart';

/// メイン画面（1倍時の都道府県シルエット写真表示・中倍率の市シルエット表示・高倍率のピン表示と左上メニュー統合）
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final AuthService _authService = AuthService.instance;
  final GroupService _groupService = GroupService.instance;

  List<TeamGroup> _teams = List<TeamGroup>.from(TeamGroup.sampleTeams);
  late TeamGroup _selectedTeam = _teams.first;

  final List<MemoryPin> _allPins = List<MemoryPin>.from(
    MemoryPin.initialSamplePins,
  );

  late final List<TripMemory> _allMemories =
      TripMemory.buildInitialSampleMemories(_allPins);

  /// 起動直後はピン非選択（1倍の全体表示から開始）
  MemoryPin? _selectedPin;

  /// 思い出詳細の「↗ Google Mapへ飛ぶ」等からフォーカス要求されたピン
  MemoryPin? _externalFocusPin;

  /// 現在1倍表示域にあるかどうか（上部タブは1倍の時のみ表示）
  bool _isAt1xZoom = true;
  bool _isMapInteracting = false;

  /// 旅行スタート〜停止の状態管理
  bool _isTripActive = false;
  String? _activeTripId;
  String? _activeTripTitle;
  DateTime? _activeTripStartDate;
  final List<MemoryPin> _activeTripPins = [];

  late AppUser _currentUser;
  Timer? _idleRestoreTimer;
  StreamSubscription<List<TeamGroup>>? _groupsSubscription;
  StreamSubscription<AppUser>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _currentUser = _authService.currentUser;
    _listenAuthAndGroups();
  }

  void _listenAuthAndGroups() {
    _authSubscription = _authService.authStateChanges.listen((user) {
      if (mounted) {
        setState(() => _currentUser = user);
        _subscribeToGroups(user.uid);
      }
    });
    _subscribeToGroups(_currentUser.uid);
  }

  void _subscribeToGroups(String uid) {
    _groupsSubscription?.cancel();
    if (_currentUser.isAnonymous) {
      return;
    }
    _groupsSubscription = _groupService.watchUserGroups(uid).listen((
      newGroups,
    ) {
      if (!mounted || newGroups.isEmpty) return;
      setState(() {
        _teams = newGroups;
        _selectedTeam = _teams.firstWhere(
          (t) => t.id == _selectedTeam.id,
          orElse: () => _teams.first,
        );
      });
    });
  }

  @override
  void dispose() {
    _idleRestoreTimer?.cancel();
    _groupsSubscription?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }

  List<MemoryPin> get _currentTeamPins {
    return _allPins.where((pin) => pin.teamId == _selectedTeam.id).toList();
  }

  List<TripMemory> get _currentTeamMemories {
    return _allMemories.where((m) => m.teamId == _selectedTeam.id).toList();
  }

  void _handleMapInteraction(bool interacting) {
    _idleRestoreTimer?.cancel();
    if (interacting) {
      if (!_isMapInteracting) {
        setState(() => _isMapInteracting = true);
      }
    } else {
      _idleRestoreTimer = Timer(const Duration(milliseconds: 280), () {
        if (mounted && _isMapInteracting) {
          setState(() => _isMapInteracting = false);
        }
      });
    }
  }

  /// 旅行スタートボタンを押したとき：旅行名を入力するダイアログを表示
  Future<void> _handleStartTrip() async {
    final controller = TextEditingController();
    final tripTitle = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('旅行をスタート'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'これから始める旅行のタイトルを入力してください。停止したときにこの名前で旅行まとめが作られます。',
                style: TextStyle(fontSize: 13, color: AppTheme.primaryGrey),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: '旅行名（タイトル）',
                  hintText: '例：鎌倉日帰り旅、北海道グルメ旅行',
                ),
                onSubmitted: (value) {
                  final trimmed = value.trim();
                  Navigator.of(
                    dialogContext,
                  ).pop(trimmed.isEmpty ? '新しい旅行' : trimmed);
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
                final text = controller.text.trim();
                Navigator.of(
                  dialogContext,
                ).pop(text.isEmpty ? '新しい旅行' : text);
              },
              child: const Text('スタート'),
            ),
          ],
        );
      },
    );

    if (tripTitle == null || !mounted) return;

    setState(() {
      _isTripActive = true;
      _activeTripId = 'trip_${DateTime.now().millisecondsSinceEpoch}';
      _activeTripTitle = tripTitle;
      _activeTripStartDate = DateTime.now();
      _activeTripPins.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('「$tripTitle」を開始しました！スポットを記録しましょう。'),
      ),
    );
  }

  /// 旅行停止ボタンを押したとき：つけたタイトルで旅行まとめ（TripMemory）を作成
  void _handleStopTrip() {
    if (!_isTripActive) return;

    final title = _activeTripTitle ?? '新しい旅行';
    final tripId =
        _activeTripId ?? 'trip_${DateTime.now().millisecondsSinceEpoch}';
    final startDate = _activeTripStartDate ?? DateTime.now();
    final endDate = DateTime.now();

    final recordedPins = List<MemoryPin>.from(_activeTripPins);

    final createdMemory = TripMemory(
      id: tripId,
      teamId: _selectedTeam.id,
      title: title,
      startDate: startDate,
      endDate: endDate,
      pins: recordedPins,
    );

    setState(() {
      _allMemories.insert(0, createdMemory);
      _isTripActive = false;
      _activeTripId = null;
      _activeTripTitle = null;
      _activeTripStartDate = null;
      _activeTripPins.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('旅行まとめ「$title」を作成しました！'),
        action: SnackBarAction(
          label: '思い出を見る',
          onPressed: _openMemoriesScreen,
        ),
      ),
    );
  }

  Future<void> _openMemoriesScreen({TripMemory? initialMemory}) async {
    final jumpedPin = await Navigator.of(context).push<MemoryPin>(
      MaterialPageRoute(
        builder: (_) => MemoriesListScreen(
          teamName: _selectedTeam.name,
          memories: _currentTeamMemories,
          initialSelectedMemory: initialMemory,
          onDeleteMemory: (memoryId) {
            setState(() {
              _allMemories.removeWhere((m) => m.id == memoryId);
            });
          },
        ),
      ),
    );

    if (jumpedPin != null && mounted) {
      setState(() {
        _selectedPin = jumpedPin;
        _externalFocusPin = jumpedPin;
      });
    }
  }

  /// 地図上の都道府県・市区町村写真プレビューをタップしたとき：対応する思い出（または思い出一覧）へ飛ぶ
  void _handleTapRegionPins(List<MemoryPin> regionPins) {
    final pinIds = regionPins.map((p) => p.id).toSet();
    final tripIds = regionPins
        .map((p) => p.tripId)
        .whereType<String>()
        .toSet();

    TripMemory? matchedMemory;
    for (final memory in _currentTeamMemories) {
      if (tripIds.contains(memory.id) ||
          memory.pins.any((p) => pinIds.contains(p.id))) {
        matchedMemory = memory;
        break;
      }
    }

    _openMemoriesScreen(initialMemory: matchedMemory);
  }

  Future<void> _openRecordScreen() async {
    final newPin = await Navigator.of(context).push<MemoryPin>(
      MaterialPageRoute(
        builder: (_) => RecordScreen(
          teamId: _selectedTeam.id,
          activeTripId: _activeTripId,
        ),
      ),
    );
    if (newPin != null && mounted) {
      setState(() {
        _allPins.add(newPin);
        if (_isTripActive) {
          _activeTripPins.add(newPin);
        }
      });
    }
  }

  Future<void> _openAuthScreen() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => LoginScreen(
          currentUserName: _currentUser.displayName,
          onSignInCompleted: (user) {
            setState(() => _currentUser = user);
          },
        ),
      ),
    );
  }

  Future<void> _handleCreateTeam(String teamName) async {
    try {
      final newTeam = await _groupService.createGroup(
        name: teamName,
        creatorUid: _currentUser.uid,
      );
      if (mounted) {
        setState(() {
          if (!_teams.any((t) => t.id == newTeam.id)) {
            _teams.add(newTeam);
          }
          _selectedTeam = newTeam;
          _selectedPin = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'グループ「${newTeam.name}」を作成しました（招待コード: ${newTeam.inviteCode}）',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('グループの作成に失敗しました: $e')));
      }
    }
  }

  Future<void> _handleJoinTeamByCode(String code) async {
    try {
      final joinedTeam = await _groupService.joinGroupByInviteCode(
        inviteCode: code,
        userUid: _currentUser.uid,
      );
      if (mounted) {
        setState(() {
          final index = _teams.indexWhere((t) => t.id == joinedTeam.id);
          if (index != -1) {
            _teams[index] = joinedTeam;
          } else {
            _teams.add(joinedTeam);
          }
          _selectedTeam = joinedTeam;
          _selectedPin = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('グループ「${joinedTeam.name}」に参加しました！'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final teamPins = _currentTeamPins;

    return Scaffold(
      body: Stack(
        children: [
          // 1. 全画面マップ（倍率に応じて 県シルエット写真 → 市シルエット写真 → 詳細マップ＋ピン を表示）
          Positioned.fill(
            child: InteractiveMapCanvas(
              pins: teamPins,
              selectedPin: _selectedPin,
              showRouteLine: true,
              externalFocusPin: _externalFocusPin,
              onExternalFocusHandled: () {
                _externalFocusPin = null;
              },
              onPinSelected: (pin) {
                setState(() => _selectedPin = pin);
              },
              onOpenPinDetail: (pin) {
                PinDetailSheet.show(context, pin);
              },
              onTapRegionPins: _handleTapRegionPins,
              onInteractionChanged: _handleMapInteraction,
              onZoom1xChanged: (isAt1x) {
                if (_isAt1xZoom != isAt1x) {
                  setState(() => _isAt1xZoom = isAt1x);
                }
              },
            ),
          ),

          // 2. 左上ヘッダーメニュー（1倍の時のみ表示・白いカード背景なし）
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: HeaderMenuOverlay(
                visible: _isAt1xZoom && !_isMapInteracting,
                teams: _teams,
                selectedTeam: _selectedTeam,
                isTripActive: _isTripActive,
                activeTripTitle: _activeTripTitle,
                pinCount: teamPins.where((p) => !p.isRouteWaypointOnly).length,
                onTeamSelected: (team) {
                  setState(() {
                    _selectedTeam = team;
                    _selectedPin = null;
                  });
                },
                onCreateTeam: _handleCreateTeam,
                onJoinTeamByCode: _handleJoinTeamByCode,
                onStartTrip: _handleStartTrip,
                onStopTrip: _handleStopTrip,
                onOpenMemories: _openMemoriesScreen,
                onOpenRecord: _openRecordScreen,
                onOpenAuth: _openAuthScreen,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
