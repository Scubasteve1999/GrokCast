# App Store Connect API key setup (one time)

1. Go to appstoreconnect.apple.com → **Users and Access** → **Integrations** tab
   → **App Store Connect API** → **Team Keys** → **Generate API Key**.
2. Name: anything (e.g. "fastlane"). Access: **App Manager**.
3. Download the `AuthKey_XXXXXXXXXX.p8` file (only downloadable ONCE) and move it
   into this `fastlane/` folder.
4. Note the **Key ID** (on the key row) and the **Issuer ID** (top of the page).
5. Create `fastlane/asc_api_key.json` (gitignored) with:

```json
{
  "key_id": "YOUR_KEY_ID",
  "issuer_id": "YOUR_ISSUER_ID",
  "key_filepath": "fastlane/AuthKey_YOUR_KEY_ID.p8",
  "in_house": false
}
```

Then upload screenshots any time with:

```bash
cd ~/Desktop/GrokCast && LC_ALL=en_US.UTF-8 fastlane deliver
```

Screenshots live in `fastlane/screenshots/en-US/` — 1320×2868 PNGs upload to the
iPhone 6.9" slot. Filename order = display order.
