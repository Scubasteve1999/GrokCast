import SwiftUI

struct GrokBriefReportSheet: View {
  let brief: String
  let locationName: String
  var onSubmitted: () -> Void

  @Environment(\.dismiss) private var dismiss
  @Environment(\.openURL) private var openURL

  @State private var reason: GrokBriefReportReason = .objectionable
  @State private var note = ""

  var body: some View {
    NavigationStack {
      Form {
        Section {
          Picker("Reason", selection: $reason) {
            ForEach(GrokBriefReportReason.allCases) { item in
              Text(item.title).tag(item)
            }
          }
          TextField("Anything we should know (optional)", text: $note, axis: .vertical)
            .lineLimit(3...6)
        } footer: {
          Text(GrokBriefReport.responsePromise)
        }

        Section("This take") {
          Text(brief)
            .font(DesignTokens.Typography.callout())
            .foregroundStyle(DesignTokens.Palette.textSecondary)
        }
      }
      .navigationTitle("Report Today's Take")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Submit") { submit() }
        }
      }
    }
    .presentationDetents([.medium, .large])
  }

  private func submit() {
    Haptic.impact(.light)
    if let url = GrokBriefReport.mailtoURL(
      reason: reason,
      brief: brief,
      locationName: locationName,
      note: note
    ) {
      openURL(url)
    }
    onSubmitted()
    dismiss()
  }
}
