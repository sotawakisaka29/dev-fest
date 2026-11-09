import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/models/memory_pin.dart';
import '../../../core/models/trip_memory.dart';
import '../../../core/theme/app_theme.dart';
import '../pin_callout/pin_callout_card.dart';
import 'region_photo_overlay.dart';

/// Google Maps 表示枠および3段階ズーム（県シルエット写真 → 市シルエット写真 → ピン＋有名スポット表示）キャンバス
class InteractiveMapCanvas extends StatefulWidget {
  const InteractiveMapCanvas({
    super.key,
    required this.pins,
    required this.selectedPin,
    required this.showRouteLine,
    required this.onPinSelected,
    required this.onOpenPinDetail,
    required this.onTapRegionPins,
    required this.onInteractionChanged,
    required this.onZoom1xChanged,
    this.memories = const [],
    this.activeRoutePoints = const [],
    this.isTripActive = false,
    this.externalFocusPin,
    this.onExternalFocusHandled,
  });

  final List<MemoryPin> pins;
  final List<TripMemory> memories;
  final List<RoutePoint> activeRoutePoints;
  final bool isTripActive;
  final MemoryPin? selectedPin;
  final bool showRouteLine;
  final ValueChanged<MemoryPin?> onPinSelected;
  final ValueChanged<MemoryPin> onOpenPinDetail;

  /// 都道府県・市区町村の写真プレビューをタップした際に対応する思い出へ遷移するコールバック
  final ValueChanged<List<MemoryPin>> onTapRegionPins;

  final ValueChanged<bool> onInteractionChanged;

  /// 現在1倍表示（初期全体表示域）にあるかどうかを通知するコールバック
  final ValueChanged<bool> onZoom1xChanged;

  /// 思い出詳細画面の「↗ Google Mapへ飛ぶ」等から明示的にジャンプ要求されたピン
  final MemoryPin? externalFocusPin;
  final VoidCallback? onExternalFocusHandled;

  @override
  State<InteractiveMapCanvas> createState() => _InteractiveMapCanvasState();
}

class _InteractiveMapCanvasState extends State<InteractiveMapCanvas> {
  /// 1倍（国全体表示）の基準ズーム倍率
  static const double _zoom1x = 5.2;

  /// 1倍とみなす上限ズーム閾値（上部タブの表示条件）
  static const double _zoom1xMaxThreshold = 6.2;

  /// 県の形 → 市区町村の形に切り替わるズーム閾値（県が画面いっぱいになる手前）
  static const double _cityModeZoomThreshold = 6.8;

  /// 市区町村の形 → ピン＆有名スポット表示に切り替わるズーム閾値
  static const double _detailPinZoomThreshold = 11.2;

  /// 低・中倍率用：道路・POI・文字ラベルを消して県の輪郭と灰・白トーンだけにするスタイル
  static const String _outlineOnlyMapStyleJson = '''
[
  {
    "featureType": "all",
    "stylers": [{"saturation": -100}]
  },
  {
    "elementType": "labels",
    "stylers": [{"visibility": "off"}]
  },
  {
    "featureType": "road",
    "stylers": [{"visibility": "off"}]
  },
  {
    "featureType": "poi",
    "stylers": [{"visibility": "off"}]
  },
  {
    "featureType": "transit",
    "stylers": [{"visibility": "off"}]
  },
  {
    "featureType": "landscape",
    "elementType": "geometry",
    "stylers": [{"color": "#f5f5f5"}]
  },
  {
    "featureType": "water",
    "elementType": "geometry",
    "stylers": [{"color": "#e3e6ea"}]
  },
  {
    "featureType": "administrative.country",
    "elementType": "geometry.stroke",
    "stylers": [{"visibility": "on"}, {"color": "#616161"}, {"weight": 1.5}]
  },
  {
    "featureType": "administrative.province",
    "elementType": "geometry.stroke",
    "stylers": [{"visibility": "on"}, {"color": "#757575"}, {"weight": 1.2}]
  }
]
''';

  /// 高倍率（第3段階）用：灰・白のトンマナを完全に維持したまま、道路と有名な観光スポット（poi.attraction）のみを表示するスタイル
  static const String _detailedMapStyleJson = '''
[
  {
    "featureType": "all",
    "stylers": [{"saturation": -100}]
  },
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
    "featureType": "poi",
    "stylers": [{"visibility": "off"}]
  },
  {
    "featureType": "poi.attraction",
    "elementType": "labels.text",
    "stylers": [{"visibility": "on"}]
  },
  {
    "featureType": "poi.park",
    "elementType": "geometry",
    "stylers": [{"visibility": "on"}, {"color": "#ebebeb"}]
  },
  {
    "featureType": "poi.park",
    "elementType": "labels.text",
    "stylers": [{"visibility": "on"}]
  },
  {
    "featureType": "transit",
    "stylers": [{"visibility": "off"}]
  },
  {
    "featureType": "road",
    "elementType": "geometry",
    "stylers": [{"color": "#ffffff"}]
  },
  {
    "featureType": "road.arterial",
    "elementType": "geometry",
    "stylers": [{"color": "#fafafa"}]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry",
    "stylers": [{"color": "#e0e0e0"}]
  },
  {
    "featureType": "road",
    "elementType": "labels",
    "stylers": [{"visibility": "off"}]
  },
  {
    "featureType": "water",
    "elementType": "geometry",
    "stylers": [{"color": "#e3e6ea"}]
  },
  {
    "featureType": "administrative.province",
    "elementType": "geometry.stroke",
    "stylers": [{"visibility": "on"}, {"color": "#9e9e9e"}, {"weight": 1.1}]
  }
]
''';

  GoogleMapController? _mapController;
  late CameraPosition _currentCameraPosition = _initialCountryCameraPosition;

  /// ホームボタンの隣の「ピンだけを見る」ボタンによるピン強制表示モード
  bool _forcePinOnlyMode = false;

  /// 端末の地域設定（または日本全体）に応じた初期1倍カメラ位置
  static CameraPosition get _initialCountryCameraPosition {
    final countryCode =
        PlatformDispatcher.instance.locale.countryCode?.toUpperCase() ?? 'JP';
    switch (countryCode) {
      case 'GB':
        return const CameraPosition(target: LatLng(54.5, -2.5), zoom: 5.3);
      case 'KR':
        return const CameraPosition(target: LatLng(36.3, 127.8), zoom: 6.5);
      case 'TW':
        return const CameraPosition(target: LatLng(23.7, 121.0), zoom: 7.0);
      case 'US':
      case 'JP':
      default:
        return const CameraPosition(
          target: LatLng(36.2048, 137.5500),
          zoom: _zoom1x,
        );
    }
  }

  bool get _isAt1x => _currentCameraPosition.zoom < _zoom1xMaxThreshold;
  bool get _isDetailPinMode =>
      _currentCameraPosition.zoom >= _detailPinZoomThreshold;
  bool get _isCityPhotoMode =>
      _currentCameraPosition.zoom >= _cityModeZoomThreshold;
  bool get _isPinVisibleMode => _isDetailPinMode || _forcePinOnlyMode;

  @override
  void didUpdateWidget(covariant InteractiveMapCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    final focusPin = widget.externalFocusPin;
    if (focusPin != null && focusPin.id != oldWidget.externalFocusPin?.id) {
      _jumpToPinDetailMode(focusPin);
      widget.onExternalFocusHandled?.call();
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  void _updateCameraState(CameraPosition position) {
    final was1x = _isAt1x;
    final wasPinVisible = _isPinVisibleMode;
    setState(() {
      _currentCameraPosition = position;
    });
    if (was1x != _isAt1x) {
      widget.onZoom1xChanged(_isAt1x);
    }
    if (wasPinVisible && !_isPinVisibleMode && widget.selectedPin != null) {
      widget.onPinSelected(null);
    }
  }

  /// ホームボタンを押したときに1倍（日本地図全体表示・県シルエット写真表示）へ戻す
  Future<void> _returnToHome1x() async {
    setState(() {
      _forcePinOnlyMode = false;
    });
    widget.onPinSelected(null);
    final homePos = _initialCountryCameraPosition;
    _updateCameraState(homePos);

    final controller = _mapController;
    if (controller == null) return;
    try {
      await controller.animateCamera(CameraUpdate.newCameraPosition(homePos));
    } catch (_) {}
  }

  /// ホームボタンの隣の「ピンだけをすぐに見る」ボタンを押したときの切り替え
  void _togglePinOnlyMode() {
    setState(() {
      _forcePinOnlyMode = !_forcePinOnlyMode;
      if (!_forcePinOnlyMode &&
          !_isDetailPinMode &&
          widget.selectedPin != null) {
        widget.onPinSelected(null);
      }
    });
  }

  Future<void> _animateToZoomTarget(LatLng target, double zoom) async {
    final nextPos = CameraPosition(target: target, zoom: zoom);
    _updateCameraState(nextPos);

    final controller = _mapController;
    if (controller == null) return;
    try {
      await controller.animateCamera(CameraUpdate.newCameraPosition(nextPos));
    } catch (_) {}
  }

  Future<void> _jumpToPinDetailMode(MemoryPin pin) async {
    await _animateToZoomTarget(pin.latLng, 14.2);
    widget.onPinSelected(pin);
  }

  Set<Polyline> _buildPolylines() {
    // ピンViewボタンがONのときは、ピン以外のルートなどのデータを出力しない
    if (_forcePinOnlyMode || !widget.showRouteLine) {
      return const <Polyline>{};
    }

    final Set<Polyline> polylines = <Polyline>{};

    // 1. 現在進行中の旅行（旅行スタート〜旅行終了まで）の実際の移動ルート線
    if (widget.isTripActive && widget.activeRoutePoints.length >= 2) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('active_trip_route'),
          points: widget.activeRoutePoints.map((p) => p.latLng).toList(),
          color: AppTheme.accentPinRed,
          width: 5,
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
      );
    }

    // 2. 詳細ズーム時は保存済み思い出（TripMemory）ごとの実ルート（通った道の履歴・タイムライン経路）のみを描画
    // ※ピンとピンの間を単純に直線で結ぶことはしない
    if (_isDetailPinMode) {
      for (final memory in widget.memories) {
        final routeLatLngs = memory.effectiveRouteLatLngs;
        if (routeLatLngs.length >= 2) {
          polylines.add(
            Polyline(
              polylineId: PolylineId('memory_route_${memory.id}'),
              points: routeLatLngs,
              color: AppTheme.darkGrey,
              width: 4,
              jointType: JointType.round,
              startCap: Cap.roundCap,
              endCap: Cap.roundCap,
            ),
          );
        }
      }
    }

    return polylines;
  }

  Set<Circle> _buildWaypointCircles() {
    // ピンViewボタンがONのときは、ピン以外の通過点サークルなどのデータを出力しない
    if (_forcePinOnlyMode || !_isDetailPinMode) {
      return const <Circle>{};
    }

    final Set<Circle> circles = <Circle>{};

    // 旅行スタート中：現在位置および移動軌跡の開始・現在ノードを表示
    if (widget.isTripActive && widget.activeRoutePoints.isNotEmpty) {
      final currentPoint = widget.activeRoutePoints.last;
      circles.add(
        Circle(
          circleId: const CircleId('active_trip_current_pos'),
          center: currentPoint.latLng,
          radius: 120,
          fillColor: AppTheme.accentPinRed,
          strokeColor: AppTheme.pureWhite,
          strokeWidth: 3,
        ),
      );
    }

    circles.addAll(
      widget.pins.where((pin) => pin.isRouteWaypointOnly).map((pin) {
        return Circle(
          circleId: CircleId('waypoint_${pin.id}'),
          center: pin.latLng,
          radius: 350,
          fillColor: AppTheme.darkGrey,
          strokeColor: AppTheme.pureWhite,
          strokeWidth: 3,
        );
      }),
    );

    return circles;
  }

  /// 地図の塗り（RegionPhotoOverlay）よりも上（最前面レイヤー）にピンを描画し、
  /// ピン表示ボタンON時や詳細ズーム時にピンをタップすると確実にレビューが出るようにする
  List<Widget> _buildTopLayerPinWidgets(Size mapSize) {
    if (!_isPinVisibleMode) {
      return const <Widget>[];
    }

    final List<Widget> widgets = [];
    for (final pin in widget.pins) {
      if (_forcePinOnlyMode && pin.isRouteWaypointOnly) continue;
      if (pin.isRouteWaypointOnly) continue;

      final screenOffset = RegionPhotoOverlay.latLngToScreenOffset(
        pin.latLng,
        _currentCameraPosition,
        mapSize,
      );
      if (screenOffset.dx < -40 ||
          screenOffset.dx > mapSize.width + 40 ||
          screenOffset.dy < -40 ||
          screenOffset.dy > mapSize.height + 40) {
        continue;
      }

      final isSelected = widget.selectedPin?.id == pin.id;
      const double pinSize = 36.0;

      widgets.add(
        Positioned(
          key: Key('top_pin_marker_${pin.id}'),
          left: screenOffset.dx - pinSize / 2,
          top: screenOffset.dy - pinSize,
          width: pinSize,
          height: pinSize,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              widget.onPinSelected(pin);
            },
            child: Tooltip(
              message: pin.placeName,
              child: Icon(
                Icons.location_on,
                size: isSelected ? 36 : 32,
                color: AppTheme.accentPinRed,
                shadows: const [
                  Shadow(
                    color: Colors.black38,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => widget.onInteractionChanged(true),
      onPointerUp: (_) => widget.onInteractionChanged(false),
      onPointerCancel: (_) => widget.onInteractionChanged(false),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final mapSize = Size(constraints.maxWidth, constraints.maxHeight);

          return Stack(
            clipBehavior: Clip.none,
            children: [
              // 1. Google Map 本体（全段階で灰・白トンマナを維持し、高倍率のみ道路と有名スポットを表示）
              Positioned.fill(
                child: GoogleMap(
                  initialCameraPosition: _initialCountryCameraPosition,
                  style: _isDetailPinMode
                      ? _detailedMapStyleJson
                      : _outlineOnlyMapStyleJson,
                  // PlatformView内部の重複ピンを排除し、最前面レイヤー（_buildTopLayerPinWidgets）のみでピンを表示
                  markers: const <Marker>{},
                  polylines: _buildPolylines(),
                  circles: _buildWaypointCircles(),
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  compassEnabled: false,
                  rotateGesturesEnabled: false,
                  tiltGesturesEnabled: false,
                  padding: const EdgeInsets.only(bottom: 30),
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
                  onCameraMove: _updateCameraState,
                  onCameraIdle: () {
                    widget.onInteractionChanged(false);
                  },
                  onTap: (_) {
                    widget.onPinSelected(null);
                  },
                ),
              ),

              // 2. 1段階目（県の形に沿って写真表示）・2段階目（市区町村の形に沿って写真表示）オーバーレイ
              //    3段階目（道路・スポットが表示される詳細倍率）では地図の情報密度に合わせて塗り/写真を非表示にする
              if (!_isDetailPinMode)
                Positioned.fill(
                  child: RegionPhotoOverlay(
                    pins: widget.pins,
                    cameraPosition: _currentCameraPosition,
                    mapSize: mapSize,
                    isCityMode: _isCityPhotoMode,
                    onTapRegionPins: widget.onTapRegionPins,
                  ),
                ),

              // 3. 地図の塗り（RegionPhotoOverlay）よりも上（最前面階層）に表示するピンレイヤー
              ..._buildTopLayerPinWidgets(mapSize),

              // 4. ピン表示時（ピン表示ボタンON時 または 詳細ズーム時）：
              //    ピンをタップした「その場の位置」の最前面にレビュー吹き出しを表示
              if (_isPinVisibleMode &&
                  widget.selectedPin != null &&
                  !widget.selectedPin!.isRouteWaypointOnly)
                Builder(
                  builder: (context) {
                    final activePin = widget.selectedPin!;
                    final pinScreenOffset =
                        RegionPhotoOverlay.latLngToScreenOffset(
                          activePin.latLng,
                          _currentCameraPosition,
                          mapSize,
                        );
                    const double cardWidth = 250.0;
                    const double cardHeight = 195.0;

                    final double left = (pinScreenOffset.dx - cardWidth / 2)
                        .clamp(
                          12.0,
                          (mapSize.width - cardWidth - 12.0).clamp(
                            12.0,
                            double.infinity,
                          ),
                        );
                    final double top = (pinScreenOffset.dy - cardHeight - 36.0)
                        .clamp(
                          48.0,
                          (mapSize.height - cardHeight - 80.0).clamp(
                            48.0,
                            double.infinity,
                          ),
                        );

                    return Positioned(
                      left: left,
                      top: top,
                      child: PinCalloutCard(
                        pin: activePin,
                        onOpenDetail: () => widget.onOpenPinDetail(activePin),
                        onClose: () => widget.onPinSelected(null),
                      ),
                    );
                  },
                ),

              // 4. 右下：ピンだけをすぐに見るボタン ＆ ホームボタン（1倍画面に戻す）
              Positioned(
                right: 16,
                bottom: 24,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ピンだけをすぐに見ることのできるボタン
                    Material(
                      key: const Key('quick_pin_only_button'),
                      color: _forcePinOnlyMode
                          ? AppTheme.darkGrey
                          : AppTheme.pureWhite.withValues(alpha: 0.92),
                      elevation: 2,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _togglePinOnlyMode,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Icon(
                            _forcePinOnlyMode
                                ? Icons.place
                                : Icons.place_outlined,
                            size: 24,
                            color: _forcePinOnlyMode
                                ? AppTheme.pureWhite
                                : AppTheme.darkGrey,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // ホームボタン（アイコンのみ・押したときには1倍の画面に戻す）
                    Material(
                      color: AppTheme.pureWhite.withValues(alpha: 0.92),
                      elevation: 2,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _returnToHome1x,
                        child: const Padding(
                          padding: EdgeInsets.all(16),
                          child: Icon(
                            Icons.home_outlined,
                            size: 24,
                            color: AppTheme.darkGrey,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
