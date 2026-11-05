import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// アイデアシート「☆☆☆☆☆（星評価）」および「口コミ」入力セクション
class ReviewInputSection extends StatelessWidget {
  const ReviewInputSection({
    super.key,
    required this.rating,
    required this.commentController,
    required this.onRatingChanged,
  });

  final int rating;
  final TextEditingController commentController;
  final ValueChanged<int> onRatingChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 5段階の星評価バー
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(5, (index) {
              final starNumber = index + 1;
              final isSelected = starNumber <= rating;
              return IconButton(
                tooltip: '$starNumberつ星',
                onPressed: () => onRatingChanged(starNumber),
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
            hintText: '訪れた場所の感想や当時の思い出を記録しましょう...',
          ),
        ),
      ],
    );
  }
}
