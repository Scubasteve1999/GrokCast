# App Store Connect — App Privacy for DayCast

Apple’s App Privacy questionnaire is **not** available via the App Store Connect API. Apply these answers in the UI:

**Path:** [App Store Connect → DayCast Weather → App Privacy](https://appstoreconnect.apple.com/apps/6798461672/appPrivacy)

Live listing is **6798461672**. Do not use the retired record `6780682022`.

## Data types to declare

| Data type | Linked to user? | Used for tracking? | Purpose |
|-----------|-----------------|--------------------|---------|
| **Device ID** | No | No | Analytics |
| **Product Interaction** | No | No | Analytics |
| **Precise Location** | No | No | App Functionality |
| **Coarse Location** | No | No | App Functionality |
| **Photos or Videos** | No | No | App Functionality |
| **Other User Content** | No | No | App Functionality |

### Photos or Videos

Storm Spotter: the user picks a photo in `PhotosPicker`. The resized image is sent to xAI through the Pro proxy for analysis. Library is not scanned. Camera is not used.

### Other User Content

AI chat / quick prompts / Today's Take questions: the typed (or canned) prompt plus weather context go to the proxy → xAI. No account, email, or contacts.

## Tracking

- **Data Used to Track You:** No (PostHog session replay / screen capture / ATT are off)

## Matches in the app

- `DayCast/PrivacyInfo.xcprivacy` — Device ID + Product Interaction (Analytics); location, photos, other user content (App Functionality)
- Settings → **Share analytics** opt-out
- Privacy policy: https://scubasteve1999.github.io/GrokCast/privacy.html
