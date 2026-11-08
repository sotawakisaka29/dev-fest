# ログイン画面におけるサインイン・ログアウトボタンの出し分け修正

## 1. 変更日時・作業ブランチ
- **変更日時**：2026-11-08 09:36
- **作業ブランチ**：`feature/login-button`

## 2. 背景・目的（Background）
ログイン画面（`LoginScreen`）において、「Googleアカウントでログイン（サインイン）」ボタンと「ログアウト / ゲストに戻る」ボタンが認証状態にかかわらず常に両方表示されていたため、ログイン前はサインインボタンのみ、ログイン後はログアウトボタンのみを表示するように改善する。

## 3. 変更内容と対象ファイル（Changes）
- `lib/screens/auth/login/login_screen.dart`
  - `_user.isAnonymous` の真偽値に基づき、ログイン前（`_user.isAnonymous == true`）は「Googleアカウントでログイン」ボタンのみを表示し、ログイン後（`_user.isAnonymous == false`）は「ログアウト / ゲストに戻る」ボタンのみを表示するよう修正。
- `lib/core/services/auth_service.dart`
  - Firebase未初期化（ローカル/テストモード）でサインイン・サインアウトを行った際にも `AuthService.instance.currentUser` に状態が保持・反映されるよう `_localFallbackUser` フィールドを追加。
- `test/widget_test.dart`
  - `LoginScreen` にてログイン前はサインインボタンのみ表示、サインイン後はログアウトボタンのみ表示、ログアウト後は再度サインインボタンのみ表示となることを検証するウィジェットテストを追加。

## 4. 変更理由・設計判断（Why）
- `AppUser` モデルが既に保持している `isAnonymous` フラグ（ゲスト状態では `true`、Google認証後は `false`）を利用することで、不要な状態変数を増やさずにシンプルかつ確実にUIの出し分けを実現した。
- また、ローカル/テストモード時にも画面再遷移後にログイン後のボタン表示が維持されるよう、`AuthService` 側でフォールバック時のユーザー状態を保持する設計とした。

## 5. 検証結果・影響範囲（Verification & Impact）
- `dart format`：フォーマット適用済み
- `flutter analyze`：静的解析エラー・警告なし
- `flutter test`：既存のテストおよび新規追加したログイン画面ボタン表示テストがすべてパスすることを確認
- **影響範囲**：`LoginScreen` のボタン表示および `AuthService` のローカルフォールバック状態保持のみであり、他機能への副作用はない。

