# 変更ログ: iOS向けGoogle Maps APIキー設定ファイル（Secrets.xcconfig）の作成

## 1. 変更日時・作業ブランチ
- **日時**: 2026-11-05 21:44
- **作業ブランチ**: `feature/map`

## 2. 背景・目的（Background）
- iOS向けのGoogle Maps SDK APIキーをソースコードにハードコードせず、Git管理外のローカル設定ファイルから安全に注入できるよう `ios/Flutter/Secrets.xcconfig` を作成する。

## 3. 変更内容と対象ファイル（Changes）
- **新規作成**:
  - `ios/Flutter/Secrets.xcconfig`（`.gitignore` によりGit追跡対象外）：`GOOGLE_MAPS_API_KEY=` の設定枠を作成

## 4. 変更理由・設計判断（Why）
- `AGENTS.md` 8.2（APIキー・認証情報の管理）に準拠し、APIキーのGitコミット漏洩を防止するため。
- 初期値を空（`GOOGLE_MAPS_API_KEY=`）とすることで、キー記入前でも `AppDelegate.swift` の空文字ガードにより起動時クラッシュを防止できる。

## 5. 検証結果・影響範囲（Verification & Impact）
- **Git除外確認**: `git status --ignored` にて `ios/Flutter/Secrets.xcconfig` が `Ignored files` として扱われ、コミット対象に含まれないことを確認。
- **他機能への影響**: 既存機能への影響なし。`GOOGLE_MAPS_API_KEY=` に実キーを設定してビルドすることでiOS実機・シミュレータ上でGoogle Mapsタイルが描画される。
