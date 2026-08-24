import Foundation

/// Public Sky Check desk copy — photo check first, honest weather questions second.
/// Tests lock these strings so chaser/field tone cannot sneak back onto the civilian desk.
enum SkyCheckDeskCopy {
  static let photoCTA = "Check this sky"
  static let checkAnotherCTA = "Check another"
  static let emptyPitch =
    "Check a sky photo for what's overhead and what to watch next."
  static let hedge =
    "Not an NWS product or warning. Rotation and hail are inferred, not certified."
  static let notesHelper = "Add optional notes about what you see."
  static let notesPlaceholder = "Optional notes"
  static let notesConfirm = "Check"
  static let photoTurnCaption = "Check this sky photo"
  /// Take action / morning OPEN_GROK — one public name, not Ask AI / Ask Grok.
  static let landingActionTitle = "Sky Check"

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
