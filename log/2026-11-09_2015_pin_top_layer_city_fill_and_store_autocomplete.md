# 2026-11-09 20:15 ピン表示ボタン時の最前面ピン・レビュー吹き出し表示、市町村塗りの復活、店舗名検索特化＆Google Places API連携

## 1. 変更日時・作業ブランチ
- **変更日時**：2026-11-09 20:15 (JST)
- **作業ブランチ**：`feature/trip-log`

## 2. 背景・目的（Background）
1. **ピン表示ボタン押下時のレビュー表示・ピンの最前面（塗りの上）表示**：
   - ピン表示ボタン（`_forcePinOnlyMode`）を押下した際、地図の塗り（`RegionPhotoOverlay`）よりも下にピンが隠れたり、ピンをタップしてもレビュー吹き出し（`PinCalloutCard`）が出なかったりする問題を解消する。
   - ピンの表示階層を地図の塗り（都道府県・市町村シルエット）よりも一番上（最前面）にする。
2. **市町村の塗りの復活**：
   - 中倍率以降で県のみしか表示されなくなっていた原因（政令指定都市の区名表記「京都市右京区」「札幌市中央区」等と `municipalities.json` のキー「京都市」「札幌市」の不一致、および自由入力スポットの市区町村名未抽出）を解消し、市町村の塗りを復活させる。
3. **場所入力欄の予測変換を「店舗名・施設名検索」に特化（ジャンル名ヒットの除外）＆ Google Maps Places API 連携**：
   - ジャンル名（「カフェ」「ラーメン」「美術館」など）や都道府県名単体では予測候補がヒットしないようにし、あくまで具体的な店舗名・施設名のみで検索できるようにする。
   - ご飯屋さん（飲食店・レストラン・カフェ等）のバリエーションを大幅に増やし、Google Maps の検索でヒットする店舗がすべて予測に出るよう Google Places API (New / Text Search) 連携を実装する。

## 3. 変更内容と対象ファイル（Changes）
- `lib/screens/map/map_canvas/interactive_map_canvas.dart`
  - `_isPinVisibleMode`（`_isDetailPinMode || _forcePinOnlyMode`）を導入し、ピン表示ボタンON時にもピンタップで `PinCalloutCard`（レビュー吹き出し）および詳細シートが表示されるよう修正。
  - `RegionPhotoOverlay`（県・市町村の塗り）よりも上層の Stack 最前面に `_buildTopLayerPinWidgets` を配置し、塗りの上からでもピンが視認・タップできるように改善。
  - 中倍率（市町村モード）への切り替え閾値を調整し、ズームイン時にも市町村の塗りが消えずピンの下層に維持されるよう修正。
- `lib/screens/map/map_canvas/region_photo_overlay.dart`
  - `ClipPath` の内側に `GestureDetector` を配置し、ポリゴンの外側の透明矩形が背後のタップを奪わないように改善。
  - `RegionBoundaryRepository.loadMunicipalities` へ各ピンの住所・座標フォールバック情報を渡すよう更新。
- `lib/screens/map/map_canvas/region_boundary_repository.dart`
  - 市区町村ポリゴン検索時に、完全一致だけでなく政令指定都市の親市名（`京都市右京区` → `京都市`）、郡名除去（`足柄下郡箱根町` → `箱根町`）、住所部分一致、および座標（Point-in-Polygon / 最近傍探索）による特定を追加し、すべてのピンで確実に市町村の塗りが表示されるよう改善。
- `lib/core/models/memory_pin.dart`
  - `city` ゲッターを改善し、郵便番号・国名プレフィックスの除去、政令指定都市の市名抽出、郡部の町村名抽出を強化。
- `lib/core/services/place_autocomplete_service.dart`
  - `isGenreOrRegionOnlyQuery` および `filterImmediateCatalogByStoreName` を実装し、ジャンル名・カテゴリ名・都道府県名単体でのヒットを排除。
  - Google Places API (New: `places:searchText` / Legacy Text Search) クライアントを実装し、ネイティブ設定済みの `GOOGLE_MAPS_API_KEY` を用いて Google マップ上の全店舗・飲食店を検索可能に改修。
  - 実在する全国の飲食店（ご飯屋さん・ラーメン・焼肉・寿司・定食・カフェ等）の内蔵店舗カタログを拡充。
- `lib/screens/record/location_input/location_input_section.dart`
  - 入力時の即時予測フィルタから `category`・`prefecture`・`address` 一致を廃止し、店舗名（`filterImmediateCatalogByStoreName`）のみに統一。
- `ios/Runner/AppDelegate.swift` / `android/app/src/main/kotlin/com/devfest/mymap/my_map_app/MainActivity.kt`
  - 既存の `Info.plist` / `AndroidManifest.xml` に注入済みの `GOOGLE_MAPS_API_KEY` を Dart 側へ安全に返す `getGoogleMapsApiKey` メソッドを追加（APIキーのハードコードなし）。
- `test/widget_test.dart`
  - ピン表示ボタンON時の最前面ピンタップでレビュー吹き出しが表示されるテスト、ジャンル名でヒットせずご飯屋さん店舗名でヒットするテスト、市町村名抽出テストを追加。

## 4. 変更理由・設計判断（Why）
- **最前面ピンレイヤーの採用**：Google Maps ネイティブの `Marker` は PlatformView 内部に描画されるため、Flutter 側の `RegionPhotoOverlay`（県・市町村の塗り）より必ず下の階層になってしまう。そのため、塗りの上（Stack の上位階層）に Web Mercator 同期投影による最前面ピンウィジェットを配置し、「塗りの一番上にピンが表示され、タップで確実にレビューが出る」体験を実現した。
- **市町村境界の多段マッチング**：住所表記の揺れ（政令指定都市の区名や番地のみ・店舗名のみ）があっても市町村の塗りが欠落しないよう、名称正規化＋住所照合＋緯度経度ポリゴン判定の多段解決を採用した。
- **APIキー管理の安全性維持**：`AGENTS.md` 8.2 に準拠し、ソースコードにAPIキーをハードコードせず、既存の `Secrets.xcconfig` / `local.properties` からネイティブ経由で取得する設計とした。

## 5. 検証結果・影響範囲（Verification & Impact）
- `dart format lib test`：フォーマット完了。
- `flutter analyze`：静的解析エラー・警告なし（No issues found）。
- `flutter test`：全6テストパス。
