# 端末アルバムおよびGoogleフォト写真の Firebase Cloud Storage 実体保存・永続共有の実装

## 1. 変更日時・作業ブランチ
- **変更日時**: 2026-11-09 00:55 (JST)
- **作業ブランチ**: `feature/trip-db`

## 2. 背景・目的（Background）
- これまで端末アルバムから選択した写真はローカルファイルパス（`localPath`）しか保持しておらず、グループ内の他メンバーの端末からは画像実体を閲覧・共有することができなかった。
- また、Google Photos Picker API から取得する画像URL（`baseUrl`）は約60分の一時的な有効期限があるため、一定時間が経過すると他メンバーおよび本人の端末でも画像が読み込めなくなる制約があった。
- これらの課題を一挙に解消するため、**端末写真および Googleフォト（キャッシュ済み）写真の両方を Firebase Cloud Storage にアップロードして永続ダウンロードURLを発行・Firestoreに保存し、グループ全員がいつまでも高画質に写真を閲覧・共有できる環境**を構築した。

## 3. 変更内容と対象ファイル（Changes）

### ① パッケージの追加
- **`pubspec.yaml`**
  - `firebase_storage: ^12.4.4` を追加。

### ② Cloud Storage セキュリティルールの新設
- **`storage.rules` (新規)**
  - `/groups/{groupId}/photos/{photoId}` への読み書きルールを定義。認証済みユーザー（`request.auth != null`）に対し、20MB以内の画像ファイルのアップロード・閲覧を許可。

### ③ アップロードサービスクラスの新規作成
- **`lib/core/services/storage_service.dart` (新規)**
  - シングルトン `StorageService.instance` を提供。
  - `uploadFile(...)`: ローカル写真ファイル（`File`）を `/groups/{groupId}/photos/{photoId}.jpg` にアップロードし、永続ダウンロードURL（`downloadUrl`）を取得。
  - `uploadPhotos(...)`: 選択された写真リスト（端末アルバムおよびGoogleフォトの両方）を一括アップロードし、永続URL付きの `AppPhoto` リストを返却。オフライン時やエラー時のフォールバックを完備。

### ④ スポット記録画面でのアップロード処理統合
- **`lib/screens/record/record_screen.dart`**
  - 保存ボタン押下時（`_handleSave`）、写真がある場合に `StorageService.instance.uploadPhotos` を実行。
  - 全面ローディングオーバーレイ（「写真をクラウドに保存中 (1/3)...」）を表示し、アップロード進捗をリアルタイムにフィードバック。
  - 発行された永続URLを各写真にセットした上で Firestore（ピンデータ）に保存。

### ⑤ 画像表示ウィジェットのフォールバック強化
- **`lib/screens/memories/memory_detail_screen.dart`**
- **`lib/screens/map/map_canvas/region_photo_overlay.dart`**
- **`lib/screens/record/photo_picker/photo_picker_section.dart`**
  - 他メンバーの端末では撮影者のローカルパス（`localPath`）が物理的に存在しないため、`File.existsSync()` を検証。実ファイルがない場合は即座に `Image.network(photo.url!)` を優先ロードするよう堅牢化。

### ⑥ 単体テストの追加
- **`test/storage_service_test.dart` (新規)**
  - `StorageService` のシングルトン検証
  - ファイル未存在時の安全な null 返却（クラッシュ防止）
  - 既存 Cloud Storage URL を持つ写真の重複アップロードスキップ検証
  - オフライン・未初期化時のオブジェクト保持フォールバック検証

## 4. 変更理由・設計判断（Why）
- **端末写真と Googleフォト写真のアップロード統一**:
  - Googleフォト写真を事前に一時ファイルへキャッシュする実装と連携し、どちらの取得経路の写真もローカルファイルとして統一的に Cloud Storage へアップロードするアーキテクチャを採用した。
  - これにより、Googleフォト写真の「有効期限（約60分）」の問題と、端末写真の「他端末での非表示」問題の両方を一度に解決した。
- **Firestore 連携との親和性**:
  - 発行された Cloud Storage の永続URLを `AppPhoto.url` に格納して Firestore に保存することで、前回実装したリアルタイム同期（`snapshots()`）を通じて、他メンバーの画面に即座に高画質画像が届くようになった。

## 5. 検証結果・影響範囲（Verification & Impact）
- **単体テスト作成**: `test/storage_service_test.dart` を整備し、フォールバックとURL判定の挙動を網羅。
- **他機能への影響**: 既存の地図表示、都道府県プレビュー、思い出一覧の表示に破綻はなく、画像ソースが自動的に Cloud Storage の永続URLへと昇格した。
- **通信量の配慮**: 既に Cloud Storage URL を持っている写真は再アップロードを自動スキップする仕組みを組み込み、無駄な通信を防止。
