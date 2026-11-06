import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/models/app_photo.dart';
import '../../core/models/memory_pin.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/google_photos_service.dart';
import '../../core/theme/app_theme.dart';
import 'location_input/location_input_section.dart';
import 'photo_picker/photo_picker_section.dart';
import 'review_input/review_input_section.dart';
import 'time_range/time_range_section.dart';

/// 記録作成画面（Googleフォト自動取得・端末アルバム写真選択対応）
class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key, required this.teamId});

  final String teamId;

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  final TextEditingController _placeController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  bool _shareLocation = true;
  String _selectedAddress = '東京都江東区平野1-4-8';
  String _selectedPrefecture = '東京都';
  double _selectedLatitude = 35.6777;
  double _selectedLongitude = 139.8027;
  Offset _selectedNormalizedPosition = const Offset(0.67, 0.55);

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 12, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 13, minute: 30);
  int _rating = 4;

  final List<AppPhoto> _photos = [];
  bool _isLoadingPhotos = false;

  @override
  void initState() {
    super.initState();
    // 画面初期化時に、選択されている日時のGoogleフォトを自動検索
    _fetchPhotosForCurrentRange();
  }

  @override
  void dispose() {
    _placeController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  DateTime get _startDateTime => DateTime(
    _selectedDate.year,
    _selectedDate.month,
    _selectedDate.day,
    _startTime.hour,
    _startTime.minute,
  );

  DateTime get _endDateTime => DateTime(
    _selectedDate.year,
    _selectedDate.month,
    _selectedDate.day,
    _endTime.hour,
    _endTime.minute,
  );

  /// 日時範囲が変更されたときに Google フォトAPIから実データを自動取得する
  Future<void> _fetchPhotosForCurrentRange() async {
    setState(() => _isLoadingPhotos = true);

    try {
      final googleUser = AuthService.instance.currentGoogleUser;
      final result = await GooglePhotosService.instance.searchPhotos(
        start: _startDateTime,
        end: _endDateTime,
        currentUser: googleUser,
      );

      if (mounted) {
        setState(() {
          // 手動でアルバム等から追加された写真は保持し、Googleフォト自動取得分のみ差し替え
          final manualPhotos = _photos.where((p) => !p.isFromGooglePhotos).toList();
          _photos.clear();
          _photos.addAll(manualPhotos);
          _photos.addAll(result.photos);
          _isLoadingPhotos = false;
        });

        // 通信結果やエラー理由をユーザーにスナックバーで通知
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message, style: const TextStyle(fontSize: 13)),
            duration: Duration(seconds: result.success ? 3 : 5),
            behavior: SnackBarBehavior.floating,
            backgroundColor: result.success ? null : Colors.redAccent.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingPhotos = false);
      }
    }
  }

  /// 端末のアルバムまたはカメラから写真を手動追加する
  Future<void> _handlePickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppTheme.pureWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: AppTheme.darkGrey),
                title: const Text('アルバムから選択（ギャラリー）'),
                onTap: () => Navigator.of(context).pop(ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: AppTheme.darkGrey),
                title: const Text('カメラで撮影'),
                onTap: () => Navigator.of(context).pop(ImageSource.camera),
              ),
            ],
          ),
        );
      },
    );

    if (source == null) return;

    try {
      if (source == ImageSource.gallery) {
        // 複数写真選択を試行
        final pickedFiles = await _imagePicker.pickMultiImage();
        if (pickedFiles.isNotEmpty && mounted) {
          setState(() {
            for (final file in pickedFiles) {
              _photos.insert(
                0, // 手動追加された写真を先頭付近に追加
                AppPhoto(
                  id: 'local_${DateTime.now().microsecondsSinceEpoch}',
                  label: file.name.isNotEmpty ? file.name : 'アルバム写真',
                  localPath: file.path,
                  takenAt: DateTime.now(),
                  isFromGooglePhotos: false,
                ),
              );
            }
          });
        }
      } else {
        // カメラ撮影
        final pickedFile = await _imagePicker.pickImage(source: ImageSource.camera);
        if (pickedFile != null && mounted) {
          setState(() {
            _photos.insert(
              0,
              AppPhoto(
                id: 'local_${DateTime.now().microsecondsSinceEpoch}',
                label: pickedFile.name.isNotEmpty ? pickedFile.name : '撮影写真',
                localPath: pickedFile.path,
                takenAt: DateTime.now(),
                isFromGooglePhotos: false,
              ),
            );
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('写真の選択に失敗しました: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
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
      photoLabels: _photos.map((p) => p.label).toList(),
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
              // 日時帯の選択セクション（変更時にGoogleフォト本番API再検索）
              TimeRangeSection(
                selectedDate: _selectedDate,
                startTime: _startTime,
                endTime: _endTime,
                isLoadingPhotos: _isLoadingPhotos,
                onDateChanged: (date) {
                  setState(() => _selectedDate = date);
                  _fetchPhotosForCurrentRange();
                },
                onStartTimeChanged: (time) {
                  setState(() => _startTime = time);
                  _fetchPhotosForCurrentRange();
                },
                onEndTimeChanged: (time) {
                  setState(() => _endTime = time);
                  _fetchPhotosForCurrentRange();
                },
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
              const SizedBox(height: 16),
              // 写真セクション（先頭手動追加・アルバム選択＆Googleフォト本番連動）
              PhotoPickerSection(
                photos: _photos,
                isLoading: _isLoadingPhotos,
                onRefreshFromGooglePhotos: _fetchPhotosForCurrentRange,
                onAddPhoto: _handlePickPhoto,
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
