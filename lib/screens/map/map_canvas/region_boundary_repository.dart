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
  static Future<Map<String, String>>? _municipalityManifest;

  static Future<RegionPolygons> loadPrefectures(Set<String> names) {
    return _load(
      assetPath: 'assets/boundaries/compact/prefectures.json',
      regionNames: names,
    );
  }

  static Future<RegionPolygons> loadMunicipalities(
    Map<String, String> regionPrefectures,
  ) async {
    if (regionPrefectures.isEmpty) return const {};

    final manifest = await _loadMunicipalityManifest();
    final namesByPrefecture = <String, Set<String>>{};
    for (final entry in regionPrefectures.entries) {
      namesByPrefecture
          .putIfAbsent(entry.value, () => <String>{})
          .add(entry.key);
    }

    final parts = await Future.wait(
      namesByPrefecture.entries.map((entry) {
        final fileName = manifest[entry.key];
        if (fileName == null) {
          return SynchronousFuture<RegionPolygons>(const {});
        }
        return _load(
          assetPath: 'assets/boundaries/compact/$fileName',
          regionNames: entry.value,
        );
      }),
    );

    return {
      for (final part in parts)
        for (final entry in part.entries) entry.key: entry.value,
    };
  }

  static Future<Map<String, String>> _loadMunicipalityManifest() {
    return _municipalityManifest ??= () async {
      final source = await rootBundle.loadString(
        'assets/boundaries/compact/manifest.json',
      );
      final decoded = jsonDecode(source) as Map<String, dynamic>;
      return decoded.map((key, value) => MapEntry(key, value as String));
    }();
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
      final source = await rootBundle.loadString(assetPath);
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
