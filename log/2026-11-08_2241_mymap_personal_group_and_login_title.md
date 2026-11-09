# 初期個人グループの「MyMap」への統一・招待不可化・全グループデータ引き継ぎ・初回ログイン画面の「ログイン」中央大文字表示

## 1. 変更日時・作業ブランチ

- **変更日時**：2026-11-08 14:41
- **作業ブランチ**：`feature/login-button`

## 2. 背景・目的（Background）

1. どのログイン（ゲスト参加・Googleログイン）であっても必ず最初に配置される個人用グループ（従来の「日常」）を **「MyMap」** という名前に統一し、個人用のため他者を招待できないようにする。
2. 「MyMap」を選択しているときは、自分が所属するすべてのグループのピン・旅行の思い出データを引き継いで集約表示できるようにする。
3. 最初のログイン画面の「ログイン」見出しを画面中央に大きく表示する。

## 3. 変更内容と対象ファイル（Changes）

- `lib/core/models/team_group.dart`
  - `sampleTeams` の先頭グループ名を `'MyMap'`（`inviteCode: ''`, `isPersonal: true`）に変更。
  - `fromFirestore` にて `isPersonal`（または `daily` プレフィックスID）のグループは名前を `'MyMap'`・招待コードを空文字に正規化する処理を追加。
- `lib/core/services/group_service.dart`
  - `ensureDefaultPersonalGroup` および `watchUserGroups` で作成・取得する個人用グループ名を `'MyMap'`（`inviteCode: ''`, `isPersonal: true`）に変更し、`_sortWithPersonalFirst` により常にグループ一覧の先頭（1番目）へ配置するよう修正。
  - `joinGroupByInviteCode` にて `isPersonal == true` のグループへの参加を拒否するガードを追加。
- `lib/screens/map/header_menu/invite/invite_button.dart`
  - `selectedTeam.isPersonal`（「MyMap」選択時）の場合は招待モーダルを開かず、「『MyMap』は個人用のため招待できません」と通知し、ボタン表示をグレーアウトするよう変更。
- `lib/screens/map/map_screen.dart`
  - `_currentTeamPins` および `_currentTeamMemories` にて、`_selectedTeam.isPersonal` の場合は全グループのピン・思い出を返すよう変更。
  - ログイン時は所属する全グループのピン・思い出をDBから読み込む `_loadAllGroupsDataFromDb` を追加。
- `lib/screens/auth/login/login_screen.dart`
  - 初回ログイン画面（`isInitialGate: true`）において、「ログイン」の文字を画面中央に大きく（`fontSize: 28`, `FontWeight.bold`, `TextAlign.center`）配置。
- `test/widget_test.dart`
  - 初回ログイン画面の「ログイン」表示、初期グループ「MyMap」の表示、「MyMap」での招待不可制御、および「MyMap」への全グループ思い出引き継ぎを検証するよう更新。

## 4. 変更理由・設計判断（Why）

- `TeamGroup.isPersonal` フラグを基準に「先頭固定」「招待不可」「全グループデータの集約表示」の3つの振る舞いを一貫して制御することで、ゲスト時とGoogleログイン時の双方で同じ体験をシンプルに実現した。

## 5. 検証結果・影響範囲（Verification & Impact）

- 個別のグループを選択した際はそのグループのデータのみが表示され招待も可能であり、「MyMap」を選択した際のみ全グループのデータが集約表示され招待が制限される。
