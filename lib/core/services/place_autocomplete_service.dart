import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';

/// 店舗名・スポット名の予測候補モデル
class PlaceCandidate {
  const PlaceCandidate({
    required this.name,
    required this.address,
    required this.prefecture,
    required this.latitude,
    required this.longitude,
    required this.normalizedPosition,
    this.category,
    this.placeId,
  });

  final String name;
  final String address;
  final String prefecture;
  final double latitude;
  final double longitude;
  final Offset normalizedPosition;
  final String? category;
  final String? placeId;

  /// 日本国内の緯度・経度からモックキャンバス用の正規化座標 (0.0 ~ 1.0) を算出する
  static Offset latLngToNormalizedOffset(double lat, double lng) {
    final normX = ((lng - 129.0) / (146.0 - 129.0)).clamp(0.05, 0.95);
    final normY = (1.0 - ((lat - 30.0) / (45.5 - 30.0))).clamp(0.05, 0.95);
    return Offset(normX, normY);
  }

  /// 住所文字列から47都道府県名を抽出する
  static String extractPrefecture(String text, {double? lat, double? lng}) {
    for (final pref in PlaceAutocompleteService.prefectureCenters.keys) {
      if (text.contains(pref)) {
        return pref;
      }
      // 「京都」「大阪」「北海道」「東京」などの略称チェック
      final shortName = pref
          .replaceAll('都', '')
          .replaceAll('府', '')
          .replaceAll('県', '');
      if (shortName.length >= 2 && text.contains(shortName)) {
        return pref;
      }
    }

    // 緯度・経度から最も近い都道府県を推定
    if (lat != null && lng != null) {
      String nearestPref = '東京都';
      double minSqDist = double.infinity;
      for (final entry in PlaceAutocompleteService.prefectureCenters.entries) {
        final dLat = lat - entry.value.$1;
        final dLng = lng - entry.value.$2;
        final sq = dLat * dLat + dLng * dLng;
        if (sq < minSqDist) {
          minSqDist = sq;
          nearestPref = entry.key;
        }
      }
      return nearestPref;
    }

    return '東京都';
  }

  static const List<PlaceCandidate> sampleCandidates =
      PlaceAutocompleteService.catalogCandidates;
}

/// GoogleMap と同様に、店舗名や施設名の入力から
/// リアルタイムに予測候補リスト（店舗名＋住所リンク情報＋座標）を返すサービス
///
/// - ジャンル名・カテゴリ名（「カフェ」「ラーメン」「温泉」「美術館」など）や都道府県名単体ではヒットさせず、
///   あくまで具体的な店舗名・施設名のみを検索対象とする。
class PlaceAutocompleteService {
  PlaceAutocompleteService._();
  static final PlaceAutocompleteService instance = PlaceAutocompleteService._();

  static const MethodChannel _nativeChannel = MethodChannel(
    'com.devfest.mymap/external_launcher',
  );

  /// テスト環境では外部HTTP通信を行わず内蔵辞書のみで即座に返すフラグ
  static bool disableNetworkInTests = false;

  static String? _cachedGoogleMapsApiKey;

  /// ジャンル名・カテゴリ名・一般名詞のブラックリスト（これら単体での入力時は予測候補を出さない）
  static const Set<String> _genreBlockedQueries = {
    'カフェ',
    '喫茶',
    '喫茶店',
    'コーヒー',
    '珈琲',
    'カフェ・喫茶',
    'レストラン',
    'ご飯',
    'ご飯屋',
    'ご飯屋さん',
    'ごはん',
    'ごはん屋',
    'ごはん屋さん',
    '飲食店',
    'グルメ',
    'ランチ',
    'ディナー',
    '定食',
    '定食屋',
    '食堂',
    '居酒屋',
    'バル',
    'バー',
    'ラーメン',
    'らーめん',
    '中華そば',
    'つけ麺',
    'うどん',
    'そば',
    '蕎麦',
    '寿司',
    'すし',
    '鮨',
    '回転寿司',
    '焼肉',
    '焼き肉',
    'ホルモン',
    'ステーキ',
    'ハンバーグ',
    '焼き鳥',
    '焼鳥',
    'やきとり',
    '串カツ',
    'とんかつ',
    '天ぷら',
    'お好み焼き',
    'たこ焼き',
    'もんじゃ',
    'イタリアン',
    'パスタ',
    'ピザ',
    'フレンチ',
    'ビストロ',
    '中華',
    '中華料理',
    '韓国料理',
    'タイ料理',
    'カレー',
    'スープカレー',
    'パン',
    'パン屋',
    'ベーカリー',
    'スイーツ',
    'ケーキ',
    'ケーキ屋',
    'パフェ',
    'アイスクリーム',
    'ファストフード',
    'ハンバーガー',
    'ファミレス',
    'ファミリーレストラン',
    '牛丼',
    '丼',
    '海鮮',
    '海鮮丼',
    '観光',
    '観光地',
    '観光スポット',
    'スポット',
    '名所',
    'ランドマーク',
    '神社',
    '仏閣',
    '寺',
    'お寺',
    '神社・仏閣',
    '美術館',
    '博物館',
    '美術館・観光',
    '水族館',
    '動物園',
    'テーマパーク',
    '遊園地',
    '公園',
    '温泉',
    '銭湯',
    'サウナ',
    'ホテル',
    '旅館',
    '宿',
    'ショッピング',
    'ショッピングモール',
    '百貨店',
    'デパート',
    'コンビニ',
    'スーパー',
    '駅',
    '空港',
    'サービスエリア',
    'パーキングエリア',
    '城',
    '史跡',
    '世界遺産',
    'ビーチ',
    '海',
    '山',
  };

  /// 入力文字列が「ジャンル名のみ」または「都道府県・市区町村名のみ」かどうかを判定する
  static bool isGenreOrRegionOnlyQuery(String rawQuery) {
    final normalized = rawQuery.trim().toLowerCase();
    if (normalized.isEmpty) return true;

    if (_genreBlockedQueries.contains(normalized)) {
      return true;
    }

    // 47都道府県名（または「東京」「京都」「大阪」などの略称）単体の入力も店舗名ではないため除外
    for (final pref in prefectureCenters.keys) {
      final shortPref = pref
          .replaceAll('都', '')
          .replaceAll('府', '')
          .replaceAll('県', '');
      if (normalized == pref.toLowerCase() ||
          normalized == shortPref.toLowerCase()) {
        return true;
      }
    }

    return false;
  }

  /// 47都道府県の代表座標・庁所在地マップ
  static const Map<String, (double, double, String)> prefectureCenters = {
    '北海道': (43.0642, 141.3469, '北海道札幌市中央区'),
    '青森県': (40.8244, 140.7400, '青森県青森市長島'),
    '岩手県': (39.7036, 141.1527, '岩手県盛岡市内丸'),
    '宮城県': (38.2688, 140.8721, '宮城県仙台市青葉区'),
    '秋田県': (39.7186, 140.1024, '秋田県秋田市山王'),
    '山形県': (38.2404, 140.3633, '山形県山形市松波'),
    '福島県': (37.7503, 140.4676, '福島県福島市杉妻町'),
    '茨城県': (36.3418, 140.4468, '茨城県水戸市笠原町'),
    '栃木県': (36.5658, 139.8836, '栃木県宇都宮市塙田'),
    '群馬県': (36.3911, 139.0608, '群馬県前橋市大手町'),
    '埼玉県': (35.8569, 139.6489, '埼玉県さいたま市浦和区'),
    '千葉県': (35.6051, 140.1233, '千葉県千葉市中央区'),
    '東京都': (35.6812, 139.7671, '東京都千代田区丸の内'),
    '神奈川県': (35.4478, 139.6425, '神奈川県横浜市中区'),
    '新潟県': (37.9026, 139.0232, '新潟県新潟市中央区'),
    '富山県': (36.6953, 137.2113, '富山県富山市新総曲輪'),
    '石川県': (36.5947, 136.6256, '石川県金沢市広坂'),
    '福井県': (36.0652, 136.2216, '福井県福井市大手'),
    '山梨県': (35.6642, 138.5684, '山梨県甲府市丸の内'),
    '長野県': (36.6513, 138.1810, '長野県長野市大字南長野'),
    '岐阜県': (35.3912, 136.7223, '岐阜県岐阜市薮田南'),
    '静岡県': (34.9769, 138.3831, '静岡県静岡市葵区'),
    '愛知県': (35.1802, 136.9066, '愛知県名古屋市中区'),
    '三重県': (34.7303, 136.5086, '三重県津市広明町'),
    '滋賀県': (35.0045, 135.8686, '滋賀県大津市京町'),
    '京都府': (35.0116, 135.7681, '京都府京都市中京区'),
    '大阪府': (34.6863, 135.5200, '大阪府大阪市中央区'),
    '兵庫県': (34.6913, 135.1830, '兵庫県神戸市中央区'),
    '奈良県': (34.6851, 135.8328, '奈良県奈良市登大路町'),
    '和歌山県': (34.2260, 135.1675, '和歌山県和歌山市小松原通'),
    '鳥取県': (35.5039, 134.2377, '鳥取県鳥取市東町'),
    '島根県': (35.4723, 133.0505, '島根県松江市殿町'),
    '岡山県': (34.6618, 133.9344, '岡山県岡山市北区'),
    '広島県': (34.3966, 132.4596, '広島県広島市中区'),
    '山口県': (34.1859, 131.4706, '山口県山口市滝町'),
    '徳島県': (34.0658, 134.5593, '徳島県徳島市万代町'),
    '香川県': (34.3401, 134.0434, '香川県高松市番町'),
    '愛媛県': (33.8416, 132.7657, '愛媛県松山市一番町'),
    '高知県': (33.5597, 133.5311, '高知県高知市丸ノ内'),
    '福岡県': (33.5902, 130.4017, '福岡県福岡市博多区'),
    '佐賀県': (33.2494, 130.2988, '佐賀県佐賀市城内'),
    '長崎県': (32.7503, 129.8777, '長崎県長崎市尾上町'),
    '熊本県': (32.7898, 130.7417, '熊本県熊本市中央区'),
    '大分県': (33.2382, 131.6126, '大分県大分市大手町'),
    '宮崎県': (31.9111, 131.4239, '宮崎県宮崎市橘通東'),
    '鹿児島県': (31.5602, 130.5581, '鹿児島県鹿児島市鴨池新町'),
    '沖縄県': (26.2124, 127.6809, '沖縄県那覇市泉崎'),
  };

  /// 全国の飲食店（ご飯屋さん・レストラン・カフェ）および主要施設の内蔵店舗名リスト
  static const List<PlaceCandidate> catalogCandidates = [
    // --- ご飯屋さん・飲食店・レストラン・カフェ ---
    PlaceCandidate(
      name: '一蘭 渋谷店',
      address: '東京都渋谷区神南1-22-7',
      prefecture: '東京都',
      latitude: 35.6612,
      longitude: 139.7010,
      normalizedPosition: Offset(0.66, 0.56),
    ),
    PlaceCandidate(
      name: '一蘭 太宰府参道店',
      address: '福岡県太宰府市宰府2-6-2',
      prefecture: '福岡県',
      latitude: 33.5196,
      longitude: 130.5313,
      normalizedPosition: Offset(0.24, 0.74),
    ),
    PlaceCandidate(
      name: '一風堂 本店',
      address: '福岡県福岡市中央区大名1-13-14',
      prefecture: '福岡県',
      latitude: 33.5877,
      longitude: 130.3970,
      normalizedPosition: Offset(0.24, 0.73),
    ),
    PlaceCandidate(
      name: '蒙古タンメン中本 新宿店',
      address: '東京都新宿区西新宿7-8-11',
      prefecture: '東京都',
      latitude: 35.6952,
      longitude: 139.6980,
      normalizedPosition: Offset(0.66, 0.56),
    ),
    PlaceCandidate(
      name: '天下一品 総本店',
      address: '京都府京都市左京区一乗寺築田町94',
      prefecture: '京都府',
      latitude: 35.0445,
      longitude: 135.7862,
      normalizedPosition: Offset(0.45, 0.62),
    ),
    PlaceCandidate(
      name: '炭焼レストラン さわやか 御殿場インター店',
      address: '静岡県御殿場市東田中984-1',
      prefecture: '静岡県',
      latitude: 35.2982,
      longitude: 138.9408,
      normalizedPosition: Offset(0.60, 0.64),
    ),
    PlaceCandidate(
      name: '叙々苑 游玄亭 新宿',
      address: '東京都新宿区歌舞伎町1-10-7',
      prefecture: '東京都',
      latitude: 35.6939,
      longitude: 139.7027,
      normalizedPosition: Offset(0.66, 0.56),
    ),
    PlaceCandidate(
      name: '牛たん炭焼 利久 仙台駅店',
      address: '宮城県仙台市青葉区中央1-1-1',
      prefecture: '宮城県',
      latitude: 38.2603,
      longitude: 140.8825,
      normalizedPosition: Offset(0.73, 0.41),
    ),
    PlaceCandidate(
      name: '矢場とん 矢場町本店',
      address: '愛知県名古屋市中区大須3-6-18',
      prefecture: '愛知県',
      latitude: 35.1618,
      longitude: 136.9066,
      normalizedPosition: Offset(0.51, 0.61),
    ),
    PlaceCandidate(
      name: 'あつた蓬莱軒 本店',
      address: '愛知県名古屋市熱田区神戸町503',
      prefecture: '愛知県',
      latitude: 35.1219,
      longitude: 136.9061,
      normalizedPosition: Offset(0.51, 0.61),
    ),
    PlaceCandidate(
      name: '味乃家 本店',
      address: '大阪府大阪市中央区難波1-7-16',
      prefecture: '大阪府',
      latitude: 34.6681,
      longitude: 135.5015,
      normalizedPosition: Offset(0.43, 0.65),
    ),
    PlaceCandidate(
      name: '串かつだるま 新世界総本店',
      address: '大阪府大阪市浪速区恵美須東2-3-9',
      prefecture: '大阪府',
      latitude: 34.6522,
      longitude: 135.5062,
      normalizedPosition: Offset(0.43, 0.65),
    ),
    PlaceCandidate(
      name: '551蓬莱 本店',
      address: '大阪府大阪市中央区難波3-6-3',
      prefecture: '大阪府',
      latitude: 34.6662,
      longitude: 135.5014,
      normalizedPosition: Offset(0.43, 0.65),
    ),
    PlaceCandidate(
      name: 'お好み焼 みっちゃん総本店 八丁堀本店',
      address: '広島県広島市中区八丁堀6-7',
      prefecture: '広島県',
      latitude: 34.3958,
      longitude: 132.4638,
      normalizedPosition: Offset(0.32, 0.68),
    ),
    PlaceCandidate(
      name: 'スープカレー GARAKU 札幌本店',
      address: '北海道札幌市中央区南2条西2丁目6-1',
      prefecture: '北海道',
      latitude: 43.0581,
      longitude: 141.3556,
      normalizedPosition: Offset(0.80, 0.22),
    ),
    PlaceCandidate(
      name: '成吉思汗 だるま 本店',
      address: '北海道札幌市中央区南5条西4',
      prefecture: '北海道',
      latitude: 43.0543,
      longitude: 141.3533,
      normalizedPosition: Offset(0.80, 0.22),
    ),
    PlaceCandidate(
      name: 'トリトン 豊平店',
      address: '北海道札幌市豊平区豊平4条6丁目1-10',
      prefecture: '北海道',
      latitude: 43.0468,
      longitude: 141.3736,
      normalizedPosition: Offset(0.80, 0.22),
    ),
    PlaceCandidate(
      name: '博多もつ鍋 やま中 赤坂店',
      address: '福岡県福岡市中央区赤坂1-9-1',
      prefecture: '福岡県',
      latitude: 33.5882,
      longitude: 130.3917,
      normalizedPosition: Offset(0.24, 0.73),
    ),
    PlaceCandidate(
      name: '元祖博多めんたい重',
      address: '福岡県福岡市中央区西中洲6-15',
      prefecture: '福岡県',
      latitude: 33.5910,
      longitude: 130.4052,
      normalizedPosition: Offset(0.24, 0.73),
    ),
    PlaceCandidate(
      name: '資さんうどん 博多千代店',
      address: '福岡県福岡市博多区千代2-1-24',
      prefecture: '福岡県',
      latitude: 33.6041,
      longitude: 130.4158,
      normalizedPosition: Offset(0.24, 0.73),
    ),
    PlaceCandidate(
      name: 'スシロー 渋谷駅前店',
      address: '東京都渋谷区宇田川町23-3',
      prefecture: '東京都',
      latitude: 35.6604,
      longitude: 139.7001,
      normalizedPosition: Offset(0.66, 0.56),
    ),
    PlaceCandidate(
      name: 'くら寿司 浅草ROX店',
      address: '東京都台東区浅草1-25-15',
      prefecture: '東京都',
      latitude: 35.7130,
      longitude: 139.7931,
      normalizedPosition: Offset(0.67, 0.55),
    ),
    PlaceCandidate(
      name: 'サイゼリヤ 渋谷文化村通り店',
      address: '東京都渋谷区道玄坂2-25-12',
      prefecture: '東京都',
      latitude: 35.6599,
      longitude: 139.6974,
      normalizedPosition: Offset(0.66, 0.56),
    ),
    PlaceCandidate(
      name: 'ガスト 新宿靖国通り店',
      address: '東京都新宿区歌舞伎町1-6-2',
      prefecture: '東京都',
      latitude: 35.6933,
      longitude: 139.7034,
      normalizedPosition: Offset(0.66, 0.56),
    ),
    PlaceCandidate(
      name: '鳥貴族 渋谷神南店',
      address: '東京都渋谷区神南1-20-15',
      prefecture: '東京都',
      latitude: 35.6617,
      longitude: 139.7004,
      normalizedPosition: Offset(0.66, 0.56),
    ),
    PlaceCandidate(
      name: '大戸屋 ごはん処 新宿東口中央通り店',
      address: '東京都新宿区新宿3-27-5',
      prefecture: '東京都',
      latitude: 35.6908,
      longitude: 139.7030,
      normalizedPosition: Offset(0.66, 0.56),
    ),
    PlaceCandidate(
      name: 'やよい軒 新宿小滝橋通り店',
      address: '東京都新宿区西新宿7-9-13',
      prefecture: '東京都',
      latitude: 35.6956,
      longitude: 139.6976,
      normalizedPosition: Offset(0.66, 0.56),
    ),
    PlaceCandidate(
      name: '松屋 新宿東口店',
      address: '東京都新宿区新宿3-22-11',
      prefecture: '東京都',
      latitude: 35.6924,
      longitude: 139.7019,
      normalizedPosition: Offset(0.66, 0.56),
    ),
    PlaceCandidate(
      name: '吉野家 有楽町店',
      address: '東京都千代田区有楽町2-9-18',
      prefecture: '東京都',
      latitude: 35.6744,
      longitude: 139.7631,
      normalizedPosition: Offset(0.66, 0.56),
    ),
    PlaceCandidate(
      name: 'すき家 渋谷道玄坂店',
      address: '東京都渋谷区道玄坂2-6-14',
      prefecture: '東京都',
      latitude: 35.6584,
      longitude: 139.6987,
      normalizedPosition: Offset(0.66, 0.56),
    ),
    PlaceCandidate(
      name: 'スターバックス コーヒー 鎌倉御成町店',
      address: '神奈川県鎌倉市御成町15-11',
      prefecture: '神奈川県',
      latitude: 35.3177,
      longitude: 139.5484,
      normalizedPosition: Offset(0.62, 0.63),
    ),
    PlaceCandidate(
      name: 'コメダ珈琲店 新宿靖国通り店',
      address: '東京都新宿区歌舞伎町1-16-3',
      prefecture: '東京都',
      latitude: 35.6938,
      longitude: 139.7016,
      normalizedPosition: Offset(0.66, 0.56),
    ),
    PlaceCandidate(
      name: 'ブルーボトルコーヒー 清澄白河フラッグシップカフェ',
      address: '東京都江東区平野1-4-8',
      prefecture: '東京都',
      latitude: 35.6777,
      longitude: 139.8027,
      normalizedPosition: Offset(0.67, 0.55),
    ),
    PlaceCandidate(
      name: 'bills 七里ヶ浜',
      address: '神奈川県鎌倉市七里ガ浜1-1-1',
      prefecture: '神奈川県',
      latitude: 35.3056,
      longitude: 139.5105,
      normalizedPosition: Offset(0.62, 0.63),
    ),
    PlaceCandidate(
      name: 'つるとんたん 新宿店',
      address: '東京都新宿区歌舞伎町2-26-3',
      prefecture: '東京都',
      latitude: 35.6961,
      longitude: 139.7024,
      normalizedPosition: Offset(0.66, 0.56),
    ),
    PlaceCandidate(
      name: '俺のイタリアン 新橋本店',
      address: '東京都港区新橋1-5-6',
      prefecture: '東京都',
      latitude: 35.6685,
      longitude: 139.7595,
      normalizedPosition: Offset(0.66, 0.56),
    ),

    // --- 主要施設・観光スポット ---
    PlaceCandidate(
      name: '金沢21世紀美術館',
      address: '石川県金沢市広坂1-2-1',
      prefecture: '石川県',
      latitude: 36.5609,
      longitude: 136.6582,
      normalizedPosition: Offset(0.52, 0.54),
    ),
    PlaceCandidate(
      name: '道頓堀 グリコサイン',
      address: '大阪府大阪市中央区道頓堀1-10-4',
      prefecture: '大阪府',
      latitude: 34.6687,
      longitude: 135.5013,
      normalizedPosition: Offset(0.43, 0.65),
    ),
    PlaceCandidate(
      name: '太宰府天満宮',
      address: '福岡県太宰府市宰府4-7-1',
      prefecture: '福岡県',
      latitude: 33.5215,
      longitude: 130.5349,
      normalizedPosition: Offset(0.24, 0.74),
    ),
    PlaceCandidate(
      name: '仙台駅 牛たん通り',
      address: '宮城県仙台市青葉区中央1-1-1',
      prefecture: '宮城県',
      latitude: 38.2601,
      longitude: 140.8824,
      normalizedPosition: Offset(0.73, 0.41),
    ),
    PlaceCandidate(
      name: '清水寺',
      address: '京都府京都市東山区清水1丁目294',
      prefecture: '京都府',
      latitude: 34.9949,
      longitude: 135.7850,
      normalizedPosition: Offset(0.45, 0.62),
    ),
    PlaceCandidate(
      name: '伏見稲荷大社',
      address: '京都府京都市伏見区深草藪之内町68',
      prefecture: '京都府',
      latitude: 34.9671,
      longitude: 135.7727,
      normalizedPosition: Offset(0.45, 0.63),
    ),
    PlaceCandidate(
      name: '嵐山 渡月橋',
      address: '京都府京都市右京区嵯峨中ノ島町',
      prefecture: '京都府',
      latitude: 35.0116,
      longitude: 135.6778,
      normalizedPosition: Offset(0.45, 0.62),
    ),
    PlaceCandidate(
      name: 'ユニバーサル・スタジオ・ジャパン (USJ)',
      address: '大阪府大阪市此花区桜島2丁目1-33',
      prefecture: '大阪府',
      latitude: 34.6654,
      longitude: 135.4323,
      normalizedPosition: Offset(0.43, 0.65),
    ),
    PlaceCandidate(
      name: '東京ディズニーランド',
      address: '千葉県浦安市舞浜1-1',
      prefecture: '千葉県',
      latitude: 35.6329,
      longitude: 139.8804,
      normalizedPosition: Offset(0.68, 0.56),
    ),
    PlaceCandidate(
      name: '東京ディズニーシー',
      address: '千葉県浦安市舞浜1-13',
      prefecture: '千葉県',
      latitude: 35.6267,
      longitude: 139.8851,
      normalizedPosition: Offset(0.68, 0.56),
    ),
    PlaceCandidate(
      name: '東京タワー',
      address: '東京都港区芝公園4丁目2-8',
      prefecture: '東京都',
      latitude: 35.6586,
      longitude: 139.7454,
      normalizedPosition: Offset(0.66, 0.56),
    ),
    PlaceCandidate(
      name: '東京スカイツリー',
      address: '東京都墨田区押上1丁目1-2',
      prefecture: '東京都',
      latitude: 35.7101,
      longitude: 139.8107,
      normalizedPosition: Offset(0.67, 0.55),
    ),
    PlaceCandidate(
      name: '浅草寺 雷門',
      address: '東京都台東区浅草2丁目3-1',
      prefecture: '東京都',
      latitude: 35.7148,
      longitude: 139.7967,
      normalizedPosition: Offset(0.67, 0.55),
    ),
    PlaceCandidate(
      name: '鎌倉 小町通り・鶴岡八幡宮',
      address: '神奈川県鎌倉市雪ノ下2丁目1-31',
      prefecture: '神奈川県',
      latitude: 35.3258,
      longitude: 139.5564,
      normalizedPosition: Offset(0.62, 0.63),
    ),
    PlaceCandidate(
      name: '横浜赤レンガ倉庫',
      address: '神奈川県横浜市中区新港1丁目1',
      prefecture: '神奈川県',
      latitude: 35.4526,
      longitude: 139.6429,
      normalizedPosition: Offset(0.63, 0.59),
    ),
    PlaceCandidate(
      name: '箱根神社・芦ノ湖',
      address: '神奈川県足柄下郡箱根町元箱根80-1',
      prefecture: '神奈川県',
      latitude: 35.2045,
      longitude: 139.0256,
      normalizedPosition: Offset(0.60, 0.64),
    ),
    PlaceCandidate(
      name: '札幌時計台・大通公園',
      address: '北海道札幌市中央区北1条西2丁目',
      prefecture: '北海道',
      latitude: 43.0626,
      longitude: 141.3535,
      normalizedPosition: Offset(0.80, 0.22),
    ),
    PlaceCandidate(
      name: '小樽運河',
      address: '北海道小樽市港町5',
      prefecture: '北海道',
      latitude: 43.1991,
      longitude: 141.0019,
      normalizedPosition: Offset(0.79, 0.21),
    ),
    PlaceCandidate(
      name: '函館山展望台',
      address: '北海道函館市函館山',
      prefecture: '北海道',
      latitude: 41.7595,
      longitude: 140.7042,
      normalizedPosition: Offset(0.77, 0.28),
    ),
    PlaceCandidate(
      name: '名古屋城',
      address: '愛知県名古屋市中区本丸1-1',
      prefecture: '愛知県',
      latitude: 35.1847,
      longitude: 136.8997,
      normalizedPosition: Offset(0.51, 0.61),
    ),
    PlaceCandidate(
      name: '伊勢神宮 内宮',
      address: '三重県伊勢市宇治館町1',
      prefecture: '三重県',
      latitude: 34.4550,
      longitude: 136.7256,
      normalizedPosition: Offset(0.50, 0.66),
    ),
    PlaceCandidate(
      name: '厳島神社（宮島）',
      address: '広島県廿日市市宮島町1-1',
      prefecture: '広島県',
      latitude: 34.2961,
      longitude: 132.3198,
      normalizedPosition: Offset(0.32, 0.68),
    ),
    PlaceCandidate(
      name: '出雲大社',
      address: '島根県出雲市大社町杵築東195',
      prefecture: '島根県',
      latitude: 35.4018,
      longitude: 132.6853,
      normalizedPosition: Offset(0.34, 0.62),
    ),
    PlaceCandidate(
      name: '沖縄美ら海水族館',
      address: '沖縄県国頭郡本部町石川424',
      prefecture: '沖縄県',
      latitude: 26.6943,
      longitude: 127.8779,
      normalizedPosition: Offset(0.12, 0.92),
    ),
    PlaceCandidate(
      name: '国際通り',
      address: '沖縄県那覇市牧志',
      prefecture: '沖縄県',
      latitude: 26.2155,
      longitude: 127.6869,
      normalizedPosition: Offset(0.12, 0.93),
    ),
    PlaceCandidate(
      name: '博多駅・中洲屋台横丁',
      address: '福岡県福岡市博多区中洲1丁目',
      prefecture: '福岡県',
      latitude: 33.5913,
      longitude: 130.4083,
      normalizedPosition: Offset(0.24, 0.73),
    ),
    PlaceCandidate(
      name: '別府温泉（地獄めぐり）',
      address: '大分県別府市鉄輪559-1',
      prefecture: '大分県',
      latitude: 33.3168,
      longitude: 131.4694,
      normalizedPosition: Offset(0.28, 0.75),
    ),
    PlaceCandidate(
      name: '軽井沢プリンスショッピングプラザ',
      address: '長野県北佐久郡軽井沢町軽井沢',
      prefecture: '長野県',
      latitude: 36.3401,
      longitude: 138.6345,
      normalizedPosition: Offset(0.58, 0.53),
    ),
    PlaceCandidate(
      name: '日光東照宮',
      address: '栃木県日光市山内2301',
      prefecture: '栃木県',
      latitude: 36.7581,
      longitude: 139.5989,
      normalizedPosition: Offset(0.66, 0.50),
    ),
    PlaceCandidate(
      name: '草津温泉 湯畑',
      address: '群馬県吾妻郡草津町草津401',
      prefecture: '群馬県',
      latitude: 36.6227,
      longitude: 138.5966,
      normalizedPosition: Offset(0.59, 0.52),
    ),
    PlaceCandidate(
      name: '熱海サンビーチ・熱海温泉',
      address: '静岡県熱海市東海岸町',
      prefecture: '静岡県',
      latitude: 35.0980,
      longitude: 139.0767,
      normalizedPosition: Offset(0.60, 0.65),
    ),
  ];

  /// 即時予測（ローカル辞書）のフィルタ：ジャンル名や都道府県名ではヒットさせず、店舗名・施設名のみで判定
  List<PlaceCandidate> filterImmediateCatalogByStoreName(String rawQuery) {
    final query = rawQuery.trim();
    if (query.isEmpty || isGenreOrRegionOnlyQuery(query)) {
      return const [];
    }

    final lower = query.toLowerCase();
    return catalogCandidates.where((c) {
      return c.name.toLowerCase().contains(lower);
    }).toList();
  }

  /// 入力されたクエリに対して予測候補を返す
  ///
  /// - ジャンル名（「カフェ」「ラーメン」「居酒屋」など）や都道府県名単体ではヒットさせない。
  /// - Google Places API (New / Text Search / Autocomplete) → Nominatim の順で全国の店舗・施設を検索する。
  Future<List<PlaceCandidate>> searchPredictions(String rawQuery) async {
    final query = rawQuery.trim();
    if (query.isEmpty || isGenreOrRegionOnlyQuery(query)) {
      return const [];
    }

    final List<PlaceCandidate> results = [];

    // 1. 内蔵カタログから店舗名（name）のみで部分一致検索（ジャンル・住所・都道府県ではヒットさせない）
    results.addAll(filterImmediateCatalogByStoreName(query));

    // 2. オンライン店舗名検索（Google Maps Places API 優先 → OpenStreetMap フォールバック）
    if (!disableNetworkInTests) {
      try {
        final remoteCandidates = await _fetchRemoteStorePredictions(query);
        for (final remote in remoteCandidates) {
          final duplicate = results.any(
            (r) =>
                r.name == remote.name &&
                (r.address == remote.address ||
                    r.prefecture == remote.prefecture),
          );
          if (!duplicate) {
            results.insert(0, remote);
          }
        }
      } catch (_) {
        // オフラインまたはテスト環境ではローカル予測候補のみを使用
      }
    }

    return results.take(12).toList();
  }

  /// ユーザーが候補をタップせずに自由入力のまま保存した場合でも、
  /// 入力文字列から都道府県・住所・座標を推定して返す
  PlaceCandidate resolveFromFreeText(String rawText) {
    final text = rawText.trim().isEmpty ? '思い出スポット' : rawText.trim();
    final lower = text.toLowerCase();

    // カタログに一致するものがあれば最優先
    for (final c in catalogCandidates) {
      if (c.name.toLowerCase().contains(lower) ||
          lower.contains(c.name.toLowerCase())) {
        return c;
      }
    }

    // 都道府県名・主要都市名が含まれていればその県に設定
    for (final entry in prefectureCenters.entries) {
      final pref = entry.key;
      final shortPref = pref
          .replaceAll('都', '')
          .replaceAll('府', '')
          .replaceAll('県', '');
      final baseAddr = entry.value.$3;
      final cityPart = baseAddr.substring(pref.length);

      if (text.contains(pref) ||
          text.contains(shortPref) ||
          (cityPart.isNotEmpty && text.contains(cityPart))) {
        final lat = entry.value.$1;
        final lng = entry.value.$2;
        return PlaceCandidate(
          name: text,
          address: text.startsWith(pref) ? text : '$baseAddr（$text）',
          prefecture: pref,
          latitude: lat,
          longitude: lng,
          normalizedPosition: PlaceCandidate.latLngToNormalizedOffset(lat, lng),
        );
      }
    }

    // 都道府県が含まれない店舗名単体の場合は、その店舗名自体をGoogleマップ検索リンク用の住所クエリとして保持する
    return PlaceCandidate(
      name: text,
      address: text,
      prefecture: '東京都',
      latitude: 35.6812,
      longitude: 139.7671,
      normalizedPosition: const Offset(0.66, 0.56),
    );
  }

  /// ネイティブ設定（Secrets.xcconfig / local.properties）または --dart-define から Google Maps API キーを取得する
  Future<String> _getGoogleMapsApiKey() async {
    if (_cachedGoogleMapsApiKey != null) {
      return _cachedGoogleMapsApiKey!;
    }

    const definedKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');
    if (definedKey.isNotEmpty) {
      _cachedGoogleMapsApiKey = definedKey;
      return definedKey;
    }

    try {
      final nativeKey = await _nativeChannel.invokeMethod<String>(
        'getGoogleMapsApiKey',
      );
      if (nativeKey != null &&
          nativeKey.trim().isNotEmpty &&
          !nativeKey.startsWith(r'$(')) {
        _cachedGoogleMapsApiKey = nativeKey.trim();
        return _cachedGoogleMapsApiKey!;
      }
    } catch (_) {}

    _cachedGoogleMapsApiKey = '';
    return '';
  }

  Future<List<PlaceCandidate>> _fetchRemoteStorePredictions(
    String query,
  ) async {
    final apiKey = await _getGoogleMapsApiKey();
    if (apiKey.isNotEmpty) {
      // 1. Google Places API (New) Text Search で店舗・施設名・座標・住所を一括取得
      final googleNewResults = await _fetchGooglePlacesNewTextSearch(
        query,
        apiKey,
      );
      if (googleNewResults.isNotEmpty) {
        return googleNewResults;
      }

      // 2. Google Places API (Legacy Text Search) フォールバック
      final googleLegacyResults = await _fetchGooglePlacesLegacyTextSearch(
        query,
        apiKey,
      );
      if (googleLegacyResults.isNotEmpty) {
        return googleLegacyResults;
      }
    }

    // 3. Google Places API が未有効化の場合のフォールバック（OpenStreetMap Nominatim 店舗・施設検索）
    return _fetchNominatimStorePlaces(query);
  }

  /// Google Places API (New): `https://places.googleapis.com/v1/places:searchText`
  Future<List<PlaceCandidate>> _fetchGooglePlacesNewTextSearch(
    String query,
    String apiKey,
  ) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(milliseconds: 2000);
    try {
      final uri = Uri.parse(
        'https://places.googleapis.com/v1/places:searchText',
      );
      final request = await client.postUrl(uri);
      request.headers.set('Content-Type', 'application/json');
      request.headers.set('X-Goog-Api-Key', apiKey);
      request.headers.set(
        'X-Goog-FieldMask',
        'places.id,places.displayName,places.formattedAddress,places.location,places.types',
      );
      request.add(
        utf8.encode(
          jsonEncode({
            'textQuery': query,
            'languageCode': 'ja',
            'regionCode': 'JP',
            'maxResultCount': 10,
          }),
        ),
      );

      final response = await request.close().timeout(
        const Duration(milliseconds: 2500),
      );
      if (response.statusCode != 200) return const [];

      final body = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) return const [];

      final places = decoded['places'] as List<dynamic>? ?? const [];
      final List<PlaceCandidate> candidates = [];

      for (final raw in places) {
        if (raw is! Map<String, dynamic>) continue;
        final types =
            (raw['types'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toSet() ??
            const <String>{};
        // 単なる行政区画（都道府県・市区町村のみ）の結果は店舗ではないため除外
        if (_isPureAdministrativeArea(types)) continue;

        final displayNameObj = raw['displayName'] as Map<String, dynamic>?;
        final name = (displayNameObj?['text'] as String?)?.trim() ?? '';
        if (name.isEmpty) continue;

        final location = raw['location'] as Map<String, dynamic>?;
        final lat = (location?['latitude'] as num?)?.toDouble();
        final lng = (location?['longitude'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;

        final rawAddress = (raw['formattedAddress'] as String?)?.trim() ?? '';
        final cleanedAddress = _cleanGoogleFormattedAddress(rawAddress);
        final pref = PlaceCandidate.extractPrefecture(
          cleanedAddress,
          lat: lat,
          lng: lng,
        );

        candidates.add(
          PlaceCandidate(
            name: name,
            address: cleanedAddress.isNotEmpty ? cleanedAddress : name,
            prefecture: pref,
            latitude: lat,
            longitude: lng,
            normalizedPosition: PlaceCandidate.latLngToNormalizedOffset(
              lat,
              lng,
            ),
            placeId: raw['id'] as String?,
          ),
        );
      }

      return candidates;
    } catch (_) {
      return const [];
    } finally {
      client.close(force: true);
    }
  }

  /// Google Places API (Legacy): `https://maps.googleapis.com/maps/api/place/textsearch/json`
  Future<List<PlaceCandidate>> _fetchGooglePlacesLegacyTextSearch(
    String query,
    String apiKey,
  ) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(milliseconds: 2000);
    try {
      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/textsearch/json',
        {'query': query, 'language': 'ja', 'region': 'jp', 'key': apiKey},
      );
      final request = await client.getUrl(uri);
      final response = await request.close().timeout(
        const Duration(milliseconds: 2500),
      );
      if (response.statusCode != 200) return const [];

      final body = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) return const [];
      if (decoded['status'] != 'OK') return const [];

      final results = decoded['results'] as List<dynamic>? ?? const [];
      final List<PlaceCandidate> candidates = [];

      for (final raw in results) {
        if (raw is! Map<String, dynamic>) continue;
        final types =
            (raw['types'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toSet() ??
            const <String>{};
        if (_isPureAdministrativeArea(types)) continue;

        final name = (raw['name'] as String?)?.trim() ?? '';
        if (name.isEmpty) continue;

        final geometry = raw['geometry'] as Map<String, dynamic>?;
        final location = geometry?['location'] as Map<String, dynamic>?;
        final lat = (location?['lat'] as num?)?.toDouble();
        final lng = (location?['lng'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;

        final rawAddress = (raw['formatted_address'] as String?)?.trim() ?? '';
        final cleanedAddress = _cleanGoogleFormattedAddress(rawAddress);
        final pref = PlaceCandidate.extractPrefecture(
          cleanedAddress,
          lat: lat,
          lng: lng,
        );

        candidates.add(
          PlaceCandidate(
            name: name,
            address: cleanedAddress.isNotEmpty ? cleanedAddress : name,
            prefecture: pref,
            latitude: lat,
            longitude: lng,
            normalizedPosition: PlaceCandidate.latLngToNormalizedOffset(
              lat,
              lng,
            ),
            placeId: raw['place_id'] as String?,
          ),
        );
      }

      return candidates;
    } catch (_) {
      return const [];
    } finally {
      client.close(force: true);
    }
  }

  bool _isPureAdministrativeArea(Set<String> types) {
    if (types.isEmpty) return false;
    if (types.contains('establishment') ||
        types.contains('point_of_interest') ||
        types.contains('food') ||
        types.contains('restaurant') ||
        types.contains('cafe') ||
        types.contains('store')) {
      return false;
    }
    return types.contains('administrative_area_level_1') ||
        types.contains('administrative_area_level_2') ||
        types.contains('locality') ||
        types.contains('postal_code') ||
        types.contains('country');
  }

  String _cleanGoogleFormattedAddress(String rawAddress) {
    return rawAddress
        .replaceFirst(RegExp(r'^日本[、,\s]*'), '')
        .replaceFirst(RegExp(r'^〒\s*\d{3}[-ー]\d{4}\s*'), '')
        .trim();
  }

  Future<List<PlaceCandidate>> _fetchNominatimStorePlaces(String query) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(milliseconds: 1800);
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': query,
        'format': 'jsonv2',
        'addressdetails': '1',
        'limit': '8',
        'countrycodes': 'jp',
        'accept-language': 'ja',
      });
      final request = await client.getUrl(uri);
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'MyMapAppDevFest/1.0 (Flutter)',
      );
      final response = await request.close().timeout(
        const Duration(milliseconds: 2200),
      );
      if (response.statusCode != 200) return const [];

      final body = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(body);
      if (decoded is! List) return const [];

      final List<PlaceCandidate> list = [];
      for (final item in decoded) {
        if (item is! Map<String, dynamic>) continue;
        final category = (item['category'] as String?) ?? '';
        // 行政境界（都道府県・市区町村そのもの）は店舗検索から除外
        if (category == 'boundary' || category == 'place') continue;

        final lat = double.tryParse('${item['lat'] ?? ''}');
        final lon = double.tryParse('${item['lon'] ?? ''}');
        if (lat == null || lon == null) continue;

        final displayName = item['display_name'] as String? ?? '';
        final rawName = (item['name'] as String?)?.trim();
        if (rawName == null || rawName.isEmpty) continue;

        final addressMap = item['address'] as Map<String, dynamic>? ?? const {};

        final pref = PlaceCandidate.extractPrefecture(
          '${addressMap['province'] ?? ''}${addressMap['state'] ?? ''}$displayName',
          lat: lat,
          lng: lon,
        );

        final formattedAddress = _formatJapaneseAddress(
          addressMap,
          displayName,
          pref,
        );

        list.add(
          PlaceCandidate(
            name: rawName,
            address: formattedAddress,
            prefecture: pref,
            latitude: lat,
            longitude: lon,
            normalizedPosition: PlaceCandidate.latLngToNormalizedOffset(
              lat,
              lon,
            ),
          ),
        );
      }
      return list;
    } finally {
      client.close(force: true);
    }
  }

  String _formatJapaneseAddress(
    Map<String, dynamic> addr,
    String displayName,
    String prefecture,
  ) {
    final city =
        (addr['city'] ??
                addr['ward'] ??
                addr['town'] ??
                addr['village'] ??
                addr['county'] ??
                '')
            .toString();
    final suburb =
        (addr['suburb'] ??
                addr['quarter'] ??
                addr['neighbourhood'] ??
                addr['road'] ??
                '')
            .toString();
    final houseNumber = (addr['house_number'] ?? '').toString();

    final combined = '$prefecture$city$suburb$houseNumber'.trim();
    if (combined.length > prefecture.length) {
      return combined;
    }
    return displayName.isNotEmpty ? displayName : prefecture;
  }
}
