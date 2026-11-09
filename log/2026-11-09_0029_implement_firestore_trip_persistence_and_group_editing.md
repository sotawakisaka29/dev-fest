# 旅行情報（ピン・旅行まとめ）の Firestore 永続化とグループ共同編集（パターンB）の実装

## 1. 変更日時・作業ブランチ
- **変更日時**: 2026-11-09 00:29 (JST)
- **作業ブランチ**: `dev`

## 2. 背景・目的（Background）
- これまで旅行情報（訪問ピン `MemoryPin` および旅行まとめ `TripMemory`）は、アプリ実行中のメモリ（State）上のみで保持されており、アプリ再起動時にリセットされるほか、同一グループに参加する他メンバーの画面へリアルタイムに共有されない課題があった。
- ユーザーからの要求に基づき、以下を実現することを目的とする：
  1. 訪問スポット（ピン）および旅行まとめの Cloud Firestore 永続化
  2. 訪問スポットおよび旅行タイトルの編集機能
  3. グループ全員が自由に加筆・修正できる「グループ共同編集（パターンB）」の採用
  4. 編集内容がグループ全員の画面へ即座に反映されるリアルタイム同期（Firestore `snapshots()`）

## 3. 変更内容と対象ファイル（Changes）

### ① セキュリティルールの拡張
- **`firestore.rules`**
  - `/groups/{groupId}/trips/{tripId}` への読み書き権限を追加し、グループ所属メンバー（`memberUids`）であれば誰でも旅行まとめを作成・共同編集・削除できるように設定。

### ② モデルのシリアライズ・デシリアライズ対応
- **`lib/core/models/app_photo.dart`**
  - `toMap()` および `AppPhoto.fromMap()` を実装し、写真メタデータ（ID、ラベル、URL、ローカルパス、撮影日時、Googleフォト由来フラグ）の相互変換に対応。
- **`lib/core/models/trip_memory.dart`**
  - タイトル変更やピン更新を容易にする `copyWith` メソッドを追加。

### ③ 永続化・リアルタイム監視サービスの新規作成
- **`lib/core/services/trip_service.dart` (新規)**
  - シングルトン `TripService.instance` を提供。
  - `watchPins(groupId)`: `/groups/{groupId}/pins` のリアルタイムストリーム（`snapshots()`）。
  - `watchTrips(groupId)`: `/groups/{groupId}/trips` のリアルタイムストリーム（`snapshots()`）。
  - `savePin(pin)`: ピンの新規保存および更新（編集）。紐づく旅行がある場合は旅行ドキュメント内のピンリストも同期更新。
  - `updateTripTitle(...)`: 旅行タイトルの更新。
  - `deleteTrip(...)` / `deletePin(...)`: 旅行・ピンの削除。
  - オフライン時やデモ実行時でも初期サンプルデータへ安全にフォールバックする耐障害性を担保。

### ④ UI の編集モード対応とリアルタイム同期統合
- **`lib/screens/record/record_screen.dart`**
  - `initialPin` パラメータを追加し、既存ピンの編集モードに対応。タイトルを「記録を編集」、保存ボタンを「変更を保存」にし、既存入力値（スポット名、住所、評価、口コミ、写真、時間帯）をフォームに自動展開。
- **`lib/screens/map/pin_callout/pin_detail_sheet.dart`**
  - 地図上でピン詳細を開いた際、右上に「スポットを編集」アイコンボタンを追加し、`onEdit` コールバック経由で編集画面を起動可能に改善。
- **`lib/screens/memories/memory_detail_screen.dart`**
  - 旅行タイトル横に鉛筆アイコン（タイトル編集）を追加し、ダイアログから旅行名を即座に編集可能に。
  - レビュー一覧の各カードに鉛筆アイコン（スポット編集）を追加し、レビュー内容や写真を再編集可能に。
- **`lib/screens/memories/memories_list_screen.dart`**
  - 思い出詳細画面からのタイトル変更（`onUpdateTripTitle`）およびスポット編集（`onEditPin`）を親へ伝播するコールバックを統合。
- **`lib/screens/map/map_screen.dart`**
  - `TripService` の `watchPins` および `watchTrips` をリアルタイム購読。誰かが追加・編集・削除すると、即座に画面上のマーカー、都道府県プレビュー、思い出一覧へ反映。
  - `_handleEditPin`、`_handleUpdateTripTitle` を追加し、Firestore への保存・更新フローを確立。

### ⑤ 単体テストの追加
- **`test/trip_persistence_test.dart` (新規)**
  - 写真・ピン・旅行モデルのシリアライズ相互変換テスト
  - `TripService` によるピン編集（`savePin`）、旅行タイトル更新（`updateTripTitle`）、旅行削除（`deleteTrip`）の検証テスト

## 4. 変更理由・設計判断（Why）
- **パターンB（グループ全員が共同編集可能）の採用**:
  - ユーザーヒアリングに基づき、旅行の記録を友達同士で自由に加筆・修正できる共同作業のしやすさを優先。
  - Firestore セキュリティルール側でも `request.auth.uid in memberUids` を検証し、同一グループ外の第三者からの改ざんは防止しつつ、グループ内では柔軟な共同編集を許可する設計とした。
- **Firestore サブコレクション構造 (`/groups/{groupId}/pins` & `/trips`)**:
  - 各グループの配下にデータを集約することで、グループ単位の権限管理（`firestore.rules`）が自然かつ強固に機能し、セキュリティ境界を明確化。
- **リアルタイムストリーム（`snapshots()`）とローカルフォールバックの共存**:
  - Firebase 接続時は自動的にクラウドDBと双方向同期し、未初期化・デモ時にもアプリがクラッシュせずローカルメモリで編集・反映されるようにすることで、ハッカソン環境での安定性を確保。

## 5. 検証結果・影響範囲（Verification & Impact）
- **単体テストコード作成**: `test/trip_persistence_test.dart` に可逆変換およびサービス編集ロジックのテストを網羅。
- **環境制限**: 現在のサンドボックス環境では `flutter` / `dart` コマンド実行が制限されているため、ローカルでの実行検証は未実施。構文・型・インポート関係は入念に手動レビューを実施。
- **他機能への影響**: 既存の地図表示、LOD倍率切り替え、都道府県シルエットプレビュー、外部Google Mapsアプリ起動等の既存仕様に破壊的変更はなく、データ層のみが永続化・リアルタイム同期へとアップグレードされている。
