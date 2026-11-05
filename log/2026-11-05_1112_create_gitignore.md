# 変更ログ：`.gitignore` の作成

## 1. 変更日時・作業ブランチ
- **日時**：2026-11-05 11:12 (JST)
- **ブランチ**：`main`（未コミット状態・作業ブランチ切り替え前）

## 2. 背景・目的（Background）
- リポジトリ初期化段階において、今後導入する Flutter（iOS・Android）・Firebase・Google Maps・Google Cloud 開発で発生するビルド生成物やキャッシュ、および `AGENTS.md`（8.2 APIキー・認証情報の管理）でコミットが禁止されている秘密情報（APIキー、`.env`、サービスアカウント秘密鍵など）が誤ってGitにコミットされるのを未然に防ぐため。

## 3. 変更内容と対象ファイル（Changes）
- **新規作成**：`.gitignore`
  - 秘密情報・環境変数・署名鍵・APIキー設定ファイル（`.env*`, `*service-account*.json`, `*credentials*.json`, `local.properties`, `key.properties`, `Secrets.xcconfig`, `ApiKeys.plist` 等）の除外設定
  - Flutter / Dart ビルド生成物（`build/`, `.dart_tool/`, `coverage/` 等）の除外設定
  - Android / iOS ネイティブビルド成果物・CocoaPods・Gradleキャッシュの除外設定
  - Firebase CLI・エミュレータのデバッグログ・キャッシュの除外設定
  - OS・エディタ固有ファイル（`.DS_Store`, `.idea/` 等）の除外設定
  - `AGENTS.md` のルール（5.6）で作成する変更ログ用ディレクトリ `log/**/*.md` が `*.log` ルールと干渉せずGit追跡対象となるよう明示（`!log/`, `!log/**/*.md`）

## 4. 変更理由・設計判断（Why）
- **セキュリティ最優先の設計**：`flutter create` が生成する標準の `.gitignore` だけでは、Google Maps APIキーを格納する `Secrets.xcconfig` / `ApiKeys.plist` や、Google Cloud のサービスアカウントJSON、`.env.*` ファイルなどが漏れるリスクがあるため、初期段階で網羅的に除外対象へ含めた。
- **`pubspec.lock` の扱い**：パッケージ開発ではなくモバイルアプリケーション開発であるため、チーム2名間で依存ライブラリのバージョンを完全一致させる目的から `pubspec.lock` は除外対象に含めていない。
- **`log/` ディレクトリの保護**：デバッグログ（`*.log`）は除外しつつ、AIエージェントの変更記録を残す `/log` ディレクトリ配下のMarkdownファイルは確実にGit管理下に置けるよう設定した。

## 5. 検証結果・影響範囲（Verification & Impact）
- `git check-ignore` により、機密ファイル・ビルド生成物が無視され、`AGENTS.md` や `log/*.md` が追跡対象として維持されることを確認。
- 既存ファイル（`README.md`, `AGENTS.md`）への影響なし。
