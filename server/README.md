# My Map 共有マップビューア (Google Cloud Run)

思い出（旅行まとめ・訪問ピン・写真・レビュー）を**閲覧専用のWebマップ**として共有・公開するための Google Cloud Run サービスです。

## 主な機能
- **閲覧専用（Read-only）のWeb地図表示**：共有リンクを開くと、各レビュー（写真）の位置情報にピンが立った地図が表示されます。編集や削除はできません。
- **ピン押下による詳細表示**：地図上のピン（または下部のスポットチップ）をタップすると、写真・評価・コメント・滞在時間を確認できます。
- **動的OGPメタタグ生成**：SNSやメッセージアプリでリンクを共有した際、旅行タイトル・訪問スポット・代表写真がカードプレビューとして表示されます。

## ローカルでの起動・確認方法

```bash
cd server
npm install
npm start
```

ブラウザで以下にアクセスして確認できます：
- デモ共有マップ: `http://localhost:8080/share/demo`
- ヘルスチェック: `http://localhost:8080/healthz`

## Google Cloud Run へのデプロイ手順

```bash
cd server

gcloud run deploy my-map-share-viewer \
  --source . \
  --project memory-map-a7406 \
  --region asia-northeast1 \
  --allow-unauthenticated \
  --set-env-vars="FIREBASE_PROJECT_ID=memory-map-a7406"
```

Google Maps JavaScript API キーを設定する場合は `--set-env-vars` に `GOOGLE_MAPS_API_KEY=<YOUR_API_KEY>` を追加してください（未設定時や制限時も自動的にインタラクティブ地図へフォールバックして動作します）。
