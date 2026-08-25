import SwiftUI

struct AlertDetailView: View {
  let alert: NWSAlert

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        header
        metadataSection
        if let instruction = alert.instruction, !instruction.isEmpty {
          detailSection(title: "Instruction", body: instruction)
        }
        if let description = alert.description, !description.isEmpty {
          detailSection(title: "Description", body: description)
        }
      }
      .padding()
    }
    .readableContentWidth(ReadableContentWidth.wide)
    .navigationTitle(alert.event)
    .navigationBarTitleDisplayMode(.inline)
    .background(Color.black.ignoresSafeArea())
  }

  private var shoutsEvent: Bool {
    alert.usesWarningEmphasis
  }

  private var header: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: NWSAlertStyle.iconName(for: alert))
        .font(DesignTokens.Typography.title())
        .foregroundStyle(NWSAlertStyle.tint(for: alert))

      VStack(alignment: .leading, spacing: 6) {
        Text(shoutsEvent ? alert.event.uppercased() : alert.event)
          .font(DesignTokens.Typography.headline())
          .foregroundStyle(.white)

        if let action = AlertsActiveCopy.cardBody(
          event: alert.event,
          headline: alert.headline,
          instruction: alert.instruction,
          description: nil
        ) {
          Text(action)
            .font(DesignTokens.Typography.callout())
            .foregroundStyle(.white.opacity(0.85))
        } else if let headline = alert.headline, !headline.isEmpty,
          !AlertsActiveCopy.isIssuedByHeadline(headline, event: alert.event)
        {
          Text(headline)
            .font(DesignTokens.Typography.callout())
            .foregroundStyle(.white.opacity(0.85))
        }

        if let until = untilLine {
          Text(until)
            .font(DesignTokens.Typography.caption())
            .foregroundStyle(.secondary)
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(16)
    .background(Color.white.opacity(0.06))
    .overlay(
      RoundedRectangle(cornerRadius: 14)
        .stroke(NWSAlertStyle.tint(for: alert).opacity(0.35), lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: 14))
  }

  private var untilLine: String? {
    let line = AlertsActiveCopy.untilLine(expires: alert.expires, areaDesc: alert.areaDesc)
    return line.isEmpty ? nil : line
  }

  private var metadataSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      if let sent = alert.sent {
        metadataRow(
          label: "Issued",
          value: sent.formatted(date: .abbreviated, time: .shortened)
        )
      }
      if let expires = alert.expires {
        metadataRow(
          label: alert.isExpired ? "Expired" : "Expires",
          value: expires.formatted(date: .abbreviated, time: .shortened)
        )
      }
      if let severity = alert.severity, !severity.isEmpty {
        metadataRow(label: "Severity", value: severity.capitalized)
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.white.opacity(0.04))
    .clipShape(RoundedRectangle(cornerRadius: 14))
  }

  private func metadataRow(label: String, value: String) -> some View {
    HStack {
      Text(label)
        .font(DesignTokens.Typography.micro())
        .foregroundStyle(.secondary)
      Spacer()
      Text(value)
        .font(DesignTokens.Typography.caption().monospaced())
        .foregroundStyle(.white.opacity(0.9))
    }
  }

  private func detailSection(title: String, body: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title)
        .font(DesignTokens.Typography.micro())
        .foregroundStyle(.secondary)
      Text(body)
        .font(DesignTokens.Typography.body())
        .foregroundStyle(.white.opacity(0.9))
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(16)
    .background(Color.white.opacity(0.06))
    .overlay(
      RoundedRectangle(cornerRadius: 14)
        .stroke(Color.white.opacity(0.1), lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: 14))
  }
}
