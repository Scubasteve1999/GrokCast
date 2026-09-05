import AVFoundation
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
  @State private var showPhotoSourceChooser = false
  @State private var showPhotoPicker = false
  @State private var showCameraPicker = false
  @State private var selectedPhotoItem: PhotosPickerItem?
  @State private var pendingImageData: Data?
  @State private var photoCaptureFailMessage: String?
  @State private var showNotesSheet = false
  @State private var stormNotes: String = ""

  @State private var previewImageURL: URL?
  @State private var previewCaption: String?
  @State private var showImagePreview = false
  @FocusState private var isInputFocused: Bool

  var body: some View {
    @Bindable var viewModel = weatherStore.grokAIViewModel

    ZStack {
      skyCheckWeatherBackground

      VStack(spacing: 0) {
        Color.clear
          .frame(
            height: SkyCheckChatChrome.threadTopSafeArea(
              safeAreaTop: SkyCheckChatChrome.windowSafeAreaTop
            )
          )
          .frame(maxWidth: .infinity)
          .accessibilityHidden(true)

        NavigationStack {
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

                if showsDeskIntro(viewModel: viewModel) {
                  deskIntroCopy
                }

                quickPromptsSection(viewModel: viewModel)

                if prefersFigmaStudioLayout, showsPhotoWell(viewModel: viewModel) {
                  skyCheckPhotoWell(viewModel: viewModel)
                }

                ForEach(viewModel.conversationHistory) { message in
                  messageBubble(for: message)
                    .id(message.id)
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

                if viewModel.isStreaming {
                  streamingResponse(viewModel: viewModel)
                }

                if viewModel.isGeneratingImage {
                  responseCard {
                    HStack(spacing: 12) {
                      ProgressView()
                        .tint(.white)
                      Text("Generating image…")
                        .font(DesignTokens.Typography.caption())
                        .foregroundStyle(DesignTokens.Palette.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                  }
                  .id("generating-image")
                }

                if let imageData = viewModel.lastStormImageData,
                  !viewModel.stormAnalysisMode,
                  !viewModel.stormAnalysisText.isEmpty
                {
                  stormShareRow(
                    viewModel: viewModel, imageData: imageData,
                    analysis: viewModel.stormAnalysisText)
                }

                if prefersFigmaStudioLayout, showsPhotoCTAButton(viewModel: viewModel) {
                  VStack(alignment: .leading, spacing: DesignTokens.Spacing.space8) {
                    skyCheckPhotoCTAButton(viewModel: viewModel)
                    if hasCompletedPhotoCheck(viewModel: viewModel) {
                      Text(SkyCheckDeskCopy.hedge)
                        .font(DesignTokens.Typography.caption())
                        .foregroundStyle(DesignTokens.Palette.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                  }
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

                Color.clear
                  .frame(height: 1)
                  .id("thread-bottom")
                  .accessibilityHidden(true)
              }
              .padding(.horizontal, DesignTokens.Layout.horizontalPadding)
              .padding(.top, DesignTokens.Layout.topPadding)
              .padding(.bottom, DesignTokens.Spacing.space8)
            }
            .scrollDismissesKeyboard(.interactively)
            .background { skyCheckWeatherBackground }
            .onChange(of: viewModel.conversationHistory.count) {
              scrollToBottom(proxy: proxy)
            }
            .onChange(of: viewModel.responseText) {
              if viewModel.isStreaming { scrollToBottom(proxy: proxy) }
            }
            .onChange(of: viewModel.stormAnalysisText) {
              if viewModel.isStreaming && viewModel.stormAnalysisMode {
                scrollToBottom(proxy: proxy)
              }
            }
            .onChange(of: viewModel.isStreaming) {
              if viewModel.isStreaming { scrollToBottom(proxy: proxy) }
            }
            .onChange(of: viewModel.isGeneratingImage) {
              if viewModel.isGeneratingImage { scrollToBottom(proxy: proxy) }
            }
            .onChange(of: isInputFocused) {
              scrollToBottom(proxy: proxy)
            }
          }
          .navigationTitle("")
          .navigationBarTitleDisplayMode(.inline)
          .weatherShowsThroughNavigationBar()
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
          VStack(alignment: .leading, spacing: 0) {
            if photoCaptureFailMessage != nil {
              skyCheckPhotoCaptureFailLine
                .padding(.bottom, DesignTokens.Spacing.space8)
            }
            inputArea(viewModel: viewModel)
          }
          .padding(.horizontal, DesignTokens.Layout.horizontalPadding)
          .padding(.top, DesignTokens.Spacing.space8)
          .padding(.bottom, prefersFigmaStudioLayout ? DesignTokens.Spacing.space12 : 8)
          .background(composerTrayBackground)
        }
        .padding(
          .bottom,
          SkyCheckChatChrome.tabBarClearance(
            isCompact: prefersFigmaStudioLayout,
            isInputFocused: isInputFocused
          )
        )
        .clipped()
        .animation(.easeInOut(duration: 0.25), value: isInputFocused)
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
    .confirmationDialog(
      skyCheckPhotoCTATitle(viewModel: viewModel),
      isPresented: $showPhotoSourceChooser,
      titleVisibility: .visible
    ) {
      Button(SkyCheckDeskCopy.cameraSource) {
        beginPhotoSource(.camera)
      }
      .accessibilityIdentifier(DayCastAccessibility.Grok.skyCheckCamera)
      Button(SkyCheckDeskCopy.librarySource) {
        beginPhotoSource(.photoLibrary)
      }
      .accessibilityIdentifier(DayCastAccessibility.Grok.skyCheckLibrary)
      Button("Cancel", role: .cancel) {}
    }
    .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotoItem, matching: .images)
    .onChange(of: selectedPhotoItem) { _, newItem in
      guard let newItem else { return }
      Task {
        do {
          let data = try await newItem.loadTransferable(type: Data.self)
          applyPendingImage(data, viewModel: viewModel)
        } catch {
          applyPendingImage(nil, viewModel: viewModel)
        }
        selectedPhotoItem = nil
      }
    }
    .fullScreenCover(isPresented: $showCameraPicker) {
      SkyCheckCameraPicker(
        onCapture: { data in
          showCameraPicker = false
          applyPendingImage(data, viewModel: viewModel)
        },
        onCancel: {
          showCameraPicker = false
        }
      )
      .ignoresSafeArea()
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

  /// Compact: the elevated pill is the chrome. A full-bleed
  /// `ultraThinMaterial` tray on iOS 26 inflates into ice-blue glass over
  /// **Check this sky** and the last bubble.
  private var composerTrayBackground: AnyShapeStyle {
    if prefersFigmaStudioLayout {
      AnyShapeStyle(Color.clear)
    } else {
      AnyShapeStyle(.ultraThinMaterial)
    }
  }

  private var skyCheckWeatherBackground: some View {
    WeatherBackgroundLayer(
      conditionCode: weatherStore.currentWeather?.conditionCode,
      isDay: weatherStore.currentWeather.map {
        WeatherBackgroundView.isDay(from: $0.symbolName)
      } ?? WeatherBackgroundView.inferredIsDay
    )
  }

  private var headerSection: some View {
    Group {
      if prefersFigmaStudioLayout {
        FigmaScreenTitle(title: "Sky Check", style: .studio)
      } else {
        VStack(alignment: .leading, spacing: 6) {
          Text("Sky Check")
            .font(DesignTokens.Typography.caption())
            .foregroundStyle(.white.opacity(0.5))

          if let location = weatherStore.currentLocation?.name {
            Text(location)
              .font(DesignTokens.Typography.subsection())
              .foregroundStyle(.white.opacity(0.85))
          } else {
            Text("Select a location for context")
              .font(DesignTokens.Typography.callout())
              .foregroundStyle(.secondary)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    .accessibilityIdentifier(DayCastAccessibility.Grok.screenTitle)
  }

  private var deskIntroCopy: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.space8) {
      Text(SkyCheckDeskCopy.emptyPitch)
        .font(DesignTokens.Typography.callout())
        .foregroundStyle(DesignTokens.Palette.textPrimary)
        .fixedSize(horizontal: false, vertical: true)
      Text(SkyCheckDeskCopy.hedge)
        .font(DesignTokens.Typography.caption())
        .foregroundStyle(DesignTokens.Palette.textSecondary)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  private func showsDeskIntro(viewModel: GrokAIViewModel) -> Bool {
    viewModel.conversationHistory.isEmpty
      && !viewModel.stormAnalysisMode
      && viewModel.responseText.isEmpty
      && viewModel.stormAnalysisText.isEmpty
  }

  private func showsPhotoWell(viewModel: GrokAIViewModel) -> Bool {
    showsDeskIntro(viewModel: viewModel)
  }

  private func showsPhotoCTAButton(viewModel: GrokAIViewModel) -> Bool {
    !showsPhotoWell(viewModel: viewModel) && !viewModel.stormAnalysisMode
  }

  private func hasCompletedPhotoCheck(viewModel: GrokAIViewModel) -> Bool {
    viewModel.lastStormImageData != nil
      && !viewModel.stormAnalysisText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && !viewModel.stormAnalysisMode
  }

  private func openSkyCheckPicker() {
    isInputFocused = false
    Task {
      guard weatherStore.canUseGrok else {
        if PaywallCoordinator.shared.canUnlockGrokViaPro {
          PaywallCoordinator.shared.present(.grokAI)
        }
        return
      }
      showPhotoSourceChooser = true
    }
  }

  private func beginPhotoSource(_ source: SkyCheckPhotoSource) {
    Task { @MainActor in
      // Let the chooser dismiss before stacking Camera / PhotosPicker.
      try? await Task.sleep(for: .milliseconds(400))
      switch source {
      case .camera:
        startCameraCapture()
      case .photoLibrary:
        showPhotoPicker = true
      }
    }
  }

  private func startCameraCapture() {
    let gate = SkyCheckCameraGate.evaluate(
      isSourceAvailable: SkyCheckPhotoIntake.isCameraSourceAvailable,
      authorization: AVCaptureDevice.authorizationStatus(for: .video)
    )
    switch gate {
    case .ready:
      photoCaptureFailMessage = nil
      showCameraPicker = true
    case .needsAuthorization:
      Task { @MainActor in
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        if granted {
          photoCaptureFailMessage = nil
          showCameraPicker = true
        } else {
          photoCaptureFailMessage = SkyCheckDeskCopy.cameraDenied
        }
      }
    case .unavailable:
      photoCaptureFailMessage = SkyCheckDeskCopy.cameraUnavailable
    case .denied:
      photoCaptureFailMessage = SkyCheckDeskCopy.cameraDenied
    }
  }

  private func applyPendingImage(_ data: Data?, viewModel: GrokAIViewModel) {
    switch SkyCheckPhotoIntake.pendingImage(from: data) {
    case .success(let imageData):
      photoCaptureFailMessage = nil
      pendingImageData = imageData
      stormNotes = ""
      showNotesSheet = true
    case .failure(let failure):
      pendingImageData = nil
      viewModel.errorMessage = failure.userMessage
    }
  }

  @ViewBuilder
  private var skyCheckPhotoCaptureFailLine: some View {
    if let photoCaptureFailMessage {
      Text(photoCaptureFailMessage)
        .font(DesignTokens.Typography.caption())
        .foregroundStyle(DesignTokens.Palette.textSecondary)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier(DayCastAccessibility.Grok.skyCheckCameraFail)
    }
  }

  /// Empty / library affordance — photography well, not a danger badge.
  /// Local dark pill behind the camera + CTA so white type punches on the
  /// dawn horizon. Keep the well-wide dim light; do not crush NewsHeroDawn.
  private func skyCheckPhotoWell(viewModel: GrokAIViewModel) -> some View {
    Button(action: openSkyCheckPicker) {
      ZStack {
        Image("NewsHeroDawn")
          .resizable()
          .scaledToFill()
          .frame(maxWidth: .infinity)
          .frame(height: DesignTokens.Spacing.space48 * 3, alignment: .top)
          .overlay {
            LinearGradient(
              colors: [
                DesignTokens.Palette.bgPrimary.opacity(0.18),
                DesignTokens.Palette.bgPrimary.opacity(0.52),
              ],
              startPoint: .top,
              endPoint: .bottom
            )
          }
          .clipped()

        VStack(spacing: DesignTokens.Spacing.space8) {
          Image(systemName: SkyCheckDeskCopy.photoGlyph)
            .font(DesignTokens.Typography.symbol(DesignTokens.Layout.heroIconSize))
            .accessibilityHidden(true)
          Text(skyCheckPhotoCTATitle(viewModel: viewModel))
            .font(DesignTokens.Typography.subsection())
        }
        .foregroundStyle(DesignTokens.Palette.textPrimary)
        .padding(.horizontal, DesignTokens.Spacing.space20)
        .padding(.vertical, DesignTokens.Spacing.space12)
        .background(
          RoundedRectangle(cornerRadius: DesignTokens.Radius.large, style: .continuous)
            .fill(DesignTokens.Palette.bgPrimary.opacity(0.72))
        )
        .overlay(
          RoundedRectangle(cornerRadius: DesignTokens.Radius.large, style: .continuous)
            .stroke(
              Color.white.opacity(0.16),
              lineWidth: DesignTokens.Card.strokeWidth
            )
        )
      }
      .frame(maxWidth: .infinity)
      .clipShape(
        RoundedRectangle(cornerRadius: DesignTokens.Radius.small, style: .continuous)
      )
      .overlay(
        RoundedRectangle(cornerRadius: DesignTokens.Radius.small, style: .continuous)
          .stroke(DesignTokens.Palette.accent.opacity(0.35), lineWidth: 1)
      )
      .contentShape(
        RoundedRectangle(cornerRadius: DesignTokens.Radius.small, style: .continuous)
      )
    }
    .buttonStyle(.plain)
    .disabled(aiActionsDisabled)
    .accessibilityLabel(skyCheckPhotoCTATitle(viewModel: viewModel))
    .accessibilityIdentifier(DayCastAccessibility.Grok.stormSpotterAnalyze)
  }

  private func skyCheckPhotoCTAButton(viewModel: GrokAIViewModel) -> some View {
    SkyCheckSolidChip(
      title: skyCheckPhotoCTATitle(viewModel: viewModel),
      systemImage: SkyCheckDeskCopy.photoGlyph,
      identifier: DayCastAccessibility.Grok.stormSpotterAnalyze,
      isDisabled: aiActionsDisabled,
      action: openSkyCheckPicker
    )
  }

  private func quickPromptsSection(viewModel: GrokAIViewModel) -> some View {
    Group {
      if prefersFigmaStudioLayout {
        compactPromptRow(viewModel: viewModel)
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

  private func compactPromptRow(viewModel: GrokAIViewModel) -> some View {
    let disabled = aiActionsDisabled
    return HStack(spacing: DesignTokens.Spacing.space8) {
      ForEach(SkyCheckDeskCopy.prompts, id: \.title) { prompt in
        GrokQuickPromptButton(title: prompt.title) {
          askQuickPrompt(prompt.body, viewModel: viewModel)
        }
        .disabled(disabled)
      }
    }
  }

  private func standardQuickPromptsSection(viewModel: GrokAIViewModel) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Quick prompts")
        .font(DesignTokens.Typography.caption())
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
            openSkyCheckPicker()
          }
          .disabled(aiActionsDisabled)
        }
      }
    }
  }

  @ViewBuilder
  private func inputArea(viewModel: GrokAIViewModel) -> some View {
    GrokInputBar(
      text: $question,
      isFocused: $isInputFocused,
      layout: prefersFigmaStudioLayout ? .figma : .standard
    ) {
      sendQuestion(viewModel: viewModel)
    }
    .disabled(aiActionsDisabled)
  }

  private func sendQuestion(viewModel: GrokAIViewModel) {
    let text = question
    question = ""
    isInputFocused = false
    Task { await viewModel.askGrok(question: text) }
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
          .disabled(viewModel.isStreaming || viewModel.isGeneratingImage)
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
    let display = SkyCheckMessageDisplay.markdown(content)
    Group {
      if let attributed = try? AttributedString(markdown: display) {
        Text(attributed)
      } else {
        Text(display)
      }
    }
    .font(DesignTokens.Typography.body())
    .foregroundStyle(DesignTokens.Palette.textPrimary)
  }

  private var bubbleGutter: CGFloat { DesignTokens.Spacing.space48 }

  private func messageBubble(for message: ChatMessage) -> some View {
    HStack(alignment: .bottom, spacing: 0) {
      if message.role == .user {
        Spacer(minLength: bubbleGutter)
        VStack(alignment: .trailing, spacing: 4) {
          // Legacy / missing / undecodable thumbs: text only — no broken-image chrome.
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
            .font(DesignTokens.Typography.body())
            .foregroundStyle(DesignTokens.Palette.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, DesignTokens.Spacing.space16)
            .padding(.vertical, DesignTokens.Spacing.space12)
            .cardStyle(
              background: DesignTokens.Palette.cardElevated,
              stroke: DesignTokens.Palette.accent.opacity(0.28),
              cornerRadius: DesignTokens.Card.cornerRadiusMedium
            )
          Text(timeString(from: message.timestamp))
            .font(DesignTokens.Typography.micro())
            .foregroundStyle(DesignTokens.Palette.textTertiary)
        }
      } else if let url = message.generatedImageURL {
        VStack(alignment: .leading, spacing: 6) {
          Text(message.content)
            .font(DesignTokens.Typography.body())
            .foregroundStyle(DesignTokens.Palette.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, DesignTokens.Spacing.space12)
            .padding(.vertical, DesignTokens.Spacing.space8)
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
            .frame(maxWidth: .infinity)
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
        .frame(maxWidth: .infinity, alignment: .leading)
        Spacer(minLength: bubbleGutter)
      } else {
        VStack(alignment: .leading, spacing: 4) {
          if message.usesSkyCheckAnalysisCard {
            assistantMessageText(message.content)
              .fixedSize(horizontal: false, vertical: true)
              .padding(.horizontal, DesignTokens.Spacing.space16)
              .padding(.vertical, DesignTokens.Spacing.space12)
              .cardStyle(
                background: DesignTokens.Palette.cardBackground,
                stroke: DesignTokens.Palette.cardStroke,
                cornerRadius: DesignTokens.Card.cornerRadiusMedium
              )
          } else {
            SkyCheckGlanceCard(
              result: SkyCheckGlance.parse(message.content),
              onForecast: {
                weatherStore.selectedTab = .forecast
              },
              onRadar: {
                weatherStore.selectedTab = .radar
              }
            )
          }
          Text(timeString(from: message.timestamp))
            .font(DesignTokens.Typography.micro())
            .foregroundStyle(DesignTokens.Palette.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        Spacer(minLength: bubbleGutter)
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

  private func scrollToBottom(proxy: ScrollViewProxy) {
    withAnimation {
      proxy.scrollTo("thread-bottom", anchor: .bottom)
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
    hasCompletedPhotoCheck(viewModel: viewModel)
      ? SkyCheckDeskCopy.checkAnotherCTA : SkyCheckDeskCopy.photoCTA
  }

  private func streamingResponse(viewModel: GrokAIViewModel) -> some View {
    let streamText =
      viewModel.stormAnalysisMode ? viewModel.stormAnalysisText : viewModel.responseText
    return GrokAIResponseView(
      response: streamText.isEmpty ? nil : streamText,
      isThinking: streamText.isEmpty,
      isStreaming: !streamText.isEmpty
    )
    .id(streamText.isEmpty ? "thinking" : "streaming")
  }

  private func askQuickPrompt(_ prompt: String, viewModel: GrokAIViewModel) {
    isInputFocused = false
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

/// Render-time honesty for assistant markdown. Grok often emits
/// `MS.\n\n**Watch next**` (or `MS.**Watch next**`). SwiftUI `Text` can
/// drop the paragraph break, so it reads `MS.Watch next`. Insert a space.
/// Prompts are unchanged.
enum SkyCheckMessageDisplay {
  static func markdown(_ content: String) -> String {
    let normalized = content.replacingOccurrences(of: "\r\n", with: "\n")
    let afterBreak = normalized.replacingOccurrences(
      of: #"([.!?])[ \t]*\n+[ \t]*(\*{1,2})"#,
      with: "$1 $2",
      options: .regularExpression
    )
    return afterBreak.replacingOccurrences(
      of: #"([.!?])(\*{1,2}[^*])"#,
      with: "$1 $2",
      options: .regularExpression
    )
  }
}

#Preview {
  GrokAIView()
    .environment(WeatherStore.shared)
}
