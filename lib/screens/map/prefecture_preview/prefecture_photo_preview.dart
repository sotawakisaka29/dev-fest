import 'package:flutter/material.dart';
import '../../../core/models/memory_pin.dart';
import '../../../core/theme/app_theme.dart';

/// 都道府県の形に沿った写真プレビュー（MVP必須機能⑥）
///
/// 訪問・記録した都道府県ごとに写真を視覚的に配置し、
/// 埋まっていく達成感を得られるビジュアルビューを提供する。
class PrefecturePhotoPreview extends StatelessWidget {
  const PrefecturePhotoPreview({
    super.key,
    required this.pins,
    required this.onSelectPin,
  });

  final List<MemoryPin> pins;
  final ValueChanged<MemoryPin> onSelectPin;

  static const List<_PrefectureShapeSlot> _slots = [
    _PrefectureShapeSlot(
      name: '北海道',
      region: '北海道',
      normalizedRect: Rect.fromLTWH(0.60, 0.14, 0.30, 0.14),
      borderRadius: 18,
    ),
    _PrefectureShapeSlot(
      name: '宮城県',
      region: '東北',
      normalizedRect: Rect.fromLTWH(0.62, 0.32, 0.22, 0.09),
      borderRadius: 12,
    ),
    _PrefectureShapeSlot(
      name: '東京都',
      region: '関東',
      normalizedRect: Rect.fromLTWH(0.56, 0.44, 0.22, 0.10),
      borderRadius: 10,
    ),
    _PrefectureShapeSlot(
      name: '千葉県',
      region: '関東',
      normalizedRect: Rect.fromLTWH(0.79, 0.45, 0.16, 0.11),
      borderRadius: 14,
    ),
    _PrefectureShapeSlot(
      name: '神奈川県',
      region: '関東',
      normalizedRect: Rect.fromLTWH(0.54, 0.56, 0.23, 0.10),
      borderRadius: 12,
    ),
    _PrefectureShapeSlot(
      name: '京都府',
      region: '関西',
      normalizedRect: Rect.fromLTWH(0.30, 0.53, 0.22, 0.11),
      borderRadius: 14,
    ),
    _PrefectureShapeSlot(
      name: '大阪府',
      region: '関西',
      normalizedRect: Rect.fromLTWH(0.30, 0.66, 0.20, 0.09),
      borderRadius: 12,
    ),
    _PrefectureShapeSlot(
      name: '福岡県',
      region: '九州',
      normalizedRect: Rect.fromLTWH(0.08, 0.68, 0.20, 0.11),
      borderRadius: 14,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final Map<String, List<MemoryPin>> pinsByPrefecture = {};
    for (final pin in pins) {
      if (pin.isRouteWaypointOnly) continue;
      pinsByPrefecture.putIfAbsent(pin.prefecture, () => []).add(pin);
    }

    final visitedCount = pinsByPrefecture.keys.length;

    return Container(
      color: const Color(0xFFECEEF1),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;

          return Stack(
            children: [
              // 各都道府県シルエット枠への写真プレビュー配置
              ..._slots.map((slot) {
                final prefPins = pinsByPrefecture[slot.name] ?? const [];
                final isVisited = prefPins.isNotEmpty;
                final firstPhoto = prefPins
                    .expand((p) => p.photoLabels)
                    .cast<String?>()
                    .firstWhere((e) => e != null, orElse: () => null);

                return Positioned(
                  left: slot.normalizedRect.left * width,
                  top: slot.normalizedRect.top * height,
                  width: slot.normalizedRect.width * width,
                  height: slot.normalizedRect.height * height,
                  child: GestureDetector(
                    onTap: isVisited ? () => onSelectPin(prefPins.first) : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isVisited
                            ? AppTheme.darkGrey
                            : AppTheme.pureWhite.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(slot.borderRadius),
                        border: Border.all(
                          color: isVisited
                              ? AppTheme.pureWhite
                              : AppTheme.mediumGrey,
                          width: isVisited ? 2 : 1.2,
                        ),
                        boxShadow: isVisited
                            ? const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 8,
                                  offset: Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isVisited
                                    ? Icons.photo_camera_back_outlined
                                    : Icons.lock_outline,
                                size: 14,
                                color: isVisited
                                    ? AppTheme.pureWhite
                                    : AppTheme.mediumGrey,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  slot.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isVisited
                                        ? AppTheme.pureWhite
                                        : AppTheme.mediumGrey,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isVisited
                                ? '${firstPhoto ?? prefPins.first.placeName} (${prefPins.length}件)'
                                : '未訪問',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              color: isVisited
                                  ? AppTheme.lightGrey
                                  : AppTheme.mediumGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              // 左下の達成度インジケータ
              Positioned(
                left: 16,
                bottom: 28,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.pureWhite.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.lightGrey),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '都道府県フォトコレクション',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.primaryGrey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '訪問済み: $visitedCount / 47 都道府県',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.darkGrey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PrefectureShapeSlot {
  const _PrefectureShapeSlot({
    required this.name,
    required this.region,
    required this.normalizedRect,
    required this.borderRadius,
  });

  final String name;
  final String region;
  final Rect normalizedRect;
  final double borderRadius;
}
