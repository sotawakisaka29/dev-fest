# 変更ログ: アイデアシートに基づくアプリケーション全体の大枠（画面別・機能別構成）の作成

## 1. 変更日時・作業ブランチ
- **日時**: 2026-11-05 20:08
- **作業ブランチ**: `feature/app-scaffold`

## 2. 背景・目的（Background）
- アイデアシート（「DevFest GDGoC Japan 2026 Mock」）および `AGENTS.md` で定義されたMVP必須6機能（①Google Maps表示、②写真・思い出・レビューの保存、③ユーザー認証、④グループ機能、⑤シェア機能、⑥都道府県の形に沿った写真プレビュー）に基づき、アプリケーション全体の大枠（UI骨格・画面遷移・ディレクトリ構造）を構築する。
- ユーザー指示に基づき、「画面ごとにディレクトリを分け、その中で機能ごとにディレクトリを分ける」構成を採用し、灰・白を基調としたデザインで外部APIキー未設定段階でもインタラクティブに動作確認できるようにする。

## 3. 変更内容と対象ファイル（Changes）
- **更新**:
  - `lib/main.dart`: `MyMapApp` エントリーポイント、灰・白テーマ（`AppTheme.lightTheme`）適用、メイン画面（`MapScreen`）の設定
  - `test/widget_test.dart`: メイン画面の表示、「旅行スタート」⇔「記録（予定追加）」切替、記録画面への遷移・保存動作を検証するウィジェットテストに更新
- **新規作成**:
  - `lib/core/theme/app_theme.dart`: アイデアシート指定の「灰・白」を基調とした共通カラー・テーマ定義
  - `lib/core/models/memory_pin.dart`: 訪問地点・レビュー・口コミ・写真・ルート通過点（黒丸）を表現するモデルと初期サンプルデータ
  - `lib/core/models/team_group.dart`: グループ（チーム）単位の共有モデルとサンプルデータ
  - `lib/screens/auth/login/login_screen.dart`: ユーザー認証・アカウント切替画面の骨格（MVP機能③）
  - `lib/screens/map/map_screen.dart`: メイン画面の統合コンテナ
  - `lib/screens/map/header_menu/header_menu_overlay.dart`: 地図操作中は非表示になり、触っていない間だけ表示される上部オーバーレイメニュー
  - `lib/screens/map/header_menu/team_selector/team_selector_dropdown.dart`: チーム名プルダウン切替・新規グループ作成（MVP機能④）
  - `lib/screens/map/header_menu/trip_action/trip_action_button.dart`: 「旅行スタート」⇔「記録（予定追加）」切替ボタン
  - `lib/screens/map/header_menu/invite/invite_button.dart`: 「招待する」ボタン＆招待リンク発行シート（MVP機能④）
  - `lib/screens/map/header_menu/share/share_button.dart`: 「共有する」ボタン＆公開範囲制御シート（MVP機能⑤）
  - `lib/screens/map/map_canvas/interactive_map_canvas.dart`: 日本列島シルエット・ルート線・赤ピン・通過点黒丸・吹き出しを描画するインタラクティブマップ枠（MVP機能①）
  - `lib/screens/map/pin_callout/pin_callout_card.dart`: ピン選択時の吹き出しカード（星5段階、口コミ、写真、`詳細→`）
  - `lib/screens/map/pin_callout/pin_detail_sheet.dart`: `詳細→` タップ時に下から開く記録詳細ボトムシート
  - `lib/screens/map/prefecture_preview/prefecture_photo_preview.dart`: 都道府県の形に沿った写真プレビュー表示（MVP機能⑥）
  - `lib/screens/record/record_screen.dart`: 記録作成・保存画面の統合コンテナ（MVP機能②）
  - `lib/screens/record/location_input/location_input_section.dart`: 位置共有ON/OFF切替、店名・スポット候補検索と住所自動読込枠
  - `lib/screens/record/time_range/time_range_section.dart`: 時間範囲指定（`00:00 ~ 00:00`）セクション
  - `lib/screens/record/review_input/review_input_section.dart`: 5段階の星評価（`☆☆☆☆☆`）と口コミ入力欄
  - `lib/screens/record/photo_picker/photo_picker_section.dart`: 写真一覧・追加・右上「×」ボタンによる削除セクション

## 4. 変更理由・設計判断（Why）
- **画面別 ＞ 機能別の2階層ディレクトリ構成**:
  - `lib/screens/<画面>/<機能>/` とすることで、2人での並行開発時にどの画面のどの機能を編集しているかが直感的に分かり、Gitコンフリクトを最小化できるようにした。
- **外部パッケージ追加なしの標準実装による骨格構築**:
  - 5日間ハッカソンの初期段階として、まずはFlutter標準の `StatefulWidget` 等のみで全画面のUIギミック（地図操作時のヘッダー自動非表示、「旅行スタート」⇔「記録」切替、ピン吹き出しと詳細ボトムシート、記録追加）が即座に動作する状態を実現した。
- **Google Maps / Firebase の差し替え境界の明確化**:
  - `InteractiveMapCanvas` や `LocationInputSection`（スポット候補検索）、`LoginScreen` など、後続フェーズで実API・SDKへ差し替える箇所を独立した機能ディレクトリとして分離した。

## 5. 検証結果・影響範囲（Verification & Impact）
- **コードフォーマット**: `dart format --output=none --set-exit-if-changed .` を実行し、フォーマット差分なし。
- **静的解析**: `dart analyze` を実行し、警告・エラーなし（`No issues found!`）。
- **ウィジェットテスト**: `flutter test` を実行し、メイン画面表示・旅行開始切替・記録画面遷移・保存テストがすべて通過（`All tests passed!`）。
- **他機能への影響**: 初期テンプレートのカウンター画面を置き換える変更であり、既存設定（Android/iOS設定、`.gitignore` 等）への悪影響なし。
