# DayCast proxy deployment

Deployed September 5, 2026. Version: `57517d01-f640-42b9-b889-7e630fa144b8`.

URL: https://daycast-grok-proxy.stephendev.workers.dev

Quota activation: September 6 at 00:00 UTC — September 5 at 7:00 p.m. America/Chicago. Proxied AI requests remain unavailable until that time; activation is automatic in the deployed code.

Live `/v1/health` returned HTTP 200 with `ok: true`. Live `/v1/alert` returned HTTP 200 and successfully read the new Durable Object ledger. The existing XAI_API_KEY and PROXY_SECRET bindings were preserved; quota limits remain unchanged. The daily report cron is configured for 23:59 UTC.

104 proxy tests passed before deployment; final configuration dry run passed. No paid provider request was made. Subscriber happy-path behavior after activation has not yet been verified.

Preserve `QUOTA_START_DAY = "2026-09-06"` on future deployments. Rollback must retain the SQLite ledger or disable forwarding; do not return to the old KV-counter version.

Cloudflare deployment record confirms 100% traffic on the new version.
