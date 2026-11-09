import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/models/app_photo.dart';
import '../../../core/models/memory_pin.dart';
import '../../../core/theme/app_theme.dart';
import 'region_boundary_repository.dart';

/// 1倍（都道府県単位）および中倍率（市区町村単位）で、
/// 公的な行政境界ポリゴンに沿って写真を切り抜き、5秒間隔でランダムに流すオーバーレイ
class RegionPhotoOverlay extends StatelessWidget {
  const RegionPhotoOverlay({
    super.key,
    required this.pins,
    required this.cameraPosition,
    required this.mapSize,
    required this.isCityMode,
    required this.onTapRegionPins,
  });

  final List<MemoryPin> pins;
  final CameraPosition cameraPosition;
  final Size mapSize;

  /// false: 1倍〜低倍率（県の形に沿って表示）
  /// true: 中倍率（市の形に沿って表示）
  final bool isCityMode;

  /// 県または市の写真プレビューをタップしたとき、対応する思い出（または思い出一覧）へ飛ぶコールバック
  final ValueChanged<List<MemoryPin>> onTapRegionPins;

  /// 緯度経度を現在の GoogleMap カメラ座標から画面上の Offset に変換する（Web Mercator投影）
  static Offset latLngToScreenOffset(
    LatLng point,
    CameraPosition camera,
    Size screenSize,
  ) {
    final double worldSize = 256.0 * math.pow(2.0, camera.zoom);
    final Offset centerWorld = _projectToWorld(camera.target, worldSize);
    final Offset pointWorld = _projectToWorld(point, worldSize);

    return Offset(
      screenSize.width / 2.0 + (pointWorld.dx - centerWorld.dx),
      screenSize.height / 2.0 + (pointWorld.dy - centerWorld.dy),
    );
  }

  static Offset _projectToWorld(LatLng latLng, double worldSize) {
    final double siny = math
        .sin(latLng.latitude * math.pi / 180.0)
        .clamp(-0.9999, 0.9999);
    final double x = (0.5 + latLng.longitude / 360.0) * worldSize;
    final double y =
        (0.5 - math.log((1.0 + siny) / (1.0 - siny)) / (4.0 * math.pi)) *
        worldSize;
    return Offset(x, y);
  }

  @override
  Widget build(BuildContext context) {
    if (isCityMode) {
      return _buildCityOverlay();
    }
    return _buildPrefectureOverlay();
  }

  /// 1倍〜低倍率：各県の実座標ポリゴンに沿って写真を切り抜き表示
  Widget _buildPrefectureOverlay() {
    final Map<String, List<MemoryPin>> byPrefecture = {};
    for (final pin in pins) {
      if (pin.isRouteWaypointOnly &&
          pin.photoLabels.isEmpty &&
          pin.photos.isEmpty) {
        continue;
      }
      byPrefecture.putIfAbsent(pin.prefecture, () => []).add(pin);
    }

    return FutureBuilder<RegionPolygons>(
      future: RegionBoundaryRepository.loadPrefectures(
        byPrefecture.keys.toSet(),
      ),
      builder: (context, snapshot) {
        final boundaries = snapshot.data;
        if (boundaries == null) return const SizedBox.shrink();
        return Stack(
          clipBehavior: Clip.none,
          children: byPrefecture.entries
              .where((entry) => boundaries[entry.key]?.isNotEmpty ?? false)
              .map(
                (entry) => _buildProjectedPolygonWidget(
                  regionKey: 'pref_${entry.key}',
                  latLngPolygons: boundaries[entry.key]!,
                  regionPins: entry.value,
                ),
              )
              .toList(),
        );
      },
    );
  }

  /// 中倍率：各市区町村の実座標ポリゴンに沿って写真を切り抜き表示
  Widget _buildCityOverlay() {
    final Map<String, List<MemoryPin>> byCity = {};
    for (final pin in pins) {
      if (pin.isRouteWaypointOnly &&
          pin.photoLabels.isEmpty &&
          pin.photos.isEmpty) {
        continue;
      }
      final key = '${pin.prefecture}_${pin.city}';
      byCity.putIfAbsent(key, () => []).add(pin);
    }

    final cityPrefectures = {
      for (final cityPins in byCity.values)
        cityPins.first.city: cityPins.first.prefecture,
    };
    return FutureBuilder<RegionPolygons>(
      future: RegionBoundaryRepository.loadMunicipalities(cityPrefectures),
      builder: (context, snapshot) {
        final boundaries = snapshot.data;
        if (boundaries == null) return const SizedBox.shrink();
        return Stack(
          clipBehavior: Clip.none,
          children: byCity.entries
              .where(
                (entry) =>
                    boundaries[entry.value.first.city]?.isNotEmpty ?? false,
              )
              .map(
                (entry) => _buildProjectedPolygonWidget(
                  regionKey: 'city_${entry.key}',
                  latLngPolygons: boundaries[entry.value.first.city]!,
                  regionPins: entry.value,
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildProjectedPolygonWidget({
    required String regionKey,
    required List<List<LatLng>> latLngPolygons,
    required List<MemoryPin> regionPins,
  }) {
    final screenPolygons = latLngPolygons
        .map(
          (polygon) => polygon
              .map((ll) => latLngToScreenOffset(ll, cameraPosition, mapSize))
              .toList(growable: false),
        )
        .where((polygon) => polygon.length >= 3)
        .toList(growable: false);
    final screenPoints = screenPolygons.expand((polygon) => polygon).toList();

    double minX = screenPoints.first.dx;
    double maxX = screenPoints.first.dx;
    double minY = screenPoints.first.dy;
    double maxY = screenPoints.first.dy;

    for (final pt in screenPoints.skip(1)) {
      if (pt.dx < minX) minX = pt.dx;
      if (pt.dx > maxX) maxX = pt.dx;
      if (pt.dy < minY) minY = pt.dy;
      if (pt.dy > maxY) maxY = pt.dy;
    }

    final double rawWidth = (maxX - minX).clamp(1.0, 4000.0);
    final double rawHeight = (maxY - minY).clamp(1.0, 4000.0);
    final double width = rawWidth;
    final double height = rawHeight;
    final double centerX = (minX + maxX) / 2.0;
    final double centerY = (minY + maxY) / 2.0;

    final localPolygons = screenPolygons
        .map(
          (polygon) => polygon
              .map(
                (pt) => Offset(
                  pt.dx - centerX + width / 2.0,
                  pt.dy - centerY + height / 2.0,
                ),
              )
              .toList(growable: false),
        )
        .toList(growable: false);

    final photos = regionPins.expand((pin) => pin.photos).toList();

    return Positioned(
      key: ValueKey(regionKey),
      left: centerX - width / 2.0,
      top: centerY - height / 2.0,
      width: width,
      height: height,
      child: _GeoPolygonPhotoSlideshow(
        regionKey: regionKey,
        localPolygons: localPolygons,
        userPhotos: photos,
        onTap: () => onTapRegionPins(regionPins),
      ),
    );
  }
}

/// 県・市の実形状ポリゴン内で写真を文字なしで5秒間隔ランダム再生するWidget
class _GeoPolygonPhotoSlideshow extends StatefulWidget {
  const _GeoPolygonPhotoSlideshow({
    required this.regionKey,
    required this.localPolygons,
    required this.userPhotos,
    required this.onTap,
  });

  final String regionKey;
  final List<List<Offset>> localPolygons;
  final List<AppPhoto> userPhotos;
  final VoidCallback onTap;

  @override
  State<_GeoPolygonPhotoSlideshow> createState() =>
      _GeoPolygonPhotoSlideshowState();
}

class _GeoPolygonPhotoSlideshowState extends State<_GeoPolygonPhotoSlideshow> {
  late final math.Random _random = math.Random(widget.regionKey.hashCode);
  int _currentSlideIndex = 0;
  Timer? _slideshowTimer;

  List<AppPhoto> get _availablePhotos {
    return widget.userPhotos
        .where(
          (p) =>
              (p.localPath != null && p.localPath!.isNotEmpty) ||
              (p.url != null && p.url!.isNotEmpty),
        )
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    // 同じ写真が連続しないよう、5秒間隔でランダムに切り替える。
    _slideshowTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      final total = _availablePhotos.length;
      if (total <= 1) return;
      int next = _random.nextInt(total);
      if (next == _currentSlideIndex) {
        next = (next + 1) % total;
      }
      setState(() {
        _currentSlideIndex = next;
      });
    });
  }

  @override
  void didUpdateWidget(covariant _GeoPolygonPhotoSlideshow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final total = _availablePhotos.length;
    if (total == 0 || _currentSlideIndex >= total) {
      _currentSlideIndex = 0;
    }
  }

  @override
  void dispose() {
    _slideshowTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: CustomPaint(
        foregroundPainter: _ExactPolygonBorderPainter(
          polygons: widget.localPolygons,
        ),
        child: ClipPath(
          clipper: _ExactPolygonClipper(polygons: widget.localPolygons),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 550),
            child: SizedBox.expand(
              key: ValueKey<int>(_currentSlideIndex),
              child: _buildSlideContent(_currentSlideIndex),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSlideContent(int index) {
    final photos = _availablePhotos;
    if (photos.isEmpty) {
      return const ColoredBox(color: AppTheme.mediumGrey);
    }

    final photo = photos[index.clamp(0, photos.length - 1)];
    final bool hasLocalFile = photo.localPath != null &&
        photo.localPath!.isNotEmpty &&
        File(photo.localPath!).existsSync();

    if (hasLocalFile) {
      return Image.file(
        File(photo.localPath!),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) {
          if (photo.url != null && photo.url!.isNotEmpty) {
            return Image.network(
              photo.url!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const ColoredBox(color: AppTheme.mediumGrey),
            );
          }
          return const ColoredBox(color: AppTheme.mediumGrey);
        },
      );
    }
    if (photo.url != null && photo.url!.isNotEmpty) {
      return Image.network(
        photo.url!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const ColoredBox(color: AppTheme.mediumGrey),
      );
    }
    return const ColoredBox(color: AppTheme.mediumGrey);
  }
}

class _ExactPolygonClipper extends CustomClipper<Path> {
  const _ExactPolygonClipper({required this.polygons});

  final List<List<Offset>> polygons;

  @override
  Path getClip(Size size) {
    final path = Path()..fillType = PathFillType.evenOdd;
    for (final points in polygons) {
      if (points.length < 3) continue;
      path.addPolygon(points, true);
    }
    return path;
  }

  @override
  bool shouldReclip(covariant _ExactPolygonClipper oldClipper) {
    return oldClipper.polygons != polygons;
  }
}

class _ExactPolygonBorderPainter extends CustomPainter {
  const _ExactPolygonBorderPainter({required this.polygons});

  final List<List<Offset>> polygons;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    for (final points in polygons) {
      if (points.length < 3) continue;
      path.addPolygon(points, true);
    }

    final outerStroke = Paint()
      ..color = AppTheme.pureWhite
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

    final innerStroke = Paint()
      ..color = AppTheme.darkGrey
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, outerStroke);
    canvas.drawPath(path, innerStroke);
  }

  @override
  bool shouldRepaint(covariant _ExactPolygonBorderPainter oldDelegate) {
    return oldDelegate.polygons != polygons;
  }
}
