import Foundation

/// Public Sky Check desk copy — weather questions first, photo check second.
/// Tests lock these strings so chaser/field tone cannot sneak back onto the civilian desk.
enum SkyCheckDeskCopy {
  static let photoCTA = "Check this sky"
  static let checkAnotherCTA = "Check another"
  static let cameraSource = "Camera"
  static let librarySource = "Photo Library"
  static let photoGlyph = "camera"
  static let cameraUnavailable =
    "This device has no camera. Pick a photo from the library."
  static let cameraDenied =
    "Camera access is off. Pick a photo from the library."
  static let photoLoadFailed =
    "Couldn't load that photo. Try another image (JPEG/PNG)."
  static let emptyPitch =
    "Ask about your weather. Check a sky photo when you want eyes on the sky."
  static let hedge =
    "Not an NWS product or warning. Rotation and hail are inferred, not certified."
  static let notesHelper = "Add optional notes about what you see."
  static let notesPlaceholder = "Optional notes"
  static let notesConfirm = "Check"
  static let alreadyChecking =
    "Already checking this sky. Try when this one finishes."
  static let alreadyAnswering =
    "Already answering. Try when this one finishes."
  /// Finished Sky Check reply failed the 4.7 screen. Honest hide — not a lecture.
  static let replyHidden = "Couldn't show that reply. Try another question."
  static let photoTurnCaption = "Check this sky photo"

  /// One in-flight generation. Photo check vs chat/Imagine.
  static func generationBusyMessage(isCheckingSky: Bool) -> String {
    isCheckingSky ? alreadyChecking : alreadyAnswering
  }
  /// Take action / morning OPEN_GROK — one public name, not Ask AI / Ask Grok.
  static let landingActionTitle = "Sky Check"
  static let detailsTitle = SkyCheckGlance.detailsTitle
  static let forecastAction = SkyCheckGlance.forecastAction
  static let radarAction = SkyCheckGlance.radarAction

  struct QuickPrompt: Equatable {
    let title: String
    let icon: String
    let body: String
  }

  static let threatCheck = QuickPrompt(
    title: "Threat check",
    icon: "exclamationmark.triangle.fill",
    body: "Are there watches or warnings near me, and what should I watch next?"
  )

  static let outsideNow = QuickPrompt(
    title: "Outside now?",
    icon: "car.fill",
    body:
      "Is it a good idea to be outside near me right now? Hazards, timing, and what to watch if I need to go out."
  )

  static let outlook = QuickPrompt(
    title: "Outlook",
    icon: "cloud.bolt.fill",
    body:
      "What's the weather outlook for my area today and tomorrow — timing and anything severe I should know."
  )

  /// Compact 3-chip row and regular chips share this set. No Radar read, no Imagine.
  static let prompts: [QuickPrompt] = [threatCheck, outsideNow, outlook]
}

/// Take / morning OPEN_GROK / Today's Take tap → Sky Check ready to type.
enum SkyCheckLanding {
  static func queueReadyToType() {
    AskGrokPendingPrompt.set(.focusInput)
    AskGrokPendingPrompt.notify()
  }

  @MainActor
  static func openReadyToType(on store: WeatherStore) {
    AskGrokPendingPrompt.set(.focusInput)
    store.selectedTab = .grok
    AskGrokPendingPrompt.notify()
  }
}
