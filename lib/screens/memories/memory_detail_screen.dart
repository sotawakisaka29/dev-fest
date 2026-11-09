import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/models/app_photo.dart';
import '../../core/models/memory_pin.dart';
import '../../core/models/trip_memory.dart';
import '../../core/services/external_map_launcher.dart';
import '../../core/theme/app_theme.dart';

/// 添付スケッチ画像準拠の「各思い出（旅行まとめ）詳細画面」
///
/// - タイトル（下線付き）＋ ゴミ箱（削除）・紙飛行機（共有）アイコン
/// - 期間（0月0日 〜 0月0日）＋ 総移動距離（0km）
/// - レビュー一覧：高評価順（★5 → ★4 → …）にソートして表示、レビュー間の境目に十分な余白（32px）を確保
///   - ★評価 ＋ コメント ＋ 右端「↗（登録住所のGoogle Mapアプリを起動）」
///   - 写真があるレビューのみ直下に横スクロールで写真を表示（ない場合は表示なし）
/// - 画面下部：3列グリッドで旅行全体の写真を説明文なしで一覧表示
/// - すべての基本余白は8の倍数（8, 16, 24, 32）で構成
class MemoryDetailScreen extends StatefulWidget {
  const MemoryDetailScreen({
    super.key,
    required this.memory,
    required this.onDelete,
    this.onJumpToMapPin,
    this.onUpdateTitle,
    this.onEditPin,
  });

  final TripMemory memory;
  final VoidCallback onDelete;
  final ValueChanged<MemoryPin>? onJumpToMapPin;
  final ValueChanged<String>? onUpdateTitle;
  final ValueChanged<MemoryPin>? onEditPin;

  @override
  State<MemoryDetailScreen> createState() => _MemoryDetailScreenState();
}

class _MemoryDetailScreenState extends State<MemoryDetailScreen> {
  late TripMemory _currentMemory;

  @override
  void initState() {
    super.initState();
    _currentMemory = widget.memory;
  }

  @override
  void didUpdateWidget(covariant MemoryDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.memory != oldWidget.memory) {
      _currentMemory = widget.memory;
    }
  }

  TripMemory get memory => _currentMemory;

  Future<void> _showEditTitleDialog(BuildContext context) async {
    final controller = TextEditingController(text: memory.title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('旅行タイトルを編集'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: '新しい旅行タイトル',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () {
                final trimmed = controller.text.trim();
                Navigator.of(
                  dialogContext,
                ).pop(trimmed.isEmpty ? memory.title : trimmed);
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );

    if (newTitle != null && newTitle.isNotEmpty && newTitle != memory.title) {
      setState(() {
        _currentMemory = _currentMemory.copyWith(title: newTitle);
      });
      widget.onUpdateTitle?.call(newTitle);
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('思い出を削除'),
          content: Text('「${memory.title}」を削除してもよろしいですか？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: AppTheme.pureWhite,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('削除する'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && context.mounted) {
      widget.onDelete();
      Navigator.of(context).pop();
    }
  }

  void _showShareSheet(BuildContext context) {
    final summaryText =
        '【${memory.title}】\n'
        '期間: ${memory.formattedDateRange} / 総移動距離: ${memory.formattedDistance}\n'
        '訪問スポット: ${memory.pins.map((p) => p.placeName).join(' → ')}';

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.pureWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.send_outlined, color: AppTheme.darkGrey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '「${memory.title}」を共有',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.darkGrey,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceGrey,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.lightGrey),
                  ),
                  child: Text(
                    summaryText,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.darkGrey,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: summaryText));
                      if (sheetContext.mounted) {
                        Navigator.of(sheetContext).pop();
                      }
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('旅行まとめの共有テキストをコピーしました')),
                        );
                      }
                    },
                    icon: const Icon(Icons.send_outlined, size: 18),
                    label: const Text('共有リンク・まとめをコピー'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleOpenExternalGoogleMap(
    BuildContext context,
    MemoryPin pin,
  ) async {
    await ExternalMapLauncher.openGoogleMapsForAddress(
      context,
      address: pin.address,
      placeName: pin.placeName,
      latitude: pin.latitude,
      longitude: pin.longitude,
    );
  }

  @override
  Widget build(BuildContext context) {
    // レビューを高評価順（rating の降順）にソート
    final sortedPins = List<MemoryPin>.from(memory.pins)
      ..sort((a, b) => b.rating.compareTo(a.rating));
    final allPhotos = memory.allPhotos;

    return Scaffold(
      backgroundColor: AppTheme.pureWhite,
      appBar: AppBar(
        backgroundColor: AppTheme.pureWhite,
        elevation: 0,
        leading: IconButton(
          tooltip: '思い出一覧へ戻る',
          icon: const Icon(Icons.arrow_back, color: AppTheme.darkGrey),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '思い出',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryGrey,
          ),
        ),
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // 1. ヘッダー：タイトル・下線・ゴミ箱・共有・日付期間・総移動距離（余白はすべて8の倍数）
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // タイトル＋下線
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.only(bottom: 8),
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: AppTheme.darkGrey,
                                  width: 2.0,
                                ),
                              ),
                            ),
                            child: Text(
                              memory.title,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.darkGrey,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // 鉛筆アイコン（タイトル編集）
                        IconButton(
                          tooltip: '旅行タイトルを編集',
                          onPressed: () => _showEditTitleDialog(context),
                          icon: const Icon(
                            Icons.edit_outlined,
                            size: 24,
                            color: AppTheme.darkGrey,
                          ),
                        ),
                        // ゴミ箱アイコン（削除）
                        IconButton(
                          tooltip: 'この思い出を削除',
                          onPressed: () => _confirmDelete(context),
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 26,
                            color: AppTheme.darkGrey,
                          ),
                        ),
                        // 紙飛行機アイコン（共有）
                        IconButton(
                          tooltip: '共有',
                          onPressed: () => _showShareSheet(context),
                          icon: const Icon(
                            Icons.send_outlined,
                            size: 25,
                            color: AppTheme.darkGrey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // 0月0日 〜 0月0日   🚶 0km（総移動距離）
                    Row(
                      children: [
                        Text(
                          memory.formattedDateRange,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.primaryGrey,
                          ),
                        ),
                        const SizedBox(width: 24),
                        const Icon(
                          Icons.directions_walk,
                          size: 18,
                          color: AppTheme.darkGrey,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          memory.formattedDistance,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.darkGrey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // 2. レビュー一覧セクション（高評価順・レビュー間の境目に32pxの余白）
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'レビュー',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkGrey,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (sortedPins.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          '記録されたレビューはありません',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.mediumGrey,
                          ),
                        ),
                      )
                    else
                      ...sortedPins.map((pin) {
                        final pinPhotos = TripMemory.photosForPin(pin);
                        final commentText = pin.comment.isNotEmpty
                            ? '${pin.placeName}：${pin.comment}'
                            : pin.placeName;

                        return Padding(
                          // レビューとレビューの境目がはっきり分かるよう 32px（8×4）の余白を確保
                          padding: const EdgeInsets.only(bottom: 32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ★★★★★ 〜〜〜〜〜〜   ↗（登録住所のGoogle Mapアプリを起動）
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // 5段階の星表示
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: List.generate(5, (index) {
                                      final filled = index < pin.rating;
                                      return Icon(
                                        filled
                                            ? Icons.star_rounded
                                            : Icons.star_border_rounded,
                                        size: 20,
                                        color: AppTheme.darkGrey,
                                      );
                                    }),
                                  ),
                                  const SizedBox(width: 8),
                                  // レビューコメント＋場所名
                                  Expanded(
                                    child: Text(
                                      commentText,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: AppTheme.darkGrey,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // スポット編集ボタン
                                  if (widget.onEditPin != null)
                                    InkWell(
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: () => widget.onEditPin!(pin),
                                      child: const Padding(
                                        padding: EdgeInsets.all(8),
                                        child: Tooltip(
                                          message: 'スポットを編集',
                                          child: Icon(
                                            Icons.edit_outlined,
                                            size: 20,
                                            color: AppTheme.darkGrey,
                                          ),
                                        ),
                                      ),
                                    ),
                                  // ↗ 登録住所の Google Maps アプリへ飛ぶボタン
                                  InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: () => _handleOpenExternalGoogleMap(
                                      context,
                                      pin,
                                    ),
                                    child: const Padding(
                                      padding: EdgeInsets.all(8),
                                      child: Tooltip(
                                        message: 'Google Maps アプリで住所を開く',
                                        child: Icon(
                                          Icons.north_east,
                                          size: 20,
                                          color: AppTheme.darkGrey,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              // 横スクロールで写真（ない場合はとくに表示なし・説明文字なし）
                              if (pinPhotos.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 80,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: pinPhotos.length,
                                    separatorBuilder: (_, _) =>
                                        const SizedBox(width: 8),
                                    itemBuilder: (context, index) {
                                      return SizedBox(
                                        width: 80,
                                        height: 80,
                                        child: MemoryPhotoThumbnail(
                                          photo: pinPhotos[index],
                                          borderRadius: 0,
                                          showBorder: true,
                                          showCaptionOverlay: false,
                                          showPlaceholderLabel: false,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),

            // 3. 下部：3列グリッドで写真一覧（写真の説明等は一切表示しない）
            if (allPhotos.isNotEmpty) ...[
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: Divider(height: 1),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.0,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final photo = allPhotos[index];
                    return MemoryPhotoThumbnail(
                      photo: photo,
                      borderRadius: 0,
                      showBorder: false,
                      showCaptionOverlay: false,
                      showPlaceholderLabel: false,
                    );
                  }, childCount: allPhotos.length),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 思い出一覧の全面背景・詳細画面の写真サムネイル描画Widget（文字・説明なし対応）
class MemoryPhotoThumbnail extends StatelessWidget {
  const MemoryPhotoThumbnail({
    super.key,
    required this.photo,
    this.subtitle,
    this.borderRadius = 0,
    this.showBorder = false,
    this.showCaptionOverlay = false,
    this.showPlaceholderLabel = false,
  });

  final AppPhoto photo;
  final String? subtitle;
  final double borderRadius;
  final bool showBorder;
  final bool showCaptionOverlay;
  final bool showPlaceholderLabel;

  static const List<List<Color>> _samplePalettes = [
    [Color(0xFF355C7D), Color(0xFF6C5B7B), Color(0xFFC06C84)],
    [Color(0xFF2C3E50), Color(0xFF4CA1AF), Color(0xFFC4E0E5)],
    [Color(0xFF134E5E), Color(0xFF71B280), Color(0xFFB8E994)],
    [Color(0xFF4B6CB7), Color(0xFF182848), Color(0xFF8E9EAB)],
    [Color(0xFF5D4157), Color(0xFFA8CABA), Color(0xFFE6DADA)],
  ];

  @override
  Widget build(BuildContext context) {
    final palette =
        _samplePalettes[photo.label.hashCode.abs() % _samplePalettes.length];

    final localFile = photo.localFile;
    final bool hasLocalFile = localFile != null && localFile.existsSync();

    Widget imageContent;
    if (hasLocalFile) {
      imageContent = Image.file(
        localFile,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) {
          if (photo.url != null && photo.url!.isNotEmpty) {
            return Image.network(
              photo.url!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _buildFallbackVisual(palette),
            );
          }
          return _buildFallbackVisual(palette);
        },
      );
    } else if (photo.url != null && photo.url!.isNotEmpty) {
      imageContent = Image.network(
        photo.url!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _buildFallbackVisual(palette),
      );
    } else {
      imageContent = _buildFallbackVisual(palette);
    }

    Widget content = Stack(
      fit: StackFit.expand,
      children: [
        imageContent,
        if (showCaptionOverlay)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black54, Colors.transparent],
                ),
              ),
              child: Text(
                photo.label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.pureWhite,
                ),
              ),
            ),
          ),
      ],
    );

    if (showBorder) {
      content = DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.darkGrey, width: 1.0),
          borderRadius: borderRadius > 0
              ? BorderRadius.circular(borderRadius)
              : BorderRadius.zero,
        ),
        child: content,
      );
    }

    if (borderRadius > 0) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: content,
      );
    }
    return content;
  }

  Widget _buildFallbackVisual(List<Color> palette) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: palette,
        ),
      ),
      child: showPlaceholderLabel
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.photo_camera_back_outlined,
                      color: Colors.white70,
                      size: 22,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      photo.label,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.pureWhite,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}
