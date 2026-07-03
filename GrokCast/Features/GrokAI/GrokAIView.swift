import PhotosUI
import SwiftUI
import UIKit

struct GrokAIView: View {
  var body: some View {
    GrokAIViewContent()
  }
}

private struct GrokAIViewContent: View {
  @Environment(WeatherStore.self) private var weatherStore
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  @State private var question: String = ""
  @State private var showPhotoPicker = false
  @State private var selectedPhotoItem: PhotosPickerItem?
  @State private var pendingImageData: Data?
  @State private var showNotesSheet = false
  @State private var stormNotes: String = ""

  @State private var previewImageURL: URL?
  @State private var previewCaption: String?
  @State private var showImagePreview = false
  @FocusState private var isInputFocused: Bool

  var body: some View {
    @Bindable var viewModel = weatherStore.grokAIViewModel

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

        ScrollViewReader { proxy in
            ScrollView {
              VStack(alignment: .leading, spacing: DesignTokens.Spacing.space16) {
                headerSection
                quickPromptsSection(viewModel: viewModel)
                figmaStormSpotterCard(viewModel: viewModel)

                ForEach(viewModel.conversationHistory) { message in
                  messageBubble(for: message)
                    .id(message.id)
                }

                if viewModel.isStreaming && !viewModel.stormAnalysisMode {
                  GrokAIResponseView(
                    response: viewModel.responseText.isEmpty ? nil : viewModel.responseText,
                    isThinking: viewModel.responseText.isEmpty,
                    isStreaming: !viewModel.responseText.isEmpty
                  )
                  .id(viewModel.responseText.isEmpty ? "thinking" : "streaming")
                }

                if viewModel.isGeneratingImage {
                  responseCard {
                    HStack(spacing: 12) {
                      ProgressView()
                        .tint(.white)
                      Text("GENERATING IMAGE...")
                        .font(.footnote.weight(.semibold))
                        .tracking(1.5)
                        .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                  }
                  .id("generating-image")
                }

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
                    .id("storm-thumb")
                }

                if viewModel.stormAnalysisMode {
                  GrokAIResponseView(
                    response: viewModel.responseText.isEmpty ? nil : viewModel.responseText,
                    isThinking: viewModel.isStreaming && viewModel.responseText.isEmpty,
                    isStreaming: viewModel.isStreaming && !viewModel.responseText.isEmpty
                  )
                }

                if let imageData = viewModel.lastStormImageData,
                  !viewModel.stormAnalysisMode,
                  !viewModel.responseText.isEmpty
                {
                  stormShareRow(viewModel: viewModel, imageData: imageData, analysis: viewModel.responseText)
                }

                if let error = viewModel.errorMessage {
                  GrokErrorView(
                    message: error,
                    retryAction: {
                      guard !(viewModel.isStreaming || viewModel.isGeneratingImage) else { return }
                      Task {
                        if viewModel.lastStormImageData != nil {
                          await viewModel.retryStormAnalysis()
                          return
                        }
                        guard
                          let lastUser = viewModel.conversationHistory.last(where: {
                            $0.role == .user
                          })
                        else { return }
                        await viewModel.askGrok(question: lastUser.content)
                      }
                    },
                    isStormError: viewModel.lastStormImageData != nil
                  )
                  .id("error")
                }
              }
              .figmaScreenPadding(top: DesignTokens.Figma.Metrics.topPadding)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: viewModel.conversationHistory.count) {
              scrollToBottom(proxy: proxy, viewModel: viewModel)
            }
            .onChange(of: viewModel.responseText) {
              if viewModel.isStreaming && !viewModel.stormAnalysisMode {
                scrollToBottom(proxy: proxy, viewModel: viewModel)
              }
            }
            .onChange(of: viewModel.isStreaming) {
              if viewModel.isStreaming && !viewModel.stormAnalysisMode
                && viewModel.responseText.isEmpty
              {
                scrollToBottom(proxy: proxy, viewModel: viewModel)
              }
            }
            .onChange(of: viewModel.isGeneratingImage) {
              if viewModel.isGeneratingImage {
                scrollToBottom(proxy: proxy, viewModel: viewModel)
              }
            }
          }
      }
      .navigationTitle("")
      .navigationBarTitleDisplayMode(.inline)
      .safeAreaInset(edge: .bottom, spacing: 0) {
        inputArea(viewModel: viewModel)
          .padding(.horizontal, DesignTokens.Figma.Metrics.horizontalPadding)
          .padding(.top, 8)
          .padding(.bottom, 8)
          .background(
            horizontalSizeClass == .compact
              ? AnyShapeStyle(DesignTokens.Palette.bgPrimary.opacity(0.95))
              : AnyShapeStyle(.ultraThinMaterial.opacity(isInputFocused ? 1 : 0.85))
          )
      }
    }
    .preference(key: TabBarSuppressionPreferenceKey.self, value: isInputFocused)
    .preferredColorScheme(.dark)
    .onAppear {
      viewModel.recoverFromStaleActionStateIfNeeded()
      Task {
        if weatherStore.currentWeather == nil {
          await weatherStore.performInitialLoadIfNeeded()
        }
      }
    }
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
      stormNotesSheet(viewModel: viewModel)
    }
    .sheet(isPresented: $showImagePreview) {
      if let url = previewImageURL {
        imagePreviewSheet(url: url, caption: previewCaption, viewModel: viewModel)
      }
    }
  }

  private var prefersFigmaStudioLayout: Bool {
    horizontalSizeClass == .compact
  }

  private var headerSection: some View {
    Group {
      if prefersFigmaStudioLayout {
        FigmaScreenTitle(title: "Briefing Studio", style: .studio)
      } else {
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
    }
  }

  private func figmaStormSpotterCard(viewModel: GrokAIViewModel) -> some View {
    Group {
      if prefersFigmaStudioLayout {
        VStack(alignment: .leading, spacing: DesignTokens.Figma.Metrics.cardInnerSpacing) {
          FigmaAccentSectionLabel(
            title: "STORM SPOTTER ANALYSIS",
            icon: "cloud.bolt.rain.fill",
            color: DesignTokens.Palette.danger
          )

          if viewModel.stormAnalysisMode && viewModel.isStreaming && viewModel.responseText.isEmpty {
            HStack(spacing: 8) {
              ProgressView().scaleEffect(0.85)
              Text("Analyzing your photo…")
                .font(.system(size: 15))
                .foregroundStyle(DesignTokens.Palette.textSecondary)
            }
          } else if !viewModel.responseText.isEmpty,
            viewModel.stormAnalysisMode || viewModel.lastStormImageData != nil
          {
            Text(viewModel.responseText)
              .font(.system(size: 15))
              .foregroundStyle(DesignTokens.Palette.textPrimary)
              .fixedSize(horizontal: false, vertical: true)
          } else {
            Text("Upload a storm photo for Grok to assess rotation, wall clouds, and hail risk.")
              .font(.system(size: 15))
              .foregroundStyle(DesignTokens.Palette.textPrimary)
              .fixedSize(horizontal: false, vertical: true)
          }

          Button {
            Task {
              guard weatherStore.xaiService.hasValidKey else {
                PaywallCoordinator.shared.present(.grokAI)
                return
              }
              showPhotoPicker = true
            }
          } label: {
            Label("Analyze Storm Photo", systemImage: "camera.fill")
              .font(.caption.weight(.semibold))
          }
          .buttonStyle(.bordered)
          .tint(DesignTokens.Palette.danger)
          .disabled(viewModel.isStreaming || viewModel.isGeneratingImage)
        }
        .padding(DesignTokens.Spacing.space16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(
          background: DesignTokens.Palette.cardBackground,
          stroke: DesignTokens.Palette.cardStroke,
          cornerRadius: DesignTokens.Card.cornerRadiusMedium
        )
      }
    }
  }

  private func quickPromptsSection(viewModel: GrokAIViewModel) -> some View {
    Group {
      if prefersFigmaStudioLayout {
        figmaPromptGrid(viewModel: viewModel)
      } else {
        standardQuickPromptsSection(viewModel: viewModel)
      }
    }
  }

  private func figmaPromptGrid(viewModel: GrokAIViewModel) -> some View {
    let disabled = viewModel.isStreaming || viewModel.isGeneratingImage
    let columns = [
      GridItem(.flexible(), spacing: DesignTokens.Spacing.space12),
      GridItem(.flexible(), spacing: DesignTokens.Spacing.space12),
    ]

    return LazyVGrid(columns: columns, spacing: DesignTokens.Spacing.space12) {
      GrokQuickPromptButton(
        title: "Today's vibe",
        icon: "sparkles",
        layout: .figmaTile
      ) {
        askQuickPrompt(
          "Give me a short read on today's weather vibe where I am.",
          viewModel: viewModel
        )
      }
      .disabled(disabled)

      GrokQuickPromptButton(
        title: "What to wear",
        icon: "tshirt",
        layout: .figmaTile
      ) {
        askQuickPrompt(
          "What should I wear today based on the current weather?",
          viewModel: viewModel
        )
      }
      .disabled(disabled)

      GrokQuickPromptButton(
        title: "Walk check",
        icon: "figure.walk",
        layout: .figmaTile
      ) {
        askQuickPrompt(
          "Is now a good time for a walk based on the weather?",
          viewModel: viewModel
        )
      }
      .disabled(disabled)

      GrokQuickPromptButton(
        title: "Week ahead",
        icon: "calendar",
        layout: .figmaTile
      ) {
        askQuickPrompt(
          "Give me a short summary of the weather for the next few days.",
          viewModel: viewModel
        )
      }
      .disabled(disabled)
    }
  }

  private func standardQuickPromptsSection(viewModel: GrokAIViewModel) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("QUICK PROMPTS")
        .font(.caption.weight(.heavy))
        .tracking(1.5)
        .foregroundStyle(.white.opacity(0.5))

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
          GrokQuickPromptButton(title: "What should I wear?") {
            askQuickPrompt(
              "What should I wear today based on the current weather?",
              viewModel: viewModel
            )
          }
          .disabled(viewModel.isStreaming || viewModel.isGeneratingImage)
          GrokQuickPromptButton(title: "Good for hiking?") {
            askQuickPrompt(
              "Is today a good day for hiking or outdoor activities?",
              viewModel: viewModel
            )
          }
          .disabled(viewModel.isStreaming || viewModel.isGeneratingImage)
          GrokQuickPromptButton(title: "Summarize the week") {
            askQuickPrompt(
              "Give me a short summary of the weather for the next few days.",
              viewModel: viewModel
            )
          }
          .disabled(viewModel.isStreaming || viewModel.isGeneratingImage)
          GrokQuickPromptButton(title: "Any weather risks?") {
            askQuickPrompt(
              "Are there any weather risks or severe conditions I should know about?",
              viewModel: viewModel
            )
          }
          .disabled(viewModel.isStreaming || viewModel.isGeneratingImage)
          GrokQuickPromptButton(title: "Imagine the scene") {
            Task { await viewModel.generateWeatherImage() }
          }
          .disabled(viewModel.isStreaming || viewModel.isGeneratingImage)
          GrokStormSpotterButton {
            Task {
              guard weatherStore.xaiService.hasValidKey else {
                PaywallCoordinator.shared.present(.grokAI)
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
          .disabled(viewModel.isStreaming || viewModel.isGeneratingImage)
        }
      }
    }
  }

  @ViewBuilder
  private func inputArea(viewModel: GrokAIViewModel) -> some View {
    if prefersFigmaStudioLayout {
      GrokInputBar(
        text: $question,
        isFocused: $isInputFocused,
        layout: .figma
      ) {
        Task {
          await viewModel.askGrok(question: question)
          question = ""
        }
      }
      .disabled(viewModel.isStreaming || viewModel.isGeneratingImage)
    } else {
      HStack(spacing: 12) {
        GrokInputBar(text: $question, isFocused: $isInputFocused) {
          Task {
            await viewModel.askGrok(question: question)
            question = ""
          }
        }

        Button {
          Task {
            await viewModel.generateWeatherImage(description: question.isEmpty ? nil : question)
            question = ""
          }
        } label: {
          Image(systemName: "sparkles")
            .font(.title3)
            .foregroundStyle(.white.opacity(0.85))
        }
        .disabled(viewModel.isStreaming || viewModel.isGeneratingImage)
        .help("Generate image from weather + prompt")
      }
      .disabled(viewModel.isStreaming || viewModel.isGeneratingImage)
    }
  }

  private func stormNotesSheet(viewModel: GrokAIViewModel) -> some View {
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

  private func messageBubble(for message: ChatMessage) -> some View {
    HStack {
      if message.role == .user {
        Spacer(minLength: 60)
        VStack(alignment: .trailing, spacing: 4) {
          Text(message.content)
            .foregroundStyle(DesignTokens.Palette.textPrimary)
            .padding(.horizontal, DesignTokens.Spacing.space16)
            .padding(.vertical, DesignTokens.Spacing.space12)
            .cardStyle(
              background: DesignTokens.Palette.accent.opacity(0.22),
              stroke: DesignTokens.Palette.accent.opacity(0.35),
              cornerRadius: DesignTokens.Card.cornerRadiusMedium
            )
            .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 6)
            .frame(maxWidth: 280, alignment: .trailing)
          Text(timeString(from: message.timestamp))
            .font(.caption2)
            .foregroundStyle(DesignTokens.Palette.textTertiary)
        }
      } else if let url = message.generatedImageURL {
        VStack(alignment: .leading, spacing: 6) {
          Text(message.content)
            .foregroundStyle(DesignTokens.Palette.textSecondary)
            .padding(.horizontal, DesignTokens.Spacing.space12)
            .padding(.vertical, DesignTokens.Spacing.space8)
            .frame(maxWidth: 280, alignment: .leading)
          Button {
            previewImageURL = url
            previewCaption = message.content
            showImagePreview = true
          } label: {
            AsyncImage(url: url) { phase in
              switch phase {
              case .empty:
                ProgressView().frame(height: 180)
              case .success(let img):
                img.resizable().scaledToFit().frame(maxHeight: 220)
              case .failure:
                Image(systemName: "photo").foregroundStyle(.secondary)
              @unknown default: EmptyView()
              }
            }
            .frame(maxWidth: 280)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.medium))
            .overlay(
              RoundedRectangle(cornerRadius: DesignTokens.Radius.medium)
                .stroke(DesignTokens.Palette.cardStroke, lineWidth: 1)
            )
          }
          .buttonStyle(.plain)

          Text(timeString(from: message.timestamp))
            .font(.caption2)
            .foregroundStyle(DesignTokens.Palette.textTertiary)
        }
        Spacer(minLength: 60)
      } else {
        VStack(alignment: .leading, spacing: 4) {
          Text(message.content)
            .foregroundStyle(DesignTokens.Palette.textPrimary)
            .padding(.horizontal, DesignTokens.Spacing.space16)
            .padding(.vertical, DesignTokens.Spacing.space12)
            .cardStyle(
              background: DesignTokens.Palette.cardBackground,
              stroke: DesignTokens.Palette.cardStroke,
              cornerRadius: DesignTokens.Card.cornerRadiusMedium
            )
            .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 6)
            .frame(maxWidth: 280, alignment: .leading)
          Text(timeString(from: message.timestamp))
            .font(.caption2)
            .foregroundStyle(DesignTokens.Palette.textTertiary)
        }
        Spacer(minLength: 60)
      }
    }
  }

  private func stormShareRow(viewModel: GrokAIViewModel, imageData: Data, analysis: String) -> some View {
    let location = weatherStore.currentLocation?.name ?? "My location"
    let shareText = ShareableBriefText.stormSpotterReport(
      locationName: location,
      observerNotes: viewModel.lastStormNotes,
      analysis: analysis
    )

    return HStack(spacing: 12) {
      if let uiImage = UIImage(data: imageData) {
        ShareLink(
          item: StormSpotterPhotoShare(imageData: imageData),
          preview: SharePreview("Storm Spotter Photo", image: Image(uiImage: uiImage))
        ) {
          Label("Share Photo", systemImage: "photo")
        }
        .buttonStyle(.bordered)
        .tint(DesignTokens.Palette.accent)
      }

      ShareLink(item: shareText, subject: Text("GrokCast Storm Spotter")) {
        Label("Share Report", systemImage: "square.and.arrow.up")
      }
      .buttonStyle(.bordered)
      .tint(DesignTokens.Palette.accent)
    }
    .font(.caption.weight(.semibold))
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.vertical, 4)
  }

  private func scrollToBottom(proxy: ScrollViewProxy, viewModel: GrokAIViewModel) {
    withAnimation {
      if viewModel.isStreaming && !viewModel.stormAnalysisMode && !viewModel.responseText.isEmpty {
        proxy.scrollTo("streaming", anchor: .bottom)
      } else if let last = viewModel.conversationHistory.last {
        proxy.scrollTo(last.id, anchor: .bottom)
      } else if viewModel.isStreaming && !viewModel.stormAnalysisMode {
        proxy.scrollTo("thinking", anchor: .bottom)
      } else if viewModel.isGeneratingImage {
        proxy.scrollTo("generating-image", anchor: .bottom)
      }
    }
  }

  private func timeString(from date: Date) -> String {
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    return formatter.string(from: date)
  }

  private func imagePreviewSheet(
    url: URL,
    caption: String? = nil,
    viewModel: GrokAIViewModel
  ) -> some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: DesignTokens.Spacing.space16) {
          AsyncImage(url: url) { phase in
            switch phase {
            case .empty:
              ProgressView().frame(height: 400)
            case .success(let image):
              image
                .resizable()
                .scaledToFit()
                .cornerRadius(DesignTokens.Radius.medium)
                .shadow(radius: 12)
            case .failure:
              Image(systemName: "photo")
                .font(.system(size: 80))
                .foregroundStyle(.secondary)
                .frame(height: 400)
            @unknown default:
              EmptyView()
            }
          }
          .padding(.horizontal)

          if let caption = caption, !caption.isEmpty {
            Text(caption)
              .font(.subheadline)
              .foregroundStyle(DesignTokens.Palette.textSecondary)
              .multilineTextAlignment(.center)
              .padding(.horizontal)
          }

          VStack(spacing: DesignTokens.Spacing.space12) {
            ShareLink(item: url) {
              Label("Share Image", systemImage: "square.and.arrow.up")
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button {
              showImagePreview = false
              Task {
                await viewModel.generateWeatherImage(description: caption)
              }
            } label: {
              Label("Regenerate", systemImage: "arrow.clockwise")
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isGeneratingImage)
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
            showImagePreview = false
          }
        }
      }
    }
    .preferredColorScheme(.dark)
  }

  private func askQuickPrompt(_ prompt: String, viewModel: GrokAIViewModel) {
    Task {
      await viewModel.askGrok(question: prompt)
    }
  }
}

#Preview {
  GrokAIView()
    .environment(WeatherStore.shared)
}
