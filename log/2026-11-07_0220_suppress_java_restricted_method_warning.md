# 変更ログ: 2026-11-07 02:20 Javaネイティブアクセス警告の抑制設定

## 1. 変更日時・作業ブランチ
- **変更日時**: 2026-11-07 02:20
- **作業ブランチ**: `Googlephoto`

## 2. 背景・目的（Background）
ユーザーの最新JDK（Java 22/25）環境において、`flutter run` 実行時に `WARNING: A restricted method in java.lang.System has been called`（JEP 454 に起因する警告）が毎回ログに出力される事象が発生。ビルドログの視認性を改善するため、この警告を解消する。

## 3. 変更内容と対象ファイル（Changes）
- `android/gradle.properties` (変更)
  - `org.gradle.jvmargs` に `--enable-native-access=ALL-UNNAMED` オプションを追記。

## 4. 変更理由・設計判断（Why）
- 警告文内で明示的に推奨されている公式オプション（`Use --enable-native-access=ALL-UNNAMED to avoid a warning for callers in this module`）をGradleのJVM引数として渡すことで、Gradleが使用する内部ネイティブライブラリに対する不要なセキュリティ警告を安全に抑止できるため。

## 5. 検証結果・影響範囲（Verification & Impact）
- **影響範囲**: Androidビルド時のGradle JVM設定のみ。FlutterアプリのDartコードや機能への影響なし。

