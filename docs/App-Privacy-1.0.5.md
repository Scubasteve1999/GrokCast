# App Store Connect — App Privacy for DayCast 1.0.5

Apple’s App Privacy questionnaire is **not** available via the App Store Connect API. Apply these answers in the UI (can be edited while 1.0.4 is Waiting for Review):

**Path:** [App Store Connect → DayCast → App Privacy](https://appstoreconnect.apple.com/apps/6780682022/appPrivacy)

## Data types to declare

| Data type | Linked to user? | Used for tracking? | Purpose |
|-----------|-----------------|--------------------|---------|
| **Device ID** | No | No | Analytics |
| **Product Interaction** | No | No | Analytics |
| **Precise Location** | No | No | App Functionality |
| **Coarse Location** | No | No | App Functionality |

## Tracking

- **Data Used to Track You:** No (PostHog session replay / screen capture / ATT are off)

## Matches in the app

- `GrokCast/PrivacyInfo.xcprivacy` — Device ID + Product Interaction (Analytics), location (App Functionality)
- Settings → **Share analytics** opt-out
- Privacy policy: https://scubasteve1999.github.io/SpotterCast/privacy/
