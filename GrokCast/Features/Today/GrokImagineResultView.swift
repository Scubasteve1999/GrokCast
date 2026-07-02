import Photos
import SwiftUI

struct GrokImagineResultView: View {
  let imageURL: URL
  let locationName: String
  let currentCondition: String
  let temperature: Double
  var onRegenerate: (() -> Void)? = nil

  @Environment(\.dismiss) private var dismiss
  @State private var isSaving = false
  @State private var showSaveSuccess = false
  @State private var showSaveError = false
  @State private var saveErrorMessage = ""

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 24) {
          // Generated Image
          AsyncImage(url: imageURL) { phase in
            switch phase {
            case .empty:
              ProgressView()
                .frame(height: 320)
            case .success(let image):
              image
                .resizable()
                .scaledToFit()
                .cornerRadius(16)
                .shadow(radius: 10)
            case .failure:
              Image(systemName: "photo")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
                .frame(height: 320)
            @unknown default:
              EmptyView()
            }
          }
          .padding(.horizontal)

          // Context
          VStack(spacing: 4) {
            Text(locationName)
              .font(.headline)
            Text("\(currentCondition) • \(Int(temperature))°")
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }

          // Action Buttons
          VStack(spacing: 12) {
            // Save to Photos
            Button {
              saveImageToPhotos()
            } label: {
              Label(
                isSaving ? "Saving..." : "Save to Photos",
                systemImage: "square.and.arrow.down"
              )
              .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSaving)

            // Share
            ShareLink(item: imageURL) {
              Label("Share Image", systemImage: "square.and.arrow.up")
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            // Regenerate
            Button {
              if let onRegenerate = onRegenerate {
                onRegenerate()
              } else {
                dismiss()
              }
            } label: {
              Label("Regenerate", systemImage: "arrow.clockwise")
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
          }
          .padding(.horizontal)
        }
        .padding(.vertical)
      }
      .navigationTitle("Generated Image")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Done") {
            dismiss()
          }
        }
      }
      .alert("Saved to Photos", isPresented: $showSaveSuccess) {
        Button("OK", role: .cancel) {}
      }
      .alert("Failed to Save", isPresented: $showSaveError) {
        Button("OK", role: .cancel) {}
      } message: {
        Text(saveErrorMessage)
      }
    }
  }

  private func saveImageToPhotos() {
    Task { @MainActor in
      isSaving = true

      do {
        // Request authorization using modern async API
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)

        guard status == .authorized || status == .limited else {
          isSaving = false
          saveErrorMessage = "Photo library access denied. Please enable it in Settings."
          showSaveError = true
          return
        }

        // Download the image data
        let (data, _) = try await URLSession.shared.data(from: imageURL)

        guard let image = UIImage(data: data) else {
          throw NSError(
            domain: "GrokCast",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Could not create image from downloaded data"]
          )
        }

        // Save to Photos using modern async API
        try await PHPhotoLibrary.shared().performChanges {
          PHAssetChangeRequest.creationRequestForAsset(from: image)
        }

        isSaving = false
        showSaveSuccess = true

      } catch {
        isSaving = false
        saveErrorMessage = error.localizedDescription
        showSaveError = true
      }
    }
  }
}
