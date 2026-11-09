import 'dart:math' as math;
import 'app_photo.dart';
import 'memory_pin.dart';

/// 旅行スタート〜旅行停止で作成される「旅行まとめ（思い出）」モデル
class TripMemory {
  const TripMemory({
    required this.id,
    required this.teamId,
    required this.title,
    required this.startDate,
    required this.endDate,
    required this.pins,
    this.customDistanceKm,
  });

  final String id;
  final String teamId;
  final String title;
  final DateTime startDate;
  final DateTime endDate;
  final List<MemoryPin> pins;
  final double? customDistanceKm;

  TripMemory copyWith({
    String? id,
    String? teamId,
    String? title,
    DateTime? startDate,
    DateTime? endDate,
    List<MemoryPin>? pins,
    double? customDistanceKm,
  }) {
    return TripMemory(
      id: id ?? this.id,
      teamId: teamId ?? this.teamId,
      title: title ?? this.title,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      pins: pins ?? this.pins,
      customDistanceKm: customDistanceKm ?? this.customDistanceKm,
    );
  }

  /// 「0月0日 〜 0月0日」形式の期間テキスト
  String get formattedDateRange {
    return '${startDate.month}月${startDate.day}日 〜 ${endDate.month}月${endDate.day}日';
  }

  /// ピン間の緯度・経度から総移動距離（km）を算出する（Haversine公式）
  double get totalDistanceKm {
    if (customDistanceKm != null) return customDistanceKm!;
    if (pins.length < 2) return 0.0;

    double sumKm = 0.0;
    for (int i = 0; i < pins.length - 1; i++) {
      sumKm += _haversineKm(
        pins[i].latitude,
        pins[i].longitude,
        pins[i + 1].latitude,
        pins[i + 1].longitude,
      );
    }
    return sumKm;
  }

  String get formattedDistance {
    final km = totalDistanceKm;
    if (km == 0) return '0km';
    return '${km.toStringAsFixed(1)}km';
  }

  /// この旅行に含まれるすべての写真データ（下部縦スクロール一覧用）
  List<AppPhoto> get allPhotos {
    final List<AppPhoto> result = [];
    for (final pin in pins) {
      result.addAll(photosForPin(pin));
    }
    return result;
  }

  /// 特定のピンに紐づく写真リスト（実データまたはラベルから生成）
  static List<AppPhoto> photosForPin(MemoryPin pin) {
    if (pin.photos.isNotEmpty) {
      return pin.photos;
    }
    if (pin.photoLabels.isEmpty) {
      return const [];
    }
    return List.generate(pin.photoLabels.length, (index) {
      final label = pin.photoLabels[index];
      return AppPhoto(
        id: '${pin.id}_photo_$index',
        label: label,
        isFromGooglePhotos: false,
      );
    });
  }

  static double _haversineKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadiusKm = 6371.0;
    final double dLat = _degToRad(lat2 - lat1);
    final double dLon = _degToRad(lon2 - lon1);
    final double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) *
            math.cos(_degToRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _degToRad(double deg) => deg * (math.pi / 180.0);

  Map<String, dynamic> toFirestore() {
    return {
      'teamId': teamId,
      'title': title,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'customDistanceKm': customDistanceKm,
      'pins': pins.map((p) => {'id': p.id, ...p.toFirestore()}).toList(),
    };
  }

  factory TripMemory.fromFirestore(String id, Map<String, dynamic> data) {
    final rawPins = data['pins'] as List<dynamic>? ?? const [];
    final parsedPins = rawPins.map((m) {
      if (m is Map) {
        final stringKeyMap = Map<String, dynamic>.from(m);
        final pinId = stringKeyMap['id'] as String? ?? 'pin_${m.hashCode}';
        return MemoryPin.fromFirestore(pinId, stringKeyMap);
      }
      return null;
    }).whereType<MemoryPin>().toList();

    return TripMemory(
      id: id,
      teamId: data['teamId'] as String? ?? '',
      title: data['title'] as String? ?? '新しい旅行',
      startDate: data['startDate'] is String
          ? (DateTime.tryParse(data['startDate'] as String) ?? DateTime.now())
          : DateTime.now(),
      endDate: data['endDate'] is String
          ? (DateTime.tryParse(data['endDate'] as String) ?? DateTime.now())
          : DateTime.now(),
      pins: parsedPins,
      customDistanceKm: (data['customDistanceKm'] as num?)?.toDouble(),
    );
  }

  /// 初期サンプル思い出リスト（シードデータなし）
  static List<TripMemory> buildInitialSampleMemories(List<MemoryPin> allPins) {
    return const [];
  }
}
