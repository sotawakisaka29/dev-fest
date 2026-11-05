# 変更ログ: 実機起動フリーズ防止のためのFirebase初期化タイムアウト設定

## 1. 変更日時・作業ブランチ
- **日時**: 2026-11-05 23:56
- **作業ブランチ**: `feature/login`

## 2. 背景・目的（Background）
- 実機（iOS）において、Firebaseネイティブライブラリが未ロードの際、`Firebase.initializeApp()` がネイティブチャネルからの応答を無期限に待機し、アプリ起動時のスプラッシュ画面のままフリーズする現象を解決する。

## 3. 変更内容と対象ファイル（Changes）
- **更新**:
  - `lib/main.dart`: `Firebase.initializeApp()` に3秒のタイムアウト（`.timeout(const Duration(seconds: 3))`）を設定し、ネイティブ未準備や遅延時でもタイムアウトして安全にアプリUI（`runApp`）を起動するように修正。
  - `analysis_options.yaml`: `build/**` および `.dart_tool/**` を静的解析の対象外に追加。

## 4. 変更理由・設計判断（Why）
- 実機起動時に万一Firebaseの接続やネイティブ側初期化が完了しなくても、アプリが白い画面で停止するのを完全に防ぎ、オフラインやローカルフォールバックモードで画面（マップ・グループ機能UI）が立ち上がるフェイルセーフを構築するため。

## 5. 検証結果・影響範囲（Verification & Impact）
- `flutter analyze` による静的解析: `No issues found!`（警告・エラーゼロ）。
- `flutter test` によるテスト: 全4テストがすべて通過（`All tests passed!`）。
