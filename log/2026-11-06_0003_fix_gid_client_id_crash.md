# 変更ログ: iOS Google Sign-In の GIDClientID クラッシュの修正

## 1. 変更日時・作業ブランチ
- **日時**: 2026-11-06 00:03
- **作業ブランチ**: `feature/login`

## 2. 背景・目的（Background）
- 実機（iOS）で `flutter run` 実行時、以下のネイティブ例外が発生してクラッシュ（SIGABRT）する問題を解消する：
  `'NSInvalidArgumentException', reason: 'No active configuration. Make sure GIDClientID is set in Info.plist.'`
- GoogleSignIn iOS SDK（v6以降）の仕様上、`Info.plist` に `GIDClientID` が必須となっているため設定する。

## 3. 変更内容と対象ファイル（Changes）
- **更新**:
  - `ios/Runner/Info.plist`: `GoogleService-Info.plist` 内の `CLIENT_ID`（`717242936544-gjjil2scnkk6i4na01eidukg7sk93jod.apps.googleusercontent.com`）を `GIDClientID` キーとして追加。
  - `lib/screens/map/map_screen.dart`: 未ログイン（ゲスト）状態での Firestore 購読をスキップし、不要な `permission-denied` ログと無駄なクエリを抑止。

## 4. 変更理由・設計判断（Why）
- iOSネイティブ層でのGoogle Sign-In設定を完全化し、アプリ起動時およびGoogleサインイン呼び出し時のクラッシュを根絶するため。

## 5. 検証結果・影響範囲（Verification & Impact）
- `flutter analyze`: `No issues found!`（警告・エラーゼロ）。
- `flutter test`: 全テスト通過（`All tests passed!`）。
