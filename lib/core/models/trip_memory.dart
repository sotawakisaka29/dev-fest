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

  /// 初期サンプル思い出リスト
  static List<TripMemory> buildInitialSampleMemories(List<MemoryPin> allPins) {
    final kantoPins = allPins
        .where((p) => p.tripId == 'trip_kanto_day')
        .toList();
    final kyotoPins = allPins
        .where((p) => p.tripId == 'trip_kyoto_autumn')
        .toList();
    final hokkaidoPins = allPins
        .where((p) => p.tripId == 'trip_hokkaido_gourmet')
        .toList();
    final hakonePins = allPins
        .where((p) => p.tripId == 'trip_hakone_onsen')
        .toList();
    final cafePins = allPins
        .where((p) => p.tripId == 'trip_daikanyama_cafe')
        .toList();

    return [
      if (kantoPins.isNotEmpty)
        TripMemory(
          id: 'trip_kanto_day',
          teamId: 'daily',
          title: '東京・鎌倉ドライブ旅',
          startDate: DateTime(2026, 10, 18),
          endDate: DateTime(2026, 10, 19),
          pins: kantoPins,
        ),
      if (kyotoPins.isNotEmpty)
        TripMemory(
          id: 'trip_kyoto_autumn',
          teamId: 'daily',
          title: '京都・嵐山散策',
          startDate: DateTime(2026, 10, 25),
          endDate: DateTime(2026, 10, 26),
          pins: kyotoPins,
          customDistanceKm: 12.4,
        ),
      if (hokkaidoPins.isNotEmpty)
        TripMemory(
          id: 'trip_hokkaido_gourmet',
          teamId: 'daily',
          title: '札幌ナイトグルメ巡り',
          startDate: DateTime(2026, 11, 1),
          endDate: DateTime(2026, 11, 3),
          pins: hokkaidoPins,
          customDistanceKm: 28.6,
        ),
      if (hakonePins.isNotEmpty)
        TripMemory(
          id: 'trip_hakone_onsen',
          teamId: 'hakone_trip',
          title: '箱根温泉1泊2日',
          startDate: DateTime(2026, 11, 2),
          endDate: DateTime(2026, 11, 3),
          pins: hakonePins,
          customDistanceKm: 18.2,
        ),
      if (cafePins.isNotEmpty)
        TripMemory(
          id: 'trip_daikanyama_cafe',
          teamId: 'cafe_club',
          title: '代官山カフェ巡り',
          startDate: DateTime(2026, 11, 5),
          endDate: DateTime(2026, 11, 5),
          pins: cafePins,
          customDistanceKm: 4.5,
        ),
    ];
  }
}

