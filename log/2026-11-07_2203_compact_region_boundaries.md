# 行政区域境界データの軽量化

## 変更日時・作業ブランチ

- 変更日時: 2026-11-07 22:03 (JST)
- 作業ブランチ: `ui/top-screen`

## Background

都道府県・市区町村の元GeoJSONは合計約16.9MBあり、アプリ容量と初回JSON解析負荷が大きかった。輪郭の見た目を維持しながら、アプリに必要な情報だけを同梱する必要があった。

## Changes

- `tool/compact_boundaries.mjs`
  - GeoJSONから外周と地域名だけを抽出する生成スクリプトを追加。
  - Douglas-Peucker法による頂点簡略化と座標の整数量子化を実装。
  - 市区町村データを都道府県単位へ分割。
- `assets/boundaries/compact/`
  - アプリ用の都道府県境界、市区町村境界、都道府県別マニフェストを生成。
- `assets/boundaries/README.md`
  - 軽量化条件、容量、再生成方法を追記。
- `lib/screens/map/map_canvas/region_boundary_repository.dart`
  - コンパクト形式を読み込むよう変更。
  - 市区町村は必要な都道府県ファイルだけを読み込むよう変更。
- `lib/screens/map/map_canvas/region_photo_overlay.dart`
  - 市区町村名と都道府県名をリポジトリへ渡すよう変更。
- `pubspec.yaml`
  - 元GeoJSONではなく `compact/` のみをFlutterアセットへ登録。
- 元GeoJSON
  - アプリおよびリポジトリから削除。

## Why

単純なファイル分割だけでは総容量が減らず、強すぎる座標間引きは輪郭を再び粗くする。都道府県表示は低倍率、市区町村表示は中倍率という利用条件に合わせ、都道府県は約300m、市区町村は約50mを簡略化基準とした。座標は小数点以下5桁相当の整数へ変換し、不要なGeoJSON属性と構造を除去した。市区町村は都道府県別に分割することで、総容量だけでなく実行時の読み込み・解析量も削減した。

## Verification & Impact

- 容量: 16,909,373 bytes → 2,862,091 bytes（83.1%削減）。
- 主要地域（江東区、渋谷区、鎌倉市、箱根町、京都市、札幌市）の存在とポリゴン取得を確認。
- `dart format`: 成功。
- `flutter analyze`: 成功（No issues found）。
- `flutter test test/group_invite_test.dart`: 成功。
- `git diff --check`: 成功。
- 写真、ズーム、ピン、地域タップの仕様変更なし。
- 実機での輪郭品質確認は未実施。
