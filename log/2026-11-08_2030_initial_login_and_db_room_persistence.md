# 初回ログイン画面（認証ゲート）の追加と部屋（グループ）情報のDB保持対応

## 1. 変更日時・作業ブランチ

- **変更日時**：2026-11-08 14:30
- **作業ブランチ**：`feature/login-button`

## 2. 背景・目的（Background）

- アプリ起動時に未ログイン状態のまま直接マップ画面へ入るのではなく、初回ログイン画面（認証ゲート）を表示し、「Googleアカウントでログイン」または「ゲストとして参加」を選択してからアプリを利用できるようにする。
- 「ゲストとして参加」を押した場合はゲスト状態を保持し、既存のサンプルデータを表示する。
- Googleログインを行った場合は、Cloud Firestore（DB）を用いて部屋（グループ）情報および各部屋のピン・旅行の思い出を保持・取得できるようにする。

## 3. 変更内容と対象ファイル（Changes）

- `lib/main.dart`
  - `_RootAuthGate` を追加し、`AuthService.instance.hasActiveSession` が `false` の初回起動時は `LoginScreen(isInitialGate: true)` を表示し、ログインまたはゲスト参加後に `MapScreen` へ遷移するよう変更。
- `lib/core/services/auth_service.dart`
  - `hasActiveSession`、`enterGuestMode()`、`resetToInitialGate()` を追加し、初回未選択状態・ゲスト参加状態（保持）・Googleログイン状態の遷移とストリーム通知を管理。
- `lib/screens/auth/login/login_screen.dart`
  - `isInitialGate` パラメータを追加し、初回起動時は「Googleアカウントでログイン」と「ゲストとして参加」の両ボタンを表示、アプリ内のアカウント画面（`isInitialGate: false`）ではゲスト時にサインインボタンのみ、ログイン後にログアウトボタンのみを表示するよう対応。
- `lib/core/models/memory_pin.dart` / `lib/core/models/trip_memory.dart`
  - Cloud Firestore への保存・復元用の `toFirestore()` および `fromFirestore()` メソッドを追加。
- `lib/core/services/group_service.dart`
  - ログインユーザーのデフォルト部屋（「MyMap」）のDB自動生成（`ensureDefaultPersonalGroup`）、および部屋ごとのピン・思い出データのDB取得・保存・削除（`fetchGroupPins`, `savePin`, `fetchGroupMemories`, `saveMemory`, `deleteMemory`）を追加。
- `lib/screens/map/map_screen.dart`
  - ゲスト状態（`_currentUser.isAnonymous == true`）ではサンプルデータを表示し、ログイン状態（`_currentUser.isAnonymous == false`）では `GroupService` を通じてDBの部屋情報・ピン・思い出を読み書きするよう連携。
- `firestore.rules`
  - `/groups/{groupId}/memories/{memoryId}` サブコレクションに対するグループメンバーの読み書き許可ルールを追加。
- `test/widget_test.dart`
  - 初回起動時にログイン画面が表示されること、「ゲストとして参加」押下後にサンプルデータ入りのマップ画面へ遷移すること、およびアカウント画面でのボタン出し分けを検証するテストを更新。

## 4. 変更理由・設計判断（Why）

- 既存の `LoginScreen` に `isInitialGate` モードを持たせることで、画面コンポーネントを重複作成せずに初回ログインゲートとアプリ内アカウント画面を一元管理した。
- ゲスト参加時とGoogleログイン時でデータ参照元を明確に分離し、ゲスト参加時はデモ体験用のサンプルデータをそのまま維持しつつ、Googleログイン時は Cloud Firestore の `/groups/{groupId}` 配下に部屋・ピン・思い出を永続化する構成とした。

## 5. 検証結果・影響範囲（Verification & Impact）

- `dart format`・`flutter analyze`・`flutter test` によりフォーマット・静的解析・ウィジェットテストを検証。
- ゲスト参加時は従来通りのサンプルデータと全UI操作がそのまま動作し、Googleログイン時はDB上の部屋データが保持・反映される。
