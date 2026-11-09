import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/models/memory_pin.dart';
import '../../core/models/team_group.dart';
import '../../core/models/trip_memory.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/group_service.dart';
import '../../core/services/location_tracking_service.dart';
import '../../core/services/trip_service.dart';
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
  final LocationTrackingService _locationService =
      LocationTrackingService.instance;
  final TripService _tripService = TripService.instance;

  List<TeamGroup> _teams = List<TeamGroup>.from(TeamGroup.sampleTeams);
  late TeamGroup _selectedTeam = _teams.first;

  final List<MemoryPin> _allPins = [];

  final List<TripMemory> _allMemories = [];

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
  List<RoutePoint> _activeTripRoutePoints = [];

  late AppUser _currentUser;
  Timer? _idleRestoreTimer;
  StreamSubscription<List<TeamGroup>>? _groupsSubscription;
  StreamSubscription<AppUser>? _authSubscription;
  StreamSubscription<List<MemoryPin>>? _pinsSubscription;
  StreamSubscription<List<TripMemory>>? _tripsSubscription;

  @override
  void initState() {
    super.initState();
    _currentUser = _authService.currentUser;
    _listenAuthAndGroups();
    _subscribeToTripsAndPins(_selectedTeam.id);
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
      setState(() {
        _teams = List<TeamGroup>.from(TeamGroup.sampleTeams);
        _selectedTeam = _teams.first;
        _selectedPin = null;
      });
      _subscribeToTripsAndPins(_selectedTeam.id);
      return;
    }
    _groupsSubscription = _groupService.watchUserGroups(uid).listen((
      newGroups,
    ) {
      if (!mounted || newGroups.isEmpty) return;
      final nextSelected = newGroups.firstWhere(
        (t) => t.id == _selectedTeam.id,
        orElse: () => newGroups.first,
      );
      setState(() {
        _teams = newGroups;
        _selectedTeam = nextSelected;
      });
      _subscribeToTripsAndPins(nextSelected.id);
    });
  }

  /// 選択グループのピン・旅行情報をリアルタイム購読（グループ全員の画面へ即時反映）
  void _subscribeToTripsAndPins(String groupId) {
    _pinsSubscription?.cancel();
    _tripsSubscription?.cancel();

    _pinsSubscription = _tripService.watchPins(groupId).listen((pins) {
      if (!mounted) return;
      setState(() {
        // 当該グループのピンを最新のリアルタイムデータで更新
        _allPins.removeWhere((p) => p.teamId == groupId);
        _allPins.addAll(pins);
        // 選択中ピンが更新された場合も追従
        if (_selectedPin != null && _selectedPin!.teamId == groupId) {
          final updated = pins
              .where((p) => p.id == _selectedPin!.id)
              .firstOrNull;
          if (updated != null) {
            _selectedPin = updated;
          }
        }
      });
    });

    _tripsSubscription = _tripService.watchTrips(groupId).listen((trips) {
      if (!mounted) return;
      setState(() {
        _allMemories.removeWhere((m) => m.teamId == groupId);
        _allMemories.addAll(trips);
      });
    });
  }

  @override
  void dispose() {
    _idleRestoreTimer?.cancel();
    _groupsSubscription?.cancel();
    _authSubscription?.cancel();
    _locationService.stopTracking();
    _pinsSubscription?.cancel();
    _tripsSubscription?.cancel();
    super.dispose();
  }

  /// 「MyMap」（isPersonal == true）選択時は全グループのピンを引き継いで表示する
  List<MemoryPin> get _currentTeamPins {
    if (_selectedTeam.isPersonal) {
      return List<MemoryPin>.from(_allPins);
    }
    return _allPins.where((pin) => pin.teamId == _selectedTeam.id).toList();
  }

  /// 「MyMap」（isPersonal == true）選択時は全グループの思い出を引き継いで表示する
  List<TripMemory> get _currentTeamMemories {
    if (_selectedTeam.isPersonal) {
      return List<TripMemory>.from(_allMemories);
    }
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
                decoration: const InputDecoration(labelText: '旅行名（タイトル）'),
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
                Navigator.of(dialogContext).pop(text.isEmpty ? '新しい旅行' : text);
              },
              child: const Text('スタート'),
            ),
          ],
        );
      },
    );

    if (tripTitle == null || !mounted) return;

    final startTime = DateTime.now();

    setState(() {
      _isTripActive = true;
      _activeTripId = 'trip_${startTime.millisecondsSinceEpoch}';
      _activeTripTitle = tripTitle;
      _activeTripStartDate = startTime;
      _activeTripPins.clear();
      _activeTripRoutePoints = [];
    });

    // 旅行スタート時の日時と現在位置を取得し、移動に応じたルート追跡を開始
    await _locationService.startTracking(
      startTime: startTime,
      onRouteUpdated: (points) {
        if (!mounted || !_isTripActive) return;
        setState(() {
          _activeTripRoutePoints = List<RoutePoint>.from(points);
        });
      },
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('「$tripTitle」を開始し、現在位置からの移動ルート記録をスタートしました！')),
    );
  }

  /// 旅行終了ボタンを押したとき：ルートの記録をストップし、つけたタイトルで旅行まとめ（TripMemory）を作成
  Future<void> _handleStopTrip() async {
    if (!_isTripActive) return;

    final title = _activeTripTitle ?? '新しい旅行';
    final tripId =
        _activeTripId ?? 'trip_${DateTime.now().millisecondsSinceEpoch}';
    final startDate = _activeTripStartDate ?? DateTime.now();
    final endDate = DateTime.now();

    final recordedRoute = await _locationService.stopTracking();
    final recordedPins = List<MemoryPin>.from(_activeTripPins);

    // 通った道のルート（GPS移動履歴）のみを取得する（ピンの場所へ線を追従させない）
    final mergedRoute = _locationService.buildRouteForTimeWindow(
      startDateTime: startDate,
      endDateTime: endDate,
      importedTimelinePoints: recordedRoute,
    );
    final finalRoute = mergedRoute.isNotEmpty ? mergedRoute : recordedRoute;

    final createdMemory = TripMemory(
      id: tripId,
      teamId: _selectedTeam.id,
      title: title,
      startDate: startDate,
      endDate: endDate,
      pins: recordedPins,
      routePoints: finalRoute,
    );

    if (!mounted) return;

    setState(() {
      _allMemories.insert(0, createdMemory);
      _isTripActive = false;
      _activeTripId = null;
      _activeTripTitle = null;
      _activeTripStartDate = null;
      _activeTripPins.clear();
      _activeTripRoutePoints = [];
    });

    _tripService.saveTrip(createdMemory);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'ルート記録を停止し、旅行まとめ「$title」（${createdMemory.formattedDistance}）を作成しました！',
        content: Text('旅行まとめ「$title」を作成しました！'),
        action: SnackBarAction(label: '思い出を見る', onPressed: _openMemoriesScreen),
      ),
    );
  }

  Future<void> _handleUpdateTripTitle(String tripId, String newTitle) async {
    await _tripService.updateTripTitle(
      groupId: _selectedTeam.id,
      tripId: tripId,
      newTitle: newTitle,
    );
  }

  Future<MemoryPin?> _handleEditPin(MemoryPin pin) async {
    final updatedPin = await Navigator.of(context).push<MemoryPin>(
      MaterialPageRoute(
        builder: (_) => RecordScreen(
          teamId: pin.teamId,
          activeTripId: pin.tripId,
          initialPin: pin,
        ),
        action: SnackBarAction(label: '思い出を見る', onPressed: _openMemoriesScreen),
      ),
    );
    if (updatedPin != null && mounted) {
      setState(() {
        final pinIdx = _allPins.indexWhere((p) => p.id == updatedPin.id);
        if (pinIdx >= 0) {
          _allPins[pinIdx] = updatedPin;
        } else {
          _allPins.add(updatedPin);
        }

        for (int i = 0; i < _allMemories.length; i++) {
          final trip = _allMemories[i];
          final hasPin = trip.pins.any((p) => p.id == updatedPin.id);
          final matchesTrip =
              updatedPin.tripId != null && trip.id == updatedPin.tripId;
          if (hasPin || matchesTrip) {
            final updatedPins = trip.pins
                .map((p) => p.id == updatedPin.id ? updatedPin : p)
                .toList();
            if (!updatedPins.any((p) => p.id == updatedPin.id)) {
              updatedPins.add(updatedPin);
            }
            _allMemories[i] = trip.copyWith(pins: updatedPins);
          }
        }

        if (_selectedPin?.id == updatedPin.id) {
          _selectedPin = updatedPin;
        }
      });
      await _tripService.savePin(updatedPin);
      return updatedPin;
    }
    return null;
  }

  Future<MemoryPin?> _handleAddPinToTrip(String tripId, String teamId) async {
    final effectiveTeamId = teamId.isNotEmpty ? teamId : _selectedTeam.id;
    final newPin = await Navigator.of(context).push<MemoryPin>(
      MaterialPageRoute(
        builder: (_) => RecordScreen(
          teamId: effectiveTeamId,
          activeTripId: tripId,
        ),
      ),
    );
    if (newPin != null && mounted) {
      setState(() {
        _allPins.add(newPin);
        for (int i = 0; i < _allMemories.length; i++) {
          if (_allMemories[i].id == tripId) {
            final updatedPins = List<MemoryPin>.from(_allMemories[i].pins)
              ..add(newPin);
            _allMemories[i] = _allMemories[i].copyWith(pins: updatedPins);
          }
        }
      });
      await _tripService.savePin(newPin);
      return newPin;
    }
    return null;
  }

  Future<void> _openMemoriesScreen({TripMemory? initialMemory}) async {
    final jumpedPin = await Navigator.of(context).push<MemoryPin>(
      MaterialPageRoute(
        builder: (_) => MemoriesListScreen(
          teamName: _selectedTeam.name,
          teamId: _selectedTeam.id,
          memories: _currentTeamMemories,
          availablePins: _currentTeamPins,
          initialSelectedMemory: initialMemory,
          onDeleteSinglePin: _handleDeletePin,
          onCreateMemory: (createdMemory) {
            setState(() {
              _allMemories.insert(0, createdMemory);
            });
            if (!_currentUser.isAnonymous) {
              _groupService.saveMemory(createdMemory);
            }
          },
          onDeleteMemory: (memoryId, pinIdsToDelete) async {
          onUpdateTripTitle: _handleUpdateTripTitle,
          onEditPin: _handleEditPin,
          onAddPin: _handleAddPinToTrip,
          onDeleteMemory: (memoryId) {
            final target = _allMemories
                .where((m) => m.id == memoryId)
                .firstOrNull;
            setState(() {
              _allMemories.removeWhere((m) => m.id == memoryId);
              if (pinIdsToDelete.isNotEmpty) {
                _allPins.removeWhere((p) => pinIdsToDelete.contains(p.id));
                _activeTripPins.removeWhere(
                  (p) => pinIdsToDelete.contains(p.id),
                );
                if (_selectedPin != null &&
                    pinIdsToDelete.contains(_selectedPin!.id)) {
                  _selectedPin = null;
                }
              }
            });
            if (!_currentUser.isAnonymous) {
              await _groupService.deleteMemory(
                target?.teamId ?? _selectedTeam.id,
                memoryId,
              );
              for (final pinId in pinIdsToDelete) {
                await _groupService.deletePin(
                  target?.teamId ?? _selectedTeam.id,
                  pinId,
                );
              }
            }
            _tripService.deleteTrip(
              target?.teamId ?? _selectedTeam.id,
              memoryId,
            );
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
    final tripIds = regionPins.map((p) => p.tripId).whereType<String>().toSet();

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
        builder: (_) =>
            RecordScreen(teamId: _selectedTeam.id, activeTripId: _activeTripId),
      ),
    );
    if (newPin != null && mounted) {
      // レビュー（ピン）の追加と通った道のルート保存は別件のため、ルート線をピン位置へ追従させない
      setState(() {
        _allPins.add(newPin);
        if (_isTripActive) {
          _activeTripPins.add(newPin);
        }
      });
      await _tripService.savePin(newPin);
    }
  }

  Future<void> _openAuthScreen() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => LoginScreen(
          currentUserName: _currentUser.displayName,
          onSignInCompleted: (user) {
            if (!mounted) return;
            setState(() => _currentUser = user);
            _subscribeToGroups(user.uid);
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
        _subscribeToTripsAndPins(newTeam.id);
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
        _subscribeToTripsAndPins(joinedTeam.id);
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

  Future<void> _handleDeletePin(MemoryPin pin) async {
    setState(() {
      _allPins.removeWhere((p) => p.id == pin.id);
      _activeTripPins.removeWhere((p) => p.id == pin.id);
      if (_selectedPin?.id == pin.id) {
        _selectedPin = null;
      }
      if (_externalFocusPin?.id == pin.id) {
        _externalFocusPin = null;
      }
      _allMemories = _allMemories.map((m) {
        final updatedPins = m.pins.where((p) => p.id != pin.id).toList();
        return m.copyWith(pins: updatedPins);
      }).toList();
    });

    if (!_currentUser.isAnonymous) {
      await _groupService.deletePin(pin.teamId, pin.id);
    }
  }

  Future<void> _handleDeleteTeam(TeamGroup team) async {
    setState(() {
      _teams.removeWhere((t) => t.id == team.id);
      _selectedTeam = _teams.firstWhere(
        (t) => t.isPersonal,
        orElse: () => _teams.first,
      );
      _selectedPin = null;
    });
    _loadGroupDataFromDb(_selectedTeam.id);
    if (!_currentUser.isAnonymous) {
      await _groupService.deleteGroup(team.id);
    }
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('グループ「${team.name}」を削除しました')));
    }
  }

  Future<void> _handleLeaveTeam(TeamGroup team) async {
    setState(() {
      _teams.removeWhere((t) => t.id == team.id);
      _selectedTeam = _teams.firstWhere(
        (t) => t.isPersonal,
        orElse: () => _teams.first,
      );
      _selectedPin = null;
    });
    _loadGroupDataFromDb(_selectedTeam.id);
    if (!_currentUser.isAnonymous) {
      await _groupService.leaveGroup(
        groupId: team.id,
        userUid: _currentUser.uid,
      );
    }
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('グループ「${team.name}」から退出しました')));
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
              memories: _currentTeamMemories,
              activeRoutePoints: _activeTripRoutePoints,
              isTripActive: _isTripActive,
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
                PinDetailSheet.show(
                  context,
                  pin,
                  onDeletePin: _handleDeletePin,
                  onEdit: (p) => _handleEditPin(p),
                );
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

          // 2. 左上ヘッダーメニュー（1倍の時のみ表示・縦横スクロール中やホームボタン押下時も1倍なら消えない）
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: HeaderMenuOverlay(
                visible: _isAt1xZoom,
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
                  _subscribeToTripsAndPins(team.id);
                },
                onCreateTeam: _handleCreateTeam,
                onJoinTeamByCode: _handleJoinTeamByCode,
                onStartTrip: _handleStartTrip,
                onStopTrip: _handleStopTrip,
                onOpenMemories: _openMemoriesScreen,
                onOpenRecord: _openRecordScreen,
                onOpenAuth: _openAuthScreen,
                onDeleteTeam: _handleDeleteTeam,
                onLeaveTeam: _handleLeaveTeam,
                currentUid: _currentUser.uid,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
