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
    final parsedPins = rawPins.whereType<Map<String, dynamic>>().map((m) {
      final pinId = m['id'] as String? ?? 'pin_${m.hashCode}';
      return MemoryPin.fromFirestore(pinId, m);
    }).toList();

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

  /// 初期サンプル思い出リスト（実ルート軌跡データ付き）
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

    // 東京・鎌倉ドライブ旅の実際の移動ルート（清澄白河→お台場・湾岸線→アクアライン海ほたる→横浜ベイブリッジ→鎌倉・七里ヶ浜）
    final kantoRoute = <RoutePoint>[
      RoutePoint(
        latitude: 35.6821,
        longitude: 139.7988,
        timestamp: DateTime(2026, 10, 18, 10, 30),
      ),
      RoutePoint(
        latitude: 35.6585,
        longitude: 139.7924,
        timestamp: DateTime(2026, 10, 18, 12, 10),
      ),
      RoutePoint(
        latitude: 35.6260,
        longitude: 139.7760,
        timestamp: DateTime(2026, 10, 18, 12, 25),
      ),
      RoutePoint(
        latitude: 35.5494,
        longitude: 139.7798,
        timestamp: DateTime(2026, 10, 18, 12, 42),
      ),
      RoutePoint(
        latitude: 35.4646,
        longitude: 139.8744,
        timestamp: DateTime(2026, 10, 18, 13, 0),
      ),
      RoutePoint(
        latitude: 35.5122,
        longitude: 139.7445,
        timestamp: DateTime(2026, 10, 18, 13, 35),
      ),
      RoutePoint(
        latitude: 35.4437,
        longitude: 139.6380,
        timestamp: DateTime(2026, 10, 18, 13, 55),
      ),
      RoutePoint(
        latitude: 35.3391,
        longitude: 139.5489,
        timestamp: DateTime(2026, 10, 18, 14, 15),
      ),
      RoutePoint(
        latitude: 35.3056,
        longitude: 139.5105,
        timestamp: DateTime(2026, 10, 18, 14, 30),
      ),
    ];

    return [
      if (kantoPins.isNotEmpty)
        TripMemory(
          id: 'trip_kanto_day',
          teamId: 'daily',
          title: '東京・鎌倉ドライブ旅',
          startDate: DateTime(2026, 10, 18, 10, 0),
          endDate: DateTime(2026, 10, 19, 18, 0),
          pins: kantoPins,
          routePoints: kantoRoute,
        ),
      if (kyotoPins.isNotEmpty)
        TripMemory(
          id: 'trip_kyoto_autumn',
          teamId: 'daily',
          title: '京都・嵐山散策',
          startDate: DateTime(2026, 10, 25, 9, 0),
          endDate: DateTime(2026, 10, 26, 17, 0),
          pins: kyotoPins,
          routePoints: [
            RoutePoint(
              latitude: 35.0116,
              longitude: 135.6767,
              timestamp: DateTime(2026, 10, 25, 9, 0),
            ),
            RoutePoint(
              latitude: 35.0138,
              longitude: 135.6778,
              timestamp: DateTime(2026, 10, 25, 9, 30),
            ),
            RoutePoint(
              latitude: 35.0170,
              longitude: 135.6713,
              timestamp: DateTime(2026, 10, 25, 10, 15),
            ),
            RoutePoint(
              latitude: 35.0212,
              longitude: 135.6695,
              timestamp: DateTime(2026, 10, 25, 11, 0),
            ),
          ],
          customDistanceKm: 12.4,
        ),
      if (hokkaidoPins.isNotEmpty)
        TripMemory(
          id: 'trip_hokkaido_gourmet',
          teamId: 'daily',
          title: '札幌ナイトグルメ巡り',
          startDate: DateTime(2026, 11, 1, 17, 0),
          endDate: DateTime(2026, 11, 3, 21, 0),
          pins: hokkaidoPins,
          routePoints: [
            RoutePoint(
              latitude: 43.0687,
              longitude: 141.3508,
              timestamp: DateTime(2026, 11, 1, 17, 30),
            ),
            RoutePoint(
              latitude: 43.0626,
              longitude: 141.3535,
              timestamp: DateTime(2026, 11, 1, 18, 0),
            ),
            RoutePoint(
              latitude: 43.0555,
              longitude: 141.3534,
              timestamp: DateTime(2026, 11, 1, 19, 30),
            ),
          ],
          customDistanceKm: 28.6,
        ),
      if (hakonePins.isNotEmpty)
        TripMemory(
          id: 'trip_hakone_onsen',
          teamId: 'hakone_trip',
          title: '箱根温泉1泊2日',
          startDate: DateTime(2026, 11, 2, 11, 0),
          endDate: DateTime(2026, 11, 3, 15, 0),
          pins: hakonePins,
          routePoints: [
            RoutePoint(
              latitude: 35.2564,
              longitude: 139.1549,
              timestamp: DateTime(2026, 11, 2, 13, 30),
            ),
            RoutePoint(
              latitude: 35.2324,
              longitude: 139.1069,
              timestamp: DateTime(2026, 11, 2, 15, 0),
            ),
            RoutePoint(
              latitude: 35.2435,
              longitude: 139.0442,
              timestamp: DateTime(2026, 11, 3, 10, 30),
            ),
          ],
          customDistanceKm: 18.2,
        ),
      if (cafePins.isNotEmpty)
        TripMemory(
          id: 'trip_daikanyama_cafe',
          teamId: 'cafe_club',
          title: '代官山カフェ巡り',
          startDate: DateTime(2026, 11, 5, 13, 0),
          endDate: DateTime(2026, 11, 5, 17, 0),
          pins: cafePins,
          routePoints: [
            RoutePoint(
              latitude: 35.6580,
              longitude: 139.7016,
              timestamp: DateTime(2026, 11, 5, 13, 30),
            ),
            RoutePoint(
              latitude: 35.6488,
              longitude: 139.6994,
              timestamp: DateTime(2026, 11, 5, 14, 0),
            ),
            RoutePoint(
              latitude: 35.6442,
              longitude: 139.7031,
              timestamp: DateTime(2026, 11, 5, 16, 0),
            ),
          ],
          customDistanceKm: 4.5,
        ),
    ];
  }
}
