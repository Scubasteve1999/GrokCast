# GrokCast Pro — hosted Grok proxy

Pro subscribers call this proxy instead of xAI directly. Your **xAI API key stays on the server**.

## Deploy (Cloudflare Workers)

1. Install Wrangler: `npm i -g wrangler`
2. Set secrets:
   ```bash
   cd server/grok-proxy
   wrangler secret put XAI_API_KEY
   wrangler secret put PROXY_SECRET   # optional; app sends Bearer grokcast-pro by default
   ```
3. Deploy:
   ```bash
   wrangler deploy
   ```
4. Copy the worker URL into `GrokCast/Config/GrokCastProConfig.swift`:
   ```swift
   static let grokProxyBaseURL: String? = "https://YOUR-WORKER.workers.dev/v1"
   ```

## Local dev

```bash
cd server/grok-proxy
XAI_API_KEY=xai-... node worker.js
# listens on :8787 — point GrokCastProConfig to http://127.0.0.1:8787/v1 for simulator
```

## App Store Connect

Create subscription group **GrokCast Pro** with:

| Product ID | Type |
|------------|------|
| `com.scubasteve1999.GrokCast.pro.monthly` | Auto-renewable monthly |
| `com.scubasteve1999.GrokCast.pro.yearly` | Auto-renewable yearly |

Link `GrokCast/Configuration/GrokProducts.storekit` in Xcode: **Product → Scheme → Run → Options → StoreKit Configuration**.

## Pro feature gates (app)

| Feature | Free | Pro |
|---------|------|-----|
| Today / forecast / alerts / live radar | ✅ | ✅ |
| Grok AI (chat, brief, Storm Spotter, Imagine) | ❌ | ✅ |
| Radar FUTURE | ❌ | ✅ |
| Live Activity | ❌ | ✅ |
| Widget Grok one-liner | ❌ | ✅ |
| Saved locations | 1 | Unlimited |
| BYOK developer key | ✅ (advanced) | ✅ |

## Security notes (v1)

- The app sends `X-GrokCast-Subscription-Id` (StoreKit `originalID`) for rate limiting.
- **v1 trusts client-side StoreKit** — acceptable for TestFlight; before scale, add [App Store Server API](https://developer.apple.com/documentation/appstoreserverapi) verification on the proxy.

## Rate limits

Default: **200 requests / subscription ID / day** (`DAILY_REQ_LIMIT` env var).
