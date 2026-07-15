import PhotosUI
import SwiftUI
import UIKit

struct GrokAIView: View {
  @EnvironmentObject private var weatherStore: WeatherStore

  var body: some View {
    GrokAIViewContent(weatherStore: weatherStore)
  }
}

private struct GrokAIViewContent: View {
  @EnvironmentObject private var weatherStore: WeatherStore
  @StateObject private var viewModel: GrokAIViewModel

  @State private var question: String = ""
  @State private var showPhotoPicker = false
  @State private var selectedPhotoItem: PhotosPickerItem?
  @State private var pendingImageData: Data?
  @State private var showNotesSheet = false
  @State private var stormNotes: String = ""

  init(weatherStore: WeatherStore) {
    _viewModel = StateObject(wrappedValue: GrokAIViewModel(weatherStore: weatherStore))
  }

  var body: some View {
    NavigationStack {
      ZStack {
        WeatherBackgroundView(
          conditionCode: weatherStore.currentWeather?.conditionCode,
          isDay: weatherStore.currentWeather.map {
            WeatherBackgroundView.isDay(from: $0.symbolName)
          } ?? WeatherBackgroundView.inferredIsDay,
          intensity: .subtle
        )
        .ignoresSafeArea()

        VStack(spacing: 0) {
          ScrollView {
            VStack(alignment: .leading, spacing: 20) {
              headerSection

              quickPromptsSection

              if let thumbnailData = viewModel.stormThumbnailData,
                let uiImage = UIImage(data: thumbnailData)
              {
                Image(uiImage: uiImage)
                  .resizable()
                  .scaledToFill()
                  .frame(maxWidth: 120, maxHeight: 80)
                  .clipShape(RoundedRectangle(cornerRadius: 8))
                  .overlay(
                    RoundedRectangle(cornerRadius: 8)
                      .stroke(Color.white.opacity(0.15), lineWidth: 1)
                  )
              }

              if viewModel.isStreaming && viewModel.responseText.isEmpty {
                responseCard {
                  HStack(spacing: 12) {
                    ProgressView()
                      .tint(.white)
                    Text(viewModel.stormAnalysisMode ? "ANALYZING SKY..." : "THINKING...")
                      .font(.footnote.weight(.semibold))
                      .tracking(1.5)
                      .foregroundStyle(.secondary)
                  }
                  .frame(maxWidth: .infinity, alignment: .leading)
                }
              } else if !viewModel.responseText.isEmpty {
                responseCard {
                  StreamingText(text: viewModel.responseText, isStreaming: viewModel.isStreaming)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.9))
                }
              }

              if let error = viewModel.errorMessage {
                VStack(alignment: .leading, spacing: 8) {
                  HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                      .foregroundStyle(.red)
                    Text(error)
                      .font(.caption)
                      .foregroundStyle(.red)
                      .lineLimit(4)
                  }

                  if viewModel.lastStormImageData != nil {
                    Button {
                      Task { await viewModel.retryStormAnalysis() }
                    } label: {
                      Label("Retry", systemImage: "arrow.clockwise")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.red.opacity(0.2))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isStreaming)
                  }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
              }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)
            .adaptiveContainerWidth(AdaptiveLayout.contentCap)
          }

          inputBar
            .adaptiveContainerWidth(AdaptiveLayout.contentCap)
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
      }
      .navigationTitle("AI")
      .navigationBarTitleDisplayMode(.large)
    }
    .preferredColorScheme(.dark)
    .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotoItem, matching: .images)
    .onChange(of: selectedPhotoItem) { _, newItem in
      guard let newItem else { return }
      Task {
        do {
          if let data = try await newItem.loadTransferable(type: Data.self) {
            pendingImageData = data
            stormNotes = ""
            showNotesSheet = true
          } else {
            viewModel.errorMessage = "Couldn't load that photo. Try another image (JPEG/PNG)."
          }
        } catch {
          viewModel.errorMessage = "Couldn't load that photo. Try another image (JPEG/PNG)."
        }
        selectedPhotoItem = nil
      }
    }
    .sheet(isPresented: $showNotesSheet) {
      stormNotesSheet
    }
  }

  private var headerSection: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("WEATHER INTELLIGENCE")
        .font(.caption.weight(.heavy))
        .tracking(2)
        .foregroundStyle(.white.opacity(0.5))

      if let location = weatherStore.currentLocation?.name {
        Text(location.uppercased())
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(.white.opacity(0.85))
      } else {
        Text("SELECT A LOCATION FOR CONTEXT")
          .font(.subheadline.weight(.medium))
          .foregroundStyle(.secondary)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var quickPromptsSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("QUICK PROMPTS")
        .font(.caption.weight(.heavy))
        .tracking(1.5)
        .foregroundStyle(.white.opacity(0.5))

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
          StormSpotterButton {
            Task { await beginStormSpotterFlow() }
          }
          QuickPromptButton(title: "What should I wear?") {
            askQuickPrompt("What should I wear today based on the current weather?")
          }
          QuickPromptButton(title: "Good for hiking?") {
            askQuickPrompt("Is today a good day for hiking or outdoor activities?")
          }
          QuickPromptButton(title: "Summarize the week") {
            askQuickPrompt("Give me a short summary of the weather for the next few days.")
          }
          QuickPromptButton(title: "Any weather risks?") {
            askQuickPrompt("Are there any weather risks or severe conditions I should know about?")
          }
        }
      }
    }
  }

  private var stormNotesSheet: some View {
    NavigationStack {
      VStack(alignment: .leading, spacing: 16) {
        Text("Add optional notes about what you see (wall cloud, rotation, hail size, etc.)")
          .font(.subheadline)
          .foregroundStyle(.secondary)

        TextField("Observer notes (optional)", text: $stormNotes, axis: .vertical)
          .lineLimit(2...5)
          .textFieldStyle(.plain)
          .padding(12)
          .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))

        Spacer()
      }
      .padding(20)
      .navigationTitle("Storm Spotter")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            pendingImageData = nil
            showNotesSheet = false
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Analyze") {
            guard let imageData = pendingImageData else { return }
            let notes = stormNotes.trimmingCharacters(in: .whitespacesAndNewlines)
            showNotesSheet = false
            pendingImageData = nil
            Task {
              await viewModel.analyzeStormPhoto(
                imageData: imageData,
                userNotes: notes.isEmpty ? nil : notes
              )
            }
          }
          .fontWeight(.semibold)
        }
      }
    }
    .presentationDetents([.medium])
    .preferredColorScheme(.dark)
  }

  private var inputBar: some View {
    HStack(spacing: 12) {
      TextField("Ask anything about the weather...", text: $question, axis: .vertical)
        .lineLimit(1...4)
        .textFieldStyle(.plain)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
          RoundedRectangle(cornerRadius: 14)
            .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .disabled(viewModel.isStreaming)

      Button {
        Task {
          await viewModel.askGrok(question: question)
          question = ""
        }
      } label: {
        Image(systemName: "arrow.up.circle.fill")
          .font(.title2)
          .symbolRenderingMode(.palette)
          .foregroundStyle(.white, .indigo.opacity(0.8))
      }
      .disabled(viewModel.isStreaming || question.trimmingCharacters(in: .whitespaces).isEmpty)
    }
    .padding(12)
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
    .overlay(
      RoundedRectangle(cornerRadius: 18)
        .stroke(Color.white.opacity(0.1), lineWidth: 1)
    )
  }

  private func responseCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    content()
      .padding(16)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Color.white.opacity(0.06))
      .overlay(
        RoundedRectangle(cornerRadius: 14)
          .stroke(Color.white.opacity(0.1), lineWidth: 1)
      )
      .clipShape(RoundedRectangle(cornerRadius: 14))
  }

  private func askQuickPrompt(_ prompt: String) {
    Task {
      await viewModel.askGrok(question: prompt)
    }
  }

  private func beginStormSpotterFlow() async {
    guard weatherStore.xaiService.hasValidKey else {
      viewModel.errorMessage =
        "No xAI API key found. Add your developer key in Settings → Developer Key to use Storm Spotter."
      return
    }

    let targetLocation =
      weatherStore.savedLocations.first(where: {
        $0.name.localizedCaseInsensitiveContains("Olive Branch")
      })
      ?? weatherStore.savedLocations.first(where: { !$0.isCurrent })

    if let location = targetLocation {
      await weatherStore.refreshWeather(for: location)
    } else if let current = weatherStore.savedLocations.first(where: { $0.isCurrent }) {
      await weatherStore.refreshWeather(for: current)
    } else {
      await weatherStore.useCurrentDeviceLocation()
    }

    showPhotoPicker = true
  }
}

struct QuickPromptButton: View {
  let title: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Text(title)
        .font(.caption.weight(.medium))
        .foregroundStyle(.white.opacity(0.9))
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Color.white.opacity(0.08))
        .overlay(
          Capsule()
            .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .clipShape(Capsule())
    }
    .buttonStyle(.plain)
  }
}

struct StormSpotterButton: View {
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 6) {
        Image(systemName: "camera.fill")
          .font(.caption)
        Text("Storm Spotter")
          .font(.caption.weight(.semibold))
      }
      .foregroundStyle(.white)
      .padding(.horizontal, 14)
      .padding(.vertical, 9)
      .background(Color.orange.opacity(0.25))
      .overlay(
        Capsule()
          .stroke(Color.orange.opacity(0.5), lineWidth: 1)
      )
      .clipShape(Capsule())
    }
    .buttonStyle(.plain)
  }
}

#Preview {
  GrokAIView()
    .environment(WeatherStore.shared)
    .environmentObject(WeatherStore.shared)
}
