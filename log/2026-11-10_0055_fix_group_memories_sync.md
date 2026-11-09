# 変更ログ: グループの思い出・スポット追加が反映されない不具合の修正

## 1. 変更日時・作業ブランチ
- **変更日時**: 2026-11-10 00:55 (JST)
- **作業ブランチ**: `feature/fix-group-memories-sync`

---

## 2. 背景・目的（Background）
同一グループの友人が新しい思い出（旅行まとめ）やスポット（訪問ピン・レビュー）を追加したにも関わらず、自分の画面に反映されない不具合が発生していた。原因調査の結果、以下の4点が判明したため、これらを解消してグループ全員の画面にリアルタイムかつ確実に反映されるようにすることを目的とした。

1. **保存先Firestoreコレクションと監視先コレクションの不一致（直接原因）**
   - `MapScreen` では `TripService.watchTrips` により `/groups/{groupId}/trips` を監視していたが、「思い出一覧」右上の「＋」ボタンから手動作成した思い出（`onCreateMemory`）は `GroupService.saveMemory` のみを呼び出し `/groups/{groupId}/memories` へ保存されていた。
2. **思い出一覧・詳細画面を開いている間のリアルタイム更新未購読**
   - `MemoriesListScreen` および `MemoryDetailScreen` に遷移時点のスナップショットのみを渡しており、画面表示中に友人が追加・編集した内容が画面に伝播していなかった。
3. **`MemoryDetailScreen` 内の二重状態（`late final _pins` 固定）**
   - `_MemoryDetailScreenState` 内で `_currentMemory` とは別に `late final List<MemoryPin> _pins` が定義されており、`build` が `_pins` を参照していたため、スポット追加・編集を行っても詳細画面のレビュー・写真一覧が更新されなかった。
4. **「MyMap（個人用グループ）」選択時の他グループ未購読と期間一致ピンの未統合**
   - 単一グループのみを購読していたため、「MyMap」選択時に参加中グループのリアルタイム更新が取得されていなかった。また、思い出作成後に友人が同じ旅行期間のピンを追加した場合に思い出内のピンリストへ自動統合されていなかった。

---

## 3. 変更内容と対象ファイル（Changes）

### ① `lib/core/services/trip_service.dart`
- `watchTrips(groupId)` にて `/groups/{groupId}/trips` と旧 `/groups/{groupId}/memories` の両方をリアルタイム監視・統合し、旧 `memories` 側にのみ存在するデータは自動的に `trips` へマイグレーションするよう改善。
- `/groups/{groupId}/pins` の最新ピン情報も監視し、旅行に紐づくピン（`tripId` 一致、または `tripId` 未設定で旅行期間 `matchesTimeWindow` に一致する同グループのピン）をリアルタイムに旅行まとめへマージする `_mergePinsIntoTrips` を追加。
- `savePin` 時にも期間一致する旅行ドキュメントの `pins` 配列を自動更新するよう拡張。
- `deletePin` 時にローカルおよび Firestore の旅行ドキュメント内の `pins` 配列からも該当ピンを同期削除するよう修正。

### ② `lib/core/services/group_service.dart`
- `saveMemory` / `deleteMemory` / `savePin` / `deletePin` を `TripService.instance` の対応メソッドへ委譲・統一し、どの経路から呼ばれても `/groups/{groupId}/trips` および `/pins` とローカルストリームが一貫して更新されるよう修正。

### ③ `lib/screens/map/map_screen.dart`
- 単一サブスクリプション（`_pinsSubscription` / `_tripsSubscription`）をグループIDごとのマップ（`_pinsSubscriptions` / `_tripsSubscriptions`）へ変更し、所属する全グループを並行してリアルタイム購読する `_syncGroupSubscriptions` を実装。
- `_openMemoriesScreen` の `onCreateMemory` で `_tripService.saveTrip(createdMemory)` を呼び出すよう修正。
- `_handleDeletePin` で `_tripService.deletePin` を呼び出すよう統一。

### ④ `lib/screens/memories/memories_list_screen.dart`
- 表示対象グループ（`watchedTeamIds` / `teamId`）の `TripService.watchTrips` および `watchPins` を購読し、思い出一覧画面を開いている最中に友人が追加・編集した思い出やピンがリアルタイムに反映されるよう改善。

### ⑤ `lib/screens/memories/memory_detail_screen.dart`
- `late final List<MemoryPin> _pins` を廃止し、`List<MemoryPin> get _pins => _currentMemory.pins;` に一本化。
- ヘッダーのタイトル・期間・距離表示が `widget.memory` ではなく最新の `memory`（`_currentMemory`）を参照するよう修正。
- `TripService.watchTrips` を購読し、詳細画面を開いている最中に友人がスポット追加・編集・タイトル変更を行った場合も即座に画面へ反映されるよう改善。

### ⑥ `test/trip_persistence_test.dart` / `test/widget_test.dart`
- `GroupService.saveMemory` 経由の保存が `TripService.watchTrips` に反映されるテストを追加。
- 思い出作成後に友人が同期間のピンを追加した際に思い出へ自動統合されるテストを追加。
- 思い出一覧・詳細画面を開いている最中に友人が追加した思い出・スポットがリアルタイムに表示されるウィジェットテストを追加。

---

## 4. 変更理由・設計判断（Why）
- **旧 `/memories` コレクションとの後方互換・自動マイグレーション**:
  - すでに友人が追加済みの思い出データが `/groups/{groupId}/memories` に保存されているケースでも、再入力することなくそのまま画面に反映されるようにするため、両コレクションの統合監視と `/trips` への自動移行を採用した。
- **状態の一元化とリアルタイム購読の徹底**:
  - 画面遷移時のスナップショット渡しや `late final` による古い状態保持を排除し、`TripService` のストリームを単一の信頼できる情報源（Single Source of Truth）として各画面が購読する構成に統一した。

---

## 5. 検証結果・影響範囲（Verification & Impact）
- `dart format` によるコードフォーマット適用
- `flutter analyze` による静的解析チェック
- `flutter test` による全単体テスト・ウィジェットテストの実行・パス確認
- **影響範囲**: グループ思い出の保存・取得・一覧表示・詳細表示・ピン同期処理。既存の地図描画やUIデザインへの破壊的変更はなし。
