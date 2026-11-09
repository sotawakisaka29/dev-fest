# 変更ログ: 思い出画面を開くたびの明示的DB取得（fetch）とFirebase件数不一致の修正

## 1. 変更日時・作業ブランチ
- **変更日時**: 2026-11-10 01:20 (JST)
- **作業ブランチ**: `feature/fix-group-memories-sync`

---

## 2. 背景・目的（Background）
グループの「思い出一覧」に表示される思い出の数と、Firebase（Cloud Firestore）上に実際に存在する思い出の数が一致しない課題が発生した。
原因を調査した結果、以下の問題が確認されたため、これを根本的に解消することを目的とした。

1. 「思い出」画面を開く際（およびグループ切り替え時）に Firestore への明示的な再取得（`get()`）を行っておらず、初期購読時のメモリキャッシュに依存していた。また、認証切り替えや通信瞬断で一度ストリームがエラー停止すると再接続されず古い状態のまま固定されていた。
2. `/groups/{groupId}/trips`（または `/memories`・`/pins`）配下に存在するドキュメントであっても、作成時の状態によりドキュメント内部の `teamId` フィールドが空文字や別ID（`daily_...` 等）になっていると、`m.teamId == _selectedTeam.id` フィルタで弾かれ、Firebase上に実在するのに画面に表示されない現象が起きていた。
3. 読み込み時の勝手な自動マイグレーション（`/memories` から `/trips` への書き戻し）や、0件時のガード条件により、削除された思い出が復活したりキャッシュ残留するケースがあった。

---

## 3. 変更内容と対象ファイル（Changes）

### ① `lib/core/models/trip_memory.dart` / `lib/core/models/memory_pin.dart`
- `fromFirestore` に `fallbackTeamId` パラメータを追加し、グループのサブコレクションから読み込んだドキュメントは必ず親コレクションの `groupId` に `teamId` を正規化するよう修正。
- `routePoints` 等のネストされた Map 配列の安全な型変換を追加。

### ② `lib/core/services/trip_service.dart`
- Firestore から指定グループの最新思い出（`trips` & `memories`）およびピン（`pins`）を明示的に `.get()` してローカル状態とストリームを強制同期する `fetchTrips(groupId)`・`fetchPins(groupId)`・`refreshGroupData(groupId)` を実装。
- `watchTrips` / `watchPins` が Firestore の `snapshots()` だけでなく `fetchTrips` / `fetchPins` による明示的DB取得結果もリアルタイムに全購読者へ配信するよう改善。
- 読み込み時に `/memories` から `/trips` へ勝手に書き戻す自動コピー処理を削除し、DB上の実データと件数がズレないように修正。

### ③ `lib/screens/map/map_screen.dart`
- 認証状態の変更時に既存のストリーム購読をリセットして再接続する `_resetGroupDataSubscriptions` を追加。
- グループ一覧取得時、グループ切り替え時、および「思い出」画面を開く際（`_openMemoriesScreen`）に毎回 `_tripService.refreshGroupData` を呼び出してDBから最新データを取得するよう修正。

### ④ `lib/screens/memories/memories_list_screen.dart`
- 画面表示時（`initState`）に毎回 `_refreshFromDb()` を実行して Firestore から最新の思い出一覧を取得・反映するよう修正。
- 一覧画面を下に引っ張って手動でもDB再取得できる `RefreshIndicator` を追加。
- Firebase 上で思い出が0件になった場合もキャッシュを残さず0件として正確に反映するよう修正。

### ⑤ `lib/screens/memories/memory_detail_screen.dart`
- 詳細画面を開く際にも `TripService.instance.refreshGroupData` を呼び出し、最新のレビュー・写真・タイトルをDBから取得するよう改善。

### ⑥ `test/trip_persistence_test.dart`
- サブコレクション配下ドキュメントの `teamId` 正規化テスト、および `fetchTrips` による件数同期・削除後の0件反映テストを追加。

---

## 4. 変更理由・設計判断（Why）
- **ストリーム購読（Push）と画面オープン時の明示的DB取得（Pull）のハイブリッド構成**:
  - Firestore の `snapshots()` だけでは認証切り替え直後や通信復帰時に取りこぼしが生じる可能性があるため、「思い出を開くたび」「グループを切り替えるたび」「下に引っ張ったとき」に明示的な `get()`（`fetchTrips`）を実行してキャッシュとストリームを強制リフレッシュする設計とした。
- **親コレクションID（`groupId`）による `teamId` 正規化**:
  - Firestore の `/groups/{groupId}/trips`（または `/memories`）に格納されている時点でそのグループに属する思い出であるため、ドキュメント内部の `teamId` 文字列の不整合によって表示から除外されるのを防いだ。

---

## 5. 検証結果・影響範囲（Verification & Impact）
- `dart format` によるフォーマット確認
- `flutter analyze` による静的解析チェック（エラー・警告 0件）
- `flutter test` による全単体テスト・ウィジェットテストの実行（全41件パス）
- **影響範囲**: グループ思い出・ピンのDB取得および一覧・詳細画面の同期処理。既存UIや他機能への破壊的変更はなし。
