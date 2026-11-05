import 'package:flutter/material.dart';

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
    required this.mapNormalizedPosition,
    required this.startTime,
    required this.endTime,
    required this.rating,
    required this.comment,
    required this.photoLabels,
    this.shareLocation = true,
    this.isRouteWaypointOnly = false,
  });

  final String id;
  final String teamId;
  final String placeName;
  final String address;
  final String prefecture;

  /// モック地図キャンバス上の正規化座標 (0.0 ~ 1.0)
  /// 実Google Maps導入時は LatLng(latitude, longitude) へ置き換える
  final Offset mapNormalizedPosition;

  final String startTime;
  final String endTime;

  /// 1〜5の星評価（通過点のみの場合は0）
  final int rating;
  final String comment;
  final List<String> photoLabels;
  final bool shareLocation;

  /// true の場合は特定の場所レビューではなくルート線上の黒丸として表示する
  final bool isRouteWaypointOnly;

  static const List<MemoryPin> initialSamplePins = [
    MemoryPin(
      id: 'pin_tokyo_cafe',
      teamId: 'daily',
      placeName: '清澄白河 ロースタリーカフェ',
      address: '東京都江東区清澄1-4-8',
      prefecture: '東京都',
      mapNormalizedPosition: Offset(0.66, 0.56),
      startTime: '10:30',
      endTime: '12:00',
      rating: 5,
      comment: '浅煎りのハンドドリップが絶品。静かな朝の時間を楽しめた。',
      photoLabels: ['ラテアート', '外観', 'テラス席'],
    ),
    MemoryPin(
      id: 'pin_waypoint_1',
      teamId: 'daily',
      placeName: '移動中継地点（海ほたるPA）',
      address: '千葉県木更津市中島地先海ほたる',
      prefecture: '千葉県',
      mapNormalizedPosition: Offset(0.69, 0.61),
      startTime: '13:00',
      endTime: '13:20',
      rating: 0,
      comment: '',
      photoLabels: [],
      isRouteWaypointOnly: true,
    ),
    MemoryPin(
      id: 'pin_kamakura',
      teamId: 'daily',
      placeName: '七里ヶ浜 海沿いテラス',
      address: '神奈川県鎌倉市七里ガ浜1-4-11',
      prefecture: '神奈川県',
      mapNormalizedPosition: Offset(0.62, 0.63),
      startTime: '14:30',
      endTime: '16:30',
      rating: 4,
      comment: '夕暮れの江ノ島と富士山がきれいに見えた思い出の場所。',
      photoLabels: ['夕焼けの海', 'パンケーキ'],
    ),
    MemoryPin(
      id: 'pin_kyoto',
      teamId: 'daily',
      placeName: '嵐山 竹林の小径',
      address: '京都府京都市右京区嵯峨小倉山田淵山町',
      prefecture: '京都府',
      mapNormalizedPosition: Offset(0.45, 0.62),
      startTime: '09:00',
      endTime: '11:00',
      rating: 5,
      comment: '早朝に訪問したため人が少なく、風が吹く音まで心地よかった。',
      photoLabels: ['竹林', '渡月橋'],
    ),
    MemoryPin(
      id: 'pin_sapporo',
      teamId: 'daily',
      placeName: '札幌 大通公園・時計台',
      address: '北海道札幌市中央区北1条西2丁目',
      prefecture: '北海道',
      mapNormalizedPosition: Offset(0.80, 0.22),
      startTime: '18:00',
      endTime: '20:00',
      rating: 4,
      comment: '夜風が涼しく、スープカレーとシメパフェを満喫。',
      photoLabels: ['時計台夜景', 'スープカレー'],
    ),
    MemoryPin(
      id: 'pin_hakone_1',
      teamId: 'hakone_trip',
      placeName: '箱根湯本 温泉宿',
      address: '神奈川県足柄下郡箱根町湯本',
      prefecture: '神奈川県',
      mapNormalizedPosition: Offset(0.60, 0.64),
      startTime: '15:00',
      endTime: '10:00',
      rating: 5,
      comment: 'チームみんなで露天風呂と懐石料理を満喫！',
      photoLabels: ['露天風呂', '夕食', '集合写真'],
    ),
    MemoryPin(
      id: 'pin_cafe_1',
      teamId: 'cafe_club',
      placeName: '代官山 ブックカフェ',
      address: '東京都渋谷区猿楽町17-5',
      prefecture: '東京都',
      mapNormalizedPosition: Offset(0.65, 0.57),
      startTime: '14:00',
      endTime: '16:00',
      rating: 4,
      comment: '読書しながら過ごせる落ち着いた空間。チーズケーキが濃厚。',
      photoLabels: ['チーズケーキ', '本棚'],
    ),
  ];
}
