import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/services/external_map_launcher.dart';
import '../../../core/services/place_autocomplete_service.dart';
import '../../../core/theme/app_theme.dart';

/// GoogleMapやInstagramと同様に、店舗名・スポット名を打ち込むと予測候補一覧が出てきて、
/// 選択したスポットの住所がリンクとして組み込まれる場所入力セクション
///
/// - レビューするで「しない」を選択した場合は、住所（場所）の入力欄自体を非表示にする。
/// - 何も打ち込まれていない時、ヒットする候補がない時、または入力中でない時は予測変換を表示しない。
class LocationInputSection extends StatefulWidget {
  const LocationInputSection({
    super.key,
    required this.shareLocation,
    required this.placeController,
    required this.selectedAddress,
    required this.selectedPrefecture,
    required this.onShareLocationChanged,
    required this.onCandidateSelected,
    required this.onPlaceTextChanged,
    this.selectedLatitude,
    this.selectedLongitude,
  });

  final bool shareLocation;
  final TextEditingController placeController;
  final String selectedAddress;
  final String selectedPrefecture;
  final double? selectedLatitude;
  final double? selectedLongitude;
  final ValueChanged<bool> onShareLocationChanged;
  final ValueChanged<PlaceCandidate> onCandidateSelected;
  final ValueChanged<String> onPlaceTextChanged;

  @override
  State<LocationInputSection> createState() => _LocationInputSectionState();
}

class _LocationInputSectionState extends State<LocationInputSection> {
  final FocusNode _focusNode = FocusNode();
  Timer? _debounceTimer;
  List<PlaceCandidate> _predictions = const [];
  bool _isSearching = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    if (!mounted) return;
    if (!_focusNode.hasFocus) {
      setState(() {
        _isEditing = false;
      });
    } else if (widget.placeController.text.trim().isNotEmpty) {
      setState(() {
        _isEditing = true;
      });
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _handleTextChanged(String text) {
    widget.onPlaceTextChanged(text);
    final query = text.trim();

    if (query.isEmpty) {
      _debounceTimer?.cancel();
      setState(() {
        _isEditing = false;
        _isSearching = false;
        _predictions = const [];
      });
      return;
    }

    final immediate = PlaceAutocompleteService.instance
        .filterImmediateCatalogByStoreName(query);

    setState(() {
      _isEditing = true;
      _predictions = immediate.take(8).toList();
    });

    // デバウンスして都道府県・オンラインジオコーディングを含む詳細予測候補を取得
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 200), () async {
      if (!mounted) return;
      if (widget.placeController.text.trim().isEmpty) {
        setState(() {
          _predictions = const [];
          _isSearching = false;
        });
        return;
      }
      setState(() => _isSearching = true);
      final results = await PlaceAutocompleteService.instance.searchPredictions(
        text,
      );
      if (!mounted) return;
      setState(() {
        _predictions = results;
        _isSearching = false;
      });
    });
  }

  void _selectCandidate(PlaceCandidate candidate) {
    _debounceTimer?.cancel();
    widget.onCandidateSelected(candidate);
    _focusNode.unfocus();
    setState(() {
      _isEditing = false;
      _predictions = const [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasInput = widget.placeController.text.trim().isNotEmpty;
    // 入力中 かつ 文字が打ち込まれている かつ ヒットする候補が存在するときのみ予測変換を表示
    final shouldShowPredictions =
        widget.shareLocation &&
        _isEditing &&
        hasInput &&
        _predictions.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. 「✓ レビューする   ○ しない」
        Row(
          children: [
            _ShareChoiceChip(
              label: 'レビューする',
              selected: widget.shareLocation,
              onTap: () => widget.onShareLocationChanged(true),
            ),
            const SizedBox(width: 16),
            _ShareChoiceChip(
              label: 'しない',
              selected: !widget.shareLocation,
              onTap: () {
                _focusNode.unfocus();
                setState(() {
                  _isEditing = false;
                  _predictions = const [];
                });
                widget.onShareLocationChanged(false);
              },
            ),
          ],
        ),

        // 「しない」を選択した場合は、住所（場所）の入力欄・住所リンク・予測変換を非表示にする
        if (widget.shareLocation) ...[
          const SizedBox(height: 16),

          // 2. スポット名・店舗名の検索入力欄
          TextField(
            key: const Key('place_search_text_field'),
            controller: widget.placeController,
            focusNode: _focusNode,
            onChanged: _handleTextChanged,
            onTap: () {
              if (widget.placeController.text.trim().isNotEmpty) {
                setState(() => _isEditing = true);
              }
            },
            onSubmitted: (_) {
              _focusNode.unfocus();
              setState(() => _isEditing = false);
            },
            decoration: InputDecoration(
              labelText: '訪れた場所を入力',
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AppTheme.darkGrey,
              ),
              suffixIcon: hasInput
                  ? IconButton(
                      tooltip: '入力をクリア',
                      icon: const Icon(
                        Icons.clear,
                        size: 18,
                        color: AppTheme.mediumGrey,
                      ),
                      onPressed: () {
                        widget.placeController.clear();
                        _handleTextChanged('');
                      },
                    )
                  : null,
            ),
          ),

          // 3. 選択されたスポットの住所リンク（タップでGoogleマップを開く。レビュー横の「↗」にもこの住所が組み込まれる）
          if (widget.selectedAddress.isNotEmpty) ...[
            const SizedBox(height: 8),
            InkWell(
              key: const Key('selected_address_link'),
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                ExternalMapLauncher.openGoogleMapsForAddress(
                  context,
                  address: widget.selectedAddress,
                  placeName: widget.placeController.text.trim(),
                  latitude: widget.selectedLatitude,
                  longitude: widget.selectedLongitude,
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceGrey,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.lightGrey),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.link_rounded,
                      size: 16,
                      color: AppTheme.darkGrey,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        widget.selectedAddress,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.darkGrey,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.north_east,
                      size: 15,
                      color: AppTheme.darkGrey,
                    ),
                  ],
                ),
              ),
            ),
          ],

          // 4. GoogleMap / Instagram風の予測候補ドロップダウン一覧
          if (shouldShowPredictions) ...[
            const SizedBox(height: 8),
            Container(
              key: const Key('place_prediction_list_container'),
              constraints: const BoxConstraints(maxHeight: 240),
              decoration: BoxDecoration(
                color: AppTheme.pureWhite,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.lightGrey),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                      child: Row(
                        children: [
                          const Text(
                            '予測候補',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryGrey,
                            ),
                          ),
                          const Spacer(),
                          if (_isSearching)
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.8,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: _predictions.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final candidate = _predictions[index];
                          return ListTile(
                            dense: true,
                            leading: const Icon(
                              Icons.place_outlined,
                              size: 20,
                              color: AppTheme.darkGrey,
                            ),
                            title: Text(
                              candidate.name,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.darkGrey,
                              ),
                            ),
                            subtitle: Text(
                              candidate.address,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.primaryGrey,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.north_west,
                              size: 15,
                              color: AppTheme.mediumGrey,
                            ),
                            onTap: () => _selectCandidate(candidate),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
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
