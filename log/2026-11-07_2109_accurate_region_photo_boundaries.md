# 行政区域に沿った写真プレビューへの変更

## 変更日時・作業ブランチ

- 変更日時: 2026-11-07 21:09 (JST)
- 作業ブランチ: `ui/top-screen`

## Background

県・市の写真プレビューがGoogle Maps上の行政境界と一致せず、輪郭も粗く見える問題があった。従来実装は一部地域だけの手書き座標と、未定義地域向けの架空ポリゴンを使用していた。また、写真の切り替え間隔を5秒に変更する要望があった。

## Changes

- `assets/boundaries/jp_prefectures.geojson`
  - 国土数値情報を加工した2026年版の都道府県境界を追加。
- `assets/boundaries/jp_municipalities.geojson`
  - 国土数値情報を加工した2026年版の市区町村境界を追加。
- `assets/boundaries/README.md`
  - データの出典、加工元、ライセンスを記録。
- `pubspec.yaml`
  - 行政区域GeoJSONをFlutterアセットへ登録。
- `lib/screens/map/map_canvas/region_boundary_repository.dart`
  - 必要な行政区域だけを別Isolateで解析する境界リポジトリを追加。
  - 都道府県、市区町村、政令指定都市の行政区、複数島を扱えるようにした。
- `lib/screens/map/map_canvas/region_photo_overlay.dart`
  - 手書き輪郭を公的データ由来の輪郭へ置換。
  - 画面上の最小サイズ補正を廃止し、地図との位置ずれを解消。
  - マルチポリゴンの切り抜き・境界線描画へ対応。
  - 写真のランダム切り替えを2秒から5秒へ変更。
- `lib/screens/map/map_canvas/japan_region_polygons.dart`
  - 不正確な手書き座標と架空フォールバックを含むため削除。

## Why

Google Maps SDKはクライアントへ都道府県・市区町村の境界座標を提供しない。そのため、国土交通省「国土数値情報（行政区域データ）」を加工したCC BY 4.0相当のGeoJSONをローカルアセットとして採用した。外部API方式と比べて通信障害や従量課金に依存せず、MVPで安定して表示できる。約17MBのJSON解析によるUI停止を避けるため、解析は別Isolateで行い、現在表示に必要な地域だけを変換・保持する。

## Verification & Impact

- `dart format`: 成功。
- `flutter analyze`: 成功（No issues found）。
- `flutter test`: 既存の `memory_detail_screen.dart:518` にある4.2pxのRenderFlex overflowで失敗。今回変更した地図境界処理に起因する解析・コンパイルエラーはなし。
- ズーム段階、ピン表示、思い出画面への遷移ロジックは変更していない。
- 実機でのGoogle Mapsとの視覚的な重なり確認は未実施。
