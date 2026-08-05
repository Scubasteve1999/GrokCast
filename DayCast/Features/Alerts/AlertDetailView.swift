import SwiftUI

struct AlertDetailView: View {
  let alert: NWSAlert

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        header
        metadataSection
        if let description = alert.description, !description.isEmpty {
          detailSection(title: "DESCRIPTION", body: description)
        }
        if let instruction = alert.instruction, !instruction.isEmpty {
          detailSection(title: "INSTRUCTIONS", body: instruction)
        }
      }
      .padding()
    }
    .readableContentWidth(ReadableContentWidth.wide)
    .navigationTitle(alert.event)
    .navigationBarTitleDisplayMode(.inline)
    .background(Color.black.ignoresSafeArea())
  }

  private var header: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: NWSAlertStyle.iconName(for: alert))
        .font(.title)
        .foregroundStyle(NWSAlertStyle.tint(for: alert))

      VStack(alignment: .leading, spacing: 6) {
        Text(alert.event.uppercased())
          .font(.headline.weight(.bold))
          .foregroundStyle(.white)

        if let headline = alert.headline, !headline.isEmpty {
          Text(headline)
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.85))
        }

        if let area = alert.areaDesc, !area.isEmpty {
          Label(area, systemImage: "mappin.and.ellipse")
            .font(.caption)
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

  private var metadataSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      if let sent = alert.sent {
        metadataRow(label: "ISSUED", value: sent.formatted(date: .abbreviated, time: .shortened))
      }
      if let expires = alert.expires {
        metadataRow(
          label: alert.isExpired ? "EXPIRED" : "EXPIRES",
          value: expires.formatted(date: .abbreviated, time: .shortened)
        )
      }
      if let severity = alert.severity, !severity.isEmpty {
        metadataRow(label: "SEVERITY", value: severity.uppercased())
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
        .font(.caption2.weight(.heavy))
        .tracking(1)
        .foregroundStyle(.secondary)
      Spacer()
      Text(value)
        .font(.caption.monospaced())
        .foregroundStyle(.white.opacity(0.9))
    }
  }

  private func detailSection(title: String, body: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title)
        .font(.caption2.weight(.heavy))
        .tracking(1.5)
        .foregroundStyle(.secondary)
      Text(body)
        .font(.body)
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
