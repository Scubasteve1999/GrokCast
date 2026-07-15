import SwiftUI

/// Required disclosure for auto-renewable subscriptions (Guideline 3.1.2).
/// Place on any paywall or subscription purchase screen.
struct SubscriptionLegalFooter: View {
  var body: some View {
    VStack(spacing: 8) {
      HStack(spacing: 16) {
        Link("Privacy Policy", destination: AppLinks.privacyPolicy)
        Link("Terms of Use", destination: AppLinks.termsOfUse)
      }
      .font(.caption.weight(.semibold))

      Text(
        "Payment will be charged to your Apple ID account at confirmation of purchase. Subscription automatically renews unless it is canceled at least 24 hours before the end of the current period. Your account will be charged for renewal within 24 hours prior to the end of the current period. You can manage and cancel subscriptions in your App Store account settings."
      )
      .font(.caption2)
      .foregroundStyle(.secondary)
      .multilineTextAlignment(.center)

      Text("Cancel anytime • Billed via App Store")
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
  }
}

#Preview {
  SubscriptionLegalFooter()
    .padding()
}
