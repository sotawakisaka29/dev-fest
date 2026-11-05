import 'package:flutter/material.dart';
import '../../../core/models/memory_pin.dart';
import '../../../core/theme/app_theme.dart';
import '../pin_callout/pin_callout_card.dart';

/// Google Maps 表示枠およびピン・ルート・吹き出しの描画キャンバス（MVP機能①）
///
/// 実Google Maps SDK導入前でも単体で動作し、地図のドラッグ/ピンチ中のみ
/// 上部メニューを自動非表示にする（「触ってない間だけ出る」）イベントを通知する。
class InteractiveMapCanvas extends StatelessWidget {
  const InteractiveMapCanvas({
    super.key,
    required this.pins,
    required this.selectedPin,
    required this.showRouteLine,
    required this.onPinSelected,
    required this.onOpenPinDetail,
    required this.onInteractionChanged,
  });

  final List<MemoryPin> pins;
  final MemoryPin? selectedPin;
  final bool showRouteLine;
  final ValueChanged<MemoryPin?> onPinSelected;
  final ValueChanged<MemoryPin> onOpenPinDetail;
  final ValueChanged<bool> onInteractionChanged;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => onInteractionChanged(true),
      onPointerUp: (_) => onInteractionChanged(false),
      onPointerCancel: (_) => onInteractionChanged(false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onPinSelected(null),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            return InteractiveViewer(
              minScale: 0.9,
              maxScale: 2.8,
              onInteractionStart: (_) => onInteractionChanged(true),
              onInteractionEnd: (_) => onInteractionChanged(false),
              child: SizedBox(
                width: size.width,
                height: size.height,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // 1. 背景の地図ビジュアル（日本列島シルエット＋道路グリッド＋ルート線）
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _MockJapanMapPainter(
                          pins: pins,
                          showRouteLine: showRouteLine,
                        ),
                      ),
                    ),
                    // 2. 各ピンとルート上の黒丸（レビューなし通過点）
                    ...pins.map((pin) {
                      final point = Offset(
                        pin.mapNormalizedPosition.dx * size.width,
                        pin.mapNormalizedPosition.dy * size.height,
                      );
                      if (pin.isRouteWaypointOnly) {
                        // アイデアシート「レビューのないものは線上に黒丸かな？」
                        return Positioned(
                          left: point.dx - 7,
                          top: point.dy - 7,
                          child: Tooltip(
                            message: '${pin.placeName} (${pin.startTime})',
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: AppTheme.darkGrey,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppTheme.pureWhite,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        );
                      }

                      final isSelected = selectedPin?.id == pin.id;
                      return Positioned(
                        left: point.dx - 18,
                        top: point.dy - 36,
                        child: GestureDetector(
                          onTap: () => onPinSelected(pin),
                          child: AnimatedScale(
                            duration: const Duration(milliseconds: 160),
                            scale: isSelected ? 1.2 : 1.0,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: AppTheme.accentPinRed,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppTheme.pureWhite,
                                      width: 2.5,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black26,
                                        blurRadius: 6,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Center(
                                    child: CircleAvatar(
                                      radius: 4,
                                      backgroundColor: AppTheme.pureWhite,
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 3,
                                  height: 8,
                                  color: AppTheme.darkGrey,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    // 3. 選択中のピンの吹き出しカード
                    if (selectedPin != null &&
                        !selectedPin!.isRouteWaypointOnly)
                      Builder(
                        builder: (context) {
                          final activePin = selectedPin!;
                          final pinX =
                              activePin.mapNormalizedPosition.dx * size.width;
                          final pinY =
                              activePin.mapNormalizedPosition.dy * size.height;
                          final clampedLeft = (pinX - 125).clamp(
                            16.0,
                            (size.width - 266).clamp(16.0, double.infinity),
                          );
                          final topOffset = (pinY - 190).clamp(
                            110.0,
                            (size.height - 220).clamp(110.0, double.infinity),
                          );
                          return Positioned(
                            left: clampedLeft,
                            top: topOffset,
                            child: PinCalloutCard(
                              pin: activePin,
                              onOpenDetail: () => onOpenPinDetail(activePin),
                              onClose: () => onPinSelected(null),
                            ),
                          );
                        },
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

class _MockJapanMapPainter extends CustomPainter {
  _MockJapanMapPainter({required this.pins, required this.showRouteLine});

  final List<MemoryPin> pins;
  final bool showRouteLine;

  @override
  void paint(Canvas canvas, Size size) {
    // 背景（海・淡いグレー）
    final bgPaint = Paint()..color = const Color(0xFFECEEF1);
    canvas.drawRect(Offset.zero & size, bgPaint);

    // 淡い経緯度グリッド線
    final gridPaint = Paint()
      ..color = const Color(0xFFDDE1E6)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 48) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += 48) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // アイデアシート「メイン」にある日本列島の簡略シルエット（灰・白トーン）
    final landFill = Paint()
      ..color = AppTheme.pureWhite
      ..style = PaintingStyle.fill;
    final landStroke = Paint()
      ..color = AppTheme.mediumGrey
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // 北海道シルエット
    final hokkaido = Path()
      ..moveTo(size.width * 0.73, size.height * 0.16)
      ..lineTo(size.width * 0.88, size.height * 0.18)
      ..lineTo(size.width * 0.86, size.height * 0.27)
      ..lineTo(size.width * 0.72, size.height * 0.26)
      ..close();
    canvas.drawPath(hokkaido, landFill);
    canvas.drawPath(hokkaido, landStroke);

    // 本州シルエット（アイデアシートのL字状ポリゴン）
    final honshu = Path()
      ..moveTo(size.width * 0.70, size.height * 0.31)
      ..lineTo(size.width * 0.78, size.height * 0.33)
      ..lineTo(size.width * 0.74, size.height * 0.62)
      ..lineTo(size.width * 0.35, size.height * 0.70)
      ..lineTo(size.width * 0.31, size.height * 0.63)
      ..lineTo(size.width * 0.62, size.height * 0.54)
      ..close();
    canvas.drawPath(honshu, landFill);
    canvas.drawPath(honshu, landStroke);

    // 四国シルエット
    final shikoku = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            size.width * 0.38,
            size.height * 0.72,
            size.width * 0.11,
            size.height * 0.05,
          ),
          const Radius.circular(8),
        ),
      );
    canvas.drawPath(shikoku, landFill);
    canvas.drawPath(shikoku, landStroke);

    // 九州シルエット
    final kyushu = Path()
      ..addOval(
        Rect.fromLTWH(
          size.width * 0.21,
          size.height * 0.71,
          size.width * 0.12,
          size.height * 0.11,
        ),
      );
    canvas.drawPath(kyushu, landFill);
    canvas.drawPath(kyushu, landStroke);

    // ルート線（アイデアシート「ピン」下部の移動軌跡ライン）
    if (showRouteLine && pins.length >= 2) {
      final routePaint = Paint()
        ..color = AppTheme.darkGrey
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke;

      final routePath = Path();
      for (int i = 0; i < pins.length; i++) {
        final pt = Offset(
          pins[i].mapNormalizedPosition.dx * size.width,
          pins[i].mapNormalizedPosition.dy * size.height,
        );
        if (i == 0) {
          routePath.moveTo(pt.dx, pt.dy);
        } else {
          routePath.lineTo(pt.dx, pt.dy);
        }
      }
      canvas.drawPath(routePath, routePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MockJapanMapPainter oldDelegate) {
    return oldDelegate.pins != pins ||
        oldDelegate.showRouteLine != showRouteLine;
  }
}
