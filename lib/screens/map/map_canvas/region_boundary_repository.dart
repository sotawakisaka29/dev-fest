import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

typedef RegionPolygons = Map<String, List<List<LatLng>>>;

/// 国土数値情報を加工・簡略化した地域別JSONから行政区域の輪郭を読み込む。
///
/// JSON解析は描画を止めないよう別Isolateで行い、画面に必要な地域だけを返す。
class RegionBoundaryRepository {
  RegionBoundaryRepository._();

  static final Map<String, Future<RegionPolygons>> _cache = {};
  static Future<String>? _prefecturesSourceFuture;
  static Future<String>? _municipalitiesSourceFuture;

  static Future<RegionPolygons> loadPrefectures(Set<String> names) {
    return _load(
      assetPath: 'assets/boundaries/compact/prefectures.json',
      regionNames: names,
    );
  }

  static Future<RegionPolygons> loadMunicipalities(
    Map<String, String> regionPrefectures, {
    Map<
      String,
      ({String city, String address, double latitude, double longitude})
    >?
    pinFallbacks,
  }) async {
    if (regionPrefectures.isEmpty) return const {};

    final sortedEntries = regionPrefectures.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final cacheKey =
        'municipalities:${sortedEntries.map((e) {
          final fb = pinFallbacks?[e.key];
          final coordKey = fb != null ? '_${(fb.latitude * 1000).round()}_${(fb.longitude * 1000).round()}' : '';
          return '${e.value}_${e.key}$coordKey';
        }).join(",")}';

    return _cache.putIfAbsent(cacheKey, () async {
      final requests = <Map<String, Object>>[];
      for (final entry in sortedEntries) {
        final fb = pinFallbacks?[entry.key];
        requests.add({
          'key': entry.key,
          'prefecture': entry.value,
          'city': fb?.city ?? entry.key,
          'address': fb?.address ?? '',
          if (fb != null) 'lat': fb.latitude,
          if (fb != null) 'lng': fb.longitude,
        });
      }

      final source = await (_municipalitiesSourceFuture ??= rootBundle
          .loadString('assets/boundaries/compact/municipalities.json'));
      final parsed = await compute(_parseSelectedMunicipalities, {
        'source': source,
        'requests': requests,
      });

      return parsed.map(
        (name, polygons) => MapEntry(
          name,
          polygons
              .map(
                (ring) => ring
                    .map(
                      (point) =>
                          LatLng(point[1] / 100000.0, point[0] / 100000.0),
                    )
                    .toList(growable: false),
              )
              .where((ring) => ring.length >= 3)
              .toList(growable: false),
        ),
      );
    });
  }

  static Future<RegionPolygons> _load({
    required String assetPath,
    required Set<String> regionNames,
  }) {
    if (regionNames.isEmpty) {
      return SynchronousFuture(const {});
    }

    final sortedNames = regionNames.toList()..sort();
    final cacheKey = '$assetPath:${sortedNames.join(",")}';
    return _cache.putIfAbsent(cacheKey, () async {
      final source = assetPath.endsWith('prefectures.json')
          ? await (_prefecturesSourceFuture ??= rootBundle.loadString(
              assetPath,
            ))
          : await rootBundle.loadString(assetPath);
      final parsed = await compute(_parseSelectedBoundaries, {
        'source': source,
        'regionNames': sortedNames,
      });

      return parsed.map(
        (name, polygons) => MapEntry(
          name,
          polygons
              .map(
                (ring) => ring
                    .map(
                      (point) =>
                          LatLng(point[1] / 100000.0, point[0] / 100000.0),
                    )
                    .toList(growable: false),
              )
              .where((ring) => ring.length >= 3)
              .toList(growable: false),
        ),
      );
    });
  }
}

Map<String, List<List<List<int>>>> _parseSelectedBoundaries(
  Map<String, Object> arguments,
) {
  final source = arguments['source']! as String;
  final requested = (arguments['regionNames']! as List<Object>)
      .cast<String>()
      .toSet();
  final decoded = jsonDecode(source) as Map<String, dynamic>;
  return {
    for (final name in requested)
      if (decoded[name] case final List<dynamic> polygons)
        name: polygons
            .map(
              (polygon) => (polygon as List<dynamic>)
                  .map(
                    (point) => (point as List<dynamic>)
                        .cast<num>()
                        .map((value) => value.toInt())
                        .toList(growable: false),
                  )
                  .toList(growable: false),
            )
            .toList(growable: false),
  };
}

Map<String, List<List<List<int>>>> _parseSelectedMunicipalities(
  Map<String, Object> arguments,
) {
  final source = arguments['source']! as String;
  final requests = (arguments['requests']! as List<Object>)
      .cast<Map<String, Object>>();
  final decoded = jsonDecode(source) as Map<String, dynamic>;
  final result = <String, List<List<List<int>>>>{};

  for (final req in requests) {
    final resultKey = req['key']! as String;
    final prefName = req['prefecture']! as String;
    final cityName = req['city']! as String;
    final address = req['address']! as String;
    final lat = (req['lat'] as num?)?.toDouble();
    final lng = (req['lng'] as num?)?.toDouble();

    final prefData = decoded[prefName] as Map<String, dynamic>?;
    if (prefData == null) continue;

    final rawPolygons = _resolveMunicipalityPolygons(
      prefData: prefData,
      cityName: cityName,
      address: address,
      latitude: lat,
      longitude: lng,
    );
    if (rawPolygons == null) continue;

    result[resultKey] = rawPolygons
        .map(
          (polygon) => (polygon as List<dynamic>)
              .map(
                (point) => (point as List<dynamic>)
                    .cast<num>()
                    .map((value) => value.toInt())
                    .toList(growable: false),
              )
              .toList(growable: false),
        )
        .toList(growable: false);
  }

  return result;
}

List<dynamic>? _resolveMunicipalityPolygons({
  required Map<String, dynamic> prefData,
  required String cityName,
  required String address,
  double? latitude,
  double? longitude,
}) {
  // 1. 完全一致
  if (prefData[cityName] is List<dynamic>) {
    return prefData[cityName] as List<dynamic>;
  }

  // 2. 政令指定都市の区名（「京都市右京区」→「京都市」）や郡名（「足柄下郡箱根町」→「箱根町」）の正規化
  if (cityName.contains('郡')) {
    final afterGun = cityName.split('郡').last.trim();
    if (afterGun.isNotEmpty && prefData[afterGun] is List<dynamic>) {
      return prefData[afterGun] as List<dynamic>;
    }
  }
  final shiIndex = cityName.indexOf('市');
  if (shiIndex > 0) {
    final parentShi = cityName.substring(0, shiIndex + 1);
    if (prefData[parentShi] is List<dynamic>) {
      return prefData[parentShi] as List<dynamic>;
    }
  }

  // 3. 住所文字列・市区町村名に含まれる自治体キーを長い順に照合
  final candidateKeys = prefData.keys.where((k) => k != '所属未定地').toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  for (final k in candidateKeys) {
    if (cityName.contains(k) || address.contains(k)) {
      if (prefData[k] is List<dynamic>) {
        return prefData[k] as List<dynamic>;
      }
    }
  }

  // 4. 自由入力（店舗名のみ等）で住所に市区町村名が含まれない場合は、緯度・経度から該当市区町村ポリゴンを特定
  if (latitude != null && longitude != null) {
    final x = (longitude * 100000.0).round();
    final y = (latitude * 100000.0).round();

    String? nearestKey;
    double minSqDist = double.infinity;

    for (final k in candidateKeys) {
      final rawPolys = prefData[k];
      if (rawPolys is! List<dynamic>) continue;
      for (final rawRing in rawPolys) {
        if (rawRing is! List<dynamic> || rawRing.length < 3) continue;
        if (_pointInQuantizedRing(x, y, rawRing)) {
          return rawPolys;
        }
        for (final pt in rawRing) {
          if (pt is! List<dynamic> || pt.length < 2) continue;
          final dx = ((pt[0] as num).toInt() - x).toDouble();
          final dy = ((pt[1] as num).toInt() - y).toDouble();
          final sq = dx * dx + dy * dy;
          if (sq < minSqDist) {
            minSqDist = sq;
            nearestKey = k;
          }
        }
      }
    }

    if (nearestKey != null && prefData[nearestKey] is List<dynamic>) {
      return prefData[nearestKey] as List<dynamic>;
    }
  }

  // 最終フォールバック：県内の先頭市区町村
  for (final k in candidateKeys) {
    if (prefData[k] is List<dynamic>) {
      return prefData[k] as List<dynamic>;
    }
  }
  return null;
}

bool _pointInQuantizedRing(int x, int y, List<dynamic> ring) {
  bool inside = false;
  for (int i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    final pi = ring[i] as List<dynamic>;
    final pj = ring[j] as List<dynamic>;
    final xi = (pi[0] as num).toInt();
    final yi = (pi[1] as num).toInt();
    final xj = (pj[0] as num).toInt();
    final yj = (pj[1] as num).toInt();

    final intersect =
        ((yi > y) != (yj > y)) &&
        (x < (xj - xi) * (y - yi) / ((yj - yi) == 0 ? 1 : (yj - yi)) + xi);
    if (intersect) inside = !inside;
  }
  return inside;
}
