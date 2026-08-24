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
          intensity: .staticOnly
        )
        .ignoresSafeArea()

        ScrollViewReader { proxy in
          ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.space16) {
              headerSection
              if !weatherStore.canUseGrok {
                GrokAPIKeyEmptyStateView(
                  store: weatherStore,
                  subscription: SubscriptionManager.shared
                )
              }
              // Sky Check first — core DayCast feature, not buried under lifestyle prompts.
              figmaStormSpotterCard(viewModel: viewModel)
              quickPromptsSection(viewModel: viewModel)

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
                      .font(DesignTokens.Typography.caption())
                      .tracking(1.5)
                      .foregroundStyle(.secondary)
                  }
                  .frame(maxWidth: .infinity, alignment: .leading)
                }
                .id("generating-image")
              }

              if viewModel.stormAnalysisMode,
                let thumbnailData = viewModel.stormThumbnailData,
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

              // Regular width only: compact streams inside the Sky Check card.
              if viewModel.stormAnalysisMode && !prefersFigmaStudioLayout {
                GrokAIResponseView(
                  response: viewModel.stormAnalysisText.isEmpty ? nil : viewModel.stormAnalysisText,
                  isThinking: viewModel.isStreaming && viewModel.stormAnalysisText.isEmpty,
                  isStreaming: viewModel.isStreaming && !viewModel.stormAnalysisText.isEmpty
                )
              }

              if let imageData = viewModel.lastStormImageData,
                !viewModel.stormAnalysisMode,
                !viewModel.stormAnalysisText.isEmpty
              {
                stormShareRow(
                  viewModel: viewModel, imageData: imageData, analysis: viewModel.stormAnalysisText)
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
            .figmaScreenPadding(top: DesignTokens.Layout.topPadding)
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
          .padding(.horizontal, DesignTokens.Layout.horizontalPadding)
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
      viewModel.syncThread(to: weatherStore.currentLocation?.id)
      viewModel.recoverFromStaleActionStateIfNeeded()
      consumePendingAskGrok(viewModel: viewModel)
      Task {
        if weatherStore.currentWeather == nil {
          await weatherStore.performInitialLoadIfNeeded()
        }
      }
    }
    .onChange(of: weatherStore.selectedTab) { _, tab in
      if tab == .grok {
        viewModel.syncThread(to: weatherStore.currentLocation?.id)
        consumePendingAskGrok(viewModel: viewModel)
      }
    }
    .onChange(of: weatherStore.currentLocation?.id) { _, locationID in
      viewModel.syncThread(to: locationID)
    }
    .onReceive(NotificationCenter.default.publisher(for: AskGrokPendingPrompt.didChange)) { _ in
      consumePendingAskGrok(viewModel: viewModel)
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
        FigmaScreenTitle(title: "Sky Check", style: .studio)
      } else {
        VStack(alignment: .leading, spacing: 6) {
          Text("SKY CHECK")
            .font(DesignTokens.Typography.caption())
            .tracking(2)
            .foregroundStyle(.white.opacity(0.5))

          if let location = weatherStore.currentLocation?.name {
            Text(location.uppercased())
              .font(DesignTokens.Typography.subsection())
              .foregroundStyle(.white.opacity(0.85))
          } else {
            Text("SELECT A LOCATION FOR CONTEXT")
              .font(DesignTokens.Typography.callout())
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
        VStack(alignment: .leading, spacing: DesignTokens.Layout.cardInnerSpacing) {
          FigmaAccentSectionLabel(
            title: "SKY CHECK",
            icon: "cloud.bolt.rain.fill",
            color: DesignTokens.Palette.danger
          )

          if viewModel.stormAnalysisMode && viewModel.isStreaming
            && viewModel.stormAnalysisText.isEmpty
          {
            HStack(spacing: 8) {
              ProgressView().scaleEffect(0.85)
              Text("Checking your photo…")
                .font(DesignTokens.Typography.callout())
                .foregroundStyle(DesignTokens.Palette.textSecondary)
            }
          } else if !viewModel.stormAnalysisText.isEmpty {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.space8) {
              Text(viewModel.stormAnalysisText)
                .font(DesignTokens.Typography.callout())
                .foregroundStyle(DesignTokens.Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
              if !viewModel.stormAnalysisMode {
                Text(SkyCheckDeskCopy.hedge)
                  .font(DesignTokens.Typography.caption())
                  .foregroundStyle(DesignTokens.Palette.textTertiary)
                  .fixedSize(horizontal: false, vertical: true)
              }
            }
          } else {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.space8) {
              Text(SkyCheckDeskCopy.emptyPitch)
                .font(DesignTokens.Typography.callout())
                .foregroundStyle(DesignTokens.Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
              Text(SkyCheckDeskCopy.hedge)
                .font(DesignTokens.Typography.caption())
                .foregroundStyle(DesignTokens.Palette.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
            }
          }

          Button {
            Task {
              guard weatherStore.canUseGrok else {
                if PaywallCoordinator.shared.canUnlockGrokViaPro {
                  PaywallCoordinator.shared.present(.grokAI)
                }
                return
              }
              showPhotoPicker = true
            }
          } label: {
            Label(skyCheckPhotoCTATitle(viewModel: viewModel), systemImage: "photo")
              .font(DesignTokens.Typography.subsection())
              .frame(maxWidth: .infinity)
              .padding(.vertical, DesignTokens.Spacing.space4)
          }
          .buttonStyle(.borderedProminent)
          .tint(DesignTokens.Palette.danger)
          .disabled(aiActionsDisabled)
          .accessibilityIdentifier(DayCastAccessibility.Grok.stormSpotterAnalyze)
        }
        .padding(DesignTokens.Spacing.space16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(
          background: DesignTokens.Palette.cardElevated,
          stroke: DesignTokens.Palette.danger.opacity(0.45),
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

  private var aiActionsDisabled: Bool {
    !weatherStore.canUseGrok
      || weatherStore.grokAIViewModel.isStreaming
      || weatherStore.grokAIViewModel.isGeneratingImage
  }

  private func figmaPromptGrid(viewModel: GrokAIViewModel) -> some View {
    let disabled = aiActionsDisabled
    let columns = [
      GridItem(.flexible(), spacing: DesignTokens.Spacing.space12),
      GridItem(.flexible(), spacing: DesignTokens.Spacing.space12),
    ]

    return LazyVGrid(columns: columns, spacing: DesignTokens.Spacing.space12) {
      ForEach(SkyCheckDeskCopy.prompts, id: \.title) { prompt in
        GrokQuickPromptButton(
          title: prompt.title,
          icon: prompt.icon,
          layout: .figmaTile
        ) {
          askQuickPrompt(prompt.body, viewModel: viewModel)
        }
        .disabled(disabled)
      }
    }
  }

  private func standardQuickPromptsSection(viewModel: GrokAIViewModel) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("QUICK PROMPTS")
        .font(DesignTokens.Typography.caption())
        .tracking(1.5)
        .foregroundStyle(.white.opacity(0.5))

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
          ForEach(SkyCheckDeskCopy.prompts, id: \.title) { prompt in
            GrokQuickPromptButton(title: prompt.title) {
              askQuickPrompt(prompt.body, viewModel: viewModel)
            }
            .disabled(aiActionsDisabled)
          }
          GrokStormSpotterButton {
            Task {
              guard weatherStore.canUseGrok else {
                if PaywallCoordinator.shared.canUnlockGrokViaPro {
                  PaywallCoordinator.shared.present(.grokAI)
                }
                return
              }
              showPhotoPicker = true
            }
          }
          .disabled(aiActionsDisabled)
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
      .disabled(aiActionsDisabled)
    } else {
      GrokInputBar(text: $question, isFocused: $isInputFocused) {
        Task {
          await viewModel.askGrok(question: question)
          question = ""
        }
      }
      .disabled(aiActionsDisabled)
    }
  }

  private func stormNotesSheet(viewModel: GrokAIViewModel) -> some View {
    NavigationStack {
      VStack(alignment: .leading, spacing: 16) {
        Text(SkyCheckDeskCopy.notesHelper)
          .font(DesignTokens.Typography.callout())
          .foregroundStyle(.secondary)

        TextField(SkyCheckDeskCopy.notesPlaceholder, text: $stormNotes, axis: .vertical)
          .lineLimit(2...5)
          .textFieldStyle(.plain)
          .padding(12)
          .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))

        Spacer()
      }
      .padding(20)
      .navigationTitle("Sky Check")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            pendingImageData = nil
            showNotesSheet = false
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(SkyCheckDeskCopy.notesConfirm) {
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

  @ViewBuilder
  private func assistantMessageText(_ content: String) -> some View {
    if let attributed = try? AttributedString(markdown: content) {
      Text(attributed)
    } else {
      Text(content)
    }
  }

  private func messageBubble(for message: ChatMessage) -> some View {
    HStack {
      if message.role == .user {
        Spacer(minLength: 60)
        VStack(alignment: .trailing, spacing: 4) {
          if let imageData = message.imageData, let uiImage = UIImage(data: imageData) {
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
            .font(DesignTokens.Typography.micro())
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
            .font(DesignTokens.Typography.micro())
            .foregroundStyle(DesignTokens.Palette.textTertiary)
        }
        Spacer(minLength: 60)
      } else {
        VStack(alignment: .leading, spacing: 4) {
          assistantMessageText(message.content)
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
            .font(DesignTokens.Typography.micro())
            .foregroundStyle(DesignTokens.Palette.textTertiary)
        }
        Spacer(minLength: 60)
      }
    }
  }

  private func stormShareRow(viewModel: GrokAIViewModel, imageData: Data, analysis: String)
    -> some View
  {
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
          preview: SharePreview("Sky Check Photo", image: Image(uiImage: uiImage))
        ) {
          Label("Share Photo", systemImage: "photo")
        }
        .buttonStyle(.bordered)
        .tint(DesignTokens.Palette.accent)
        .simultaneousGesture(
          TapGesture().onEnded {
            Analytics.track(.shareStarted, parameters: ["surface": "storm_photo"])
          }
        )
      }

      ShareLink(item: shareText, subject: Text("DayCast Sky Check")) {
        Label("Share Report", systemImage: "square.and.arrow.up")
      }
      .buttonStyle(.bordered)
      .tint(DesignTokens.Palette.accent)
      .simultaneousGesture(
        TapGesture().onEnded {
          Analytics.track(.shareStarted, parameters: ["surface": "storm_report"])
        }
      )
    }
    .font(DesignTokens.Typography.caption())
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
                .font(DesignTokens.Typography.symbol(80))
                .foregroundStyle(.secondary)
                .frame(height: 400)
            @unknown default:
              EmptyView()
            }
          }
          .padding(.horizontal)

          if let caption = caption, !caption.isEmpty {
            Text(caption)
              .font(DesignTokens.Typography.callout())
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

  private func skyCheckPhotoCTATitle(viewModel: GrokAIViewModel) -> String {
    let completed =
      viewModel.lastStormImageData != nil
      && !viewModel.stormAnalysisText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && !viewModel.stormAnalysisMode
    return completed ? SkyCheckDeskCopy.checkAnotherCTA : SkyCheckDeskCopy.photoCTA
  }

  private func askQuickPrompt(_ prompt: String, viewModel: GrokAIViewModel) {
    Task {
      await viewModel.askGrok(question: prompt)
    }
  }

  private func consumePendingAskGrok(viewModel: GrokAIViewModel) {
    guard let action = AskGrokPendingPrompt.take() else { return }
    switch action {
    case .submit(let pending):
      question = ""
      Task { await viewModel.askGrok(question: pending) }
    case .focusInput:
      isInputFocused = true
    }
  }
}

#Preview {
  GrokAIView()
    .environment(WeatherStore.shared)
}
