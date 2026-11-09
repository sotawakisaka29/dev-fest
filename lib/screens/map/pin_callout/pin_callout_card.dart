import 'package:flutter/material.dart';
import '../../../core/models/memory_pin.dart';
import '../../../core/theme/app_theme.dart';

/// アイデアシート「ピン」の吹き出しカード
///
/// 記録のレビュー（5段階星評価）、口コミ、写真を元に地図上のピン上部に表示し、
/// 右下の「詳細→」から詳細ボトムシートを開く。
class PinCalloutCard extends StatelessWidget {
  const PinCalloutCard({
    super.key,
    required this.pin,
    required this.onOpenDetail,
    required this.onClose,
  });

  final MemoryPin pin;
  final VoidCallback onOpenDetail;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 250,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          decoration: BoxDecoration(
            color: AppTheme.pureWhite,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.darkGrey, width: 1.2),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      pin.placeName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkGrey,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: onClose,
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: AppTheme.mediumGrey,
                    ),
                  ),
                ],
              ),
              // ☆☆☆☆☆ 5段階評価（評価がある場合のみ表示）
              if (pin.rating != null && pin.rating! > 0) ...[
                const SizedBox(height: 4),
                Row(
                  children: List.generate(5, (index) {
                    final filled = index < pin.rating!;
                    return Icon(
                      filled ? Icons.star_rounded : Icons.star_border_rounded,
                      size: 18,
                      color: AppTheme.darkGrey,
                    );
                  }),
                ),
              ],
              if (pin.comment.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  pin.comment,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.primaryGrey,
                    height: 1.35,
                  ),
                ),
              ],
              if (pin.photoLabels.isNotEmpty) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: pin.photoLabels.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 6),
                    itemBuilder: (context, index) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceGrey,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.lightGrey),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.photo_outlined,
                              size: 13,
                              color: AppTheme.primaryGrey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              pin.photoLabels[index],
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppTheme.darkGrey,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: InkWell(
                  onTap: onOpenDetail,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.only(bottom: 1),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: AppTheme.darkGrey,
                          width: 1.1,
                        ),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '詳細',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.darkGrey,
                          ),
                        ),
                        SizedBox(width: 2),
                        Icon(
                          Icons.arrow_forward,
                          size: 13,
                          color: AppTheme.darkGrey,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // 吹き出し下部の三角形ポインタ
        CustomPaint(
          size: const Size(18, 9),
          painter: _CalloutTrianglePainter(),
        ),
      ],
    );
  }
}

class _CalloutTrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = AppTheme.pureWhite
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = AppTheme.darkGrey
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();

    canvas.drawPath(path, fillPaint);
    canvas.drawLine(
      Offset.zero,
      Offset(size.width / 2, size.height),
      strokePaint,
    );
    canvas.drawLine(
      Offset(size.width / 2, size.height),
      Offset(size.width, 0),
      strokePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
