import 'dart:math' as math;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'app_photo.dart';
import 'memory_pin.dart';

/// 移動ルートの1地点（緯度・経度・通過日時）を表すモデル
class RoutePoint {
  const RoutePoint({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  final double latitude;
  final double longitude;
  final DateTime timestamp;

  LatLng get latLng => LatLng(latitude, longitude);

  Map<String, dynamic> toMap() {
    return {
      'lat': latitude,
      'lng': longitude,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory RoutePoint.fromMap(Map<String, dynamic> map) {
    return RoutePoint(
      latitude: (map['lat'] as num?)?.toDouble() ?? 35.6812,
      longitude: (map['lng'] as num?)?.toDouble() ?? 139.7671,
      timestamp: map['timestamp'] is String
          ? (DateTime.tryParse(map['timestamp'] as String) ?? DateTime.now())
          : DateTime.now(),
    );
  }
}

/// 旅行スタート〜旅行終了、または手動の期間指定で作成される「旅行まとめ（思い出）」モデル
class TripMemory {
  const TripMemory({
    required this.id,
    required this.teamId,
    required this.title,
    required this.startDate,
    required this.endDate,
    required this.pins,
    this.routePoints = const [],
    this.customDistanceKm,
  });

  final String id;
  final String teamId;
  final String title;
  final DateTime startDate;
  final DateTime endDate;
  final List<MemoryPin> pins;

  /// 旅行中またはGoogleタイムライン等から取得・記録された実際の移動ルート座標列
  final List<RoutePoint> routePoints;
  final double? customDistanceKm;

  /// 「0月0日 〜 0月0日」形式の期間テキスト
  String get formattedDateRange {
    return '${startDate.month}月${startDate.day}日 〜 ${endDate.month}月${endDate.day}日';
  }

  /// 地図上に描画するためのルート座標列（通った道のルート保存のみを使用し、ピンには追従しない）
  List<LatLng> get effectiveRouteLatLngs {
    if (routePoints.length >= 2) {
      return routePoints.map((p) => p.latLng).toList();
    }
    return const [];
  }

  /// 通った道の実ルート座標列（routePoints）の緯度・経度から総移動距離（km）を算出する（Haversine公式）
  double get totalDistanceKm {
    if (customDistanceKm != null) return customDistanceKm!;

    final points = effectiveRouteLatLngs;
    if (points.length < 2) return 0.0;

    double sumKm = 0.0;
    for (int i = 0; i < points.length - 1; i++) {
      sumKm += haversineKm(
        points[i].latitude,
        points[i].longitude,
        points[i + 1].latitude,
        points[i + 1].longitude,
      );
    }
    return sumKm;
  }

  String get formattedDistance {
    final km = totalDistanceKm;
    if (km == 0) return '0km';
    return '${km.toStringAsFixed(1)}km';
  }

  TripMemory copyWith({
    String? id,
    String? teamId,
    String? title,
    DateTime? startDate,
    DateTime? endDate,
    List<MemoryPin>? pins,
    List<RoutePoint>? routePoints,
    double? customDistanceKm,
  }) {
    return TripMemory(
      id: id ?? this.id,
      teamId: teamId ?? this.teamId,
      title: title ?? this.title,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      pins: pins ?? this.pins,
      routePoints: routePoints ?? this.routePoints,
      customDistanceKm: customDistanceKm ?? this.customDistanceKm,
    );
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

  static double haversineKm(
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

  static double calculateRouteDistanceKm(List<RoutePoint> route) {
    if (route.length < 2) return 0.0;
    double sumKm = 0.0;
    for (int i = 0; i < route.length - 1; i++) {
      sumKm += haversineKm(
        route[i].latitude,
        route[i].longitude,
        route[i + 1].latitude,
        route[i + 1].longitude,
      );
    }
    return sumKm;
  }

  static double _degToRad(double deg) => deg * (math.pi / 180.0);

  Map<String, dynamic> toFirestore() {
    return {
      'teamId': teamId,
      'title': title,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'customDistanceKm': customDistanceKm,
      'routePoints': routePoints.map((rp) => rp.toMap()).toList(),
      'pins': pins.map((p) => {'id': p.id, ...p.toFirestore()}).toList(),
    };
  }

  factory TripMemory.fromFirestore(String id, Map<String, dynamic> data) {
    final rawPins = data['pins'] as List<dynamic>? ?? const [];
    final parsedPins = rawPins
        .map((m) {
          if (m is Map) {
            final stringKeyMap = Map<String, dynamic>.from(m);
            final pinId = stringKeyMap['id'] as String? ?? 'pin_${m.hashCode}';
            return MemoryPin.fromFirestore(pinId, stringKeyMap);
          }
          return null;
        })
        .whereType<MemoryPin>()
        .toList();

    final rawRoutePoints = data['routePoints'] as List<dynamic>? ?? const [];
    final parsedRoutePoints = rawRoutePoints
        .whereType<Map<String, dynamic>>()
        .map(RoutePoint.fromMap)
        .toList();

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
      routePoints: parsedRoutePoints,
      customDistanceKm: (data['customDistanceKm'] as num?)?.toDouble(),
    );
  }

  /// 初期サンプル思い出リスト（シードデータなし）
  static List<TripMemory> buildInitialSampleMemories(List<MemoryPin> allPins) {
    return const [];
  }
}
