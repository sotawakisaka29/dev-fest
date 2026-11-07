# 変更ログ: iOSにおけるGoogleフォトアクセス権限誤判定の修正

## 1. 変更日時・作業ブランチ
- **変更日時**: 2026-11-07 20:48
- **作業ブランチ**: `feature/googlrphoto`

## 2. 背景・目的（Background）
- iOS環境で「Googleフォトから選択」を実行し、Googleの認可Web画面で許可を完了しても、アプリ側で「Googleフォトのアクセス権限が許可されませんでした。写真を選択するには権限を許可してください。」とエラー表示される問題が発生していた。
- 調査の結果、利用中の `google_sign_in: 6.3.0` / `google_sign_in_ios: 5.9.0` において、`GoogleSignIn` の初期化時に `scopes: ['email', 'profile']` を明示指定した状態で後から `requestScopes([photoPickerScope])` を呼ぶと、iOSネイティブプラグイン側のスコープ比較判定において基本スコープ（email / profile）が返却された `grantedScopes` と一致せず、ユーザーが「許可」しても誤って `false` を返してしまう既知の不具合（flutter/flutter#157639）が原因であった。
- 5日間のハッカソンMVPとして、パッケージ更新や破壊的変更を避け、最も低リスクかつ確実に解決するための修正を行った。

## 3. 変更内容と対象ファイル（Changes）
1. **`lib/core/services/auth_service.dart`**:
   - `_googleSignIn` の初期化時に明示されていた `scopes: ['email', 'profile']` を削除し、デフォルト（空リスト）に変更。Google Sign-In の標準仕様に従い、`email`/`profile`/`openid` は暗黙に要求・取得される状態を維持。
   - `requestPhotoPickerScopeDetailed()` メソッドを新設し、認可結果区分（`ScopeRequestResult`: `granted`, `cancelled`, `denied`, `failed`）を返却。
   - iOSプラグインの誤判定に対する安全策（フォールバック）として、Google OAuth2 公式の `https://oauth2.googleapis.com/tokeninfo` エンドポイントへ問い合わせ、アクセストークン自体に対象スコープが付与されているか検証するロジック（`verifyAccessTokenHasScope`、`parseScopesFromTokenInfo`）を実装。
   - 認可例外発生時に、ユーザーキャンセル（`sign_in_canceled`、`-5` 等）を識別できるように改善。
   - アクセストークンなどの機密情報はログやUIに出力しない設計を徹底。
2. **`lib/core/services/google_photos_service.dart`**:
   - `pickPhotosFromGooglePhotos()` 内で `requestPhotoPickerScopeDetailed()` を呼び出し、キャンセル・拒否・エラーを識別して適切なエラータイプ（`userCancelled` / `scopeNotGranted` / `unknown`）およびフィードバックメッセージを返却。
3. **`test/google_photos_picker_test.dart`**:
   - `AuthService.parseScopesFromTokenInfo` のパースおよびスコープ包含判定に関する単体テストを追加。
   - `GooglePhotosPickerResult` テストの const 不整合を解消。

## 4. 変更理由・設計判断（Why）
- **第一候補（初期スコープ削除）の採用**:
  `google_sign_in` 7系へのメジャーアップデートは、破壊的API変更（`authorizationForScopes` 等の導入）を伴い、iOS・Android両方での検証負荷と退行リスクが高いためハッカソンMVP期間中には採用を見送った。
  初期スコープから `email`/`profile` の明示指定を省くことで、iOSプラグイン内部での比較対象が追加要求した `photoPickerScope` のみとなり、flutter/flutter#157639 を安全に回避できる。
- **二重防護（tokeninfo フォールバック）の導入**:
  万が一端末やOS環境の差異で `requestScopes` が `false` を返した場合でも、実際のアクセストークンが Google Photos Picker スコープを保持していれば認可成功として扱うことで、ユーザーが不当にブロックされる事態を100%防止する。
- **キャンセルと拒否の分離**:
  ユーザーが認可画面で「キャンセル」を押した際に「権限が拒否されました」と赤色エラーが表示されるUX上の不整合を解消し、自然な操作感を実現した。

## 5. 検証結果・影響範囲（Verification & Impact）
- **静的解析**: `flutter analyze` 実行 -> `No issues found!`（警告・エラー0件）。
- **コードフォーマット**: `dart format lib test` 実行 -> 全ファイル正常整形済み。
- **単体テスト**: `flutter test` 実行 -> 全テスト成功（`All tests passed!`、11件）。
- **iOSビルド検証**: `flutter build ios --no-codesign --simulator` 実行 -> 正常終了（Runner.app ビルド成功）。
- **他機能・プラットフォーム影響**:
  - Googleログイン / Firebase Auth: 暗黙スコープにより表示名・メール・写真URLの取得およびFirebaseログインは引き続き維持される。
  - 端末アルバムからの選択、地図表示、記録機能、Android側のGoogleログイン: いずれも影響なし。
