# 変更ログ: PodfileのiOS最小デプロイターゲット設定（16.0）

## 1. 変更日時・作業ブランチ
- **日時**: 2026-11-05 22:09
- **作業ブランチ**: `feature/map`

## 2. 背景・目的（Background）
- 実機（`SotaのiPhone 05X`）へ `flutter run` を実行した際、`ios/Pods/Pods.xcodeproj` の `IPHONEOS_DEPLOYMENT_TARGET` が `13.0` / `14.0` となり、Xcodeのサポート範囲（`15.0` 〜 `27.2.x`）を下回るビルドエラーが発生したため解消する。

## 3. 変更内容と対象ファイル（Changes）
- **更新**:
  - `ios/Podfile`:
    - `platform :ios, '16.0'` を有効化
    - `post_install` ブロックにて、各Podターゲットの `IPHONEOS_DEPLOYMENT_TARGET` が `16.0` 未満の場合に `16.0` に設定する処理を追加

## 4. 変更理由・設計判断（Why）
- `AppDelegate.swift` や他の設定ファイルには手を触れず、`Pods.xcodeproj` 生成時のデプロイターゲット指定のみを Xcode サポート範囲（15.0+）および `GoogleMaps 10.x` / `Google-Maps-iOS-Utils 6.1.3` の対象バージョン（16.0+）に合わせる最小限の修正とするため。

## 5. 検証結果・影響範囲（Verification & Impact）
- `git diff ios/Podfile` により、`ios/Podfile` のみ変更されていることを確認。
- 他機能や `Secrets.xcconfig` への影響なし。
