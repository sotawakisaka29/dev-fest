# 変更ログ：左上タブの拡大・思い出一覧の背景写真＋右下タイトルUI化・レビュー高評価順ソート

## 1. 変更日時・作業ブランチ
- **変更日時**：2026-11-07 22:45
- **作業ブランチ**：`ui/top-screen`

## 2. 背景・目的（Background）
- 画面左上のヘッダーメニュー（チーム名・アカウントアイコン・各アクションボタン）が小さかったため、全体的にサイズを拡大して視認性と操作性を高めるため。
- 思い出一覧画面の各アイテムにおいて、角丸の輪郭・枠線や余分なメタ情報を廃止し、写真を背景にして右下にタイトルだけが表示される洗練されたデザインにするため。
- 各思い出の詳細画面（思い出一覧の中身）におけるレビュー一覧を、高評価順（星評価の降順）で表示するため。

## 3. 変更内容と対象ファイル（Changes）
- `lib/screens/map/header_menu/header_menu_overlay.dart`
  - アカウントアイコン（`28px`）、思い出ボタンアイコン（`29px`）・ラベル（`14px`）、旅行中ステータス文字（`13px`）およびボタン間の余白を拡大。
- `lib/screens/map/header_menu/team_selector/team_selector_dropdown.dart`
  - チーム名テキスト（`26px`）、プルダウン矢印アイコン（`30px`）、左側の縦インジケータバーのサイズを拡大。
- `lib/screens/map/header_menu/trip_action/trip_action_button.dart`、`invite_button.dart`、`share_button.dart`
  - 各ボタンのアイコン（`29px`）とテキスト（`14px`、サブリンク `12px`）およびタップ領域のパディングを拡大。
- `lib/screens/memories/memories_list_screen.dart`
  - 角丸（`BorderRadius`）と枠線（`Border`）を完全に撤廃し、長方形の全面写真背景の上に右下タイトル（`memory.title`）のみを表示するレイアウトに刷新。
- `lib/screens/memories/memory_detail_screen.dart`
  - レビュー一覧の表示時に `memory.pins` を `b.rating.compareTo(a.rating)` で高評価順（降順）にソートして描画するよう変更。
  - `MemoryPhotoThumbnail` で角丸・枠線なしの全面写真描画（`borderRadius: 0`, `showBorder: false`, `showPlaceholderLabel: false`）に対応。
- `test/widget_test.dart`
  - 思い出詳細画面でレビューが高評価順（★5 → ★4 → ★0）に並んでいることを検証するアサーションを追加。

## 4. 変更理由・設計判断（Why）
- 思い出一覧カードでは写真のビジュアルとタイトルの印象を際立たせるため、角丸や枠線、日付・件数テキストを排し、下部グラデーションの上に右下揃えの白文字タイトルのみを配置する構成とした。
- レビューのソートは元の `TripMemory.pins`（移動順序）を破壊しないよう、表示時にコピーを作成して `rating` 降順ソートを行う設計とした（これにより総移動距離の算出順序には影響を与えない）。

## 5. 検証結果・影響範囲（Verification & Impact）
- `dart format`、`flutter analyze`、`flutter test` によりフォーマット・静的解析・ウィジェットテストを実施。
- 他の機能（マップ表示・グループ招待・記録作成・移動距離算出）への副作用はない。

