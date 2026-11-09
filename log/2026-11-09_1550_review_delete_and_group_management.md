# 2026-11-09 15:50 レビュー削除・思い出削除時のレビュー一括削除選択・グループ削除/退出・ホームタブ常時維持・ピンView仕様の改善

## 1. 変更日時・作業ブランチ
- **変更日時**：2026-11-09 15:50 (JST)
- **作業ブランチ**：`feature/trip-log`

## 2. 背景・目的（Background）
1. **レビューの削除機能の追加**：
   - 地図上のピン詳細シート（`PinDetailSheet`）および思い出詳細画面（`MemoryDetailScreen`）の各レビュー行に削除ボタンを配置し、不要になった個別レビューを削除できるようにする。
2. **思い出削除時の関連レビュー一括削除確認（チェックリスト選択方式）**：
   - 思い出を削除する際に「この思い出に紐づくレビュー・ピンも同時に削除するか」をユーザーに質問し、チェックリスト（`CheckboxListTile`）で削除したいレビューを選択して一括削除できるようにする。
3. **ピンViewボタンの仕様改善（見た目・倍率不変、ルートデータ抑止）**：
   - ホームボタン隣のピンViewボタン押下時、地図の見た目（県シルエット写真表示や倍率ルール）を変えずに再描画を発生させず、ピン以外のルート線や通過点（ウェイポイント）などのデータのみを出力・描画しないようにする。
4. **1倍時のホームタブ（HeaderMenuOverlay）非表示バグの解消**：
   - 1倍表示のままマップを縦横に場所移動（スクロール・パン操作）している間や、ホームボタンを押下した瞬間にもホームタブが誤って非表示にならないよう、表示条件を `visible: _isAt1xZoom` に修正する。
5. **グループの削除・退出機能**：
   - 個人用グループ（MyMap）以外のグループについて、オーナーはグループ削除、メンバーはグループ退出ができるようにし、削除/退出後は自動的に「MyMap」に切り替える。
6. **`record_screen.dart` の静的解析エラー・型競合の恒久修正**：
   - `location_input_section.dart` からの不要な型exportを整理し、型二重定義エラーを解消。

## 3. 変更内容と対象ファイル（Changes）
- `lib/core/models/trip_memory.dart`
  - `copyWith` メソッドを追加し、レビュー削除時に関連ピンリストを安全に更新可能に改修。
- `lib/core/services/group_service.dart`
  - 個別ピン削除（`deletePin`）、グループ削除（`deleteGroup`）、グループ退出（`leaveGroup`）を実装。
- `lib/core/services/auth_service.dart`
  - Firebase未接続（テスト/ローカル）環境下で `signOut()` 時にプラグイン呼び出しを安全にハンドリングするようガードを追加。
- `lib/screens/map/pin_callout/pin_detail_sheet.dart`
  - 右上に個別レビュー削除ボタンと確認ダイアログを追加。
- `lib/screens/memories/memory_detail_screen.dart`
  - 各レビュー行に個別削除ボタンを追加。
  - タイトル横のゴミ箱アイコン押下時に、「思い出に含まれるレビューも同時に削除するか」のチェックリスト付きダイアログを表示し、選択されたピンと合わせて一括削除するよう改修。
- `lib/screens/memories/memories_list_screen.dart`
  - 個別レビュー削除・思い出削除時の選択ピンID集合（`Set<String>`）を受け取るコールバックを実装。
- `lib/screens/map/header_menu/team_selector/team_selector_dropdown.dart`
  - グループプルダウンメニューに「グループを削除」「グループから退出」項目および確認ダイアログを追加。
- `lib/screens/map/header_menu/header_menu_overlay.dart`
  - `onDeleteTeam`、`onLeaveTeam`、`currentUid` を中継。
- `lib/screens/map/map_canvas/interactive_map_canvas.dart`
  - `_forcePinOnlyMode` 有効時、地図スタイルやズーム倍率を変更せず、ピン以外のルート線（`_buildPolylines()`）や通過点（`_buildWaypointCircles()`）のみ空リストを返して出力を抑止。
- `lib/screens/map/map_screen.dart`
  - `HeaderMenuOverlay` の表示条件を `visible: _isAt1xZoom` に修正（場所移動中やホームボタン押下時も非表示にならないよう改善）。
  - グループ削除（`_handleDeleteTeam`）、グループ退出（`_handleLeaveTeam`）、ピン削除（`_handleDeletePin`）のハンドラを実装し、削除後は自動的に「MyMap」へフォールバック。
  - 思い出削除時にチェックされたピンを `_allPins` および Firestore から一括削除する連携を実装。
- `lib/screens/record/location_input/location_input_section.dart`
  - `ListTile` を `Material` で包み、背景色とインク効果の競合を解消。
- `test/widget_test.dart`
  - 全6テスト（初回ログイン・ゲスト参加、ログイン/ログアウト切り替え、旅行スタート〜終了の実ルート追跡と手動作成距離反映、スポット予測検索と住所リンク、レビュー個別削除＆思い出削除時の一括削除、グループ削除/退出＆ピンViewルート抑止＆ホームタブ維持）を統合し、全テストパス（6/6）を確認。

## 4. 変更理由・設計判断（Why）
- **ピンViewボタンの「見た目不変・データ抑止」**：
  - ユーザーからの「Mapの見た目（倍率ルール等）は変えず、再描画のチラつきを起こさず、ピン以外のルート線などのデータを出力しない」という明確な要望に沿い、キャンバスのズーム状態を強制書き換えするのではなく描画レイヤー（Polyline/Circle）側でピン以外のデータをフィルタリングする設計を採用した。
- **ホームタブ常時表示の安定化**：
  - マップドラッグ時の微細なインタラクション検知（`_isMapInteracting`）でメニューが点滅・非表示になるのを防ぎ、1倍表示域にいる限りは常にヘッダーメニューを操作できるようにした。

## 5. 検証結果・影響範囲（Verification & Impact）
- `dart format lib test`：全コードをDart公式規約に準拠してフォーマット完了。
- `flutter test test/widget_test.dart`：全6テストすべて成功（All tests passed!）。
- 既存の都道府県・市町村写真表示、タイムライン連携、手動思い出作成、Googleフォト連携のすべてが正常に動作し、回帰問題のないことを確認。

