# 変更ログ: 2026-11-07 03:15 Googleフォトフルスコープの追加とAPI生エラー通知対応

## 1. 変更日時・作業ブランチ
- **変更日時**: 2026-11-07 03:15
- **作業ブランチ**: `Googlephoto`

## 2. 背景・目的（Background）
ユーザーの環境においてGoogleフォトAPIリクエスト時に403エラーが発生。GCP設定上のスコープ（`.../auth/photoslibrary`）との不一致の解消、およびGoogleサーバーから返却される詳細エラー理由のリアルタイム表示を行う。

## 3. 変更内容と対象ファイル（Changes）
- `lib/core/services/auth_service.dart` (変更)
  - `GoogleSignIn` のスコープに `https://www.googleapis.com/auth/photoslibrary`（フルスコープ）と `https://www.googleapis.com/auth/photoslibrary.readonly`（読み取りスコープ）の両方を登録。
- `lib/core/services/google_photos_service.dart` (変更)
  - HTTP 403等の非200レスポンス時、Googleサーバーからの生エラーメッセージ（`error.message`, `error.status`）をJSON解析して画面上のスナックバーに詳細表示するよう改善。

## 4. 変更理由・設計判断（Why）
- GCPのOAuth同意画面で設定されたスコープ表記のブレ（フル権限 vs 読み取り専用）を吸収するため。
- プロジェクトID不一致や権限不足などの真の要因を、開発者が画面上で直接確認できるようにするため。

## 5. 検証結果・影響範囲（Verification & Impact）
- **影響範囲**: 認証スコープとエラーメッセージ表示。
- **検証**: 構文チェック完了。

