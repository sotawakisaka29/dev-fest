# 変更ログ: グループおよびMyMapの思い出編集画面における「新しい思い出スポット追加」機能の実装とUI体裁統一

## 1. 変更日時・作業ブランチ
- **変更日時**: 2026-11-09 21:52
- **作業ブランチ**: `fix/db`

---

## 2. 背景・目的（Background）
ユーザーより「グループの思い出の編集で新しい思い出スポットを追加できる様にしてほしい。MyMapとグループでUIの体裁は同じにしてほしい」という要求があった。
従来の思い出詳細画面（`MemoryDetailScreen`）には、既存スポットの編集ボタン（鉛筆アイコン）は存在していたが、作成済みの旅行まとめに対して新しいスポット（ピン・レビュー・写真）を追記・追加するUIおよび連携フローが存在していなかった。

本変更では、MyMap（個人マップ）とグループの思い出の両方において完全に同一のUI体裁・トーン＆マナーで「スポットを追加」できるようにし、追加されたスポットが即座に思い出詳細・思い出一覧・地図画面・Firestoreへ同期・永続化されるようにした。

---

## 3. 変更内容と対象ファイル（Changes）

### ① `lib/screens/memories/memory_detail_screen.dart`
- コンストラクタに `final Future<MemoryPin?> Function(String tripId, String teamId)? onAddPin;` を追加。
- `_handleAddNewSpot` メソッドを実装し、スポット追加完了時に返却された `newPin` を State（`_currentMemory.pins`）に追加して `setState` で即時再描画し、`onUpdateMemory` コールバックで親の一覧画面へ最新状態を伝播。
- レビュー見出し行の右端に「＋ スポットを追加」（`Icons.add_location_alt_outlined`）ボタンを配置。
- レビューが0件の場合の空領域にも「新しいスポットを追加」ボタンを配置。
- フォント、余白（8の倍数）、カラー（`AppTheme.darkGrey`）、角丸（8px）をアプリ共通のデザイン規約に準拠させ、MyMapとグループで共通のUI体裁を適用。

### ② `lib/screens/memories/memories_list_screen.dart`
- コンストラクタに `onAddPin` プロパティを追加し、`MemoryDetailScreen` への遷移時にそのまま中継するように修正。

### ③ `lib/screens/map/map_screen.dart`
- `_handleAddPinToTrip(String tripId, String teamId)` を実装。
- 該当思い出の `activeTripId: tripId` および `teamId: effectiveTeamId` を指定して `RecordScreen` を起動。
- 保存された新しいピンを `_allPins` および `_allMemories` の当該旅行まとめに追加し、`TripService.savePin` によりローカルキャッシュおよび Cloud Firestore へ永続化。
- `_openMemoriesScreen` 内で `MemoriesListScreen` に `onAddPin: _handleAddPinToTrip` を渡すよう統合。

---

## 4. 変更理由・設計判断（Why）
- **UI体裁の完全共通化**:
  - `MemoryDetailScreen` は MyMap（個人用）および各グループで共通のコンポーネントとして動作しており、今回の追加ボタンも同一のトーン＆マナーで実装したため、どちらのコンテキストから開いても完全に同一のUI体裁と操作感が保たれる。
- **データ不整合の防止**:
  - 新規スポット追加時に `teamId`（グループIDまたはMyMapのID）と `activeTripId`（思い出のID）を確実に紐付け、`TripService.savePin` を呼び出すことで、ピンコレクション（`groups/{groupId}/pins`）と旅行まとめドキュメント（`groups/{groupId}/trips/{tripId}` 内の pins 配列）の双方が自動的かつ確実に同期される設計とした。

---

## 5. 検証結果・影響範囲（Verification & Impact）
- **影響範囲**:
  - 思い出詳細画面（`MemoryDetailScreen`）のレビューセクション。
  - 思い出一覧画面（`MemoriesListScreen`）のアイテム更新。
  - 地図画面（`MapScreen`）の `_allPins` および `_allMemories`。
  - Cloud Firestore の `pins` および `trips` コレクション。
- **検証内容**:
  - 全変更ファイルの静的型整合性、null 安全性、非同期ライフサイクル（`mounted`）を確認済み。
  - 既存の地図画面からのスポット記録や、ピン編集機能への副作用がないことを確認。
