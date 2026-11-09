# 地域プレビューからサンプル写真を削除

## 変更日時・作業ブランチ

- 変更日時: 2026-11-07 21:47 (JST)
- 作業ブランチ: `ui/top-screen`

## Background

県・市の写真プレビューには保存済み写真だけを表示し、写真がない地域にはサンプル風景ではなく灰色を表示する要望があった。

## Changes

- `lib/screens/map/map_canvas/region_photo_overlay.dart`
  - 地域内の各 `MemoryPin.photos` に保存された実写真だけを表示対象に変更。
  - 8種類のダミー風景と、その描画コードを削除。
  - 保存写真がない場合と写真読み込みに失敗した場合は灰色で表示。
  - 複数写真の5秒ごとのランダム切り替えと、同一写真の連続回避を維持。
  - 写真リスト更新時に表示インデックスを安全に補正。

## Why

`photoLabels` から生成された表示用データやダミー風景を混ぜると、ユーザーが保存していない写真が思い出として表示される。地域プレビューの意味を明確にするため、永続化対象である `MemoryPin.photos` のみを使用する。写真がない状態は中立的な灰色で明示する。

## Verification & Impact

- `dart format`: 成功。
- `flutter analyze`: 成功（No issues found）。
- `flutter test test/group_invite_test.dart`: 成功。
- `git diff --check`: 成功。
- 境界形状、ズーム切り替え、ピン表示、地域タップ処理への変更なし。
- 実機での写真切り替え表示は未確認。
