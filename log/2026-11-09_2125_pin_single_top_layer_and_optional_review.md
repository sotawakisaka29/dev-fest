# 変更ログ: 2026-11-09 21:25 ピン単一最前面化・星評価なし/コメント未記載の許容および非表示対応

## 1. 変更日時・作業ブランチ
- **日時**: 2026-11-09 21:25 JST
- **作業ブランチ**: `feature/trip-log`

---

## 2. 背景・目的（Background）
ユーザーより以下の要望・課題が提示されたため対応を実施：
1. **ピン重複の解消**: 地図上にピンが2重（PlatformViewネイティブのMarkerとStack最前面のFlutterウィジェット）で表示されているため、最前面のピンのみを単一表示としたい。
2. **レビュー「しない」選択時の非表示化**: 記録画面で「レビューする / しない」のトグルで「しない」を選択した際、住所欄だけでなくレビューボタン（星評価）および口コミ入力欄も非表示にしたい。
3. **星評価なし・コメント未記載の許容**: レビュー「しない」の時や未評価の保存時にダミー補完（`rating: 0` や `'とても良い時間を過ごせました。'`）を行うのではなく、星評価はそもそもなし（`rating: null`）、コメントは未記載（空文字列 `''`）として自然に保存・表示したい。

---

## 3. 変更内容と対象ファイル（Changes）

### (1) `lib/core/models/memory_pin.dart`
- `rating` フィールドの型を `final int rating;` から nullable の `final int? rating;` に変更。
- コンストラクタ、`copyWith`、`toFirestore`、`fromFirestore`（`(data['rating'] as num?)?.toInt()`）を更新。
- サンプルピンの通過点（`pin_waypoint_1`）の `rating: 0` 指定を削除（null 化）。

### (2) `lib/screens/map/map_canvas/interactive_map_canvas.dart`
- `GoogleMap` の `markers` プロパティを `const <Marker>{}` に固定し、PlatformView 内部のネイティブ Marker を描画停止。
- 使われなくなった `_buildMarkers` ヘルパーメソッドを削除。
- Stack 最前面の Flutter ウィジェットピン（`_buildTopLayerPinWidgets`）のみを表示し、ピンが二重に見える現象を解消。

### (3) `lib/screens/record/review_input/review_input_section.dart`
- `rating` 引数の型を `final int? rating;` に、コールバックを `ValueChanged<int?>` に変更。
- 星の再タップ時に未評価（`null`）にリセット可能なトグルロジックを実装。
- 口コミ欄のヒントテキストを `（省略可能）` に更新。

### (4) `lib/screens/record/record_screen.dart`
- 状態変数 `_rating` の型を `int?`（初期値 `null`）に変更。
- 位置共有トグル（`_shareLocation`）が `false`（しない）の時、`LocationInputSection` の住所欄だけでなく、`ReviewInputSection`（星評価・口コミ欄）全体を条件分岐（`if (_shareLocation) ...`）で非表示化。
- `_handleSave()` で保存時：
  - `rating: !_shareLocation ? null : _rating`
  - `comment: !_shareLocation ? '' : _commentController.text.trim()`
  - 空文字入力時のダミー文言補完を撤廃し、未記載のまま保存可能に。

### (5) `lib/screens/map/pin_callout/pin_callout_card.dart`
- 吹き出しカードにおいて、`pin.rating != null && pin.rating! > 0` の場合のみ5段階の星表示を表示。
- 口コミコメントが空でない場合のみコメント枠を表示。

### (6) `lib/screens/map/pin_callout/pin_detail_sheet.dart`
- 詳細ボトムシートにおいて、`pin.rating != null && pin.rating! > 0` の場合のみ星表示を表示（星がない場合は時間のみをコンパクトに表示）。

### (7) `lib/screens/memories/memory_detail_screen.dart`
- レビュー一覧のソートを `(b.rating ?? -1).compareTo(a.rating ?? -1)` に修正（未評価レビューも安全に扱えるように）。
- レビュー行の星表示を `if (pin.rating != null && pin.rating! > 0) ...` で囲み、星評価がある場合のみ星アイコンを表示。
- 静的解析の warning/info（`_pins` の final 化、`context.mounted` の適用）を修正。

### (8) `test/widget_test.dart`
- 最前面レイヤーの単一ピンウィジェット存在検証（`top_pin_marker_${pin.id}`）にアサートを整合。
- 記録画面で「しない」選択時に住所入力欄および `ReviewInputSection` が非表示になること、再選択で復活することの検証ステップを追加。

---

## 4. 変更理由・設計判断（Why）
- **ピン二重化の防止**: Google Maps の Flutter プラグインではネイティブ PlatformView 内の Marker と Flutter 側の Stack ウィジェットが同時に描画されると視差や二重描画が発生する。すべて Flutter ウィジェットピン（`Positioned`）に一本化することで、地図の塗り（県・市区町村シルエット）よりも手前にピンを確実に配置でき、タップ検知や吹き出し表示もシンプルかつ統一的に制御できる。
- **データ整合性と UX の向上**: 「レビューしない」記録や「星を付けたくない」訪問記録に対して、固定値の 0 や定型文を無理に補完するとユーザーの意図しないデータが残ってしまう。`int?`（nullable）および空文字列を許容し、UI 各部で「評価がある時だけ星を表示する」分岐を行うことで、記録の自由度を高めた。

---

## 5. 検証結果・影響範囲（Verification & Impact）
- **`dart format lib test`**: 正常終了（全37ファイル整形完了）。
- **`flutter analyze`**: エラー・警告ゼロ（`No issues found!`）。
- **`flutter test test/widget_test.dart`**: 全6テストケースすべてパス（`6/6 All tests passed!`）。
  - 初回ログイン・サンプルデータ表示・UI
  - 認証フロー
  - 旅行実ルート追跡・手動思い出作成
  - スポット検索・予測候補・「しない」非表示・ルート追従抑止
  - レビュー個別削除・思い出削除時の関連レビュー一括削除
  - グループ管理・ピンViewボタン・ホームタブ維持

