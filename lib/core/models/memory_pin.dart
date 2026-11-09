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
    this.rating,
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

  /// 1〜5の星評価（未評価・評価なし・通過点の場合はnull）
  final int? rating;
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
    var rest = address.trim();
    // Google Maps等の「日本、〒123-4567 」プレフィックスを除去
    rest = rest.replaceFirst(
      RegExp(r'^(?:日本[、,\s]*)?(?:〒?\s*\d{3}[-ー]\d{4}\s*)?'),
      '',
    );
    if (prefecture.isNotEmpty) {
      final prefIndex = rest.indexOf(prefecture);
      if (prefIndex >= 0) {
        rest = rest.substring(prefIndex + prefecture.length).trim();
      }
    }

    // 1. 「足柄下郡箱根町」のように郡（大和郡山市・小郡市・蒲郡市・郡山市を除く）が含まれる場合は町・村名を抽出
    final gunMatch = RegExp(
      r'^(?!(?:大和郡山|小郡|蒲郡|郡山)市)([^0-9０-９\-ー\s市区町村]+?郡)\s*([^0-9０-９\-ー\s]+?[町村])',
    ).firstMatch(rest);
    if (gunMatch != null) {
      return gunMatch.group(2)!;
    }

    // 2. 市名（政令指定都市の「京都市右京区」→「京都市」、および「市川市」「四日市市」「廿日市市」「町田市」「東村山市」等に対応）
    final shiMatch = RegExp(
      r'^((?:市川|市原|四日市|廿日市|八日市場|十日町|野々市|大町|町田|東村山|武蔵村山|羽村|村上|大村|[^0-9０-９\-ー\s市区]+?)市)',
    ).firstMatch(rest);
    if (shiMatch != null) {
      return shiMatch.group(1)!;
    }

    // 3. 特別区（東京都23区など）や郡省略の町村名
    final kuChosonMatch = RegExp(r'^([^0-9０-９\-ー\s]+?[区町村])').firstMatch(rest);
    if (kuChosonMatch != null) {
      return kuChosonMatch.group(1)!;
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
    final parsedPhotos = rawPhotos.whereType<Map<String, dynamic>>().map((m) {
      return AppPhoto(
        id: m['id'] as String? ?? '',
        label: m['label'] as String? ?? '',
        url: m['url'] as String?,
        localPath: m['localPath'] as String?,
        takenAt: m['takenAt'] is String
            ? DateTime.tryParse(m['takenAt'] as String)
            : null,
        isFromGooglePhotos: m['isFromGooglePhotos'] as bool? ?? true,
      );
    }).toList();

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
      rating: (data['rating'] as num?)?.toInt(),
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

  /// このピンが指定された開始日時〜終了日時の範囲内に該当するかどうかを判定する
  bool matchesTimeWindow(DateTime windowStart, DateTime windowEnd) {
    final pinRange = resolvedTimeRange;
    if (pinRange != null) {
      // ピンの滞在時間帯と指定期間が少しでも重なっていれば一致とみなす
      final overlaps =
          !pinRange.$2.isBefore(windowStart) && !pinRange.$1.isAfter(windowEnd);
      if (overlaps) return true;
    }

    // 写真の撮影日時（takenAt）が指定期間内にある場合も一致とみなす
    for (final photo in photos) {
      final taken = photo.takenAt;
      if (taken != null &&
          !taken.isBefore(windowStart) &&
          !taken.isAfter(windowEnd)) {
        return true;
      }
    }
    return false;
  }

  /// `recordedDate` と `startTime` / `endTime` から実日時の範囲 `(startDateTime, endDateTime)` を算出する
  (DateTime, DateTime)? get resolvedTimeRange {
    final baseDate = recordedDate;
    if (baseDate == null) return null;

    final startParts = _parseHourMinute(startTime);
    final endParts = _parseHourMinute(endTime);

    final startDt = DateTime(
      baseDate.year,
      baseDate.month,
      baseDate.day,
      startParts.$1,
      startParts.$2,
    );

    var endDt = DateTime(
      baseDate.year,
      baseDate.month,
      baseDate.day,
      endParts.$1,
      endParts.$2,
    );
    // 終了時刻が開始時刻より前の場合（宿泊など日跨ぎ）は翌日扱いにする
    if (endDt.isBefore(startDt)) {
      endDt = endDt.add(const Duration(days: 1));
    }
    return (startDt, endDt);
  }

  static (int, int) _parseHourMinute(String text) {
    final parts = text.split(':');
    if (parts.length >= 2) {
      final h = int.tryParse(parts[0].trim()) ?? 0;
      final m = int.tryParse(parts[1].trim()) ?? 0;
      return (h.clamp(0, 23), m.clamp(0, 59));
    }
    return (12, 0);
  }

  static final List<MemoryPin> initialSamplePins = [
    MemoryPin(
      id: 'pin_tokyo_cafe',
      teamId: 'daily',
      placeName: '清澄白河 ロースタリーカフェ',
      address: '東京都江東区清澄1-4-8',
      prefecture: '東京都',
      latitude: 35.6821,
      longitude: 139.7988,
      mapNormalizedPosition: const Offset(0.66, 0.56),
      startTime: '10:30',
      endTime: '12:00',
      rating: 5,
      comment: '浅煎りのハンドドリップが絶品。静かな朝の時間を楽しめた。',
      photoLabels: const ['ラテアート', '外観', 'テラス席'],
      recordedDate: DateTime(2026, 10, 18),
      tripId: 'trip_kanto_day',
    ),
    MemoryPin(
      id: 'pin_waypoint_1',
      teamId: 'daily',
      placeName: '移動中継地点（海ほたるPA）',
      address: '千葉県木更津市中島地先海ほたる',
      prefecture: '千葉県',
      latitude: 35.4646,
      longitude: 139.8744,
      mapNormalizedPosition: const Offset(0.69, 0.61),
      startTime: '13:00',
      endTime: '13:20',
      comment: '東京湾を一望できるパーキングエリアで小休憩。',
      photoLabels: const [],
      recordedDate: DateTime(2026, 10, 18),
      isRouteWaypointOnly: true,
      tripId: 'trip_kanto_day',
    ),
    MemoryPin(
      id: 'pin_kamakura',
      teamId: 'daily',
      placeName: '七里ヶ浜 海沿いテラス',
      address: '神奈川県鎌倉市七里ガ浜1-4-11',
      prefecture: '神奈川県',
      latitude: 35.3056,
      longitude: 139.5105,
      mapNormalizedPosition: const Offset(0.62, 0.63),
      startTime: '14:30',
      endTime: '16:30',
      rating: 4,
      comment: '夕暮れの江ノ島と富士山がきれいに見えた思い出の場所。',
      photoLabels: const ['夕焼けの海', 'パンケーキ'],
      recordedDate: DateTime(2026, 10, 18),
      tripId: 'trip_kanto_day',
    ),
    MemoryPin(
      id: 'pin_kyoto',
      teamId: 'daily',
      placeName: '嵐山 竹林の小径',
      address: '京都府京都市右京区嵯峨小倉山田淵山町',
      prefecture: '京都府',
      latitude: 35.0170,
      longitude: 135.6713,
      mapNormalizedPosition: const Offset(0.45, 0.62),
      startTime: '09:00',
      endTime: '11:00',
      rating: 5,
      comment: '早朝に訪問したため人が少なく、風が吹く音まで心地よかった。',
      photoLabels: const ['竹林', '渡月橋'],
      recordedDate: DateTime(2026, 10, 25),
      tripId: 'trip_kyoto_autumn',
    ),
    MemoryPin(
      id: 'pin_sapporo',
      teamId: 'daily',
      placeName: '札幌 大通公園・時計台',
      address: '北海道札幌市中央区北1条西2丁目',
      prefecture: '北海道',
      latitude: 43.0626,
      longitude: 141.3535,
      mapNormalizedPosition: const Offset(0.80, 0.22),
      startTime: '18:00',
      endTime: '20:00',
      rating: 4,
      comment: '夜風が涼しく、スープカレーとシメパフェを満喫。',
      photoLabels: const ['時計台夜景', 'スープカレー'],
      recordedDate: DateTime(2026, 11, 1),
      tripId: 'trip_hokkaido_gourmet',
    ),
    MemoryPin(
      id: 'pin_hakone_1',
      teamId: 'hakone_trip',
      placeName: '箱根湯本 温泉宿',
      address: '神奈川県足柄下郡箱根町湯本',
      prefecture: '神奈川県',
      latitude: 35.2324,
      longitude: 139.1069,
      mapNormalizedPosition: const Offset(0.60, 0.64),
      startTime: '15:00',
      endTime: '10:00',
      rating: 5,
      comment: 'チームみんなで露天風呂と懐石料理を満喫！',
      photoLabels: const ['露天風呂', '夕食', '集合写真'],
      recordedDate: DateTime(2026, 11, 2),
      tripId: 'trip_hakone_onsen',
    ),
    MemoryPin(
      id: 'pin_cafe_1',
      teamId: 'cafe_club',
      placeName: '代官山 ブックカフェ',
      address: '東京都渋谷区猿楽町17-5',
      prefecture: '東京都',
      latitude: 35.6488,
      longitude: 139.6994,
      mapNormalizedPosition: const Offset(0.65, 0.57),
      startTime: '14:00',
      endTime: '16:00',
      rating: 4,
      comment: '読書しながら過ごせる落ち着いた空間。チーズケーキが濃厚。',
      photoLabels: const ['チーズケーキ', '本棚'],
      recordedDate: DateTime(2026, 11, 5),
      tripId: 'trip_daikanyama_cafe',
    ),
  ];
}
