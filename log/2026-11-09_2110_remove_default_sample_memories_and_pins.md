# 初期サンプルの思い出・訪問ピン（シードデータ）の削除

## 1. 変更日時・作業ブランチ
- **変更日時**: 2026-11-09 21:10 (JST)
- **作業ブランチ**: `fix/db`

## 2. 背景・目的（Background）
アプリ起動時およびオフライン・初期表示時に自動的に注入されていた初期サンプルの思い出（「東京・鎌倉ドライブ旅」「京都・嵐山散策」「札幌ナイトグルメ巡り」「箱根温泉1泊2日」「代官山カフェ巡り」）および関連する訪問ピンデータを削除し、ユーザー自身が作成した記録のみが表示されるクリーンな状態にする。

## 3. 変更内容と対象ファイル（Changes）
- **`lib/core/models/trip_memory.dart`**
  - `buildInitialSampleMemories()` が空リスト（`const []`）を返却するように変更。
- **`lib/core/models/memory_pin.dart`**
  - `initialSamplePins` を空リスト（`const []`）に変更。
- **`lib/core/services/trip_service.dart`**
  - `_initLocalFallbacks()` 内でサンプルピン・旅行を注入していた処理を削除し、空のローカル状態を維持するように更新。
- **`lib/screens/map/map_screen.dart`**
  - `_allPins` および `_allMemories` の初期状態を空リスト（`[]`）として初期化。
- **`test/widget_test.dart`**
  - サンプルデータ前提の検証を、シードデータなしのクリーンな状態からユーザーが旅行を開始・作成するフローの検証へ更新。

## 4. 変更理由・設計判断（Why）
- ユーザーの実データとダミーデータが混在することを防ぎ、本番MVPとしてユーザー本来の訪問記録のみが地図・思い出一覧に反映されるようにした。
- 思い出一覧画面には既存のEmpty State（空状態案内）が実装されており、思い出が0件のときでも破綻なく自然なUIを表示可能。

## 5. 検証結果・影響範囲（Verification & Impact）
- **静的解析**: `flutter analyze` にてエラー・警告 0件（No issues found!）。
- **テスト結果**: `flutter test` にて全29テストがすべて成功（All tests passed!）。
- **影響範囲**: グループ（部屋）の構成自体は変更せず、思い出とピンのシードデータのみを安全に削除。
