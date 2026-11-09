# 変更ログ：思い出詳細の下部写真3列グリッド化・説明文削除・レビュー間余白（8の倍数）調整・Google Mapsアプリ起動連携

## 1. 変更日時・作業ブランチ
- **変更日時**：2026-11-07 23:21
- **作業ブランチ**：`ui/top-screen`

## 2. 背景・目的（Background）
- 思い出詳細画面の最下部にある写真一覧を3列のグリッド表示にまとめ、写真の説明文やラベルを表示しないシンプルなUIにするため。
- レビューとレビューの境目をわかりやすくするため、基本余白を8の倍数（`8`, `16`, `24`, `32`）で統一し、レビュー間の余白を `32px` に広げるため。
- レビュー右端の「`↗`」ボタンをタップした際、そのスポットに登録されている住所（`pin.address`）で実際の Google Maps アプリ（またはブラウザ版 Google Maps）を起動するため。

## 3. 変更内容と対象ファイル（Changes）
- **新規作成**
  - `lib/core/services/external_map_launcher.dart`：登録住所（`address`）をクエリとして MethodChannel（`com.devfest.mymap/external_launcher`）経由でネイティブの Google Maps アプリを起動するサービスを作成。
- **変更**
  - `lib/screens/memories/memory_detail_screen.dart`
    - 下部写真セクションを `SliverGrid`（`crossAxisCount: 3`, `mainAxisSpacing: 8`, `crossAxisSpacing: 8`）に変更し、`showCaptionOverlay: false` / `showPlaceholderLabel: false` で説明文・ラベルを非表示化。
    - レビュー間の下余白を `32px`（8×4）に設定し、画面全体の余白を8の倍数（`8`, `16`, `24`, `32`）に統一。
    - レビュー右端の「`↗`」ボタン押下時に `ExternalMapLauncher.openGoogleMapsForAddress` を呼び出すよう変更。
  - `lib/screens/memories/memories_list_screen.dart`、`lib/screens/map/header_menu/header_menu_overlay.dart`
    - 余白・サイズを8の倍数に統一。
  - `android/app/src/main/kotlin/com/devfest/mymap/my_map_app/MainActivity.kt`、`android/app/src/main/AndroidManifest.xml`
    - `geo:0,0?q=<登録住所>` で `com.google.android.apps.maps`（Google Mapsアプリ）を起動し、未インストール時はユニバーサルURLを開くネイティブ処理と `<queries>` 定義を追加。
  - `ios/Runner/AppDelegate.swift`、`ios/Runner/Info.plist`
    - `comgooglemaps://?q=<登録住所>` スキームで Google Maps アプリを起動し、未インストール時はユニバーサルURLを開くネイティブ処理と `LSApplicationQueriesSchemes` を追加。
  - `test/widget_test.dart`
    - 3列グリッド（`SliverGrid`）表示・説明文非表示・登録住所での Google Maps 起動要求のアサーションを追加。

## 4. 変更理由・設計判断（Why）
- 外部パッケージ（`url_launcher` 等）を新規追加せずに iOS / Android 両対応で確実に Google Maps アプリを起動できるよう、Flutter 標準の `MethodChannel` と各OS標準の Intent / URL Scheme（`geo:` / `comgooglemaps://` ＋ `https://www.google.com/maps/search/?api=1&query=` フォールバック）を採用した。
- レビュー内のテキストと横スクロール写真の間は `8px`、次のレビューとの間は `32px` と明確な差（1:4の比率、ともに8の倍数）をつけることで、どの写真がどのレビューに属するかの視覚的グルーピングを明確にした。

## 5. 検証結果・影響範囲（Verification & Impact）
- `dart format`、`flutter analyze`、`flutter test` を実行して検証。
- マップ画面や記録機能、グループ機能への副作用はない。

