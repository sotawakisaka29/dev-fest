import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/models/memory_pin.dart';
import '../../../core/theme/app_theme.dart';
import '../pin_callout/pin_callout_card.dart';

/// Google Maps 表示枠およびピン・ルート・吹き出しの描画キャンバス（MVP機能①）
///
/// `google_maps_flutter` を用いて実際の地図上に訪問地点の赤ピン（Marker）、
/// 移動軌跡のルート線（Polyline）、レビューなし通過点の黒丸（Circle）を描画する。
/// 地図のドラッグ/ピンチ操作中は上部メニューを自動非表示にするイベントを通知する。
class InteractiveMapCanvas extends StatefulWidget {
  const InteractiveMapCanvas({
    super.key,
    required this.pins,
    required this.selectedPin,
    required this.showRouteLine,
    required this.onPinSelected,
    required this.onOpenPinDetail,
    required this.onInteractionChanged,
  });

  final List<MemoryPin> pins;
  final MemoryPin? selectedPin;
  final bool showRouteLine;
  final ValueChanged<MemoryPin?> onPinSelected;
  final ValueChanged<MemoryPin> onOpenPinDetail;
  final ValueChanged<bool> onInteractionChanged;

  @override
  State<InteractiveMapCanvas> createState() => _InteractiveMapCanvasState();
}

class _InteractiveMapCanvasState extends State<InteractiveMapCanvas> {
  static const LatLng _defaultTokyoLatLng = LatLng(35.6812, 139.7671);

  /// アイデアシートの「灰・白」トーンに合わせたグレースケール地図スタイル
  static const String _greyWhiteMapStyleJson = '''
[
  {
    "elementType": "geometry",
    "stylers": [{"color": "#f5f5f5"}]
  },
  {
    "elementType": "labels.icon",
    "stylers": [{"visibility": "off"}]
  },
  {
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#616161"}]
  },
  {
    "elementType": "labels.text.stroke",
    "stylers": [{"color": "#f5f5f5"}]
  },
  {
    "featureType": "administrative.land_parcel",
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#bdbdbd"}]
  },
  {
    "featureType": "poi",
    "elementType": "geometry",
    "stylers": [{"color": "#eeeeee"}]
  },
  {
    "featureType": "road",
    "elementType": "geometry",
    "stylers": [{"color": "#ffffff"}]
  },
  {
    "featureType": "road.arterial",
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#757575"}]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry",
    "stylers": [{"color": "#dadada"}]
  },
  {
    "featureType": "water",
    "elementType": "geometry",
    "stylers": [{"color": "#e3e6ea"}]
  },
  {
    "featureType": "water",
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#9e9e9e"}]
  }
]
''';

  GoogleMapController? _mapController;

  /// APIキー未設定のローカル環境でもピン位置を確認できるフォールバックモード切替
  bool _useMockFallback = false;

  CameraPosition get _initialCameraPosition {
    final target =
        widget.selectedPin?.latLng ??
        (widget.pins.isNotEmpty
            ? widget.pins.first.latLng
            : _defaultTokyoLatLng);
    return CameraPosition(target: target, zoom: 10.5);
  }

  @override
  void didUpdateWidget(covariant InteractiveMapCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextPin = widget.selectedPin;
    if (nextPin != null && nextPin.id != oldWidget.selectedPin?.id) {
      _animateToPin(nextPin);
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _animateToPin(MemoryPin pin) async {
    final controller = _mapController;
    if (controller == null) return;
    try {
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: pin.latLng, zoom: 12.0),
        ),
      );
    } catch (_) {
      // ウィジェットテスト環境やコントローラ破棄後の呼び出し時は無視する
    }
  }

  Future<void> _fitAllPins() async {
    final controller = _mapController;
    if (controller == null || widget.pins.isEmpty) return;
    try {
      if (widget.pins.length == 1) {
        await controller.animateCamera(
          CameraUpdate.newLatLngZoom(widget.pins.first.latLng, 12.0),
        );
        return;
      }

      double minLat = widget.pins.first.latitude;
      double maxLat = widget.pins.first.latitude;
      double minLng = widget.pins.first.longitude;
      double maxLng = widget.pins.first.longitude;

      for (final pin in widget.pins.skip(1)) {
        minLat = math.min(minLat, pin.latitude);
        maxLat = math.max(maxLat, pin.latitude);
        minLng = math.min(minLng, pin.longitude);
        maxLng = math.max(maxLng, pin.longitude);
      }

      final bounds = LatLngBounds(
        southwest: LatLng(minLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      );
      await controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 72));
    } catch (_) {
      // 同一座標のみの場合などの例外を安全に無視する
    }
  }

  Set<Marker> _buildMarkers() {
    return widget.pins.map((pin) {
      if (pin.isRouteWaypointOnly) {
        return Marker(
          markerId: MarkerId(pin.id),
          position: pin.latLng,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
          infoWindow: InfoWindow(
            title: pin.placeName,
            snippet: '通過地点 (${pin.startTime}〜${pin.endTime})',
          ),
        );
      }

      return Marker(
        markerId: MarkerId(pin.id),
        position: pin.latLng,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        onTap: () {
          widget.onPinSelected(pin);
          _animateToPin(pin);
        },
      );
    }).toSet();
  }

  Set<Polyline> _buildPolylines() {
    if (!widget.showRouteLine || widget.pins.length < 2) {
      return const <Polyline>{};
    }

    return <Polyline>{
      Polyline(
        polylineId: const PolylineId('memory_trip_route'),
        points: widget.pins.map((pin) => pin.latLng).toList(),
        color: AppTheme.darkGrey,
        width: 4,
        jointType: JointType.round,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      ),
    };
  }

  Set<Circle> _buildWaypointCircles() {
    return widget.pins.where((pin) => pin.isRouteWaypointOnly).map((pin) {
      return Circle(
        circleId: CircleId('waypoint_${pin.id}'),
        center: pin.latLng,
        radius: 350,
        fillColor: AppTheme.darkGrey,
        strokeColor: AppTheme.pureWhite,
        strokeWidth: 3,
      );
    }).toSet();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => widget.onInteractionChanged(true),
      onPointerUp: (_) => widget.onInteractionChanged(false),
      onPointerCancel: (_) => widget.onInteractionChanged(false),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 1. 地図本体（Google Maps または APIキー未設定時用の簡易キャンバス）
          Positioned.fill(
            child: _useMockFallback
                ? _buildMockMapCanvas()
                : GoogleMap(
                    initialCameraPosition: _initialCameraPosition,
                    style: _greyWhiteMapStyleJson,
                    markers: _buildMarkers(),
                    polylines: _buildPolylines(),
                    circles: _buildWaypointCircles(),
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                    compassEnabled: true,
                    gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                      Factory<OneSequenceGestureRecognizer>(
                        EagerGestureRecognizer.new,
                      ),
                    },
                    onMapCreated: (controller) {
                      _mapController = controller;
                    },
                    onCameraMoveStarted: () {
                      widget.onInteractionChanged(true);
                    },
                    onCameraIdle: () {
                      widget.onInteractionChanged(false);
                    },
                    onTap: (_) {
                      widget.onPinSelected(null);
                    },
                  ),
          ),

          // 2. Google Maps モード時の選択ピン吹き出しカード
          if (!_useMockFallback &&
              widget.selectedPin != null &&
              !widget.selectedPin!.isRouteWaypointOnly)
            Positioned(
              left: 16,
              right: 16,
              bottom: 92,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: PinCalloutCard(
                  pin: widget.selectedPin!,
                  onOpenDetail: () =>
                      widget.onOpenPinDetail(widget.selectedPin!),
                  onClose: () => widget.onPinSelected(null),
                ),
              ),
            ),

          // 3. 左下：全体表示＆マップモード切替補助ボタン
          Positioned(
            left: 16,
            bottom: 28,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!_useMockFallback) ...[
                  Material(
                    color: AppTheme.pureWhite,
                    elevation: 2,
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: _fitAllPins,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.fit_screen_outlined,
                              size: 16,
                              color: AppTheme.darkGrey,
                            ),
                            SizedBox(width: 4),
                            Text(
                              '全体表示',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.darkGrey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Material(
                  color: AppTheme.pureWhite.withValues(alpha: 0.92),
                  elevation: 2,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      setState(() => _useMockFallback = !_useMockFallback);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _useMockFallback
                                ? Icons.public
                                : Icons.map_outlined,
                            size: 15,
                            color: AppTheme.primaryGrey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _useMockFallback ? 'Google Mapへ' : '簡易地図',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.primaryGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMockMapCanvas() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => widget.onPinSelected(null),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          return InteractiveViewer(
            minScale: 0.9,
            maxScale: 2.8,
            onInteractionStart: (_) => widget.onInteractionChanged(true),
            onInteractionEnd: (_) => widget.onInteractionChanged(false),
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _MockJapanMapPainter(
                        pins: widget.pins,
                        showRouteLine: widget.showRouteLine,
                      ),
                    ),
                  ),
                  ...widget.pins.map((pin) {
                    final point = Offset(
                      pin.mapNormalizedPosition.dx * size.width,
                      pin.mapNormalizedPosition.dy * size.height,
                    );
                    if (pin.isRouteWaypointOnly) {
                      return Positioned(
                        left: point.dx - 7,
                        top: point.dy - 7,
                        child: Tooltip(
                          message: '${pin.placeName} (${pin.startTime})',
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: AppTheme.darkGrey,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppTheme.pureWhite,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      );
                    }

                    final isSelected = widget.selectedPin?.id == pin.id;
                    return Positioned(
                      left: point.dx - 18,
                      top: point.dy - 36,
                      child: GestureDetector(
                        onTap: () => widget.onPinSelected(pin),
                        child: AnimatedScale(
                          duration: const Duration(milliseconds: 160),
                          scale: isSelected ? 1.2 : 1.0,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: AppTheme.accentPinRed,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppTheme.pureWhite,
                                    width: 2.5,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 6,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: CircleAvatar(
                                    radius: 4,
                                    backgroundColor: AppTheme.pureWhite,
                                  ),
                                ),
                              ),
                              Container(
                                width: 3,
                                height: 8,
                                color: AppTheme.darkGrey,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  if (widget.selectedPin != null &&
                      !widget.selectedPin!.isRouteWaypointOnly)
                    Builder(
                      builder: (context) {
                        final activePin = widget.selectedPin!;
                        final pinX =
                            activePin.mapNormalizedPosition.dx * size.width;
                        final pinY =
                            activePin.mapNormalizedPosition.dy * size.height;
                        final clampedLeft = (pinX - 125).clamp(
                          16.0,
                          (size.width - 266).clamp(16.0, double.infinity),
                        );
                        final topOffset = (pinY - 190).clamp(
                          110.0,
                          (size.height - 220).clamp(110.0, double.infinity),
                        );
                        return Positioned(
                          left: clampedLeft,
                          top: topOffset,
                          child: PinCalloutCard(
                            pin: activePin,
                            onOpenDetail: () =>
                                widget.onOpenPinDetail(activePin),
                            onClose: () => widget.onPinSelected(null),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MockJapanMapPainter extends CustomPainter {
  _MockJapanMapPainter({required this.pins, required this.showRouteLine});

  final List<MemoryPin> pins;
  final bool showRouteLine;

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFFECEEF1);
    canvas.drawRect(Offset.zero & size, bgPaint);

    final gridPaint = Paint()
      ..color = const Color(0xFFDDE1E6)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 48) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += 48) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final landFill = Paint()
      ..color = AppTheme.pureWhite
      ..style = PaintingStyle.fill;
    final landStroke = Paint()
      ..color = AppTheme.mediumGrey
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final hokkaido = Path()
      ..moveTo(size.width * 0.73, size.height * 0.16)
      ..lineTo(size.width * 0.88, size.height * 0.18)
      ..lineTo(size.width * 0.86, size.height * 0.27)
      ..lineTo(size.width * 0.72, size.height * 0.26)
      ..close();
    canvas.drawPath(hokkaido, landFill);
    canvas.drawPath(hokkaido, landStroke);

    final honshu = Path()
      ..moveTo(size.width * 0.70, size.height * 0.31)
      ..lineTo(size.width * 0.78, size.height * 0.33)
      ..lineTo(size.width * 0.74, size.height * 0.62)
      ..lineTo(size.width * 0.35, size.height * 0.70)
      ..lineTo(size.width * 0.31, size.height * 0.63)
      ..lineTo(size.width * 0.62, size.height * 0.54)
      ..close();
    canvas.drawPath(honshu, landFill);
    canvas.drawPath(honshu, landStroke);

    final shikoku = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            size.width * 0.38,
            size.height * 0.72,
            size.width * 0.11,
            size.height * 0.05,
          ),
          const Radius.circular(8),
        ),
      );
    canvas.drawPath(shikoku, landFill);
    canvas.drawPath(shikoku, landStroke);

    final kyushu = Path()
      ..addOval(
        Rect.fromLTWH(
          size.width * 0.21,
          size.height * 0.71,
          size.width * 0.12,
          size.height * 0.11,
        ),
      );
    canvas.drawPath(kyushu, landFill);
    canvas.drawPath(kyushu, landStroke);

    if (showRouteLine && pins.length >= 2) {
      final routePaint = Paint()
        ..color = AppTheme.darkGrey
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke;

      final routePath = Path();
      for (int i = 0; i < pins.length; i++) {
        final pt = Offset(
          pins[i].mapNormalizedPosition.dx * size.width,
          pins[i].mapNormalizedPosition.dy * size.height,
        );
        if (i == 0) {
          routePath.moveTo(pt.dx, pt.dy);
        } else {
          routePath.lineTo(pt.dx, pt.dy);
        }
      }
      canvas.drawPath(routePath, routePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MockJapanMapPainter oldDelegate) {
    return oldDelegate.pins != pins ||
        oldDelegate.showRouteLine != showRouteLine;
  }
}
