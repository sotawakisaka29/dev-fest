const http = require('http');
const zlib = require('zlib');

const PORT = process.env.PORT || 8080;
const FIREBASE_PROJECT_ID = process.env.FIREBASE_PROJECT_ID || 'memory-map-a7406';
const GOOGLE_MAPS_API_KEY = process.env.GOOGLE_MAPS_API_KEY || '';

// Firebase Admin SDK の初期化（Cloud Run 上ではデフォルトサービスアカウントで自動認証）
let db = null;
try {
  const admin = require('firebase-admin');
  if (!admin.apps.length) {
    admin.initializeApp({
      projectId: FIREBASE_PROJECT_ID,
    });
  }
  db = admin.firestore();
} catch (err) {
  // ローカル検証時など firebase-admin 未導入・未認証環境でもインメモリ＆URLデータで動作可能
}

// インメモリキャッシュ（Firestore未接続環境や即時共有時の高速フォールバック用）
const memoryShareStore = new Map();

// デモ用のサンプル共有データ（/share/demo でいつでも動作確認可能）
const DEMO_SHARE_DATA = {
  shareId: 'demo',
  title: '鎌倉・江ノ島 日帰りフォトウォーク',
  formattedDateRange: '11月8日 〜 11月8日',
  formattedDistance: '8.4km',
  createdAt: new Date().toISOString(),
  routePoints: [
    { lat: 35.3191, lng: 139.5504 },
    { lat: 35.3261, lng: 139.5561 },
    { lat: 35.3167, lng: 139.5358 },
    { lat: 35.3065, lng: 139.4804 },
  ],
  pins: [
    {
      id: 'demo_pin_1',
      placeName: '鶴岡八幡宮',
      address: '神奈川県鎌倉市雪ノ下2-1-31',
      prefecture: '神奈川県',
      latitude: 35.3261,
      longitude: 139.5561,
      startTime: '10:00',
      endTime: '11:30',
      rating: 5,
      comment: '朝の澄んだ空気の中で参拝。本宮からの眺めがとても綺麗で、鳩みくじも引きました！',
      photos: [
        {
          label: '本宮と大石段',
          url: 'https://images.unsplash.com/photo-1590559899731-a382839e5549?auto=format&fit=crop&w=900&q=80',
        },
      ],
      isRouteWaypointOnly: false,
    },
    {
      id: 'demo_pin_2',
      placeName: '鎌倉大仏殿高徳院',
      address: '神奈川県鎌倉市長谷4-2-28',
      prefecture: '神奈川県',
      latitude: 35.3167,
      longitude: 139.5358,
      startTime: '12:30',
      endTime: '13:30',
      rating: 4,
      comment: '実物の大仏様は想像以上の迫力。近くのカフェで食べた抹茶スイーツも最高でした。',
      photos: [
        {
          label: '鎌倉大仏',
          url: 'https://images.unsplash.com/photo-1545569341-9eb8b30979d9?auto=format&fit=crop&w=900&q=80',
        },
      ],
      isRouteWaypointOnly: false,
    },
    {
      id: 'demo_pin_3',
      placeName: '江の島シーキャンドル',
      address: '神奈川県藤沢市江の島2-3-28',
      prefecture: '神奈川県',
      latitude: 35.2997,
      longitude: 139.4787,
      startTime: '16:30',
      endTime: '18:00',
      rating: 5,
      comment: '夕暮れ時の湘南の海と富士山のシルエットが絶景！旅の締めくくりにぴったりの場所でした。',
      photos: [
        {
          label: '湘南の夕景',
          url: 'https://images.unsplash.com/photo-1493976040374-85c8e12f0c0e?auto=format&fit=crop&w=900&q=80',
        },
      ],
      isRouteWaypointOnly: false,
    },
  ],
};

/**
 * HTMLエスケープ処理（XSS防止）
 */
function escapeHtml(str) {
  if (str === null || str === undefined) return '';
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

/**
 * <script>タグ内へ安全にJSONを埋め込むためのシリアライズ処理
 */
function safeJsonForScript(obj) {
  return JSON.stringify(obj)
    .replace(/</g, '\\u003c')
    .replace(/>/g, '\\u003e')
    .replace(/&/g, '\\u0026')
    .replace(/\u2028/g, '\\u2028')
    .replace(/\u2029/g, '\\u2029');
}

/**
 * 共有データの正規化・サニタイズ（公開可能なフィールドのみを抽出）
 */
function sanitizeShareData(raw, fallbackShareId = '') {
  if (!raw || typeof raw !== 'object') return null;

  const title = typeof raw.title === 'string' && raw.title.trim()
    ? raw.title.trim()
    : '思い出マップ';

  // 日付期間の整形
  let formattedDateRange = raw.formattedDateRange || '';
  if (!formattedDateRange && raw.startDate && raw.endDate) {
    try {
      const s = new Date(raw.startDate);
      const e = new Date(raw.endDate);
      if (!isNaN(s.getTime()) && !isNaN(e.getTime())) {
        formattedDateRange = `${s.getMonth() + 1}月${s.getDate()}日 〜 ${e.getMonth() + 1}月${e.getDate()}日`;
      }
    } catch (_) {}
  }

  const rawPins = Array.isArray(raw.pins) ? raw.pins : [];
  // 位置情報の共有がオフ（shareLocation === false）のピンは除外
  const sanitizedPins = rawPins
    .filter((p) => p && p.shareLocation !== false)
    .map((p, idx) => {
      const lat = Number(p.latitude ?? p.lat ?? 35.6812);
      const lng = Number(p.longitude ?? p.lng ?? 139.7671);

      const rawPhotos = Array.isArray(p.photos) ? p.photos : [];
      // 公開可能なHTTP/HTTPS URLまたはData URLを持つ写真のみを抽出（端末ローカルパスは除外）
      const photos = rawPhotos
        .filter((ph) => ph && typeof ph.url === 'string' && /^(https?:\/\/|data:image\/)/i.test(ph.url.trim()))
        .map((ph) => ({
          label: typeof ph.label === 'string' ? ph.label : '',
          url: ph.url.trim(),
        }));

      const ratingNum = p.rating !== null && p.rating !== undefined ? Number(p.rating) : null;
      const validRating = ratingNum && ratingNum >= 1 && ratingNum <= 5 ? Math.round(ratingNum) : null;

      return {
        id: String(p.id || `pin_${idx}`),
        placeName: String(p.placeName || p.name || `スポット ${idx + 1}`),
        address: String(p.address || ''),
        prefecture: String(p.prefecture || ''),
        latitude: isNaN(lat) ? 35.6812 : lat,
        longitude: isNaN(lng) ? 139.7671 : lng,
        startTime: String(p.startTime || ''),
        endTime: String(p.endTime || ''),
        rating: validRating,
        comment: String(p.comment || ''),
        photos,
        isRouteWaypointOnly: Boolean(p.isRouteWaypointOnly),
      };
    });

  const rawRoute = Array.isArray(raw.routePoints) ? raw.routePoints : [];
  const routePoints = rawRoute
    .map((rp) => ({
      lat: Number(rp.lat ?? rp.latitude),
      lng: Number(rp.lng ?? rp.longitude),
    }))
    .filter((rp) => !isNaN(rp.lat) && !isNaN(rp.lng));

  let formattedDistance = raw.formattedDistance || '';
  if (!formattedDistance && typeof raw.customDistanceKm === 'number') {
    formattedDistance = `${raw.customDistanceKm.toFixed(1)}km`;
  }

  return {
    shareId: String(raw.shareId || fallbackShareId || ''),
    title,
    formattedDateRange: formattedDateRange || '期間指定なし',
    formattedDistance: formattedDistance || '0km',
    pins: sanitizedPins,
    routePoints,
    createdAt: raw.createdAt || new Date().toISOString(),
  };
}

/**
 * URLクエリパラメータ (?d=...) に埋め込まれた軽量データのデコード
 */
function decodeEmbeddedData(encoded) {
  if (!encoded || typeof encoded !== 'string') return null;
  try {
    const buffer = Buffer.from(encoded, 'base64url');
    let jsonStr;
    try {
      jsonStr = zlib.inflateSync(buffer).toString('utf8');
    } catch (_) {
      jsonStr = buffer.toString('utf8');
    }
    const parsed = JSON.parse(jsonStr);
    // 短縮キーからの復元対応
    if (parsed && parsed.t && Array.isArray(parsed.p)) {
      return sanitizeShareData({
        title: parsed.t,
        formattedDateRange: parsed.dr || '',
        formattedDistance: parsed.dist || '',
        pins: parsed.p.map((item, i) => ({
          id: `pin_${i}`,
          placeName: item.n || '',
          address: item.a || '',
          prefecture: item.pr || '',
          latitude: item.la,
          longitude: item.ln,
          startTime: item.st || '',
          endTime: item.et || '',
          rating: item.r,
          comment: item.c || '',
          photos: Array.isArray(item.ph)
            ? item.ph.map((u) => (typeof u === 'string' ? { label: '', url: u } : u))
            : [],
          isRouteWaypointOnly: Boolean(item.w),
        })),
        routePoints: Array.isArray(parsed.rp)
          ? parsed.rp.map((pt) => ({ lat: pt[0], lng: pt[1] }))
          : [],
      });
    }
    return sanitizeShareData(parsed);
  } catch (err) {
    console.warn('Failed to decode embedded share data:', err.message);
    return null;
  }
}

/**
 * 共有データの取得（インメモリ → Firestore shares → Firestore groups/memories → Firestore groups/trips → URLパラメータ）
 */
async function resolveShareData(shareId, query = {}) {
  if (shareId === 'demo') {
    return DEMO_SHARE_DATA;
  }

  // 1. インメモリキャッシュを確認
  if (memoryShareStore.has(shareId)) {
    return memoryShareStore.get(shareId);
  }

  const groupId = query.g || query.groupId || '';
  const tripId = query.t || query.tripId || shareId;

  // 2. Firestore から取得を試行
  if (db) {
    // 2a. トップレベル shares/{shareId}
    try {
      const shareDoc = await db.collection('shares').doc(shareId).get();
      if (shareDoc.exists) {
        const sanitized = sanitizeShareData(shareDoc.data(), shareId);
        if (sanitized) {
          memoryShareStore.set(shareId, sanitized);
          return sanitized;
        }
      }
    } catch (err) {
      console.warn('Firestore shares lookup skipped:', err.message);
    }

    // 2b. groups/{groupId}/memories/{shareId}
    if (groupId) {
      try {
        const memDoc = await db
          .collection('groups')
          .doc(groupId)
          .collection('memories')
          .doc(shareId)
          .get();
        if (memDoc.exists) {
          const sanitized = sanitizeShareData(memDoc.data(), shareId);
          if (sanitized) {
            memoryShareStore.set(shareId, sanitized);
            return sanitized;
          }
        }
      } catch (err) {
        console.warn('Firestore group memories lookup skipped:', err.message);
      }

      // 2c. groups/{groupId}/trips/{tripId}
      try {
        const tripDoc = await db
          .collection('groups')
          .doc(groupId)
          .collection('trips')
          .doc(tripId)
          .get();
        if (tripDoc.exists) {
          const sanitized = sanitizeShareData(tripDoc.data(), shareId);
          if (sanitized) {
            memoryShareStore.set(shareId, sanitized);
            return sanitized;
          }
        }
      } catch (err) {
        console.warn('Firestore group trips lookup skipped:', err.message);
      }
    }
  }

  // 3. URLクエリパラメータ (?d=...) の埋め込みデータから復元
  if (query.d) {
    const decoded = decodeEmbeddedData(query.d);
    if (decoded) {
      decoded.shareId = shareId;
      memoryShareStore.set(shareId, decoded);
      return decoded;
    }
  }

  return null;
}

/**
 * リクエストボディ（JSON）の読み取りヘルパー
 */
function readJsonBody(req) {
  return new Promise((resolve, reject) => {
    let body = '';
    req.on('data', (chunk) => {
      body += chunk.toString('utf8');
      if (body.length > 5 * 1024 * 1024) {
        reject(new Error('Payload too large'));
      }
    });
    req.on('end', () => {
      if (!body.trim()) return resolve({});
      try {
        resolve(JSON.parse(body));
      } catch (e) {
        reject(e);
      }
    });
    req.on('error', reject);
  });
}

function sendJson(res, statusCode, payload) {
  const body = JSON.stringify(payload);
  res.writeHead(statusCode, {
    'Content-Type': 'application/json; charset=utf-8',
    'Access-Control-Allow-Origin': '*',
  });
  res.end(body);
}

function sendHtml(res, statusCode, html) {
  res.writeHead(statusCode, {
    'Content-Type': 'text/html; charset=utf-8',
    'Access-Control-Allow-Origin': '*',
  });
  res.end(html);
}

/**
 * HTTPリクエストハンドラ（Cloud Run & ローカル共通）
 */
async function handleRequest(req, res) {
  // CORS preflight
  if (req.method === 'OPTIONS') {
    res.writeHead(204, {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    });
    return res.end();
  }

  const host = req.headers.host || `localhost:${PORT}`;
  const protocol = req.headers['x-forwarded-proto'] || 'http';
  const parsedUrl = new URL(req.url || '/', `${protocol}://${host}`);
  const pathname = parsedUrl.pathname;
  const query = Object.fromEntries(parsedUrl.searchParams.entries());

  // 1. ヘルスチェック
  if (req.method === 'GET' && pathname === '/healthz') {
    return sendJson(res, 200, { status: 'ok', service: 'my-map-share-viewer' });
  }

  // 2. トップページ → デモ共有マップへリダイレクト
  if (req.method === 'GET' && pathname === '/') {
    res.writeHead(302, { Location: '/share/demo' });
    return res.end();
  }

  // 3. 共有データ登録API (POST /api/shares)
  if (req.method === 'POST' && pathname === '/api/shares') {
    try {
      const raw = await readJsonBody(req);
      const shareId =
        raw.shareId ||
        `sh_${Date.now().toString(36)}_${Math.random().toString(36).substring(2, 8)}`;

      const sanitized = sanitizeShareData(raw, shareId);
      if (!sanitized) {
        return sendJson(res, 400, { error: 'Invalid share payload' });
      }

      memoryShareStore.set(shareId, sanitized);

      if (db) {
        try {
          await db.collection('shares').doc(shareId).set(sanitized, { merge: true });
        } catch (err) {
          console.warn('Firestore write warning (kept in memory):', err.message);
        }
      }

      const shareUrl = `${protocol}://${host}/share/${encodeURIComponent(shareId)}`;
      return sendJson(res, 201, { shareId, shareUrl });
    } catch (err) {
      return sendJson(res, 400, { error: 'Invalid JSON request' });
    }
  }

  // 4. 共有データJSON取得API (GET /api/shares/:shareId)
  const apiMatch = pathname.match(/^\/api\/shares\/([^/]+)$/);
  if (req.method === 'GET' && apiMatch) {
    const shareId = decodeURIComponent(apiMatch[1]);
    const shareData = await resolveShareData(shareId, query);
    if (!shareData) {
      return sendJson(res, 404, { error: 'Shared memory not found' });
    }
    return sendJson(res, 200, shareData);
  }

  // 5. 共有マップWebビューア（閲覧専用）(GET /share/:shareId or /shares/:shareId)
  const shareMatch = pathname.match(/^\/shares?\/([^/]+)$/);
  if (req.method === 'GET' && shareMatch) {
    const shareId = decodeURIComponent(shareMatch[1]);
    const shareData = await resolveShareData(shareId, query);
    if (!shareData) {
      return sendHtml(res, 404, renderNotFoundHtml(shareId));
    }
    const mapsApiKey = query.key || GOOGLE_MAPS_API_KEY;
    const html = renderShareViewerHtml(shareData, mapsApiKey);
    return sendHtml(res, 200, html);
  }

  return sendHtml(res, 404, renderNotFoundHtml(pathname));
}

/**
 * 共有データが見つからない場合の404画面
 */
function renderNotFoundHtml(shareId) {
  return `<!DOCTYPE html>
<html lang="ja">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>共有リンクが見つかりません | My Map</title>
  <style>
    body {
      margin: 0;
      font-family: -apple-system, BlinkMacSystemFont, "Hiragino Sans", "Noto Sans JP", sans-serif;
      background: #f5f5f7;
      color: #222;
      display: flex;
      align-items: center;
      justify-content: center;
      min-height: 100vh;
      padding: 24px;
      box-sizing: border-box;
    }
    .card {
      background: #fff;
      border-radius: 16px;
      padding: 32px 24px;
      max-width: 420px;
      width: 100%;
      box-shadow: 0 8px 30px rgba(0,0,0,0.08);
      text-align: center;
    }
    h1 { font-size: 20px; margin: 0 0 12px; }
    p { font-size: 14px; color: #666; line-height: 1.6; margin: 0 0 24px; }
    a.btn {
      display: inline-block;
      background: #222;
      color: #fff;
      text-decoration: none;
      padding: 12px 20px;
      border-radius: 10px;
      font-size: 14px;
      font-weight: 600;
    }
  </style>
</head>
<body>
  <div class="card">
    <h1>共有された思い出が見つかりません</h1>
    <p>共有リンク（ID: ${escapeHtml(shareId)}）の有効期限が切れているか、削除された可能性があります。</p>
    <a class="btn" href="/share/demo">サンプルの共有マップを見る</a>
  </div>
</body>
</html>`;
}

/**
 * 閲覧専用WebマップビューアのHTML生成（動的OGPメタタグ付き）
 */
function renderShareViewerHtml(shareData, googleMapsApiKey) {
  const reviewPins = (shareData.pins || []).filter((p) => !p.isRouteWaypointOnly);
  const spotNames = reviewPins.map((p) => p.placeName).filter(Boolean);
  const spotSummary = spotNames.length > 0
    ? `訪問スポット（${spotNames.length}件）: ${spotNames.slice(0, 5).join(' → ')}`
    : '地図上のピンをタップして思い出の写真やレビューを閲覧できます。';

  // OGP用の代表写真を取得
  let ogImageUrl = '';
  for (const pin of reviewPins) {
    if (pin.photos && pin.photos.length > 0 && pin.photos[0].url) {
      ogImageUrl = pin.photos[0].url;
      break;
    }
  }

  const pageTitle = `${shareData.title} | 思い出共有マップ`;
  const pageDesc = `期間: ${shareData.formattedDateRange} / 総移動距離: ${shareData.formattedDistance} | ${spotSummary}`;
  const serializedData = safeJsonForScript(shareData);
  const serializedApiKey = safeJsonForScript(googleMapsApiKey || '');

  return `<!DOCTYPE html>
<html lang="ja">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no" />
  <title>${escapeHtml(pageTitle)}</title>
  <meta name="description" content="${escapeHtml(pageDesc)}" />

  <!-- 動的OGPメタタグ -->
  <meta property="og:type" content="website" />
  <meta property="og:title" content="${escapeHtml(pageTitle)}" />
  <meta property="og:description" content="${escapeHtml(pageDesc)}" />
  ${ogImageUrl ? `<meta property="og:image" content="${escapeHtml(ogImageUrl)}" />` : ''}
  <meta name="twitter:card" content="${ogImageUrl ? 'summary_large_image' : 'summary'}" />
  <meta name="twitter:title" content="${escapeHtml(pageTitle)}" />
  <meta name="twitter:description" content="${escapeHtml(pageDesc)}" />

  <!-- Leaflet CSS（Google Maps APIキー未設定時や制限時のフォールバック用） -->
  <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" crossorigin="" />

  <style>
    :root {
      --dark-grey: #222222;
      --primary-grey: #666666;
      --light-grey: #E5E5EA;
      --surface-grey: #F5F5F7;
      --pure-white: #FFFFFF;
      --accent-amber: #F59E0B;
    }

    * {
      box-sizing: border-box;
      -webkit-tap-highlight-color: transparent;
    }

    body, html {
      margin: 0;
      padding: 0;
      width: 100%;
      height: 100%;
      overflow: hidden;
      font-family: -apple-system, BlinkMacSystemFont, "Hiragino Sans", "Noto Sans JP", sans-serif;
      color: var(--dark-grey);
      background: var(--surface-grey);
    }

    /* 上部ヘッダー（閲覧専用） */
    .top-header {
      position: fixed;
      top: 12px;
      left: 12px;
      right: 12px;
      z-index: 1000;
      background: rgba(255, 255, 255, 0.95);
      backdrop-filter: blur(12px);
      -webkit-backdrop-filter: blur(12px);
      border-radius: 16px;
      padding: 14px 18px;
      box-shadow: 0 4px 20px rgba(0, 0, 0, 0.10);
      border: 1px solid rgba(0, 0, 0, 0.06);
      max-width: 680px;
      margin: 0 auto;
    }

    .header-top-row {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 12px;
      margin-bottom: 6px;
    }

    .trip-title {
      font-size: 19px;
      font-weight: 800;
      color: var(--dark-grey);
      margin: 0;
      line-height: 1.25;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }

    .readonly-badge {
      flex-shrink: 0;
      display: inline-flex;
      align-items: center;
      gap: 4px;
      background: var(--surface-grey);
      color: var(--primary-grey);
      border: 1px solid var(--light-grey);
      font-size: 11px;
      font-weight: 700;
      padding: 4px 10px;
      border-radius: 999px;
    }

    .header-meta-row {
      display: flex;
      align-items: center;
      flex-wrap: wrap;
      gap: 14px;
      font-size: 13px;
      color: var(--primary-grey);
      font-weight: 500;
    }

    .meta-item {
      display: inline-flex;
      align-items: center;
      gap: 5px;
    }

    .meta-item strong {
      color: var(--dark-grey);
      font-weight: 700;
    }

    /* 地図キャンバス */
    #map-container {
      width: 100%;
      height: 100%;
      position: absolute;
      inset: 0;
      z-index: 1;
    }

    /* スポット一覧横スクロールバー（ピン選択チップ） */
    .spot-chips-bar {
      position: fixed;
      bottom: 20px;
      left: 0;
      right: 0;
      z-index: 900;
      display: flex;
      gap: 8px;
      overflow-x: auto;
      padding: 8px 16px;
      max-width: 680px;
      margin: 0 auto;
      scrollbar-width: none;
    }
    .spot-chips-bar::-webkit-scrollbar {
      display: none;
    }

    .spot-chip {
      flex-shrink: 0;
      display: inline-flex;
      align-items: center;
      gap: 8px;
      background: rgba(255, 255, 255, 0.96);
      border: 1.5px solid var(--light-grey);
      border-radius: 999px;
      padding: 8px 14px;
      font-size: 13px;
      font-weight: 700;
      color: var(--dark-grey);
      box-shadow: 0 3px 12px rgba(0, 0, 0, 0.12);
      cursor: pointer;
      transition: all 0.18s ease;
    }

    .spot-chip.active {
      background: var(--dark-grey);
      color: var(--pure-white);
      border-color: var(--dark-grey);
      transform: translateY(-2px);
    }

    .spot-chip-num {
      width: 22px;
      height: 22px;
      border-radius: 50%;
      background: var(--surface-grey);
      color: var(--dark-grey);
      display: inline-flex;
      align-items: center;
      justify-content: center;
      font-size: 11px;
      font-weight: 800;
    }

    .spot-chip.active .spot-chip-num {
      background: var(--pure-white);
      color: var(--dark-grey);
    }

    /* ピン押下時の詳細カード（ボトムシート風ドロワー） */
    .detail-sheet {
      position: fixed;
      left: 12px;
      right: 12px;
      bottom: 12px;
      z-index: 1100;
      max-width: 680px;
      margin: 0 auto;
      background: var(--pure-white);
      border-radius: 20px;
      box-shadow: 0 10px 40px rgba(0, 0, 0, 0.22);
      border: 1px solid var(--light-grey);
      transform: translateY(120%);
      transition: transform 0.28s cubic-bezier(0.2, 0.8, 0.2, 1);
      max-height: 72vh;
      display: flex;
      flex-direction: column;
      overflow: hidden;
    }

    .detail-sheet.open {
      transform: translateY(0);
    }

    .sheet-header {
      padding: 16px 20px 12px;
      border-bottom: 1px solid var(--light-grey);
      display: flex;
      align-items: flex-start;
      justify-content: space-between;
      gap: 12px;
    }

    .sheet-title-wrap {
      flex: 1;
      min-width: 0;
    }

    .sheet-spot-badge {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      font-size: 11px;
      font-weight: 700;
      color: var(--primary-grey);
      margin-bottom: 4px;
    }

    .sheet-place-name {
      font-size: 20px;
      font-weight: 800;
      margin: 0 0 4px;
      color: var(--dark-grey);
      line-height: 1.3;
    }

    .sheet-address {
      font-size: 12px;
      color: var(--primary-grey);
      margin: 0;
      line-height: 1.4;
    }

    .sheet-close-btn {
      background: var(--surface-grey);
      border: none;
      width: 34px;
      height: 34px;
      border-radius: 50%;
      font-size: 18px;
      color: var(--dark-grey);
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
      flex-shrink: 0;
    }

    .sheet-body {
      padding: 16px 20px 20px;
      overflow-y: auto;
    }

    .rating-time-row {
      display: flex;
      align-items: center;
      flex-wrap: wrap;
      gap: 12px;
      margin-bottom: 12px;
    }

    .stars-box {
      color: var(--accent-amber);
      font-size: 16px;
      letter-spacing: 1px;
      font-weight: 700;
    }

    .time-badge {
      font-size: 12px;
      color: var(--primary-grey);
      background: var(--surface-grey);
      padding: 4px 10px;
      border-radius: 6px;
      font-weight: 600;
    }

    .review-comment {
      font-size: 14px;
      line-height: 1.65;
      color: var(--dark-grey);
      background: var(--surface-grey);
      padding: 12px 14px;
      border-radius: 12px;
      margin: 0 0 16px;
      white-space: pre-wrap;
    }

    .photo-gallery {
      display: flex;
      gap: 10px;
      overflow-x: auto;
      padding-bottom: 6px;
      margin-bottom: 16px;
    }

    .photo-item {
      flex-shrink: 0;
      width: 150px;
      height: 150px;
      border-radius: 12px;
      overflow: hidden;
      border: 1px solid var(--light-grey);
      background: var(--surface-grey);
      cursor: pointer;
      position: relative;
    }

    .photo-item img {
      width: 100%;
      height: 100%;
      object-fit: cover;
      display: block;
    }

    .sheet-footer {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 10px;
      padding-top: 8px;
      border-top: 1px solid var(--light-grey);
    }

    .nav-btns {
      display: flex;
      gap: 8px;
    }

    .nav-btn {
      background: var(--surface-grey);
      border: 1px solid var(--light-grey);
      color: var(--dark-grey);
      border-radius: 10px;
      padding: 8px 12px;
      font-size: 12px;
      font-weight: 700;
      cursor: pointer;
    }
    .nav-btn:disabled {
      opacity: 0.4;
      cursor: default;
    }

    .open-gmap-link {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      background: var(--dark-grey);
      color: var(--pure-white);
      text-decoration: none;
      padding: 9px 14px;
      border-radius: 10px;
      font-size: 12px;
      font-weight: 700;
    }

    /* カスタムマップピンマーカー（Leaflet / Google Maps 共通スタイル） */
    .custom-pin-marker {
      display: flex;
      flex-direction: column;
      align-items: center;
      cursor: pointer;
      transition: transform 0.15s ease;
    }
    .custom-pin-marker:hover {
      transform: scale(1.08);
    }
    .custom-pin-bubble {
      display: flex;
      align-items: center;
      gap: 6px;
      background: var(--dark-grey);
      color: var(--pure-white);
      padding: 5px 10px;
      border-radius: 999px;
      font-size: 12px;
      font-weight: 800;
      box-shadow: 0 4px 12px rgba(0, 0, 0, 0.28);
      border: 2px solid var(--pure-white);
      white-space: nowrap;
      max-width: 160px;
    }
    .custom-pin-bubble.selected {
      background: #E11D48;
      transform: scale(1.1);
    }
    .custom-pin-thumb {
      width: 22px;
      height: 22px;
      border-radius: 50%;
      object-fit: cover;
      border: 1px solid #fff;
      flex-shrink: 0;
    }
    .custom-pin-label {
      overflow: hidden;
      text-overflow: ellipsis;
    }
    .custom-pin-arrow {
      width: 0;
      height: 0;
      border-left: 6px solid transparent;
      border-right: 6px solid transparent;
      border-top: 7px solid var(--dark-grey);
      margin-top: -1px;
    }
    .custom-pin-arrow.selected {
      border-top-color: #E11D48;
    }

    /* 写真拡大ライトボックスモーダル */
    .lightbox-overlay {
      position: fixed;
      inset: 0;
      background: rgba(0, 0, 0, 0.88);
      z-index: 2000;
      display: none;
      align-items: center;
      justify-content: center;
      padding: 20px;
    }
    .lightbox-overlay.active {
      display: flex;
    }
    .lightbox-overlay img {
      max-width: 95vw;
      max-height: 88vh;
      border-radius: 12px;
      object-fit: contain;
    }
  </style>
</head>
<body>

  <!-- 上部ヘッダー（閲覧専用情報） -->
  <header class="top-header">
    <div class="header-top-row">
      <h1 class="trip-title" id="trip-title">${escapeHtml(shareData.title)}</h1>
      <span class="readonly-badge" title="このマップは閲覧専用です">🔒 閲覧専用</span>
    </div>
    <div class="header-meta-row">
      <span class="meta-item">📅 <span id="trip-date">${escapeHtml(shareData.formattedDateRange)}</span></span>
      <span class="meta-item">🚶 総移動距離: <strong id="trip-distance">${escapeHtml(shareData.formattedDistance)}</strong></span>
      <span class="meta-item">📍 スポット: <strong>${reviewPins.length}件</strong></span>
    </div>
  </header>

  <!-- 地図表示領域 -->
  <div id="map-container"></div>

  <!-- 下部スポット選択チップ一覧 -->
  <div class="spot-chips-bar" id="spot-chips-bar"></div>

  <!-- ピン押下時の詳細ボトムシート（閲覧専用） -->
  <section class="detail-sheet" id="detail-sheet" aria-live="polite">
    <div class="sheet-header">
      <div class="sheet-title-wrap">
        <div class="sheet-spot-badge" id="sheet-spot-badge">SPOT 1</div>
        <h2 class="sheet-place-name" id="sheet-place-name"></h2>
        <p class="sheet-address" id="sheet-address"></p>
      </div>
      <button type="button" class="sheet-close-btn" id="sheet-close-btn" aria-label="閉じる">✕</button>
    </div>
    <div class="sheet-body">
      <div class="rating-time-row" id="sheet-rating-time"></div>
      <div class="review-comment" id="sheet-comment"></div>
      <div class="photo-gallery" id="sheet-photos"></div>
      <div class="sheet-footer">
        <div class="nav-btns">
          <button type="button" class="nav-btn" id="prev-pin-btn">◀ 前のピン</button>
          <button type="button" class="nav-btn" id="next-pin-btn">次のピン ▶</button>
        </div>
        <a class="open-gmap-link" id="open-gmap-link" href="#" target="_blank" rel="noopener noreferrer">
          Google Mapで開く ↗
        </a>
      </div>
    </div>
  </section>

  <!-- 写真拡大モーダル -->
  <div class="lightbox-overlay" id="lightbox-overlay">
    <img id="lightbox-img" src="" alt="拡大写真" />
  </div>

  <!-- Leaflet JS（フォールバック＆ユニバーサル描画用） -->
  <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js" crossorigin=""></script>

  <script>
    const SHARE_DATA = ${serializedData};
    const GOOGLE_MAPS_API_KEY = ${serializedApiKey};

    const allPins = Array.isArray(SHARE_DATA.pins) ? SHARE_DATA.pins : [];
    const reviewPins = allPins.filter(p => !p.isRouteWaypointOnly);
    const routePoints = Array.isArray(SHARE_DATA.routePoints) ? SHARE_DATA.routePoints : [];

    let selectedPinIndex = -1;
    let mapController = null;

    // UI要素の取得
    const chipsBar = document.getElementById('spot-chips-bar');
    const detailSheet = document.getElementById('detail-sheet');
    const sheetSpotBadge = document.getElementById('sheet-spot-badge');
    const sheetPlaceName = document.getElementById('sheet-place-name');
    const sheetAddress = document.getElementById('sheet-address');
    const sheetRatingTime = document.getElementById('sheet-rating-time');
    const sheetComment = document.getElementById('sheet-comment');
    const sheetPhotos = document.getElementById('sheet-photos');
    const prevPinBtn = document.getElementById('prev-pin-btn');
    const nextPinBtn = document.getElementById('next-pin-btn');
    const openGmapLink = document.getElementById('open-gmap-link');
    const lightboxOverlay = document.getElementById('lightbox-overlay');
    const lightboxImg = document.getElementById('lightbox-img');

    document.getElementById('sheet-close-btn').addEventListener('click', () => {
      detailSheet.classList.remove('open');
      selectedPinIndex = -1;
      updateActiveUI();
    });

    lightboxOverlay.addEventListener('click', () => {
      lightboxOverlay.classList.remove('active');
    });

    prevPinBtn.addEventListener('click', () => {
      if (selectedPinIndex > 0) {
        selectPin(selectedPinIndex - 1);
      }
    });

    nextPinBtn.addEventListener('click', () => {
      if (selectedPinIndex < reviewPins.length - 1) {
        selectPin(selectedPinIndex + 1);
      }
    });

    // 下部スポット選択チップの生成
    function renderSpotChips() {
      chipsBar.innerHTML = '';
      reviewPins.forEach((pin, idx) => {
        const chip = document.createElement('button');
        chip.type = 'button';
        chip.className = 'spot-chip';
        chip.dataset.index = idx;

        const numSpan = document.createElement('span');
        numSpan.className = 'spot-chip-num';
        numSpan.textContent = String(idx + 1);

        const nameSpan = document.createElement('span');
        nameSpan.textContent = pin.placeName || ('スポット ' + (idx + 1));

        chip.appendChild(numSpan);
        chip.appendChild(nameSpan);
        chip.addEventListener('click', () => selectPin(idx));
        chipsBar.appendChild(chip);
      });
    }

    // ピンを選択して詳細ボトムシートを表示
    function selectPin(index) {
      if (index < 0 || index >= reviewPins.length) return;
      selectedPinIndex = index;
      const pin = reviewPins[index];

      sheetSpotBadge.textContent = 'SPOT ' + (index + 1) + ' / ' + reviewPins.length;
      sheetPlaceName.textContent = pin.placeName || '名称未設定スポット';
      sheetAddress.textContent = pin.address || pin.prefecture || '';

      // 評価と滞在時間
      sheetRatingTime.innerHTML = '';
      if (pin.rating && pin.rating >= 1 && pin.rating <= 5) {
        const stars = document.createElement('span');
        stars.className = 'stars-box';
        stars.textContent = '★'.repeat(pin.rating) + '☆'.repeat(5 - pin.rating);
        sheetRatingTime.appendChild(stars);
      }
      if (pin.startTime || pin.endTime) {
        const timeBadge = document.createElement('span');
        timeBadge.className = 'time-badge';
        timeBadge.textContent = '🕒 ' + (pin.startTime || '') + (pin.endTime ? ' 〜 ' + pin.endTime : '');
        sheetRatingTime.appendChild(timeBadge);
      }

      // レビューコメント
      if (pin.comment && pin.comment.trim()) {
        sheetComment.style.display = 'block';
        sheetComment.textContent = pin.comment;
      } else {
        sheetComment.style.display = 'none';
        sheetComment.textContent = '';
      }

      // 写真一覧
      sheetPhotos.innerHTML = '';
      const photos = Array.isArray(pin.photos) ? pin.photos : [];
      if (photos.length > 0) {
        sheetPhotos.style.display = 'flex';
        photos.forEach((ph) => {
          if (!ph || !ph.url) return;
          const item = document.createElement('div');
          item.className = 'photo-item';
          const img = document.createElement('img');
          img.src = ph.url;
          img.alt = ph.label || pin.placeName || '思い出の写真';
          img.loading = 'lazy';
          item.addEventListener('click', () => {
            lightboxImg.src = ph.url;
            lightboxOverlay.classList.add('active');
          });
          item.appendChild(img);
          sheetPhotos.appendChild(item);
        });
      } else {
        sheetPhotos.style.display = 'none';
      }

      // 前後ボタン制御
      prevPinBtn.disabled = index <= 0;
      nextPinBtn.disabled = index >= reviewPins.length - 1;

      // Google Mapで開くリンク
      const query = encodeURIComponent(
        (pin.placeName ? pin.placeName + ' ' : '') + (pin.address || (pin.latitude + ',' + pin.longitude))
      );
      openGmapLink.href = 'https://www.google.com/maps/search/?api=1&query=' + query;

      detailSheet.classList.add('open');
      updateActiveUI();

      if (mapController && typeof mapController.focusPin === 'function') {
        mapController.focusPin(index, pin);
      }
    }

    function updateActiveUI() {
      const chips = chipsBar.querySelectorAll('.spot-chip');
      chips.forEach((chip, idx) => {
        chip.classList.toggle('active', idx === selectedPinIndex);
      });
      if (mapController && typeof mapController.highlightMarker === 'function') {
        mapController.highlightMarker(selectedPinIndex);
      }
    }

    // カスタムピンHTML要素の生成
    function createCustomPinHtml(pin, index, isSelected) {
      const hasPhoto = Array.isArray(pin.photos) && pin.photos.length > 0 && pin.photos[0].url;
      const thumbHtml = hasPhoto
        ? '<img class="custom-pin-thumb" src="' + pin.photos[0].url.replace(/"/g, '&quot;') + '" alt="" />'
        : '<span>' + (index + 1) + '</span>';
      const starText = pin.rating ? ' ★' + pin.rating : '';
      const safeName = (pin.placeName || ('スポット' + (index + 1)))
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;');

      return (
        '<div class="custom-pin-marker">' +
          '<div class="custom-pin-bubble ' + (isSelected ? 'selected' : '') + '">' +
            thumbHtml +
            '<span class="custom-pin-label">' + safeName + starText + '</span>' +
          '</div>' +
          '<div class="custom-pin-arrow ' + (isSelected ? 'selected' : '') + '"></div>' +
        '</div>'
      );
    }

    // Leaflet 地図エンジンによる描画（APIキー不要・制限エラー時にも確実に動作）
    function initLeafletMap() {
      const container = document.getElementById('map-container');
      container.innerHTML = '';

      const defaultCenter = reviewPins.length > 0
        ? [reviewPins[0].latitude, reviewPins[0].longitude]
        : [35.6812, 139.7671];

      const map = L.map(container, {
        zoomControl: false,
      }).setView(defaultCenter, 13);

      L.control.zoom({ position: 'bottomright' }).addTo(map);

      L.tileLayer('https://mt{s}.google.com/vt/lyrs=m&x={x}&y={y}&z={z}&hl=ja', {
        attribution: '&copy; Google Maps',
        subdomains: ['0', '1', '2', '3'],
        maxZoom: 20,
      }).addTo(map);

      const boundsPoints = [];

      // 移動ルート（Polyline）の描画
      if (routePoints.length >= 2) {
        const latlngs = routePoints.map(rp => [rp.lat, rp.lng]);
        L.polyline(latlngs, {
          color: '#222222',
          weight: 4,
          opacity: 0.75,
          dashArray: '8, 6',
        }).addTo(map);
        latlngs.forEach(pt => boundsPoints.push(pt));
      }

      // 各レビューピンの描画
      const markers = reviewPins.map((pin, idx) => {
        const pos = [pin.latitude, pin.longitude];
        boundsPoints.push(pos);

        const icon = L.divIcon({
          className: '',
          html: createCustomPinHtml(pin, idx, false),
          iconSize: [140, 42],
          iconAnchor: [70, 42],
        });

        const marker = L.marker(pos, { icon }).addTo(map);
        marker.on('click', () => selectPin(idx));
        return marker;
      });

      if (boundsPoints.length >= 2) {
        map.fitBounds(boundsPoints, { padding: [90, 50], maxZoom: 16 });
      } else if (boundsPoints.length === 1) {
        map.setView(boundsPoints[0], 15);
      }

      mapController = {
        focusPin(idx, pin) {
          map.flyTo([pin.latitude, pin.longitude], Math.max(map.getZoom(), 15), {
            duration: 0.5,
          });
        },
        highlightMarker(selectedIdx) {
          markers.forEach((m, idx) => {
            const icon = L.divIcon({
              className: '',
              html: createCustomPinHtml(reviewPins[idx], idx, idx === selectedIdx),
              iconSize: [140, 42],
              iconAnchor: [70, 42],
            });
            m.setIcon(icon);
          });
        },
      };
    }

    // Google Maps JavaScript API による描画（APIキー設定時）
    function initGoogleMap() {
      if (!window.google || !window.google.maps) {
        initLeafletMap();
        return;
      }

      const container = document.getElementById('map-container');
      const defaultCenter = reviewPins.length > 0
        ? { lat: reviewPins[0].latitude, lng: reviewPins[0].longitude }
        : { lat: 35.6812, lng: 139.7671 };

      const map = new google.maps.Map(container, {
        center: defaultCenter,
        zoom: 13,
        disableDefaultUI: true,
        zoomControl: true,
        clickableIcons: false,
      });

      const bounds = new google.maps.LatLngBounds();
      let hasBounds = false;

      if (routePoints.length >= 2) {
        const path = routePoints.map(rp => ({ lat: rp.lat, lng: rp.lng }));
        new google.maps.Polyline({
          path,
          geodesic: true,
          strokeColor: '#222222',
          strokeOpacity: 0.8,
          strokeWeight: 4,
          map,
        });
        path.forEach(pt => {
          bounds.extend(pt);
          hasBounds = true;
        });
      }

      const markers = reviewPins.map((pin, idx) => {
        const position = { lat: pin.latitude, lng: pin.longitude };
        bounds.extend(position);
        hasBounds = true;

        const marker = new google.maps.Marker({
          position,
          map,
          title: pin.placeName,
          label: {
            text: String(idx + 1),
            color: '#FFFFFF',
            fontWeight: 'bold',
          },
        });
        marker.addListener('click', () => selectPin(idx));
        return marker;
      });

      if (hasBounds) {
        map.fitBounds(bounds, { top: 100, bottom: 100, left: 40, right: 40 });
      }

      mapController = {
        focusPin(idx, pin) {
          map.panTo({ lat: pin.latitude, lng: pin.longitude });
          if (map.getZoom() < 15) map.setZoom(15);
        },
        highlightMarker(selectedIdx) {
          markers.forEach((m, idx) => {
            m.setAnimation(idx === selectedIdx ? google.maps.Animation.BOUNCE : null);
          });
        },
      };
    }

    // Google Maps 認証失敗時の自動フォールバックフック
    window.gm_authFailure = function() {
      console.warn('Google Maps API key auth error. Falling back to interactive map.');
      initLeafletMap();
    };

    // 初期化実行
    renderSpotChips();

    if (GOOGLE_MAPS_API_KEY && GOOGLE_MAPS_API_KEY.trim().length > 0) {
      const script = document.createElement('script');
      script.src = 'https://maps.googleapis.com/maps/api/js?key=' + encodeURIComponent(GOOGLE_MAPS_API_KEY);
      script.async = true;
      script.onload = () => initGoogleMap();
      script.onerror = () => initLeafletMap();
      document.head.appendChild(script);
    } else {
      initLeafletMap();
    }

    // 初期状態で最初のピンを軽く案内表示
    if (reviewPins.length > 0) {
      setTimeout(() => selectPin(0), 400);
    }
  </script>
</body>
</html>`;
}

const server = http.createServer((req, res) => {
  handleRequest(req, res).catch((err) => {
    console.error('Unhandled request error:', err);
    if (!res.headersSent) {
      sendJson(res, 500, { error: 'Internal server error' });
    }
  });
});

if (require.main === module) {
  server.listen(PORT, () => {
    console.log(`My Map Share Viewer listening on port ${PORT}`);
  });
}

module.exports = { server, handleRequest, sanitizeShareData, decodeEmbeddedData, renderShareViewerHtml };
