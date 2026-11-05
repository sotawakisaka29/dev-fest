import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// 場所候補データ（Google Places Autocomplete API 接続枠）
class PlaceCandidate {
  const PlaceCandidate({
    required this.name,
    required this.address,
    required this.prefecture,
    required this.latitude,
    required this.longitude,
    required this.normalizedPosition,
  });

  final String name;
  final String address;
  final String prefecture;
  final double latitude;
  final double longitude;
  final Offset normalizedPosition;

  static const List<PlaceCandidate> sampleCandidates = [
    PlaceCandidate(
      name: 'ブルーボトルコーヒー 清澄白河フラッグシップカフェ',
      address: '東京都江東区平野1-4-8',
      prefecture: '東京都',
      latitude: 35.6777,
      longitude: 139.8027,
      normalizedPosition: Offset(0.67, 0.55),
    ),
    PlaceCandidate(
      name: '金沢21世紀美術館',
      address: '石川県金沢市広坂1-2-1',
      prefecture: '石川県',
      latitude: 36.5609,
      longitude: 136.6582,
      normalizedPosition: Offset(0.52, 0.54),
    ),
    PlaceCandidate(
      name: '道頓堀 グリコサイン前',
      address: '大阪府大阪市中央区道頓堀1-10-4',
      prefecture: '大阪府',
      latitude: 34.6687,
      longitude: 135.5013,
      normalizedPosition: Offset(0.43, 0.65),
    ),
    PlaceCandidate(
      name: '太宰府天満宮 参道茶屋',
      address: '福岡県太宰府市宰府4-7-1',
      prefecture: '福岡県',
      latitude: 33.5215,
      longitude: 130.5349,
      normalizedPosition: Offset(0.24, 0.74),
    ),
    PlaceCandidate(
      name: '仙台駅 牛たん通り',
      address: '宮城県仙台市青葉区中央1-1-1',
      prefecture: '宮城県',
      latitude: 38.2601,
      longitude: 140.8824,
      normalizedPosition: Offset(0.73, 0.41),
    ),
  ];
}

/// アイデアシート「記録の様子」の位置共有ON/OFF切替および場所入力（候補検索・住所補完）セクション
class LocationInputSection extends StatelessWidget {
  const LocationInputSection({
    super.key,
    required this.shareLocation,
    required this.placeController,
    required this.selectedAddress,
    required this.selectedPrefecture,
    required this.onShareLocationChanged,
    required this.onCandidateSelected,
    required this.onPlaceTextChanged,
  });

  final bool shareLocation;
  final TextEditingController placeController;
  final String selectedAddress;
  final String selectedPrefecture;
  final ValueChanged<bool> onShareLocationChanged;
  final ValueChanged<PlaceCandidate> onCandidateSelected;
  final ValueChanged<String> onPlaceTextChanged;

  @override
  Widget build(BuildContext context) {
    final query = placeController.text.trim().toLowerCase();
    final filteredCandidates = PlaceCandidate.sampleCandidates.where((c) {
      if (query.isEmpty) return true;
      return c.name.toLowerCase().contains(query) ||
          c.address.toLowerCase().contains(query) ||
          c.prefecture.toLowerCase().contains(query);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // アイデアシート「✓ 位置を共有する   ○ しない」
        Row(
          children: [
            _ShareChoiceChip(
              label: '位置を共有する',
              selected: shareLocation,
              onTap: () => onShareLocationChanged(true),
            ),
            const SizedBox(width: 16),
            _ShareChoiceChip(
              label: 'しない',
              selected: !shareLocation,
              onTap: () => onShareLocationChanged(false),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // アイデアシート「場所を入力（店の名前とか入力したら候補が出てきて住所を読む）」
        TextField(
          controller: placeController,
          onChanged: onPlaceTextChanged,
          decoration: const InputDecoration(
            labelText: '場所を入力',
            hintText: '店名・スポット名を入力して候補から選択',
            prefixIcon: Icon(Icons.place_outlined, color: AppTheme.darkGrey),
          ),
        ),
        if (selectedAddress.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.subdirectory_arrow_right,
                size: 16,
                color: AppTheme.primaryGrey,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '住所: $selectedAddress ($selectedPrefecture)',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.primaryGrey,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 10),
        const Text(
          'スポット候補（タップで住所を自動読込）：',
          style: TextStyle(fontSize: 11, color: AppTheme.mediumGrey),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: filteredCandidates.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final candidate = filteredCandidates[index];
              return ActionChip(
                backgroundColor: AppTheme.surfaceGrey,
                side: const BorderSide(color: AppTheme.lightGrey),
                label: Text(
                  candidate.name,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.darkGrey,
                  ),
                ),
                onPressed: () => onCandidateSelected(candidate),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ShareChoiceChip extends StatelessWidget {
  const _ShareChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? Icons.check_rounded : Icons.circle_outlined,
              size: 18,
              color: selected ? AppTheme.darkGrey : AppTheme.mediumGrey,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: selected ? AppTheme.darkGrey : AppTheme.mediumGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
