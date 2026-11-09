# 変更ログ: Cloud Run を利用した思い出Webマップ共有機能（閲覧専用ビューア）の実装

## 1. 変更日時・作業ブランチ
- **日時**: 2026-11-10 00:03
- **作業ブランチ**: `feature/cloudrun`

## 2. 背景・目的（Background）
- ハッカソンの必須制約である「Google Cloud の実行・公開サービス（Google Cloud Run）の利用」と、MVP必須機能「5. シェア機能（思い出や訪問記録を他者と共有でき、公開範囲とアクセス権限を適切に管理する）」を両立するため。
- 各思い出を共有する際にリンクを発行し、リンクを開くとブラウザ上で地図が表示され、各レビュー（写真）の位置情報にピンが立ち、ピンを押すと詳細（写真・評価・コメント・滞在時間）を確認できる「閲覧専用（Read-only）のWeb共有マップ」を構築する。

## 3. 変更内容と対象ファイル（Changes）
- **新規作成**:
  - `server/server.js`: Cloud Run 用の Web 共有マップ配信サーバー（Node.js）。動的 OGP メタタグ生成、Firestore（`shares/{shareId}`, `groups/{groupId}/memories/{shareId}`, `groups/{groupId}/trips/{tripId}`）および URL エンコードデータからの共有データ解決、閲覧専用インタラクティブ地図 UI（ピン押下時の詳細ボトムシート・写真ライトボックス・ルート表示）を実装。
  - `server/Dockerfile`, `server/package.json`, `server/.dockerignore`, `server/README.md`: Cloud Run コンテナビルド定義およびデプロイ手順書。
  - `lib/core/services/share_service.dart`: 思い出（`TripMemory`）から位置共有許可済みのピンのみを抽出し、未アップロード写真の Cloud Storage 同期、Firestore への共有スナップショット保存、Cloud Run API 登録、および共有URL発行を行うサービス。
  - `test/share_service_test.dart`: `ShareService` のセキュリティ境界（位置非公開ピンの除外、端末ローカルパスの除外）および `MemoryDetailScreen` の共有シート表示に関するテスト。
- **変更**:
  - `lib/screens/memories/memory_detail_screen.dart`: 共有ボタン（紙飛行機アイコン）タップ時のボトムシートを拡張し、Cloud Run 共有マップ URL の自動生成・表示、「リンクのみコピー」「Webマップを開く」「共有リンク・まとめをコピー」、および Cloud Run ベース URL 設定ダイアログを追加。

## 4. 変更理由・設計判断（Why）
- **閲覧専用（Read-only）とプライバシー保護の徹底**:
  - アプリ側（`ShareService`）とサーバー側（`sanitizeShareData`）の双方で、`shareLocation == false` の非公開ピンや端末固有のローカルパス（`localPath`）を除外し、公開可能な情報のみを配信する設計とした。
  - Web ビューア側には編集・削除・追加系の UI や API を一切持たせず、閲覧者が安全に鑑賞のみ行える構成とした。
- **多重フォールバックによる高可用性**:
  - 既存の `firestore.rules` でグループメンバーに書き込み権限が許可されている `groups/{groupId}/memories/{shareId}` への保存に加え、Cloud Run API (`POST /api/shares`) および URL クエリパラメータ（`?d=`）への軽量スナップショット（ピン・写真・移動ルート `rp` 含む）埋め込みを併用することで、Firestore ルールの再デプロイ前やローカル検証時でも 100% 確実に共有リンクが機能するようにした。
  - ゲストモード等で Cloud Storage に未アップロードのローカル写真ファイルがある場合は自動的に Data URL 化してサーバー登録ペイロードに含めるようにし、さらに Cloud Run 本番デプロイ前にローカル検証している場合（`http://localhost:8080` 稼働時）は自動的にローカルサーバーへフォールバック・接続先切替できるようにした。
  - 地図描画においても Google Maps タイル（`https://mt{s}.google.com/vt/lyrs=m&x={x}&y={y}&z={z}&hl=ja`）および Google Maps JavaScript API とのハイブリッド描画を実装し、CartoDB タイルで発生していた `API KEY REQUIRED` 表示を解消して、APIキー制限時でも確実に日本語地図とピン・詳細カードが動作するようにした。

## 5. 検証結果・影響範囲（Verification & Impact）
- **Google Cloud Run 本番デプロイ・検証結果**:
  - サービス名: `my-map-share-viewer`（プロジェクト: `memory-map-a7406`、リージョン: `asia-northeast1`）
  - 公開 URL: `https://my-map-share-viewer-717242936544.asia-northeast1.run.app`
  - 本番エンドポイント検証（`GET /share/demo`、`POST /api/shares`、`GET /api/shares/:shareId`）：すべて正常稼働を確認
- **テスト・検証結果**:
  - `node -c server/server.js` および End-to-End URL レンダリング検証：成功（データサニタイズ、非公開ピン除外、URL デコード、HTML レンダリングを確認）
  - `dart format lib/ test/`：フォーマット差分なし
  - `flutter analyze`：`No issues found!`（警告・エラー 0 件）
  - `flutter test`：新規テスト `test/share_service_test.dart`（3件）を含む全 36 件のテストがすべて成功
- **他機能への影響**:
  - 既存のマップ表示、旅行記録、グループ管理、思い出編集・削除機能への破壊的変更はなし。
