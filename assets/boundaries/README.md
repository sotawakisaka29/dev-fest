# 日本の行政区域データ

このディレクトリのJSONは、国土交通省の2026年版「国土数値情報（行政区域データ）」をアプリ表示用に加工・軽量化したデータです。

- 出典: 「国土数値情報（行政区域データ）」（国土交通省）
- 原典: https://nlftp.mlit.go.jp/ksj/gml/datalist/KsjTmplt-N03-2026.html
- 加工データ: https://geo.maderaojen.me/
- ライセンス: CC BY 4.0相当（国土数値情報利用約款）
- リリース: `2026-08-04.1`

## アプリ同梱データ

`compact/` のみをFlutterアセットとして同梱します。

- 緯度経度を小数点以下5桁の整数へ量子化
- 都道府県境界は約300m、市区町村境界は約50mを基準に頂点を簡略化
- 市区町村境界は都道府県別に分割し、必要な地域だけ読み込み
- 元データ約16.9MBから約2.9MBへ削減

## 再生成

元GeoJSONを `assets/boundaries/source/` に配置し、次を実行します。

```powershell
node tool/compact_boundaries.mjs
```

元GeoJSONはアプリおよびリポジトリには同梱しません。
