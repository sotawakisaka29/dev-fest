# 変更ログ: Google Maps（google_maps_flutter）による地図・ピン・ルート表示機能の実装

## 1. 変更日時・作業ブランチ
- **日時**: 2026-11-05 21:16
- **作業ブランチ**: `feature/map`

## 2. 背景・目的（Background）
- MVP必須機能①「Google Mapsによる訪問地点の表示」を実現するため、確定技術スタックである Google Maps SDK（Flutter公式プラグイン `google_maps_flutter`）を導入する。
- 訪問地点の赤ピン（Marker）、移動軌跡のルート線（Polyline）、レビューなし通過点の黒丸（Circle）、選択時の吹き出しカード（`PinCalloutCard`）、および地図操作時の上部メニュー自動非表示を Google Maps 上で連携動作させる。
- `AGENTS.md` 8.2（APIキー・認証情報の管理）に基づき、APIキーをソースコードにハードコードせず、Git管理外のローカル設定ファイル（`android/local.properties` / `ios/Flutter/Secrets.xcconfig`）から注入する構成とする。

## 3. 変更内容と対象ファイル（Changes）
- **更新**:
  - `pubspec.yaml`, `pubspec.lock`: `google_maps_flutter` の追加
  - `lib/core/models/memory_pin.dart`: 実座標フィールド（`latitude`, `longitude`, `latLng` ゲッター）の追加と初期サンプルピンの実座標設定
  - `lib/screens/record/location_input/location_input_section.dart`: `PlaceCandidate` に実座標（`latitude`, `longitude`）を追加
  - `lib/screens/record/record_screen.dart`: 記録保存時に選択スポットの緯度・経度を `MemoryPin` に保存するよう更新
  - `lib/screens/map/map_canvas/interactive_map_canvas.dart`: `GoogleMap` ウィジェットの導入、灰・白トーンのカスタムマップスタイル適用、`Marker` / `Polyline` / `Circle` の構築、カメラ移動制御（選択ピンへのフォーカス・全体表示）、およびAPIキー未設定環境向けの簡易地図切替フォールバックの実装
  - `android/app/build.gradle.kts`, `android/app/src/main/AndroidManifest.xml`: `local.properties` の `GOOGLE_MAPS_API_KEY` を `manifestPlaceholders` 経由で `com.google.android.geo.API_KEY` に注入する設定を追加
  - `ios/Flutter/Debug.xcconfig`, `ios/Flutter/Release.xcconfig`, `ios/Runner/Info.plist`, `ios/Runner/AppDelegate.swift`: `Secrets.xcconfig` の任意読み込み（`#include?`）と、`GMSApiKey` 設定時のみ `GMSServices.provideAPIKey` を初期化するクラッシュ防止ガード付き実装
  - `test/widget_test.dart`: `GoogleMap` ウィジェットの描画・Marker/Polyline/Circle生成・新規記録保存後のMarker増加を確認するテストを追加

## 4. 変更理由・設計判断（Why）
- **`google_maps_flutter` の採用**:
  - Flutter公式プラグインであり、iOS/AndroidネイティブのGoogle Maps SDKを利用してマーカー・ポリライン・カメラ制御・カスタムスタイルを安定して実装できるため。
- **APIキーの安全な外部注入と未設定時のクラッシュ防止**:
  - ハードコードやコミット事故を防ぎつつ、2人開発でAPIキー未設定の端末でもiOS起動時クラッシュ（空キーによる `GMSServices` 例外）が起きないようガード処理と簡易地図切替を用意した。

## 5. 検証結果・影響範囲（Verification & Impact）
- **コードフォーマット**: `dart format --output=none --set-exit-if-changed .` にて差分なしを確認。
- **静的解析**: `flutter analyze` にてエラー・警告なしを確認。
- **ウィジェットテスト**: `flutter test` にて `GoogleMap` のマーカー・ルート描画および記録追加連携テストがパスすることを確認。
- **他機能への影響**: 都道府県シルエット写真プレビュー（`PrefecturePhotoPreview`）や上部メニュー・記録画面の既存動作を維持したまま、実Google Maps表示へ拡張。
