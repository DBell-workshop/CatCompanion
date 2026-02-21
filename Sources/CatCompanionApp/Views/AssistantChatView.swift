import SwiftUI
import CatCompanionCore

struct AssistantChatView: View {
    @ObservedObject var assistantRuntime: AssistantRuntime
    @State private var inputText: String = ""

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            conversationList

            Divider()

            composer
        }
        .frame(minWidth: 480, minHeight: 560)
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(AppStrings.text(.assistantChatWindowTitle))
                    .font(.headline)
                Text("\(AppStrings.text(.settingsAssistantConnectionStatus)): \(assistantRuntime.state.displayText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(AppStrings.text(.assistantChatSpeakLatest)) {
                assistantRuntime.speakLastAssistantMessage()
            }
            .disabled(!assistantRuntime.canSpeakLatestResponse)

            Button(AppStrings.text(.assistantChatClear)) {
                assistantRuntime.clearConversation()
            }
            .disabled(assistantRuntime.conversation.isEmpty || assistantRuntime.isSendingPrompt)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var conversationList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    if assistantRuntime.conversation.isEmpty {
                        Text(AppStrings.text(.assistantChatEmptyState))
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 24)
                    } else {
                        ForEach(assistantRuntime.conversation) { message in
                            AssistantChatBubble(message: message)
                                .id(message.id)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .background(Color(NSColor.textBackgroundColor))
            .onChange(of: assistantRuntime.conversation.count) { _, _ in
                scrollToLatest(using: proxy)
            }
            .onAppear {
                scrollToLatest(using: proxy)
            }
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                TextField(AppStrings.text(.assistantChatInputPlaceholder), text: $inputText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(sendCurrentInput)
                    .disabled(assistantRuntime.isSendingPrompt || assistantRuntime.isRecordingVoiceInput || assistantRuntime.isTranscribingVoiceInput)

                Button(
                    assistantRuntime.isRecordingVoiceInput
                        ? AppStrings.text(.assistantChatStopRecording)
                        : AppStrings.text(.assistantChatVoiceInput)
                ) {
                    assistantRuntime.toggleVoiceInput()
                }
                .disabled(assistantRuntime.isRecordingVoiceInput ? false : !assistantRuntime.canToggleVoiceInput)

                Button(AppStrings.text(.assistantChatSend), action: sendCurrentInput)
                    .disabled(!canSend)
            }

            if assistantRuntime.isRecordingVoiceInput {
                Text(AppStrings.text(.assistantChatRecording))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if assistantRuntime.isTranscribingVoiceInput {
                Text(AppStrings.text(.assistantChatTranscribing))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if assistantRuntime.isSendingPrompt {
                Text(AppStrings.text(.assistantChatSending))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if assistantRuntime.isSpeakingResponse {
                Text(AppStrings.text(.assistantChatSpeaking))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if assistantRuntime.state != .ready {
                Text(AppStrings.text(.assistantChatConnectionHint))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !assistantRuntime.lastSpeechError.isEmpty {
                Text("\(AppStrings.text(.assistantChatSpeechError)): \(assistantRuntime.lastSpeechError)")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !assistantRuntime.lastTranscriptionError.isEmpty {
                Text("\(AppStrings.text(.assistantChatTranscriptionError)): \(assistantRuntime.lastTranscriptionError)")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var canSend: Bool {
        assistantRuntime.state == .ready &&
            !assistantRuntime.isSendingPrompt &&
            !assistantRuntime.isRecordingVoiceInput &&
            !assistantRuntime.isTranscribingVoiceInput &&
            !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func sendCurrentInput() {
        guard canSend else { return }
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        inputText = ""
        assistantRuntime.sendPrompt(text)
    }

    private func scrollToLatest(using proxy: ScrollViewProxy) {
        guard let lastID = assistantRuntime.conversation.last?.id else { return }
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(lastID, anchor: .bottom)
            }
        }
    }
}

private struct AssistantChatBubble: View {
    let message: AssistantChatMessage

    private var isUser: Bool { message.role == .user }
    private var isSystem: Bool { message.role == .system }

    var body: some View {
        VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
            Text(roleTitle)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(message.text)
                .textSelection(.enabled)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(bubbleBackground)
                .foregroundStyle(isSystem ? .red : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: alignment)
    }

    private var roleTitle: String {
        switch message.role {
        case .user:
            return AppStrings.text(.assistantChatRoleUser)
        case .assistant:
            return AppStrings.text(.assistantChatRoleAssistant)
        case .system:
            return AppStrings.text(.assistantChatRoleSystem)
        }
    }

    private var alignment: Alignment {
        if isUser {
            return .trailing
        }
        return .leading
    }

    private var bubbleBackground: Color {
        if isSystem {
            return Color.red.opacity(0.08)
        }
        if isUser {
            return Color.accentColor.opacity(0.18)
        }
        return Color.gray.opacity(0.14)
    }
}
