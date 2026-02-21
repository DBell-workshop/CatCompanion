import SwiftUI
import AppKit
import UserNotifications
import CatCompanionCore

struct SettingsView: View {
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var assistantRuntime: AssistantRuntime
    var onOpenAssistantChat: (() -> Void)?

    @State private var notificationAuthorizationStatus: UNAuthorizationStatus = .notDetermined
    @State private var assistantTestPrompt: String = ""
    @State private var assistantVoiceAdvancedExpanded: Bool = false
    @State private var selectedPane: SettingsPane = .assistant
    @State private var inputAudioDevices: [AudioDeviceOption] = []
    @State private var outputAudioDevices: [AudioDeviceOption] = []

    private enum SettingsPane: String, CaseIterable, Identifiable {
        case reminders
        case assistant
        case voice
        case security
        case pet
        case notifications

        var id: Self { self }

        var title: String {
            switch self {
            case .reminders:
                return AppStrings.text(.settingsReminderSection)
            case .assistant:
                return AppStrings.text(.settingsAssistantSection)
            case .voice:
                return AppStrings.text(.settingsAssistantVoiceSection)
            case .security:
                return AppStrings.text(.settingsAssistantSecuritySection)
            case .pet:
                return AppStrings.text(.settingsPetSection)
            case .notifications:
                return AppStrings.text(.settingsNotificationSection)
            }
        }

        var iconName: String {
            switch self {
            case .reminders:
                return "clock"
            case .assistant:
                return "sparkles"
            case .voice:
                return "waveform"
            case .security:
                return "lock.shield"
            case .pet:
                return "pawprint"
            case .notifications:
                return "bell"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Picker(AppStrings.text(.settingsGroup), selection: $selectedPane) {
                    ForEach(SettingsPane.allCases) { pane in
                        Label(pane.title, systemImage: pane.iconName)
                            .tag(pane)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 280, alignment: .leading)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 4)

            Form {
                paneContent
            }
            .formStyle(.grouped)
            .controlSize(.regular)
        }
        .frame(minWidth: 680, minHeight: 700)
        .onAppear {
            refreshNotificationAuthorizationStatus()
            reloadAudioDevices()
        }
        .onChange(of: settingsStore.settings.notificationsEnabled) { _, _ in
            refreshNotificationAuthorizationStatus()
        }
        .onChange(of: settingsStore.settings.assistant.voiceSettings.enabled) { _, _ in
            reloadAudioDevices()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshNotificationAuthorizationStatus()
        }
    }

    @ViewBuilder
    private var paneContent: some View {
        switch selectedPane {
        case .reminders:
            reminderOverviewSection
            reminderPlanSections
        case .assistant:
            assistantSettingsSection
        case .voice:
            voiceSettingsSection
        case .security:
            securitySettingsSection
        case .pet:
            petSettingsSection
        case .notifications:
            notificationSettingsSection
        }
    }

    private var reminderOverviewSection: some View {
        Section {
            Toggle(AppStrings.text(.settingsPauseAllReminders), isOn: pauseRemindersBinding())
                .help(AppStrings.text(.settingsPauseAllRemindersHelp))

            settingRow(AppStrings.text(.settingsReminderCooldown)) {
                HStack(spacing: 8) {
                    Stepper("", value: cooldownBinding(), in: 0...30, step: 1)
                        .labelsHidden()
                    Text(cooldownDisplayText(settingsStore.settings.interReminderCooldownMinutes))
                        .monospacedDigit()
                }
            }
            .help(AppStrings.text(.settingsReminderCooldownHelp))
        } header: {
            Text(AppStrings.text(.settingsReminderSection))
        }
    }

    @ViewBuilder
    private var reminderPlanSections: some View {
        ForEach(ReminderType.allCases) { type in
            Section {
                ReminderPlanSection(type: type, plan: planBinding(for: type))
            }
        }
    }

    private var assistantSettingsSection: some View {
        Section {
            Toggle(AppStrings.text(.settingsAssistantEnabled), isOn: assistantEnabledBinding())

            Toggle(AppStrings.text(.settingsAssistantAutoStart), isOn: assistantAutoStartBinding())
                .disabled(!settingsStore.settings.assistant.enabled)

            settingRow(AppStrings.text(.settingsAssistantConnectionStatus)) {
                Text(assistantRuntime.state.displayText)
                    .foregroundStyle(assistantConnectionColor)
            }

            settingRow(AppStrings.text(.settingsAssistantRouteStrategy)) {
                Picker("", selection: assistantRouteStrategyBinding()) {
                    Text(AppStrings.text(.settingsAssistantRouteCloudPreferred)).tag(AssistantRouteStrategy.cloudPreferred)
                    Text(AppStrings.text(.settingsAssistantRouteCloudOnly)).tag(AssistantRouteStrategy.cloudOnly)
                    Text(AppStrings.text(.settingsAssistantRouteLocalOnly)).tag(AssistantRouteStrategy.localOnly)
                }
                .labelsHidden()
                .frame(maxWidth: 360, alignment: .leading)
                .disabled(!settingsStore.settings.assistant.enabled)
            }

            settingRow(AppStrings.text(.settingsAssistantCloudPrimaryModel)) {
                TextField("", text: assistantCloudPrimaryModelBinding())
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 420)
                    .disabled(!settingsStore.settings.assistant.enabled)
            }

            settingRow(AppStrings.text(.settingsAssistantLocalFallbackModel)) {
                TextField("", text: assistantLocalFallbackModelBinding())
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 420)
                    .disabled(!settingsStore.settings.assistant.enabled)
            }

            settingRow(AppStrings.text(.settingsAssistantGatewayURL)) {
                TextField("", text: assistantGatewayURLBinding())
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 420)
                    .disabled(!settingsStore.settings.assistant.enabled)
            }

            settingRow(AppStrings.text(.settingsAssistantGatewayToken)) {
                SecureField("", text: assistantGatewayTokenBinding())
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 420)
                    .disabled(!settingsStore.settings.assistant.enabled)
            }

            settingRow(AppStrings.text(.settingsAssistantGatewaySessionKey)) {
                TextField("", text: assistantGatewaySessionKeyBinding())
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 220)
                    .disabled(!settingsStore.settings.assistant.enabled)
            }

            Divider()

            settingRow(AppStrings.text(.settingsAssistantTestPrompt)) {
                TextField("", text: $assistantTestPrompt)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 420)
                    .disabled(!isAssistantPromptEnabled)
            }

            HStack(spacing: 12) {
                Button(AppStrings.text(.settingsAssistantSendTest)) {
                    assistantRuntime.sendPrompt(assistantTestPrompt)
                }
                .disabled(!isAssistantPromptEnabled || assistantTestPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button(AppStrings.text(.settingsAssistantOpenChat)) {
                    onOpenAssistantChat?()
                }
                .disabled(!settingsStore.settings.assistant.enabled)
            }

            if assistantRuntime.isSendingPrompt {
                Text(AppStrings.text(.settingsAssistantSending))
                    .foregroundStyle(.secondary)
            }

            if !assistantRuntime.lastResponse.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(AppStrings.text(.settingsAssistantLastResponse))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text(assistantRuntime.lastResponse)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if !assistantRuntime.lastError.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(AppStrings.text(.settingsAssistantLastError))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text(assistantRuntime.lastError)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        } header: {
            Text(AppStrings.text(.settingsAssistantSection))
        }
    }

    private var voiceSettingsSection: some View {
        Section {
            Toggle(AppStrings.text(.settingsAssistantVoiceEnabled), isOn: assistantVoiceEnabledBinding())
                .disabled(!settingsStore.settings.assistant.enabled)

            Toggle(AppStrings.text(.settingsAssistantVoiceAutoSpeak), isOn: assistantVoiceAutoSpeakBinding())
                .disabled(!settingsStore.settings.assistant.enabled || !settingsStore.settings.assistant.voiceSettings.enabled)

            settingRow(AppStrings.text(.settingsAssistantVoiceInputDevice)) {
                Picker("", selection: assistantVoiceInputDeviceBinding()) {
                    Text(AppStrings.text(.settingsAssistantVoiceDeviceSystemDefault)).tag("")
                    ForEach(inputAudioDevices) { device in
                        Text(device.name).tag(device.uid)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 420, alignment: .leading)
                .disabled(!settingsStore.settings.assistant.enabled || !settingsStore.settings.assistant.voiceSettings.enabled)
            }

            settingRow(AppStrings.text(.settingsAssistantVoiceOutputDevice)) {
                Picker("", selection: assistantVoiceOutputDeviceBinding()) {
                    Text(AppStrings.text(.settingsAssistantVoiceDeviceSystemDefault)).tag("")
                    ForEach(outputAudioDevices) { device in
                        Text(device.name).tag(device.uid)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 420, alignment: .leading)
                .disabled(!settingsStore.settings.assistant.enabled || !settingsStore.settings.assistant.voiceSettings.enabled)
            }

            HStack(spacing: 10) {
                Button(AppStrings.text(.settingsAssistantVoiceRefreshDevices)) {
                    reloadAudioDevices()
                }
                .disabled(!settingsStore.settings.assistant.enabled || !settingsStore.settings.assistant.voiceSettings.enabled)

                Button(AppStrings.text(.settingsAssistantVoiceTestInput)) {
                    assistantRuntime.testVoiceInputDevice()
                }
                .disabled(!assistantRuntime.canTestVoiceInputDevice)

                Button(AppStrings.text(.settingsAssistantVoiceTestOutput)) {
                    assistantRuntime.testVoiceOutputDevice()
                }
                .disabled(!assistantRuntime.canTestVoiceOutputDevice)
            }

            if !assistantRuntime.lastVoiceInputDeviceTestResult.isEmpty {
                settingRow(AppStrings.text(.settingsAssistantVoiceInputTestResult)) {
                    Text(assistantRuntime.lastVoiceInputDeviceTestResult)
                        .foregroundStyle(
                            assistantRuntime.lastVoiceInputDeviceTestResult == AppStrings.text(.settingsAssistantVoiceTestPassed)
                                ? .green
                                : (assistantRuntime.lastVoiceInputDeviceTestResult == AppStrings.text(.settingsAssistantVoiceTestRunning) ? .secondary : .red)
                        )
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if !assistantRuntime.lastVoiceOutputDeviceTestResult.isEmpty {
                settingRow(AppStrings.text(.settingsAssistantVoiceOutputTestResult)) {
                    Text(assistantRuntime.lastVoiceOutputDeviceTestResult)
                        .foregroundStyle(
                            assistantRuntime.lastVoiceOutputDeviceTestResult == AppStrings.text(.settingsAssistantVoiceTestPassed)
                                ? .green
                                : (assistantRuntime.lastVoiceOutputDeviceTestResult == AppStrings.text(.settingsAssistantVoiceTestRunning) ? .secondary : .red)
                        )
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            DisclosureGroup(
                AppStrings.text(.settingsAssistantVoiceAdvanced),
                isExpanded: $assistantVoiceAdvancedExpanded
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    settingRow(AppStrings.text(.settingsAssistantVoicePythonCommand)) {
                        TextField("", text: assistantVoicePythonCommandBinding())
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 280)
                    }

                    settingRow(AppStrings.text(.settingsAssistantVoiceSTTCommand)) {
                        TextField("", text: assistantVoiceSTTCommandBinding())
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 280)
                    }

                    settingRow(AppStrings.text(.settingsAssistantVoiceSTTModelPath)) {
                        TextField("", text: assistantVoiceSTTModelPathBinding())
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 420)
                    }

                    settingRow(AppStrings.text(.settingsAssistantVoiceSTTLanguage)) {
                        TextField("", text: assistantVoiceSTTLanguageBinding())
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 220)
                    }

                    settingRow(AppStrings.text(.settingsAssistantVoiceModel)) {
                        TextField("", text: assistantVoiceModelBinding())
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 420)
                    }

                    settingRow(AppStrings.text(.settingsAssistantVoiceSpeaker)) {
                        TextField("", text: assistantVoiceSpeakerBinding())
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 280)
                    }

                    settingRow(AppStrings.text(.settingsAssistantVoiceScriptPath)) {
                        TextField("", text: assistantVoiceScriptPathBinding())
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 420)
                    }
                }
                .padding(.top, 4)
            }
            .disabled(!settingsStore.settings.assistant.enabled || !settingsStore.settings.assistant.voiceSettings.enabled)

            Text(AppStrings.text(.settingsAssistantVoiceAdvancedHint))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text(AppStrings.text(.settingsAssistantVoiceHint))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } header: {
            Text(AppStrings.text(.settingsAssistantVoiceSection))
        }
    }

    private var securitySettingsSection: some View {
        Section {
            Toggle(AppStrings.text(.settingsAssistantAllowReadOnly), isOn: assistantAllowReadOnlyBinding())
                .disabled(!settingsStore.settings.assistant.enabled)
            Toggle(AppStrings.text(.settingsAssistantAllowFileActions), isOn: assistantAllowFileActionsBinding())
                .disabled(!settingsStore.settings.assistant.enabled)
            Toggle(AppStrings.text(.settingsAssistantAllowTerminalActions), isOn: assistantAllowTerminalActionsBinding())
                .disabled(!settingsStore.settings.assistant.enabled)
            Toggle(AppStrings.text(.settingsAssistantAllowBrowserActions), isOn: assistantAllowBrowserActionsBinding())
                .disabled(!settingsStore.settings.assistant.enabled)

            Text(AppStrings.text(.settingsAssistantThirdPartySkillsDisabledHint))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } header: {
            Text(AppStrings.text(.settingsAssistantSecuritySection))
        }
    }

    private var petSettingsSection: some View {
        Section {
            Toggle(AppStrings.text(.settingsAlwaysOnTop), isOn: petAlwaysOnTopBinding())

            Toggle(AppStrings.text(.settingsPetShowOnlyWhenReminding), isOn: petShowOnlyWhenRemindingBinding())
                .help(AppStrings.text(.settingsPetShowOnlyWhenRemindingHelp))

            settingRow(AppStrings.text(.settingsPetMotionProfile)) {
                Picker("", selection: petMotionProfileBinding()) {
                    Text(AppStrings.text(.settingsPetMotionProfileSubtle)).tag(PetMotionProfile.subtle)
                    Text(AppStrings.text(.settingsPetMotionProfileVivid)).tag(PetMotionProfile.vivid)
                }
                .labelsHidden()
                .frame(maxWidth: 220, alignment: .leading)
            }
            .help(AppStrings.text(.settingsPetMotionProfileHelp))

            Toggle(AppStrings.text(.settingsPetIdleLowPowerEnabled), isOn: petIdleLowPowerEnabledBinding())
                .help(AppStrings.text(.settingsPetIdleLowPowerHelp))

            settingRow(AppStrings.text(.settingsPetIdleLowPowerDelay)) {
                HStack(spacing: 8) {
                    Stepper("", value: petIdleLowPowerDelaySecondsBinding(), in: 5...120, step: 1)
                        .labelsHidden()
                    Text("\(settingsStore.settings.petIdleLowPowerDelaySeconds)")
                        .monospacedDigit()
                }
            }
            .help(AppStrings.text(.settingsPetIdleLowPowerDelayHelp))
            .disabled(!settingsStore.settings.petIdleLowPowerEnabled)
        } header: {
            Text(AppStrings.text(.settingsPetSection))
        }
    }

    private var notificationSettingsSection: some View {
        Section {
            Toggle(AppStrings.text(.settingsEnableSystemNotification), isOn: notificationsBinding())
                .help(AppStrings.text(.settingsNotificationHelp))

            settingRow(AppStrings.text(.settingsAuthorizationStatus)) {
                Text(notificationAuthorizationLabel)
                    .foregroundStyle(notificationAuthorizationColor)
            }

            if notificationAuthorizationStatus == .denied {
                Button(AppStrings.text(.settingsOpenSystemSettings)) {
                    openSystemNotificationSettings()
                }
                .buttonStyle(.link)
            }
        } header: {
            Text(AppStrings.text(.settingsNotificationSection))
        }
    }

    private func settingRow<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        LabeledContent {
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Text(title)
        }
    }

    private func planBinding(for type: ReminderType) -> Binding<ReminderPlan> {
        Binding(
            get: {
                settingsStore.settings.plans[type] ?? ReminderPlan(
                    enabled: true,
                    intervalMinutes: type.defaultIntervalMinutes,
                    quietHours: QuietHours(),
                    snoozeMinutes: type.defaultSnoozeMinutes
                )
            },
            set: { newValue in
                var settings = settingsStore.settings
                settings.plans[type] = newValue
                settingsStore.settings = settings
            }
        )
    }

    private func notificationsBinding() -> Binding<Bool> {
        Binding(
            get: { settingsStore.settings.notificationsEnabled },
            set: { newValue in
                var settings = settingsStore.settings
                settings.notificationsEnabled = newValue
                settingsStore.settings = settings
            }
        )
    }

    private func pauseRemindersBinding() -> Binding<Bool> {
        Binding(
            get: { settingsStore.settings.remindersPaused },
            set: { newValue in
                var settings = settingsStore.settings
                settings.remindersPaused = newValue
                settingsStore.settings = settings
            }
        )
    }

    private func petAlwaysOnTopBinding() -> Binding<Bool> {
        Binding(
            get: { settingsStore.settings.petAlwaysOnTop },
            set: { newValue in
                var settings = settingsStore.settings
                settings.petAlwaysOnTop = newValue
                settingsStore.settings = settings
            }
        )
    }

    private func petShowOnlyWhenRemindingBinding() -> Binding<Bool> {
        Binding(
            get: { settingsStore.settings.petShowOnlyWhenReminding },
            set: { newValue in
                var settings = settingsStore.settings
                settings.petShowOnlyWhenReminding = newValue
                settingsStore.settings = settings
            }
        )
    }

    private func petMotionProfileBinding() -> Binding<PetMotionProfile> {
        Binding(
            get: { settingsStore.settings.petMotionProfile },
            set: { newValue in
                var settings = settingsStore.settings
                settings.petMotionProfile = newValue
                settingsStore.settings = settings
            }
        )
    }

    private func petIdleLowPowerEnabledBinding() -> Binding<Bool> {
        Binding(
            get: { settingsStore.settings.petIdleLowPowerEnabled },
            set: { newValue in
                var settings = settingsStore.settings
                settings.petIdleLowPowerEnabled = newValue
                settingsStore.settings = settings
            }
        )
    }

    private func petIdleLowPowerDelaySecondsBinding() -> Binding<Int> {
        Binding(
            get: { settingsStore.settings.petIdleLowPowerDelaySeconds },
            set: { newValue in
                var settings = settingsStore.settings
                settings.petIdleLowPowerDelaySeconds = max(5, newValue)
                settingsStore.settings = settings
            }
        )
    }

    private func cooldownBinding() -> Binding<Int> {
        Binding(
            get: { settingsStore.settings.interReminderCooldownMinutes },
            set: { newValue in
                var settings = settingsStore.settings
                settings.interReminderCooldownMinutes = max(0, newValue)
                settingsStore.settings = settings
            }
        )
    }

    private func assistantEnabledBinding() -> Binding<Bool> {
        Binding(
            get: { settingsStore.settings.assistant.enabled },
            set: { newValue in
                mutateAssistantSettings { assistant in
                    assistant.enabled = newValue
                }
            }
        )
    }

    private func assistantAutoStartBinding() -> Binding<Bool> {
        Binding(
            get: { settingsStore.settings.assistant.autoStartHelper },
            set: { newValue in
                mutateAssistantSettings { assistant in
                    assistant.autoStartHelper = newValue
                }
            }
        )
    }

    private func assistantRouteStrategyBinding() -> Binding<AssistantRouteStrategy> {
        Binding(
            get: { settingsStore.settings.assistant.routeStrategy },
            set: { newValue in
                mutateAssistantSettings { assistant in
                    assistant.routeStrategy = newValue
                }
            }
        )
    }

    private func assistantCloudPrimaryModelBinding() -> Binding<String> {
        Binding(
            get: { settingsStore.settings.assistant.cloudPrimaryModel },
            set: { newValue in
                mutateAssistantSettings { assistant in
                    assistant.cloudPrimaryModel = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        )
    }

    private func assistantLocalFallbackModelBinding() -> Binding<String> {
        Binding(
            get: { settingsStore.settings.assistant.localFallbackModel },
            set: { newValue in
                mutateAssistantSettings { assistant in
                    assistant.localFallbackModel = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        )
    }

    private func assistantGatewayURLBinding() -> Binding<String> {
        Binding(
            get: { settingsStore.settings.assistant.gatewayURL },
            set: { newValue in
                mutateAssistantSettings { assistant in
                    assistant.gatewayURL = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        )
    }

    private func assistantGatewayTokenBinding() -> Binding<String> {
        Binding(
            get: { settingsStore.settings.assistant.gatewayToken },
            set: { newValue in
                mutateAssistantSettings { assistant in
                    assistant.gatewayToken = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        )
    }

    private func assistantGatewaySessionKeyBinding() -> Binding<String> {
        Binding(
            get: { settingsStore.settings.assistant.gatewaySessionKey },
            set: { newValue in
                mutateAssistantSettings { assistant in
                    let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    assistant.gatewaySessionKey = trimmed.isEmpty ? "main" : trimmed
                }
            }
        )
    }

    private func assistantAllowReadOnlyBinding() -> Binding<Bool> {
        Binding(
            get: { settingsStore.settings.assistant.actionScope.allowReadOnlyActions },
            set: { newValue in
                mutateAssistantSettings { assistant in
                    assistant.actionScope.allowReadOnlyActions = newValue
                }
            }
        )
    }

    private func assistantAllowFileActionsBinding() -> Binding<Bool> {
        Binding(
            get: { settingsStore.settings.assistant.actionScope.allowFileActions },
            set: { newValue in
                mutateAssistantSettings { assistant in
                    assistant.actionScope.allowFileActions = newValue
                }
            }
        )
    }

    private func assistantAllowTerminalActionsBinding() -> Binding<Bool> {
        Binding(
            get: { settingsStore.settings.assistant.actionScope.allowTerminalActions },
            set: { newValue in
                mutateAssistantSettings { assistant in
                    assistant.actionScope.allowTerminalActions = newValue
                }
            }
        )
    }

    private func assistantAllowBrowserActionsBinding() -> Binding<Bool> {
        Binding(
            get: { settingsStore.settings.assistant.actionScope.allowBrowserActions },
            set: { newValue in
                mutateAssistantSettings { assistant in
                    assistant.actionScope.allowBrowserActions = newValue
                }
            }
        )
    }

    private func assistantVoiceEnabledBinding() -> Binding<Bool> {
        Binding(
            get: { settingsStore.settings.assistant.voiceSettings.enabled },
            set: { newValue in
                mutateAssistantSettings { assistant in
                    assistant.voiceSettings.enabled = newValue
                }
            }
        )
    }

    private func assistantVoiceAutoSpeakBinding() -> Binding<Bool> {
        Binding(
            get: { settingsStore.settings.assistant.voiceSettings.autoSpeakAssistantReplies },
            set: { newValue in
                mutateAssistantSettings { assistant in
                    assistant.voiceSettings.autoSpeakAssistantReplies = newValue
                }
            }
        )
    }

    private func assistantVoicePythonCommandBinding() -> Binding<String> {
        Binding(
            get: { settingsStore.settings.assistant.voiceSettings.pythonCommand },
            set: { newValue in
                mutateAssistantSettings { assistant in
                    assistant.voiceSettings.pythonCommand = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        )
    }

    private func assistantVoiceSTTCommandBinding() -> Binding<String> {
        Binding(
            get: { settingsStore.settings.assistant.voiceSettings.whisperCommand },
            set: { newValue in
                mutateAssistantSettings { assistant in
                    assistant.voiceSettings.whisperCommand = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        )
    }

    private func assistantVoiceSTTModelPathBinding() -> Binding<String> {
        Binding(
            get: { settingsStore.settings.assistant.voiceSettings.whisperModelPath },
            set: { newValue in
                mutateAssistantSettings { assistant in
                    assistant.voiceSettings.whisperModelPath = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        )
    }

    private func assistantVoiceSTTLanguageBinding() -> Binding<String> {
        Binding(
            get: { settingsStore.settings.assistant.voiceSettings.whisperLanguage },
            set: { newValue in
                mutateAssistantSettings { assistant in
                    let value = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    assistant.voiceSettings.whisperLanguage = value.isEmpty ? "auto" : value
                }
            }
        )
    }

    private func assistantVoiceModelBinding() -> Binding<String> {
        Binding(
            get: { settingsStore.settings.assistant.voiceSettings.cosyVoiceModel },
            set: { newValue in
                mutateAssistantSettings { assistant in
                    assistant.voiceSettings.cosyVoiceModel = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        )
    }

    private func assistantVoiceSpeakerBinding() -> Binding<String> {
        Binding(
            get: { settingsStore.settings.assistant.voiceSettings.cosyVoiceSpeaker },
            set: { newValue in
                mutateAssistantSettings { assistant in
                    assistant.voiceSettings.cosyVoiceSpeaker = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        )
    }

    private func assistantVoiceScriptPathBinding() -> Binding<String> {
        Binding(
            get: { settingsStore.settings.assistant.voiceSettings.cosyVoiceScriptPath },
            set: { newValue in
                mutateAssistantSettings { assistant in
                    assistant.voiceSettings.cosyVoiceScriptPath = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        )
    }

    private func assistantVoiceInputDeviceBinding() -> Binding<String> {
        Binding(
            get: { settingsStore.settings.assistant.voiceSettings.voiceInputDeviceUID },
            set: { newValue in
                mutateAssistantSettings { assistant in
                    assistant.voiceSettings.voiceInputDeviceUID = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        )
    }

    private func assistantVoiceOutputDeviceBinding() -> Binding<String> {
        Binding(
            get: { settingsStore.settings.assistant.voiceSettings.voiceOutputDeviceUID },
            set: { newValue in
                mutateAssistantSettings { assistant in
                    assistant.voiceSettings.voiceOutputDeviceUID = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        )
    }

    private func reloadAudioDevices() {
        inputAudioDevices = AudioDeviceCatalog.inputDevices()
        outputAudioDevices = AudioDeviceCatalog.outputDevices()
    }

    private func mutateAssistantSettings(_ mutate: (inout AssistantSettings) -> Void) {
        var settings = settingsStore.settings
        mutate(&settings.assistant)
        settingsStore.settings = settings
    }

    private func cooldownDisplayText(_ minutes: Int) -> String {
        if minutes == 0 {
            return AppStrings.text(.settingsReminderCooldownOff)
        }
        return AppStrings.minutesText(minutes)
    }

    private var isAssistantPromptEnabled: Bool {
        settingsStore.settings.assistant.enabled && assistantRuntime.state == .ready && !assistantRuntime.isSendingPrompt
    }

    private var assistantConnectionColor: Color {
        switch assistantRuntime.state {
        case .ready:
            return .green
        case .starting:
            return .secondary
        case .idle:
            return .secondary
        case .unavailable, .failed:
            return .red
        }
    }

    private var notificationAuthorizationLabel: String {
        switch notificationAuthorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return AppStrings.text(.settingsAuthorizationAllowed)
        case .denied:
            return AppStrings.text(.settingsAuthorizationDenied)
        case .notDetermined:
            return AppStrings.text(.settingsAuthorizationNotDetermined)
        @unknown default:
            return AppStrings.text(.settingsAuthorizationUnknown)
        }
    }

    private var notificationAuthorizationColor: Color {
        switch notificationAuthorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return .green
        case .denied:
            return .red
        case .notDetermined:
            return .secondary
        @unknown default:
            return .secondary
        }
    }

    private func refreshNotificationAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationAuthorizationStatus = settings.authorizationStatus
            }
        }
    }

    private func openSystemNotificationSettings() {
        let deepLinks = [
            "x-apple.systempreferences:com.apple.preference.notifications",
            "x-apple.systempreferences:com.apple.Notifications-Settings.extension",
            "x-apple.systempreferences:"
        ]

        for link in deepLinks {
            guard let url = URL(string: link) else { continue }
            if NSWorkspace.shared.open(url) {
                return
            }
        }
    }
}

private struct ReminderPlanSection: View {
    let type: ReminderType
    @Binding var plan: ReminderPlan

    var body: some View {
        Toggle(type.displayName, isOn: $plan.enabled)

        if plan.enabled {
            settingRow(AppStrings.text(.settingsIntervalMinutes)) {
                HStack(spacing: 8) {
                    Stepper("", value: $plan.intervalMinutes, in: 15...240, step: 5)
                        .labelsHidden()
                    Text("\(plan.intervalMinutes)")
                        .monospacedDigit()
                }
            }

            settingRow(AppStrings.text(.settingsQuietHours)) {
                HStack(spacing: 8) {
                    Text(AppStrings.text(.settingsQuietStart))
                    Picker("", selection: $plan.quietHours.startHour) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text(String(format: "%02d:00", hour)).tag(hour)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 84)

                    Text(AppStrings.text(.settingsQuietEnd))
                    Picker("", selection: $plan.quietHours.endHour) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text(String(format: "%02d:00", hour)).tag(hour)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 84)
                }
            }

            settingRow(AppStrings.text(.settingsSnoozeReminder)) {
                HStack(spacing: 8) {
                    Stepper("", value: $plan.snoozeMinutes, in: 5...60, step: 5)
                        .labelsHidden()
                    Text(AppStrings.minutesText(plan.snoozeMinutes))
                        .monospacedDigit()
                }
            }
        }
    }

    private func settingRow<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        LabeledContent {
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Text(title)
        }
    }
}
