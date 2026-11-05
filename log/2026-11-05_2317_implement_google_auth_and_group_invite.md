# 変更ログ: Googleアカウント認証および英数大文字8文字の招待コードによるグループ機能の実装

## 1. 変更日時・作業ブランチ
- **日時**: 2026-11-05 23:17
- **作業ブランチ**: `feature/login`

## 2. 背景・目的（Background）
- `AGENTS.md` で定義されたMVP必須機能「③ ユーザー認証」および「④ グループ機能」を具現化する。
- Firebase Authentication を用いた Googleアカウント連携によるログイン・ログアウトと、Cloud Firestore を用いたグループ管理を接続する。
- グループへの参加要件として「英数大文字8文字程度の招待コード」を採用し、新規グループ作成時にユニークな8文字コードを自動生成し、メンバー招待シートでのコード共有・コピー、およびヘッダープルダウンからの「招待コードで参加」を実現する。
- Firebase未接続環境やテスト時でもクラッシュせずローカル動作する安全なフォールバック設計を維持する。

## 3. 変更内容と対象ファイル（Changes）
- **依存関係の追加**:
  - `pubspec.yaml`: `firebase_core`, `firebase_auth`, `google_sign_in`, `cloud_firestore` を追加
- **プラットフォーム設定**:
  - `ios/Runner/Info.plist`: `GoogleService-Info.plist` の `REVERSED_CLIENT_ID`（`com.googleusercontent.apps.717242936544-gjjil2scnkk6i4na01eidukg7sk93jod`）に対応する `CFBundleURLTypes` を設定
  - `lib/firebase_options.dart`: FlutterFire 設定から Android/iOS 向けの `DefaultFirebaseOptions` を生成・配置
- **セキュリティ**:
  - `firestore.rules`: 認証済みユーザーの検証・グループ作成・招待コードによる参加（`memberUids` への自身追加）および削除権限を厳密に定義したセキュリティルールを作成
- **コアモデル・サービス**:
  - `lib/core/models/team_group.dart`: `inviteCode`（英数大文字8桁）、`ownerUid`、`memberUids`、ランダム8文字生成（`generateInviteCode`）、バリデーション（`isValidInviteCode`）、Firestoreシリアライズ（`fromFirestore` / `toFirestore`）を追加
  - `lib/core/services/auth_service.dart`: Firebase Auth + Google Sign-In のログイン・ログアウト・ユーザー情報ストリームを提供するサービスを新設（未初期化時のデモフォールバック対応）
  - `lib/core/services/group_service.dart`: Firestore を用いたグループ作成、8文字招待コードによるグループ検索・参加、所属グループストリーム購読を提供するサービスを新設
- **UIコンポーネント**:
  - `lib/main.dart`: `WidgetsFlutterBinding.ensureInitialized()` および `Firebase.initializeApp` の安全な初期化を追加
  - `lib/screens/auth/login/login_screen.dart`: Googleアカウントログインボタン、サインアウト、Firebase接続ステータス表示を実装
  - `lib/screens/map/header_menu/invite/invite_button.dart`: 選択中グループの8文字招待コードを大きく表示し、ワンタップでクリップボードにコピーする機能を実装
  - `lib/screens/map/header_menu/team_selector/team_selector_dropdown.dart`: 「招待コードで参加...」メニューおよび英数大文字8文字のバリデーション付き入力ダイアログを追加
  - `lib/screens/map/header_menu/header_menu_overlay.dart`: 招待コード参加コールバックの連携を追加
  - `lib/screens/map/map_screen.dart`: `AuthService` と `GroupService` を連携し、グループ作成時のFirestore保存と招待コード発行、招待コード入力時のグループ参加・切り替え処理を統合
- **テスト**:
  - `test/group_invite_test.dart`: 招待コード生成（8文字）・バリデーション境界値・グループ作成＆招待コード参加の自動テストを新設

## 4. 変更理由・設計判断（Why）
- **誤読防止を考慮した招待コード生成**:
  - `generateInviteCode()` では、視認時に誤読しやすい数字 `0` と英字 `O`、数字 `1` と英字 `I` をあらかじめ除外した文字セット（`23456789ABCDEFGHJKLMNPQRSTUVWXYZ`）から暗号学的に安全な `Random.secure()` で8文字を抽出。ユーザー入力時には小文字が入力されても自動で大文字へ正規化する処理を組み込んだ。
- **アーキテクチャのシンプルさ維持**:
  - 5日間ハッカソンでの開発速度と可読性を最優先し、過度な抽象化を避け、`AuthService` と `GroupService` のシングルトン構成で既存の `StatefulWidget` と直接連動させた。
- **フォールバック設計**:
  - ネイティブ側の設定状況やネットワーク状態に左右されず、ウィジェットテストや初期段階の開発が中断されないよう、Firebase未初期化時でもインメモリ上でグループ作成・招待コード参加がシミュレートできる構造を確保した。

## 5. 検証結果・影響範囲（Verification & Impact）
- **コードフォーマット**: `dart format .` を実行し、全25ファイルが正常にフォーマット済み。
- **静的解析**: `flutter analyze` を実行し、`No issues found!`（警告・エラーゼロ）。
- **自動テスト**: `flutter test` を実行し、全4テスト（既存のGoogle Maps・画面遷移テスト＋新設の招待コード・グループ参加テスト）がすべて通過。
- **他機能への影響**: 既存のGoogle Maps表示、ピン詳細シート、旅行開始/記録切替、都道府県写真プレビューの機能に悪影響を与えず正常に動作することを確認。
