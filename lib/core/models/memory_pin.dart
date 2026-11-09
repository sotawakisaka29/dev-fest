import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'app_photo.dart';

/// 地図上の訪問地点・思い出・レビューを表すモデル
///
/// アイデアシートの「ピン」仕様に基づき、レビュー・口コミ・写真を持つ通常ピンと、
/// ルート上の通過点（レビューなしの黒丸ノード）の両方を表現できるように設計している。
class MemoryPin {
  const MemoryPin({
    required this.id,
    required this.teamId,
    required this.placeName,
    required this.address,
    required this.prefecture,
    required this.latitude,
    required this.longitude,
    required this.mapNormalizedPosition,
    required this.startTime,
    required this.endTime,
    required this.rating,
    required this.comment,
    required this.photoLabels,
    this.photos = const [],
    this.recordedDate,
    this.tripId,
    this.shareLocation = true,
    this.isRouteWaypointOnly = false,
  });

  final String id;
  final String teamId;
  final String placeName;
  final String address;
  final String prefecture;

  /// Google Maps 上の実座標（緯度・経度）
  final double latitude;
  final double longitude;

  /// Google Maps SDK 用の LatLng 座標を取得する
  LatLng get latLng => LatLng(latitude, longitude);

  /// 都道府県シルエット表示およびモック地図キャンバス上の正規化座標 (0.0 ~ 1.0)
  final Offset mapNormalizedPosition;

  final String startTime;
  final String endTime;

  /// 1〜5の星評価（通過点のみの場合は0）
  final int rating;
  final String comment;
  final List<String> photoLabels;

  /// 端末アルバムやGoogleフォトから選択された実写真データリスト
  final List<AppPhoto> photos;

  /// 記録日（未指定時は当日扱い）
  final DateTime? recordedDate;

  /// 紐づく旅行ID（旅行スタート〜停止の間に記録された場合）
  final String? tripId;

  final bool shareLocation;

  /// true の場合は特定の場所レビューではなくルート線上の黒丸として表示する
  final bool isRouteWaypointOnly;

  /// 住所文字列から市区町村名（例: 江東区、鎌倉市、京都市、札幌市、箱根町）を抽出する
  String get city {
    var rest = address;
    if (prefecture.isNotEmpty && rest.startsWith(prefecture)) {
      rest = rest.substring(prefecture.length);
    }
    final match = RegExp(r'^([^0-9０-９\-ー]+?[市区町村])').firstMatch(rest);
    if (match != null) {
      final raw = match.group(1)!;
      // 「足柄下郡箱根町」のように郡が含まれる場合は町・村名を優先表示
      final gunSplit = raw.split('郡');
      if (gunSplit.length > 1 && gunSplit.last.isNotEmpty) {
        return gunSplit.last;
      }
      return raw;
    }
    return prefecture;
  }

  MemoryPin copyWith({
    String? id,
    String? teamId,
    String? placeName,
    String? address,
    String? prefecture,
    double? latitude,
    double? longitude,
    Offset? mapNormalizedPosition,
    String? startTime,
    String? endTime,
    int? rating,
    String? comment,
    List<String>? photoLabels,
    List<AppPhoto>? photos,
    DateTime? recordedDate,
    String? tripId,
    bool? shareLocation,
    bool? isRouteWaypointOnly,
  }) {
    return MemoryPin(
      id: id ?? this.id,
      teamId: teamId ?? this.teamId,
      placeName: placeName ?? this.placeName,
      address: address ?? this.address,
      prefecture: prefecture ?? this.prefecture,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      mapNormalizedPosition:
          mapNormalizedPosition ?? this.mapNormalizedPosition,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      photoLabels: photoLabels ?? this.photoLabels,
      photos: photos ?? this.photos,
      recordedDate: recordedDate ?? this.recordedDate,
      tripId: tripId ?? this.tripId,
      shareLocation: shareLocation ?? this.shareLocation,
      isRouteWaypointOnly: isRouteWaypointOnly ?? this.isRouteWaypointOnly,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'teamId': teamId,
      'placeName': placeName,
      'address': address,
      'prefecture': prefecture,
      'latitude': latitude,
      'longitude': longitude,
      'normX': mapNormalizedPosition.dx,
      'normY': mapNormalizedPosition.dy,
      'startTime': startTime,
      'endTime': endTime,
      'rating': rating,
      'comment': comment,
      'photoLabels': photoLabels,
      'photos': photos
          .map(
            (p) => {
              'id': p.id,
              'label': p.label,
              'url': p.url,
              'localPath': p.localPath,
              'takenAt': p.takenAt?.toIso8601String(),
              'isFromGooglePhotos': p.isFromGooglePhotos,
            },
          )
          .toList(),
      'recordedDate': recordedDate?.toIso8601String(),
      'tripId': tripId,
      'shareLocation': shareLocation,
      'isRouteWaypointOnly': isRouteWaypointOnly,
    };
  }

  factory MemoryPin.fromFirestore(String id, Map<String, dynamic> data) {
    final labels =
        (data['photoLabels'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        <String>[];
    final rawPhotos = data['photos'] as List<dynamic>? ?? const [];
    final parsedPhotos = rawPhotos.map((m) {
      if (m is Map) {
        final stringKeyMap = Map<String, dynamic>.from(m);
        return AppPhoto(
          id: stringKeyMap['id'] as String? ?? '',
          label: stringKeyMap['label'] as String? ?? '',
          url: stringKeyMap['url'] as String?,
          localPath: stringKeyMap['localPath'] as String?,
          takenAt: stringKeyMap['takenAt'] is String
              ? DateTime.tryParse(stringKeyMap['takenAt'] as String)
              : null,
          isFromGooglePhotos: stringKeyMap['isFromGooglePhotos'] as bool? ?? true,
        );
      }
      return null;
    }).whereType<AppPhoto>().toList();

    return MemoryPin(
      id: id,
      teamId: data['teamId'] as String? ?? '',
      placeName: data['placeName'] as String? ?? '名称未設定',
      address: data['address'] as String? ?? '',
      prefecture: data['prefecture'] as String? ?? '東京都',
      latitude: (data['latitude'] as num?)?.toDouble() ?? 35.6812,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 139.7671,
      mapNormalizedPosition: Offset(
        (data['normX'] as num?)?.toDouble() ?? 0.66,
        (data['normY'] as num?)?.toDouble() ?? 0.56,
      ),
      startTime: data['startTime'] as String? ?? '10:00',
      endTime: data['endTime'] as String? ?? '11:00',
      rating: (data['rating'] as num?)?.toInt() ?? 0,
      comment: data['comment'] as String? ?? '',
      photoLabels: labels,
      photos: parsedPhotos,
      recordedDate: data['recordedDate'] is String
          ? DateTime.tryParse(data['recordedDate'] as String)
          : null,
      tripId: data['tripId'] as String?,
      shareLocation: data['shareLocation'] as bool? ?? true,
      isRouteWaypointOnly: data['isRouteWaypointOnly'] as bool? ?? false,
    );
  }

  /// 初期サンプルピンリスト（シードデータなし）
  static const List<MemoryPin> initialSamplePins = [];
}
