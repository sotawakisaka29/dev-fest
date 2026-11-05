import 'package:flutter/material.dart';
import '../../core/models/memory_pin.dart';
import '../../core/theme/app_theme.dart';
import 'location_input/location_input_section.dart';
import 'photo_picker/photo_picker_section.dart';
import 'review_input/review_input_section.dart';
import 'time_range/time_range_section.dart';

/// アイデアシート「記録の様子」を統合する記録作成画面（MVP必須機能②）
class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key, required this.teamId});

  final String teamId;

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  final TextEditingController _placeController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();

  bool _shareLocation = true;
  String _selectedAddress = '東京都江東区平野1-4-8';
  String _selectedPrefecture = '東京都';
  double _selectedLatitude = 35.6777;
  double _selectedLongitude = 139.8027;
  Offset _selectedNormalizedPosition = const Offset(0.67, 0.55);

  TimeOfDay _startTime = const TimeOfDay(hour: 12, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 13, minute: 30);
  int _rating = 4;
  final List<String> _photos = ['外観写真', 'お気に入り1枚', '風景スナップ'];

  @override
  void dispose() {
    _placeController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  String _formatTime(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  void _handleSave() {
    final placeName = _placeController.text.trim().isEmpty
        ? '新しい思い出スポット'
        : _placeController.text.trim();

    final createdPin = MemoryPin(
      id: 'pin_${DateTime.now().millisecondsSinceEpoch}',
      teamId: widget.teamId,
      placeName: placeName,
      address: _selectedAddress,
      prefecture: _selectedPrefecture,
      latitude: _selectedLatitude,
      longitude: _selectedLongitude,
      mapNormalizedPosition: _selectedNormalizedPosition,
      startTime: _formatTime(_startTime),
      endTime: _formatTime(_endTime),
      rating: _rating,
      comment: _commentController.text.trim().isEmpty
          ? 'とても良い時間を過ごせました。'
          : _commentController.text.trim(),
      photoLabels: List<String>.from(_photos),
      shareLocation: _shareLocation,
    );

    Navigator.of(context).pop(createdPin);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          '記録',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppTheme.darkGrey,
          ),
        ),
        actions: [
          IconButton(
            tooltip: '戻る',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back, color: AppTheme.darkGrey),
          ),
          IconButton(
            tooltip: '保存する',
            onPressed: _handleSave,
            icon: const Icon(Icons.check, color: AppTheme.darkGrey),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LocationInputSection(
                shareLocation: _shareLocation,
                placeController: _placeController,
                selectedAddress: _selectedAddress,
                selectedPrefecture: _selectedPrefecture,
                onShareLocationChanged: (value) {
                  setState(() => _shareLocation = value);
                },
                onPlaceTextChanged: (_) {
                  setState(() {});
                },
                onCandidateSelected: (candidate) {
                  setState(() {
                    _placeController.text = candidate.name;
                    _selectedAddress = candidate.address;
                    _selectedPrefecture = candidate.prefecture;
                    _selectedLatitude = candidate.latitude;
                    _selectedLongitude = candidate.longitude;
                    _selectedNormalizedPosition = candidate.normalizedPosition;
                  });
                },
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 16),
              TimeRangeSection(
                startTime: _startTime,
                endTime: _endTime,
                onStartTimeChanged: (time) => setState(() => _startTime = time),
                onEndTimeChanged: (time) => setState(() => _endTime = time),
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),
              ReviewInputSection(
                rating: _rating,
                commentController: _commentController,
                onRatingChanged: (value) => setState(() => _rating = value),
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),
              PhotoPickerSection(
                photos: _photos,
                onAddPhoto: () {
                  setState(() {
                    _photos.add('追加写真 ${_photos.length + 1}');
                  });
                },
                onRemovePhotoAt: (index) {
                  setState(() {
                    _photos.removeAt(index);
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
