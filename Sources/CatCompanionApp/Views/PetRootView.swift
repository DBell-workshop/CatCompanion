import SwiftUI
import CatCompanionCore

struct PetRootView: View {
    @ObservedObject var reminderEngine: ReminderEngine
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var assistantRuntime: AssistantRuntime
    @State private var lastActiveAt: Date = .now
    @State private var now: Date = .now

    var body: some View {
        ZStack(alignment: .top) {
            PetView(
                isAlerting: isAlerting,
                isSpeaking: assistantRuntime.isSpeakingResponse,
                isListening: assistantRuntime.isRecordingVoiceInput || assistantRuntime.isTranscribingVoiceInput,
                speechLevel: assistantRuntime.speechActivityLevel,
                motionProfile: settingsStore.settings.petMotionProfile,
                isLowPowerMode: shouldUseLowPowerMode,
                statusText: statusText,
                activeReminderType: reminderEngine.activeReminder
            )
            .frame(width: 200, height: 240)

            if let active = reminderEngine.activeReminder {
                ReminderBubbleView(
                    reminderType: active,
                    onComplete: { reminderEngine.completeActiveReminder() },
                    onSnooze: { reminderEngine.snoozeActiveReminder() }
                )
                .offset(y: -10)
            }
        }
        .padding(12)
        .background(Color.clear)
        .onAppear {
            markActivity()
        }
        .onChange(of: activitySignature) { _, _ in
            if isActiveInteraction {
                markActivity()
            }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { current in
            now = current
            if isActiveInteraction {
                lastActiveAt = current
            }
        }
    }

    private var statusText: String {
        if let active = reminderEngine.activeReminder {
            return active.displayName
        }
        if assistantRuntime.isSpeakingResponse {
            return AppStrings.text(.assistantChatSpeaking)
        }
        if assistantRuntime.isRecordingVoiceInput {
            return AppStrings.text(.assistantChatRecording)
        }
        if assistantRuntime.isTranscribingVoiceInput {
            return AppStrings.text(.assistantChatTranscribing)
        }
        return assistantRuntime.state.displayText
    }

    private var isAlerting: Bool {
        reminderEngine.activeReminder != nil
    }

    private var isActiveInteraction: Bool {
        isAlerting ||
            assistantRuntime.isSendingPrompt ||
            assistantRuntime.isSpeakingResponse ||
            assistantRuntime.isRecordingVoiceInput ||
            assistantRuntime.isTranscribingVoiceInput
    }

    private var shouldUseLowPowerMode: Bool {
        guard settingsStore.settings.petIdleLowPowerEnabled else { return false }
        guard !isActiveInteraction else { return false }
        let delay = max(5, settingsStore.settings.petIdleLowPowerDelaySeconds)
        return now.timeIntervalSince(lastActiveAt) >= TimeInterval(delay)
    }

    private var activitySignature: Int {
        var value = 0
        if isAlerting { value |= 1 << 0 }
        if assistantRuntime.isSendingPrompt { value |= 1 << 1 }
        if assistantRuntime.isSpeakingResponse { value |= 1 << 2 }
        if assistantRuntime.isRecordingVoiceInput { value |= 1 << 3 }
        if assistantRuntime.isTranscribingVoiceInput { value |= 1 << 4 }
        return value
    }

    private func markActivity() {
        let timestamp = Date()
        now = timestamp
        lastActiveAt = timestamp
    }
}
