# DayCast Pro — hosted Grok proxy

Pro subscribers call this proxy instead of xAI directly. Your **xAI API key stays on the server**.

## Deploy (Cloudflare Workers)

1. Install Wrangler: `npm i -g wrangler`
2. Set secrets:
   ```bash
   cd server/grok-proxy
   wrangler secret put XAI_API_KEY
   wrangler secret put PROXY_SECRET   # optional; app sends Bearer daycast-pro by default
   ```
3. Deploy:
   ```bash
   wrangler deploy
   ```
4. Production is already wired in `DayCastProConfig.productionGrokProxyBaseURL`:
   ```swift
   static let productionGrokProxyBaseURL =
     "https://daycast-grok-proxy.stephendev.workers.dev/v1"
   ```
   Optional local override: `DeveloperAPIKey.grokProxyBaseURL` (simulator / staging).
   Do **not** point at `grok-proxy.daycast.app` unless that hostname is deployed and DNS resolves.

## Local dev

```bash
cd server/grok-proxy
XAI_API_KEY=xai-... node worker.js
# listens on :8787 — set DeveloperAPIKey.grokProxyBaseURL to http://127.0.0.1:8787/v1 for simulator
```

## App Store Connect

Create subscription group **DayCast Pro** with:

| Product ID | Type |
|------------|------|
| `com.scubasteve1999.DayCast.pro.monthly` | Auto-renewable monthly |
| `com.scubasteve1999.DayCast.pro.yearly` | Auto-renewable yearly |

Link `DayCast/Configuration/GrokProducts.storekit` in Xcode: **Product → Scheme → Run → Options → StoreKit Configuration**.

## Pro feature gates (app)

| Feature | Free | Pro |
|---------|------|-----|
| Today / forecast / alerts / live radar | ✅ | ✅ |
| Grok AI (chat, brief, Storm Spotter, Imagine) | ❌ (BYOK key OK) | ✅ via hosted proxy **or** BYOK |
| Radar FUTURE | ❌ | ✅ |
| Live Activity | ❌ | ✅ |
| Widget Grok one-liner | ❌ | ✅ |
| Saved locations | 1 | Unlimited |
| BYOK developer key | ✅ (advanced) | ✅ |

> **Note:** Pro AI routes through the committed production worker. Other Pro perks (radar FUTURE, Live Activity, unlimited locations) still unlock with Pro alone. A Keychain xAI key remains a BYOK fallback.

## Security notes (v1)

- The app sends `X-DayCast-Subscription-Id` (StoreKit `originalID`) for rate limiting.
- **v1 trusts client-side StoreKit** — acceptable for TestFlight; before scale, add [App Store Server API](https://developer.apple.com/documentation/appstoreserverapi) verification on the proxy.

## Rate limits

Default: **200 requests / subscription ID / day** (`DAILY_REQ_LIMIT` env var).
