import SwiftUI

struct GrokAIView: View {
    @Environment(WeatherStore.self) private var store

    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isSending = false
    @State private var showAPIKeyAlert = false

    var weather: GrokCastWeather? { store.currentWeather }
    var hasKey: Bool { store.xaiService.hasAPIKey() }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !hasKey {
                    apiKeyBanner
                }

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 16) {
                            if messages.isEmpty {
                                emptyState
                            } else {
                                ForEach(messages) { message in
                                    MessageBubble(message: message)
                                        .id(message.id)
                                }
                            }
                        }
                        .padding()
                    }
                    .onChange(of: messages.count) { _, _ in
                        withAnimation {
                            proxy.scrollTo(messages.last?.id, anchor: .bottom)
                        }
                    }
                }

                Divider()

                quickPrompts

                chatInput
            }
            .navigationTitle("GrokCast AI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !messages.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Clear") { messages.removeAll() }
                            .tint(.secondary)
                    }
                }
            }
            .alert("xAI API Key Required", isPresented: $showAPIKeyAlert) {
                Button("Go to Settings") {
                    store.selectedTab = .locations // quick hack, better to have settings tab later
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Add your xAI API key in the Locations tab (or create a Settings view) to chat with Grok about the weather.")
            }
        }
    }

    private var apiKeyBanner: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
            Text("Add your xAI API key in Settings to unlock Grok AI")
            Spacer()
        }
        .font(.caption)
        .padding(10)
        .background(Color.orange.opacity(0.15))
        .foregroundStyle(.orange)
    }

    private var emptyState: some View {
        VStack(spacing: 24) {
            Image(systemName: "sparkles")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
                .padding(.top, 40)

            VStack(spacing: 8) {
                Text("Ask Grok about the weather")
                    .font(.title3.weight(.semibold))
                Text("Get witty insights, outfit ideas, activity recommendations, and more — powered by xAI.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let weather {
                Text("Current: \(Int(round(weather.currentTemp)))° • \(weather.conditionText) in \(weather.location.name)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }

    private var quickPrompts: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(QuickPrompt.allCases) { prompt in
                    Button {
                        sendQuickPrompt(prompt)
                    } label: {
                        Label(prompt.rawValue, systemImage: prompt.icon)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(.thinMaterial, in: Capsule())
                    }
                    .disabled(isSending || !hasKey)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
    }

    private var chatInput: some View {
        HStack(spacing: 12) {
            TextField("Ask Grok anything about the weather...", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(12)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
                .disabled(isSending || !hasKey)

            Button {
                sendMessage()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title)
                    .foregroundStyle(inputText.trimmingCharacters(in: .whitespaces).isEmpty || isSending || !hasKey ? .secondary : Color.accentColor)
            }
            .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || isSending || !hasKey)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private func sendQuickPrompt(_ prompt: QuickPrompt) {
        guard hasKey, let weather = weather else {
            showAPIKeyAlert = true
            return
        }

        let userMessage = ChatMessage.user(prompt.rawValue)
        messages.append(userMessage)

        Task {
            await performAIRequest(promptText: prompt.prompt, weather: weather)
        }
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, hasKey else { return }

        let userMsg = ChatMessage.user(text)
        messages.append(userMsg)
        inputText = ""

        Task {
            await performAIRequest(promptText: text)
        }
    }

    @MainActor
    private func performAIRequest(promptText: String, weather: GrokCastWeather? = nil) async {
        isSending = true
        let currentWeather = weather ?? self.weather

        var context: String? = nil
        if let w = currentWeather {
            context = store.xaiService.buildWeatherSystemPrompt(for: w)
        }

        let history = messages.suffix(6) // keep context window small

        do {
            let reply = try await store.xaiService.sendMessage(messages: Array(history), context: context)

            let assistantMsg = ChatMessage.assistant(reply)
            messages.append(assistantMsg)
        } catch {
            let errMsg = ChatMessage.assistant("Sorry, Grok ran into an issue: \(error.localizedDescription)")
            messages.append(errMsg)
        }

        isSending = false
    }
}

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer() }

            Text(message.content)
                .padding(14)
                .background(
                    message.role == .user
                        ? Color.accentColor
                        : Color(.secondarySystemBackground)
                )
                .foregroundStyle(message.role == .user ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .frame(maxWidth: 280, alignment: message.role == .user ? .trailing : .leading)

            if message.role == .assistant { Spacer() }
        }
    }
}

#Preview {
    GrokAIView()
        .environment(WeatherStore())
}