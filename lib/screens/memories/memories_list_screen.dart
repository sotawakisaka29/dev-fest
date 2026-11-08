import 'package:flutter/material.dart';
import '../../core/models/app_photo.dart';
import '../../core/models/memory_pin.dart';
import '../../core/models/trip_memory.dart';
import '../../core/theme/app_theme.dart';
import 'memory_detail_screen.dart';

/// ホームタブの「思い出」ボタン、または地図上の県・市プレビュータップから遷移する思い出一覧画面
///
/// - 丸い輪郭（角丸や枠線）を廃止し、シャープな長方形の写真を全面背景に表示する。
/// - カード内には右下にタイトルのみを表示する。
class MemoriesListScreen extends StatefulWidget {
  const MemoriesListScreen({
    super.key,
    required this.teamName,
    required this.memories,
    required this.onDeleteMemory,
    this.initialSelectedMemory,
    this.onUpdateTripTitle,
    this.onEditPin,
  });

  final String teamName;
  final List<TripMemory> memories;
  final ValueChanged<String> onDeleteMemory;
  final TripMemory? initialSelectedMemory;
  final void Function(String tripId, String newTitle)? onUpdateTripTitle;
  final ValueChanged<MemoryPin>? onEditPin;

  @override
  State<MemoriesListScreen> createState() => _MemoriesListScreenState();
}

class _MemoriesListScreenState extends State<MemoriesListScreen> {
  late List<TripMemory> _items = List<TripMemory>.from(widget.memories);

  @override
  void initState() {
    super.initState();
    final initial = widget.initialSelectedMemory;
    if (initial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _openDetail(initial);
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant MemoriesListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.memories != oldWidget.memories) {
      setState(() {
        _items = List<TripMemory>.from(widget.memories);
      });
    }
  }

  void _handleDelete(TripMemory memory) {
    setState(() {
      _items.removeWhere((m) => m.id == memory.id);
    });
    widget.onDeleteMemory(memory.id);
  }

  Future<void> _openDetail(TripMemory memory) async {
    final jumpedPin = await Navigator.of(context).push<MemoryPin>(
      MaterialPageRoute(
        builder: (detailContext) => MemoryDetailScreen(
          memory: memory,
          onDelete: () => _handleDelete(memory),
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
          onEditPin: widget.onEditPin,
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
      ),
      body: SafeArea(
        child: _items.isEmpty
            ? const Center(
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
                        'まだ思い出がありません。\n「旅行スタート」から旅を始めるとここにまとめが作られます。',
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
              )
            : ListView.separated(
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
    );
  }
}
