import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// アイデアシート「☆☆☆☆☆（星評価）」および「口コミ」入力セクション
class ReviewInputSection extends StatelessWidget {
  const ReviewInputSection({
    super.key,
    required this.rating,
    required this.commentController,
    required this.onRatingChanged,
    this.showRating = true,
  });

  /// false の場合（レビュー「しない」選択時）は星評価バーを非表示にし、口コミ入力欄のみ表示する
  final bool showRating;
  final int? rating;
  final TextEditingController commentController;
  final ValueChanged<int?> onRatingChanged;

  @override
  Widget build(BuildContext context) {
    final currentRating = rating ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 5段階の星評価バー（再タップで解除・未評価化可能）
        if (showRating) ...[
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(5, (index) {
                final starNumber = index + 1;
                final isSelected = starNumber <= currentRating;
                return IconButton(
                  tooltip: '$starNumberつ星',
                  onPressed: () {
                    if (rating == starNumber) {
                      onRatingChanged(null);
                    } else {
                      onRatingChanged(starNumber);
                    }
                  },
                  iconSize: 36,
                  icon: Icon(
                    isSelected ? Icons.star_rounded : Icons.star_border_rounded,
                    color: AppTheme.darkGrey,
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 12),
        ],
        const Text(
          '口コミ',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.darkGrey,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: commentController,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: '訪れた場所の感想や当時の思い出を記録しましょう（省略可能）...',
          ),
        ),
      ],
    );
  }
}
