import SwiftUI

/// Plain-English explainer for the NCEP short-range cutover. Opens official SCN PDFs in-app.
struct ForecastEraNoticeCard: View {
  @Environment(\.dismiss) private var dismiss
  @State private var safariURL: IdentifiableURL?

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.space16) {
          ForEach(Array(ForecastEraNotice.Copy.paragraphs.enumerated()), id: \.offset) { _, text in
            Text(text)
              .font(DesignTokens.Typography.body())
              .foregroundStyle(DesignTokens.Palette.textPrimary)
              .fixedSize(horizontal: false, vertical: true)
          }

          Button {
            safariURL = IdentifiableURL(AppLinks.nwsSCN2648)
          } label: {
            scnLinkLabel(ForecastEraNotice.Copy.scn48LinkTitle)
          }
          .buttonStyle(.plain)
          .accessibilityIdentifier(DayCastAccessibility.Today.forecastEraNoticeSCN48)

          Button {
            safariURL = IdentifiableURL(AppLinks.nwsSCN2647)
          } label: {
            scnLinkLabel(ForecastEraNotice.Copy.scn47LinkTitle)
          }
          .buttonStyle(.plain)
          .accessibilityIdentifier(DayCastAccessibility.Today.forecastEraNoticeSCN47)
        }
        .padding(DesignTokens.Spacing.space20)
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .background(DesignTokens.Palette.bgPrimary)
      .navigationTitle(ForecastEraNotice.Copy.cardTitle)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { dismiss() }
        }
      }
      .sheet(item: $safariURL) { item in
        SafariView(url: item.url)
      }
    }
    .presentationDetents([.medium, .large])
    .accessibilityElement(children: .contain)
    .accessibilityLabel(ForecastEraNotice.Copy.cardAccessibility)
    .accessibilityIdentifier(DayCastAccessibility.Today.forecastEraNoticeCard)
    .preferredColorScheme(.dark)
  }

  private func scnLinkLabel(_ title: String) -> some View {
    HStack(spacing: DesignTokens.Spacing.space12) {
      Image(systemName: "doc.text")
        .font(DesignTokens.Typography.body())
        .foregroundStyle(DesignTokens.Palette.accent)
      Text(title)
        .font(DesignTokens.Typography.subsection())
        .foregroundStyle(DesignTokens.Palette.accent)
        .multilineTextAlignment(.leading)
      Spacer()
      Image(systemName: "arrow.up.right")
        .font(DesignTokens.Typography.caption())
        .foregroundStyle(DesignTokens.Palette.textTertiary)
    }
    .padding(.vertical, DesignTokens.Spacing.space8)
    .frame(minHeight: DesignTokens.Layout.minHitTarget)
    .contentShape(Rectangle())
  }
}
