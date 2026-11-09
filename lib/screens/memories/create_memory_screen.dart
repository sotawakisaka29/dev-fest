import 'package:flutter/material.dart';
import '../../core/models/memory_pin.dart';
import '../../core/models/trip_memory.dart';
import '../../core/services/location_tracking_service.dart';
import '../../core/theme/app_theme.dart';

/// 思い出一覧右上の「＋」ボタンから別ページとして遷移する「思い出を新規作成」画面
///
/// - タイトルと旅行の始まり〜終わりの日時を設定すると、その時間帯にそぐうレビュー・写真を自動でまとめる
/// - 通った道のルート（タイムライン・GPS履歴）があれば地図上のルート線と移動距離に反映する
/// - Googleマップのタイムラインを取り込む手順を、専門用語を使わずに誰でも迷わないようステップごとに親切に案内する
class CreateMemoryScreen extends StatefulWidget {
  const CreateMemoryScreen({
    super.key,
    required this.teamId,
    required this.availablePins,
  });

  final String teamId;
  final List<MemoryPin> availablePins;

  @override
  State<CreateMemoryScreen> createState() => _CreateMemoryScreenState();
}

class _CreateMemoryScreenState extends State<CreateMemoryScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _timelineController = TextEditingController();

  late DateTime _startDate;
  late TimeOfDay _startTime;
  late DateTime _endDate;
  late TimeOfDay _endTime;

  bool _showTimelineGuide = false;
  List<RoutePoint> _importedTimelinePoints = const [];

  @override
  void initState() {
    super.initState();
    final latestRecorded = widget.availablePins
        .map((p) => p.recordedDate)
        .whereType<DateTime>()
        .fold<DateTime?>(
          null,
          (prev, el) => prev == null || el.isAfter(prev) ? el : prev,
        );
    final baseDate = latestRecorded ?? DateTime.now();
    _startDate = DateTime(baseDate.year, baseDate.month, baseDate.day);
    _startTime = const TimeOfDay(hour: 9, minute: 0);
    _endDate = DateTime(baseDate.year, baseDate.month, baseDate.day);
    _endTime = const TimeOfDay(hour: 21, minute: 0);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _timelineController.dispose();
    super.dispose();
  }

  DateTime get _startDateTime => DateTime(
    _startDate.year,
    _startDate.month,
    _startDate.day,
    _startTime.hour,
    _startTime.minute,
  );

  DateTime get _endDateTime {
    final rawEnd = DateTime(
      _endDate.year,
      _endDate.month,
      _endDate.day,
      _endTime.hour,
      _endTime.minute,
    );
    if (rawEnd.isBefore(_startDateTime)) {
      return _startDateTime.add(const Duration(hours: 1));
    }
    return rawEnd;
  }

  /// 設定した時間帯に合致するレビュー・写真（MemoryPin）を自動抽出
  List<MemoryPin> get _matchedPins {
    final start = _startDateTime;
    final end = _endDateTime;
    final matched = widget.availablePins
        .where((pin) => pin.matchesTimeWindow(start, end))
        .toList();
    matched.sort((a, b) {
      final aTime = a.resolvedTimeRange?.$1 ?? a.recordedDate ?? start;
      final bTime = b.resolvedTimeRange?.$1 ?? b.recordedDate ?? start;
      return aTime.compareTo(bTime);
    });
    return matched;
  }

  /// 設定した時間帯に通った道のルート（タイムライン・GPS履歴）のみを取得（※ピン位置には追従しない）
  List<RoutePoint> get _matchedRoutePoints {
    return LocationTrackingService.instance.buildRouteForTimeWindow(
      startDateTime: _startDateTime,
      endDateTime: _endDateTime,
      importedTimelinePoints: _importedTimelinePoints,
    );
  }

  double get _estimatedDistanceKm {
    final route = _matchedRoutePoints;
    if (route.length >= 2) {
      return TripMemory.calculateRouteDistanceKm(route);
    }
    return 0.0;
  }

  int get _matchedPhotoCount {
    int count = 0;
    for (final pin in _matchedPins) {
      count += TripMemory.photosForPin(pin).length;
    }
    return count;
  }

  String _formatDate(DateTime date) {
    return '${date.year}年${date.month}月${date.day}日';
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null && mounted) {
      setState(() {
        _startDate = picked;
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate;
        }
      });
    }
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (picked != null && mounted) {
      setState(() => _startTime = picked);
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null && mounted) {
      setState(() {
        _endDate = picked;
        if (_endDate.isBefore(_startDate)) {
          _startDate = _endDate;
        }
      });
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
    );
    if (picked != null && mounted) {
      setState(() => _endTime = picked);
    }
  }

  void _handleTimelineTextChanged(String rawText) {
    if (rawText.trim().isEmpty) {
      setState(() => _importedTimelinePoints = const []);
      return;
    }
    final parsed = LocationTrackingService.instance.parseGoogleTimelineJson(
      rawText,
    );
    setState(() {
      _importedTimelinePoints = parsed;
    });
  }

  void _handleSubmit() {
    final title = _titleController.text.trim().isEmpty
        ? '新しい思い出'
        : _titleController.text.trim();
    final memoryId = 'trip_manual_${DateTime.now().millisecondsSinceEpoch}';
    final pins = _matchedPins
        .map((p) => p.copyWith(tripId: p.tripId ?? memoryId))
        .toList();
    final routePoints = _matchedRoutePoints;
    final distanceKm = _estimatedDistanceKm;

    final createdMemory = TripMemory(
      id: memoryId,
      teamId: widget.teamId,
      title: title,
      startDate: _startDateTime,
      endDate: _endDateTime,
      pins: pins,
      routePoints: routePoints,
      customDistanceKm: distanceKm > 0 ? distanceKm : null,
    );

    Navigator.of(context).pop(createdMemory);
  }

  @override
  Widget build(BuildContext context) {
    final matchedPins = _matchedPins;
    final routePoints = _matchedRoutePoints;
    final distKm = _estimatedDistanceKm;

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
          '思い出を新規作成',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.darkGrey,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),

              // 1. タイトル入力
              const Text(
                '旅行のタイトル',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkGrey,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('manual_memory_title_field'),
                controller: _titleController,
                decoration: const InputDecoration(),
              ),
              const SizedBox(height: 24),

              // 2. 旅行の始まり〜終わりの日時設定
              const Text(
                '旅行の始まり',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkGrey,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: OutlinedButton.icon(
                      key: const Key('manual_memory_start_date_button'),
                      onPressed: _pickStartDate,
                      icon: const Icon(Icons.calendar_today_outlined, size: 18),
                      label: Text(_formatDate(_startDate)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: OutlinedButton.icon(
                      key: const Key('manual_memory_start_time_button'),
                      onPressed: _pickStartTime,
                      icon: const Icon(Icons.access_time, size: 18),
                      label: Text(_formatTime(_startTime)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              const Text(
                '旅行の終わり（終了日時）',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkGrey,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: OutlinedButton.icon(
                      key: const Key('manual_memory_end_date_button'),
                      onPressed: _pickEndDate,
                      icon: const Icon(Icons.event_outlined, size: 18),
                      label: Text(_formatDate(_endDate)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: OutlinedButton.icon(
                      key: const Key('manual_memory_end_time_button'),
                      onPressed: _pickEndTime,
                      icon: const Icon(Icons.access_time, size: 18),
                      label: Text(_formatTime(_endTime)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),

              // 3. Googleマップのタイムライン（通った道）の貼り付け＆やさしい手順ガイド
              const Text(
                'Googleマップのタイムラインを取り込む',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkGrey,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'アプリに移動記録が残っていない場合、GoogleMapタイムラインのデータを用いることができます。',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.primaryGrey,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),

              // 誰でも迷わないステップバイステップの説明カード（開閉可能・初期表示でも見やすいボタン）
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  setState(() => _showTimelineGuide = !_showTimelineGuide);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceGrey,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.lightGrey),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.help_outline_rounded,
                            size: 20,
                            color: AppTheme.darkGrey,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'はじめての方へ：タイムラインの取り出し方を見る',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.darkGrey,
                              ),
                            ),
                          ),
                          Icon(
                            _showTimelineGuide
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            color: AppTheme.darkGrey,
                          ),
                        ],
                      ),
                      if (_showTimelineGuide) ...[
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 12),
                        const _StepGuideRow(
                          stepNumber: '1',
                          title: 'スマホで「Google マップ」アプリを開きます',
                          description: '普段使っているGoogleマップのアプリを起動してください。',
                        ),
                        const SizedBox(height: 10),
                        const _StepGuideRow(
                          stepNumber: '2',
                          title: '画面右上の「自分のアイコン（丸い写真）」をタップします',
                          description: '検索バーの右端にあるあなたのプロフィール画像を押します。',
                        ),
                        const SizedBox(height: 10),
                        const _StepGuideRow(
                          stepNumber: '3',
                          title: 'メニューの中の「タイムライン」をタップします',
                          description: 'あなたが歩いた・移動した道の記録画面が開きます。',
                        ),
                        const SizedBox(height: 10),
                        const _StepGuideRow(
                          stepNumber: '4',
                          title: '右上の「…（3つの点）」→「位置情報とプライバシーの設定」を押します',
                          description:
                              '画面を少し下にスクロールすると出てくる「タイムライン データをエクスポート（書き出し）」をタップして保存します。',
                        ),
                        const SizedBox(height: 10),
                        const _StepGuideRow(
                          stepNumber: '5',
                          title: '保存されたファイルを開き、中身をすべてコピーして下の欄に貼り付けます',
                          description:
                              'スマホの「ファイル」アプリで書き出したファイルを開き、「すべて選択」→「コピー」して、すぐ下の入力欄を長押しして「貼り付け」してください。',
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('manual_memory_timeline_json_field'),
                controller: _timelineController,
                maxLines: 4,
                style: const TextStyle(fontSize: 12),
                decoration: const InputDecoration(
                  labelText: 'ここにコピーしたデータを貼り付けて下さい',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: _handleTimelineTextChanged,
              ),
              const SizedBox(height: 24),

              // 4. この時間帯で自動まとめされる内容のプレビュー
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceGrey,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.lightGrey),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '自動でまとめられる内容',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkGrey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '・対象レビュー：${matchedPins.length}件 / 写真：$_matchedPhotoCount枚',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.darkGrey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '・通った道のルート：${routePoints.length}地点（移動距離：${distKm == 0 ? '0km' : '${distKm.toStringAsFixed(1)}km'}）',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.darkGrey,
                      ),
                    ),
                    if (matchedPins.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        '含まれるスポット：${matchedPins.map((p) => p.placeName).join('、')}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.primaryGrey,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // 5. 作成ボタン
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  key: const Key('manual_memory_submit_button'),
                  onPressed: _handleSubmit,
                  child: const Text(
                    '作成',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepGuideRow extends StatelessWidget {
  const _StepGuideRow({
    required this.stepNumber,
    required this.title,
    required this.description,
  });

  final String stepNumber;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppTheme.darkGrey,
            shape: BoxShape.circle,
          ),
          child: Text(
            stepNumber,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppTheme.pureWhite,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkGrey,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.primaryGrey,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
