# 写真データの端末永続化（Documents領域保存）およびiOS再起動・UUID変化耐性対応

## 1. 変更日時・作業ブランチ
- **変更日時**: 2026-11-09 20:56 (JST)
- **作業ブランチ**: `fix/db`

## 2. 背景・目的（Background）
Googleフォトから取得した写真について、アプリを再起動した際にデータベース（Firestore）から写真自体を読み込んで表示できていない問題が発生していた。
調査の結果、以下の複合要因が判明した：
1. **一時領域保存によるファイル消失**: Googleフォト写真がOSの一時ディレクトリ（`Directory.systemTemp`）に保存されていたため、アプリ再起動やOSのメモリクリーンアップによって実体ファイルが消去されていた。
2. **iOSサンドボックスUUIDの再起動変化**: iOSではアプリ再起動ごとにコンテナパスのUUIDが変わるため、データベースに保存された前回の絶対パス（`localPath`）が無効化し、`File.existsSync()` が必ず `false` になっていた。
3. **Google Photos Picker API の一時URL仕様**: Googleフォトの `baseUrl` は OAuth Bearer 認証ヘッダーが必須かつ有効期限が約60分の一時URLであるため、素のHTTP GETを行う `Image.network` では 401/403 エラーとなり画像を表示できなかった。

これらを解消し、**アプリを再起動しても端末永続領域から写真実体を即座に発見・解決し、いつでも高画質に写真を表示できる仕組み** を構築した。

## 3. 変更内容と対象ファイル（Changes）

### ① パッケージの追加
- **`pubspec.yaml`**
  - Flutter公式推奨の永続ディレクトリ取得パッケージ `path_provider: ^2.1.5` を追加。

### ② 写真永続化サービスの作成
- **`lib/core/services/photo_storage_service.dart` (新規)**
  - `getPhotosDirectory()`: アプリ専用の永続ドキュメント領域（`{Documents}/app_photos`）を取得・作成。
  - `savePhotoBytes()`: 写真バイトデータを永続ディレクトリに安全に書き込み、パスを返却。
  - `resolveLocalFile()`: iOS再起動等で旧UUIDパスが渡された場合でも、ファイル名を抽出して現在の永続ディレクトリから実体ファイルを特定・復元する動的解決機構を実装。

### ③ Googleフォト写真の永続保存対応
- **`lib/core/services/google_photos_service.dart`**
  - `downloadPhotoToTempFile()` 内で `PhotoStorageService.instance.savePhotoBytes` を呼び出し、Googleフォト写真を一時領域ではなく永続ディレクトリに保存するように修正。
  - 重複したnullチェックを削除。

### ④ モデル・表示ウィジェットの動的パス解決対応
- **`lib/core/models/app_photo.dart`**
  - `localFile` ゲッターおよび `hasLocalFile` ゲッターを追加し、`PhotoStorageService.instance.resolveLocalFile` を通じてiOS再起動後も実体 `File` を即座に解決可能にした。
- **`lib/core/services/storage_service.dart`**
  - Cloud Storage へのアップロード時も `photo.localFile` から解決された実体ファイルを対象とし、有効なパスと永続URLを更新。
- **`lib/screens/memories/memory_detail_screen.dart`**
- **`lib/screens/map/map_canvas/region_photo_overlay.dart`**
- **`lib/screens/record/photo_picker/photo_picker_section.dart`**
  - 単純な `File(localPath).existsSync()` ではなく `photo.localFile` による解決ファイルを用いて `Image.file` を描画するように統一。

### ⑤ 単体テスト・既存テストの整備
- **`test/photo_storage_service_test.dart` (新規)**
  - 写真データの保存、直接パス解決、旧UUIDからの動的ファイル名解決、存在しないパスのフォールバックを網羅的に検証。
- **`test/widget_test.dart` / `lib/core/services/trip_service.dart` / `lib/core/services/auth_service.dart`**
  - テスト環境でのサインアウト・リセット処理およびサンプルデータ初期化の整合性を保ち、全29テストを完走（PASS）。

## 4. 変更理由・設計判断（Why）
- **ファイル名ベースの動的解決の採用**:
  iOSのサンドボックス構造上、絶対パスをそのまま永続化すると再起動で必ずパス切れが発生する。ファイル名をキーにして現在の `app_photos` ディレクトリを探索する仕組みにすることで、過去に保存された既存のFirestoreデータもコード変更なしで自動的に復元・表示できるように配慮した。
- **サムネイル非表示要件の遵守**:
  ユーザー要望に基づき `PinDetailSheet` へのサムネイル追加は行わず、写真の永続化と既存画面（地図プレビュー、思い出詳細・一覧、編集画面）での確実な描画に集中した。

## 5. 検証結果・影響範囲（Verification & Impact）
- **静的解析**: `flutter analyze` にてエラー・警告 0件（No issues found!）。
- **テスト結果**: `flutter test` にて新設テストを含む全29テストがすべて成功（All tests passed!）。
- **他機能への影響**: 既存のグループ同期や地図表示を壊すことなく、写真の永続性と表示安定性が向上。
