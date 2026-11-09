import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/models/app_photo.dart';
import '../../core/models/memory_pin.dart';
import '../../core/models/trip_memory.dart';
import '../../core/services/trip_service.dart';
import '../../core/theme/app_theme.dart';
import 'create_memory_screen.dart';
import 'memory_detail_screen.dart';

/// ホームタブの「思い出」ボタン、または地図上の県・市プレビュータップから遷移する思い出一覧画面
///
/// - 丸い輪郭（角丸や枠線）を廃止し、シャープな長方形の写真を全面背景に表示する。
/// - カード内には右下にタイトルのみを表示する。
/// - 右上の「＋」ボタンから、別ページ（CreateMemoryScreen）へ遷移して手動で思い出を新規作成できる。
class MemoriesListScreen extends StatefulWidget {
  const MemoriesListScreen({
    super.key,
    required this.teamName,
    required this.teamId,
    required this.memories,
    required this.availablePins,
    required this.onDeleteMemory,
    required this.onCreateMemory,
    this.watchedTeamIds,
    this.onDeleteSinglePin,
    this.initialSelectedMemory,
    this.onUpdateTripTitle,
    this.onEditPin,
    this.onAddPin,
  });

  final String teamName;
  final String teamId;
  final List<String>? watchedTeamIds;
  final List<TripMemory> memories;
  final List<MemoryPin> availablePins;
  final void Function(String memoryId, Set<String> pinIdsToDelete)
  onDeleteMemory;
  final ValueChanged<TripMemory> onCreateMemory;
  final ValueChanged<MemoryPin>? onDeleteSinglePin;
  final TripMemory? initialSelectedMemory;
  final void Function(String tripId, String newTitle)? onUpdateTripTitle;
  final Future<MemoryPin?> Function(MemoryPin)? onEditPin;
  final Future<MemoryPin?> Function(String tripId, String teamId)? onAddPin;

  @override
  State<MemoriesListScreen> createState() => _MemoriesListScreenState();
}

class _MemoriesListScreenState extends State<MemoriesListScreen> {
  late List<TripMemory> _items = List<TripMemory>.from(widget.memories);
  late final List<MemoryPin> _availablePins = List<MemoryPin>.from(
    widget.availablePins,
  );
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  final Set<String> _syncedTripGroups = {};
  final Set<String> _syncedPinGroups = {};

  @override
  void initState() {
    super.initState();
    _subscribeRealtimeUpdates();
    _refreshFromDb();
    final initial = widget.initialSelectedMemory;
    if (initial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _openDetail(initial);
        }
      });
    }
  }

  Set<String> get _targetGroupIds {
    return <String>{
      widget.teamId,
      ...?widget.watchedTeamIds,
      ...widget.memories.map((m) => m.teamId),
      ...widget.availablePins.map((p) => p.teamId),
    }..removeWhere((id) => id.isEmpty);
  }

  /// 思い出一覧を開くたび（およびプルリフレッシュ時）にDBへ直接アクセスして最新データを取得・同期
  Future<void> _refreshFromDb() async {
    final groupIds = _targetGroupIds.toList();
    for (final groupId in groupIds) {
      final fetchedTrips = await TripService.instance.fetchTrips(groupId);
      if (!mounted) return;
      final shouldReplaceEmpty =
          TripService.instance.isFirebaseInitialized ||
          _syncedTripGroups.contains(groupId) ||
          fetchedTrips.isNotEmpty;
      if (shouldReplaceEmpty) {
        _syncedTripGroups.add(groupId);
        setState(() {
          _items.removeWhere((m) => m.teamId == groupId);
          for (final trip in fetchedTrips) {
            final existingIdx = _items.indexWhere((m) => m.id == trip.id);
            if (existingIdx >= 0) {
              _items[existingIdx] = trip;
            } else {
              _items.add(trip);
            }
          }
        });
      }
    }
  }

  void _subscribeRealtimeUpdates() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();

    final groupIds = _targetGroupIds;

    for (final groupId in groupIds) {
      _subscriptions.add(
        TripService.instance.watchTrips(groupId).listen((trips) {
          if (!mounted) return;
          if (trips.isEmpty &&
              !TripService.instance.isFirebaseInitialized &&
              !_syncedTripGroups.contains(groupId)) {
            return;
          }
          _syncedTripGroups.add(groupId);
          setState(() {
            _items.removeWhere((m) => m.teamId == groupId);
            // 他のグループに同名IDがない場合に追加
            for (final trip in trips) {
              final existingIdx = _items.indexWhere((m) => m.id == trip.id);
              if (existingIdx >= 0) {
                _items[existingIdx] = trip;
              } else {
                _items.add(trip);
              }
            }
          });
        }),
      );

      _subscriptions.add(
        TripService.instance.watchPins(groupId).listen((pins) {
          if (!mounted) return;
          if (pins.isEmpty &&
              !TripService.instance.isFirebaseInitialized &&
              !_syncedPinGroups.contains(groupId)) {
            return;
          }
          _syncedPinGroups.add(groupId);
          setState(() {
            _availablePins.removeWhere((p) => p.teamId == groupId);
            _availablePins.addAll(pins);
          });
        }),
      );
    }
  }

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MemoriesListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.memories != oldWidget.memories) {
      setState(() {
        _items = List<TripMemory>.from(widget.memories);
      });
    }
    if (widget.teamId != oldWidget.teamId) {
      _subscribeRealtimeUpdates();
    }
  }

  void _handleDelete(TripMemory memory, Set<String> pinIdsToDelete) {
    _syncedTripGroups.add(memory.teamId);
    setState(() {
      _items.removeWhere((m) => m.id == memory.id);
      if (pinIdsToDelete.isNotEmpty) {
        _availablePins.removeWhere((p) => pinIdsToDelete.contains(p.id));
      }
    });
    widget.onDeleteMemory(memory.id, pinIdsToDelete);
  }

  /// 右上の「＋」ボタン押下時：ダイアログではなく別ページ（CreateMemoryScreen）に遷移する
  Future<void> _openCreateMemoryPage() async {
    final created = await Navigator.of(context).push<TripMemory>(
      MaterialPageRoute(
        builder: (_) => CreateMemoryScreen(
          teamId: widget.teamId,
          availablePins: _availablePins,
        ),
      ),
    );

    if (created != null && mounted) {
      _syncedTripGroups.add(created.teamId);
      setState(() {
        _items.removeWhere((m) => m.id == created.id);
        _items.insert(0, created);
      });
      widget.onCreateMemory(created);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '思い出「${created.title}」（スポット${created.pins.length}件 / ${created.formattedDistance}）を作成しました',
          ),
        ),
      );
    }
  }

  Future<void> _openDetail(TripMemory memory) async {
    final jumpedPin = await Navigator.of(context).push<MemoryPin>(
      MaterialPageRoute(
        builder: (detailContext) => MemoryDetailScreen(
          memory: memory,
          onDelete: (pinIdsToDelete) => _handleDelete(memory, pinIdsToDelete),
          onDeleteSinglePin: (pin) {
            widget.onDeleteSinglePin?.call(pin);
          },
          onJumpToMapPin: (pin) {
            Navigator.of(detailContext).pop(pin);
          },
          onUpdateTitle: (newTitle) {
            setState(() {
              final idx = _items.indexWhere((m) => m.id == memory.id);
              if (idx >= 0) {
                _items[idx] = _items[idx].copyWith(title: newTitle);
              }
            });
            widget.onUpdateTripTitle?.call(memory.id, newTitle);
          },
          onUpdateMemory: (updatedMemory) {
            setState(() {
              final idx = _items.indexWhere((m) => m.id == updatedMemory.id);
              if (idx >= 0) {
                _items[idx] = updatedMemory;
              }
            });
          },
          onEditPin: widget.onEditPin,
          onAddPin: widget.onAddPin,
        ),
      ),
    );

    if (jumpedPin != null && mounted) {
      Navigator.of(context).pop(jumpedPin);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.pureWhite,
      appBar: AppBar(
        backgroundColor: AppTheme.pureWhite,
        elevation: 0,
        leading: IconButton(
          tooltip: 'マップへ戻る',
          icon: const Icon(Icons.arrow_back, color: AppTheme.darkGrey),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '思い出一覧',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkGrey,
              ),
            ),
            Text(
              widget.teamName,
              style: const TextStyle(fontSize: 12, color: AppTheme.primaryGrey),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '思い出を手動で追加',
            icon: const Icon(Icons.add, size: 28, color: AppTheme.darkGrey),
            onPressed: _openCreateMemoryPage,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.darkGrey,
          onRefresh: _refreshFromDb,
          child: _items.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 160),
                    Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.auto_stories_outlined,
                              size: 48,
                              color: AppTheme.mediumGrey,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'まだ思い出がありません。\n「旅行スタート」から旅を始めるか、右上の「＋」から作成できます。',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: AppTheme.primaryGrey,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  itemCount: _items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final memory = _items[index];
                    final photos = memory.allPhotos;
                    final backgroundPhoto = photos.isNotEmpty
                        ? photos.first
                        : AppPhoto(id: 'bg_${memory.id}', label: memory.title);

                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _openDetail(memory),
                      child: SizedBox(
                        width: double.infinity,
                        height: 176,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // 全面写真背景（丸い輪郭・枠線なし）
                            MemoryPhotoThumbnail(
                              photo: backgroundPhoto,
                              borderRadius: 0,
                              showBorder: false,
                              showPlaceholderLabel: false,
                            ),
                            // 右下タイトルの可読性を高める下部グラデーション
                            const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Colors.transparent, Colors.black54],
                                  stops: [0.45, 1.0],
                                ),
                              ),
                            ),
                            // 右下にタイトルのみ表示
                            Positioned(
                              left: 16,
                              right: 16,
                              bottom: 16,
                              child: Align(
                                alignment: Alignment.bottomRight,
                                child: Text(
                                  memory.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.pureWhite,
                                    letterSpacing: 0.5,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black87,
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
