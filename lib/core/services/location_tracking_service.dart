import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/memory_pin.dart';
import '../models/trip_memory.dart';

/// 案A：GPSリアルタイム軌跡記録 ＋ Googleタイムライン（Location History）データ連携サービス
///
/// 1. 「旅行スタート」押下時に開始日時（DateTime）と現在位置を取得し、
///    「旅行終了」まで移動した位置の座標を継続取得してリアルタイムに線を引く。
/// 2. 過去に記録した位置履歴・タイムラインデータ（Google Timeline JSONインポート含む）を保持し、
///    「思い出一覧の＋ボタン」から期間指定で手動作成する際に、その時間帯のルート線と移動距離（km）を自動算出する。
class LocationTrackingService {
  LocationTrackingService._() {
    _seedInitialTimelineLogs();
  }

  static final LocationTrackingService instance = LocationTrackingService._();

  StreamSubscription<Position>? _positionSubscription;
  final List<RoutePoint> _activeRoutePoints = [];
  final List<RoutePoint> _timelineHistoryLogs = [];
  bool _isTracking = false;

  /// テスト環境やシミュレータでGPSストリームを制御するためのオーバーライドフック
  @visibleForTesting
  Future<RoutePoint?> Function()? mockCurrentLocationProvider;

  @visibleForTesting
  Stream<RoutePoint>? mockPositionStream;

  bool get isTracking => _isTracking;

  List<RoutePoint> get activeRoutePoints =>
      List<RoutePoint>.unmodifiable(_activeRoutePoints);

  List<RoutePoint> get timelineHistoryLogs =>
      List<RoutePoint>.unmodifiable(_timelineHistoryLogs);

  void _seedInitialTimelineLogs() {
    if (_timelineHistoryLogs.isNotEmpty) return;
    final sampleMemories = TripMemory.buildInitialSampleMemories(
      MemoryPin.initialSamplePins,
    );
    for (final memory in sampleMemories) {
      for (final point in memory.routePoints) {
        _addHistoryPointIfUnique(point);
      }
    }
  }

  void _addHistoryPointIfUnique(RoutePoint point) {
    final exists = _timelineHistoryLogs.any(
      (p) =>
          p.timestamp.isAtSameMomentAs(point.timestamp) &&
          (p.latitude - point.latitude).abs() < 1e-6 &&
          (p.longitude - point.longitude).abs() < 1e-6,
    );
    if (!exists) {
      _timelineHistoryLogs.add(point);
      _timelineHistoryLogs.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    }
  }

  /// 旅行スタート時に現在位置を取得し、移動に応じたルート追跡を開始する
  Future<RoutePoint> startTracking({
    required ValueChanged<List<RoutePoint>> onRouteUpdated,
    DateTime? startTime,
    RoutePoint? fallbackInitialPoint,
  }) async {
    await stopTracking();
    _activeRoutePoints.clear();
    _isTracking = true;

    final startTimestamp = startTime ?? DateTime.now();
    final initialPoint = await _resolveCurrentLocation(
      timestamp: startTimestamp,
      fallback: fallbackInitialPoint,
    );

    _appendActivePoint(initialPoint);
    onRouteUpdated(activeRoutePoints);

    // テスト用モックストリームがある場合
    if (mockPositionStream != null) {
      _positionSubscription = mockPositionStream!
          .map(
            (rp) => Position(
              latitude: rp.latitude,
              longitude: rp.longitude,
              timestamp: rp.timestamp,
              accuracy: 5.0,
              altitude: 0.0,
              altitudeAccuracy: 0.0,
              heading: 0.0,
              headingAccuracy: 0.0,
              speed: 0.0,
              speedAccuracy: 0.0,
            ),
          )
          .listen((pos) {
            if (!_isTracking) return;
            _appendActivePoint(
              RoutePoint(
                latitude: pos.latitude,
                longitude: pos.longitude,
                timestamp: pos.timestamp,
              ),
            );
            onRouteUpdated(activeRoutePoints);
          });
      return initialPoint;
    }

    // 実機・エミュレータのGPSストリーム購読
    try {
      final hasPermission = await _ensureLocationPermission();
      if (hasPermission) {
        const locationSettings = LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // 10m以上移動するごとに新しい座標点を追加
        );
        _positionSubscription =
            Geolocator.getPositionStream(
              locationSettings: locationSettings,
            ).listen(
              (Position position) {
                if (!_isTracking) return;
                final point = RoutePoint(
                  latitude: position.latitude,
                  longitude: position.longitude,
                  timestamp: DateTime.now(),
                );
                if (_shouldRecordNextPoint(point)) {
                  _appendActivePoint(point);
                  onRouteUpdated(activeRoutePoints);
                }
              },
              onError: (Object error) {
                debugPrint('Location stream error: $error');
              },
            );
      }
    } catch (e) {
      debugPrint('Geolocator stream initialization skipped: $e');
    }

    return initialPoint;
  }

  /// 旅行中にスポット記録（ピン追加）などが行われた際、または手動で現在位置が更新された際にルート点を追加する
  void recordManualOrWaypointLocation(RoutePoint point) {
    _addHistoryPointIfUnique(point);
    if (!_isTracking) return;
    if (_shouldRecordNextPoint(point)) {
      _appendActivePoint(point);
    }
  }

  /// 旅行終了ボタン押下時にルート記録をストップし、そこまでの経路座標リストを返す
  Future<List<RoutePoint>> stopTracking() async {
    _isTracking = false;
    try {
      await _positionSubscription?.cancel();
    } catch (_) {}
    _positionSubscription = null;

    final recorded = List<RoutePoint>.from(_activeRoutePoints);
    return recorded;
  }

  void _appendActivePoint(RoutePoint point) {
    _activeRoutePoints.add(point);
    _addHistoryPointIfUnique(point);
  }

  bool _shouldRecordNextPoint(RoutePoint nextPoint) {
    if (_activeRoutePoints.isEmpty) return true;
    final last = _activeRoutePoints.last;
    final distKm = TripMemory.haversineKm(
      last.latitude,
      last.longitude,
      nextPoint.latitude,
      nextPoint.longitude,
    );
    // 約5m以上の移動があれば新しいルート点として記録
    return distKm >= 0.005;
  }

  Future<RoutePoint> _resolveCurrentLocation({
    required DateTime timestamp,
    RoutePoint? fallback,
  }) async {
    if (mockCurrentLocationProvider != null) {
      final mocked = await mockCurrentLocationProvider!();
      if (mocked != null) {
        return RoutePoint(
          latitude: mocked.latitude,
          longitude: mocked.longitude,
          timestamp: timestamp,
        );
      }
    }

    try {
      final hasPermission = await _ensureLocationPermission();
      if (hasPermission) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 5),
          ),
        );
        return RoutePoint(
          latitude: pos.latitude,
          longitude: pos.longitude,
          timestamp: timestamp,
        );
      }
    } catch (e) {
      debugPrint('Current location fallback used: $e');
    }

    return fallback ??
        RoutePoint(
          latitude: 35.6812,
          longitude: 139.7671,
          timestamp: timestamp,
        );
  }

  Future<bool> _ensureLocationPermission() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return false;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      return permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    } catch (_) {
      return false;
    }
  }

  /// 指定された時間帯（startDateTime 〜 endDateTime）に合致する通った道のルート（タイムライン・GPS履歴）のみを抽出する
  /// ※ピン（レビュー）と通った道のルート保存は別件のため、ピンの場所へ線を追従させることはしない
  List<RoutePoint> buildRouteForTimeWindow({
    required DateTime startDateTime,
    required DateTime endDateTime,
    List<RoutePoint> importedTimelinePoints = const [],
  }) {
    final List<RoutePoint> collected = [];

    // 1. アプリ内GPS・タイムライン履歴ログから該当時間帯の座標を抽出
    for (final point in _timelineHistoryLogs) {
      if (!point.timestamp.isBefore(startDateTime) &&
          !point.timestamp.isAfter(endDateTime)) {
        collected.add(point);
      }
    }

    // 2. 貼り付け（インポート）されたGoogleタイムライン座標があれば統合
    for (final point in importedTimelinePoints) {
      if (!point.timestamp.isBefore(startDateTime) &&
          !point.timestamp.isAfter(endDateTime)) {
        collected.add(point);
      }
    }

    // 時間帯フィルタに一致しないタイムラインデータが貼り付けられた場合でも、
    // ユーザーが明示的に今回の旅行用として貼り付けたタイムライン点があればそれを使用する
    if (collected.isEmpty && importedTimelinePoints.isNotEmpty) {
      collected.addAll(importedTimelinePoints);
    }

    collected.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // 重複座標の除去
    final List<RoutePoint> deduplicated = [];
    for (final pt in collected) {
      if (deduplicated.isEmpty) {
        deduplicated.add(pt);
        continue;
      }
      final prev = deduplicated.last;
      final dist = TripMemory.haversineKm(
        prev.latitude,
        prev.longitude,
        pt.latitude,
        pt.longitude,
      );
      if (dist >= 0.002) {
        deduplicated.add(pt);
      }
    }

    return deduplicated;
  }

  /// Googleマップのタイムライン（Timeline.json / Semantic Location History / GeoJSON 形式）テキストから
  /// 経路座標（RoutePoint）をパースして取り込む
  List<RoutePoint> parseGoogleTimelineJson(
    String rawJsonText, {
    DateTime? filterStart,
    DateTime? filterEnd,
  }) {
    final List<RoutePoint> results = [];
    try {
      final decoded = jsonDecode(rawJsonText);
      _extractTimelinePointsRecursive(decoded, results);
    } catch (e) {
      debugPrint('Timeline JSON parse error: $e');
    }

    if (results.isEmpty) return const [];

    results.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    for (final pt in results) {
      _addHistoryPointIfUnique(pt);
    }

    if (filterStart != null && filterEnd != null) {
      return results
          .where(
            (p) =>
                !p.timestamp.isBefore(filterStart) &&
                !p.timestamp.isAfter(filterEnd),
          )
          .toList();
    }
    return results;
  }

  void _extractTimelinePointsRecursive(
    dynamic node,
    List<RoutePoint> outPoints,
  ) {
    if (node is List) {
      for (final item in node) {
        _extractTimelinePointsRecursive(item, outPoints);
      }
      return;
    }
    if (node is! Map) return;

    // 1. 新形式 Google Timeline JSON: semanticSegments -> timelinePath -> [{"point": "35.6812°, 139.7671°", "time": "..."}]
    if (node['point'] is String) {
      final latLng = _parseLatLngString(node['point'] as String);
      final timeStr =
          node['time'] as String? ?? node['timestamp'] as String? ?? '';
      final parsedTime =
          DateTime.tryParse(timeStr)?.toLocal() ?? DateTime.now();
      if (latLng != null) {
        outPoints.add(
          RoutePoint(
            latitude: latLng.$1,
            longitude: latLng.$2,
            timestamp: parsedTime,
          ),
        );
      }
    }

    // 2. E7 形式 (latitudeE7 / longitudeE7 または latE7 / lngE7)
    final latE7 = (node['latitudeE7'] ?? node['latE7']) as num?;
    final lngE7 = (node['longitudeE7'] ?? node['lngE7']) as num?;
    if (latE7 != null && lngE7 != null) {
      final timeStr =
          (node['timestamp'] ?? node['startTimestamp']) as String? ?? '';
      final ms = node['timestampMs'] is String
          ? int.tryParse(node['timestampMs'] as String)
          : (node['timestampMs'] as num?)?.toInt();
      final parsedTime = ms != null
          ? DateTime.fromMillisecondsSinceEpoch(ms)
          : (DateTime.tryParse(timeStr)?.toLocal() ?? DateTime.now());
      outPoints.add(
        RoutePoint(
          latitude: latE7.toDouble() / 1e7,
          longitude: lngE7.toDouble() / 1e7,
          timestamp: parsedTime,
        ),
      );
    }

    // 3. シンプルな {"lat": 35.68, "lng": 139.76, "timestamp": "..."} 形式
    final lat = (node['lat'] ?? node['latitude']) as num?;
    final lng = (node['lng'] ?? node['longitude']) as num?;
    if (lat != null && lng != null && latE7 == null) {
      final timeStr = (node['timestamp'] ?? node['time']) as String? ?? '';
      final parsedTime =
          DateTime.tryParse(timeStr)?.toLocal() ?? DateTime.now();
      outPoints.add(
        RoutePoint(
          latitude: lat.toDouble(),
          longitude: lng.toDouble(),
          timestamp: parsedTime,
        ),
      );
    }

    for (final value in node.values) {
      if (value is Map || value is List) {
        _extractTimelinePointsRecursive(value, outPoints);
      }
    }
  }

  (double, double)? _parseLatLngString(String raw) {
    final cleaned = raw.replaceAll('°', '').replaceAll('geo:', '').trim();
    final parts = cleaned.split(',');
    if (parts.length < 2) return null;
    final lat = double.tryParse(parts[0].trim());
    final lng = double.tryParse(parts[1].trim());
    if (lat == null || lng == null) return null;
    return (lat, lng);
  }
}
