import Foundation
import SwiftUI
import Darwin
import AppKit
import CatCompanionCore

@main
struct CatCompanionApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()

    init() {
        RuntimeAutomationLog.configure(arguments: ProcessInfo.processInfo.arguments)
        if ProcessInfo.processInfo.arguments.contains("--dump-startup-diagnostics") {
            Self.dumpStartupDiagnosticsAndExit()
        }
        if ProcessInfo.processInfo.arguments.contains("--dump-localization") {
            Self.dumpLocalizationSnapshotAndExit()
        }
        appDelegate.model = model
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(model: model)
        } label: {
            Image("MenuBarCatTemplate")
                .renderingMode(.template)
                .accessibilityLabel(Text(AppStrings.text(.appName)))
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView(
                settingsStore: model.settingsStore,
                assistantRuntime: model.assistantRuntime,
                onOpenAssistantChat: { model.showAssistantChat() }
            )
                .frame(minWidth: 680, minHeight: 700)
        }
    }
}

enum RuntimeAutomationLog {
    private static let queue = DispatchQueue(label: "catcompanion.runtime-automation-log")
    private static var fileURL: URL?

    static func configure(arguments: [String]) {
        guard let argumentIndex = arguments.firstIndex(of: "--ui-automation-log"),
              argumentIndex + 1 < arguments.count else {
            return
        }

        let path = arguments[argumentIndex + 1]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else { return }

        let url = URL(fileURLWithPath: path)
        queue.sync {
            fileURL = url
            let directory = url.deletingLastPathComponent()
            try? FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            FileManager.default.createFile(atPath: url.path, contents: Data())
        }
    }

    static func record(_ event: String) {
        let trimmedEvent = event.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEvent.isEmpty else { return }
        queue.async {
            guard let fileURL else { return }
            let timestamp = ISO8601DateFormatter().string(from: Date())
            let line = "\(timestamp)\t\(trimmedEvent)\n"
            guard let data = line.data(using: .utf8) else { return }
            if let handle = try? FileHandle(forWritingTo: fileURL) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
            }
        }
    }
}

private extension CatCompanionApp {
    struct StartupDiagnosticsSnapshot: Codable {
        struct Check: Codable {
            let id: String
            let title: String
            let detail: String
            let status: String
        }

        let createdAt: String
        let checks: [Check]
    }

    struct LocalizationSnapshot: Codable {
        let resolvedLanguage: String
        let minutesText15: String
        let values: [String: String]
    }

    static func dumpStartupDiagnosticsAndExit() -> Never {
        let environment = ProcessInfo.processInfo.environment
        let assistantDefaults = AssistantSettings.defaults()
        let voiceDefaults = AssistantVoiceSettings.defaults()

        let input = StartupDiagnosticInput(
            assistantEnabled: envBool(environment, key: "CAT_DIAG_ASSISTANT_ENABLED", fallback: assistantDefaults.enabled),
            gatewayURL: envString(environment, key: "CAT_DIAG_GATEWAY_URL", fallback: assistantDefaults.gatewayURL),
            gatewayToken: envString(environment, key: "CAT_DIAG_GATEWAY_TOKEN", fallback: assistantDefaults.gatewayToken),
            whisperCommand: envString(environment, key: "CAT_DIAG_WHISPER_COMMAND", fallback: voiceDefaults.whisperCommand),
            whisperModelPath: envString(environment, key: "CAT_DIAG_WHISPER_MODEL_PATH", fallback: voiceDefaults.whisperModelPath),
            pythonCommand: envString(environment, key: "CAT_DIAG_PYTHON_COMMAND", fallback: voiceDefaults.pythonCommand),
            cosyVoiceScriptPath: envString(environment, key: "CAT_DIAG_COSYVOICE_SCRIPT_PATH", fallback: voiceDefaults.cosyVoiceScriptPath),
            voiceInputDeviceUID: envString(environment, key: "CAT_DIAG_VOICE_INPUT_DEVICE_UID", fallback: voiceDefaults.voiceInputDeviceUID),
            voiceOutputDeviceUID: envString(environment, key: "CAT_DIAG_VOICE_OUTPUT_DEVICE_UID", fallback: voiceDefaults.voiceOutputDeviceUID),
            voiceEnabled: envBool(environment, key: "CAT_DIAG_VOICE_ENABLED", fallback: voiceDefaults.enabled)
        )

        let semaphore = DispatchSemaphore(value: 0)
        let resultQueue = DispatchQueue(label: "catcompanion.diagdump.result")
        var checkPayload: [StartupDiagnosticsSnapshot.Check] = []

        Task.detached(priority: .userInitiated) {
            let checks = await StartupDiagnosticsRunner.run(input: input)
            let mappedChecks = checks.map { check in
                StartupDiagnosticsSnapshot.Check(
                    id: check.id,
                    title: check.title,
                    detail: check.detail,
                    status: check.status.code
                )
            }
            resultQueue.sync {
                checkPayload = mappedChecks
            }
            semaphore.signal()
        }

        let timeout = DispatchTime.now() + .seconds(20)
        if semaphore.wait(timeout: timeout) == .timedOut {
            print("{\"error\":\"diagnostics_timeout\"}")
            fflush(stdout)
            Darwin.exit(1)
        }

        let finalChecks = resultQueue.sync {
            checkPayload
        }
        let snapshot = StartupDiagnosticsSnapshot(
            createdAt: ISO8601DateFormatter().string(from: Date()),
            checks: finalChecks
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        if let data = try? encoder.encode(snapshot),
           let output = String(data: data, encoding: .utf8) {
            print(output)
        } else {
            print("{\"error\":\"failed_to_encode_startup_diagnostics\"}")
            fflush(stdout)
            Darwin.exit(1)
        }
        fflush(stdout)
        Darwin.exit(0)
    }

    static func dumpLocalizationSnapshotAndExit() -> Never {
        let keys: [AppStringKey] = [
            .appName,
            .menuSettings,
            .menuPauseReminders,
            .reminderHydrateName,
            .reminderHydratePrompt,
            .actionComplete,
            .actionSnooze,
            .settingsPauseAllReminders,
            .settingsReminderCooldown,
            .settingsReminderCooldownHelp,
            .settingsReminderCooldownOff
        ]

        var values: [String: String] = [:]
        for key in keys {
            values[key.rawValue] = AppStrings.text(key)
        }

        let snapshot = LocalizationSnapshot(
            resolvedLanguage: AppLanguage.current().rawValue,
            minutesText15: AppStrings.minutesText(15),
            values: values
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        if let data = try? encoder.encode(snapshot),
           let output = String(data: data, encoding: .utf8) {
            print(output)
        } else {
            print("{\"error\":\"failed_to_encode_localization_snapshot\"}")
        }
        fflush(stdout)
        Darwin.exit(0)
    }

    static func envString(_ environment: [String: String], key: String, fallback: String) -> String {
        environment[key] ?? fallback
    }

    static func envBool(_ environment: [String: String], key: String, fallback: Bool) -> Bool {
        guard let raw = environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !raw.isEmpty else {
            return fallback
        }
        switch raw {
        case "1", "true", "yes", "y", "on":
            return true
        case "0", "false", "no", "n", "off":
            return false
        default:
            return fallback
        }
    }

}

private struct MenuContentView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Group {
            // ── Assistant ──
            Button(model.petVisible ? AppStrings.text(.menuHidePet) : AppStrings.text(.menuShowPet)) {
                model.togglePetVisibility()
            }

            Button(AppStrings.text(.menuAssistantChat)) {
                model.showAssistantChat()
            }
            .disabled(!model.settingsStore.settings.assistant.enabled)

            Divider()

            // ── Reminders ──
            if model.settingsStore.settings.remindersPaused {
                Text(AppStrings.text(.menuRemindersPaused))
                Button(AppStrings.text(.menuResumeReminders)) {
                    var settings = model.settingsStore.settings
                    settings.remindersPaused = false
                    model.settingsStore.settings = settings
                }
            } else {
                nextReminderRow

                Menu(AppStrings.text(.settingsReminderSection)) {
                    ForEach(ReminderType.allCases) { type in
                        Toggle(type.displayName, isOn: planBinding(for: type).enabled)
                    }
                    Divider()
                    Button(AppStrings.text(.menuPauseReminders)) {
                        var settings = model.settingsStore.settings
                        settings.remindersPaused = true
                        model.settingsStore.settings = settings
                    }
                }
            }

            // ── Active reminder snooze ──
            if model.reminderEngine.activeReminder != nil {
                Menu(AppStrings.text(.actionSnooze)) {
                    Button(AppStrings.text(.menuSnooze5Min)) {
                        model.snoozeActiveReminderWith(minutes: 5)
                    }
                    Button(AppStrings.text(.menuSnooze10Min)) {
                        model.snoozeActiveReminderWith(minutes: 10)
                    }
                    Button(AppStrings.text(.menuSnooze30Min)) {
                        model.snoozeActiveReminderWith(minutes: 30)
                    }
                }
                Button(AppStrings.text(.actionComplete)) {
                    model.reminderEngine.completeActiveReminder()
                }
            }

            Divider()

            // ── AI & Settings ──
            Menu(AppStrings.text(.settingsAssistantSection)) {
                Toggle(AppStrings.text(.menuAssistantEnabled), isOn: assistantEnabledBinding())
                Divider()
                Button(AppStrings.text(.menuDiagnostics)) {
                    model.showDiagnosticsGuide()
                }
                Divider()
                Text("\(AppStrings.text(.settingsAssistantConnectionStatus)): \(model.assistantStatusText)")
            }

            Toggle(AppStrings.text(.menuSystemNotification), isOn: notificationsBinding())

            Divider()

            Button(AppStrings.text(.menuSettings)) {
                model.openSettingsWindow()
            }

            Button(AppStrings.text(.menuQuit)) {
                NSApplication.shared.terminate(nil)
            }
        }
    }

    @ViewBuilder
    private var nextReminderRow: some View {
        if let info = model.reminderEngine.nextReminderInfo() {
            let minutes = max(0, Int(info.due.timeIntervalSinceNow / 60))
            Text("\(AppStrings.text(.menuNextReminder)): \(info.type.displayName) (\(AppStrings.minutesText(minutes)))")
        }
    }

    private func planBinding(for type: ReminderType) -> Binding<ReminderPlan> {
        Binding(
            get: {
                model.settingsStore.settings.plans[type] ?? ReminderPlan(
                    enabled: true,
                    intervalMinutes: type.defaultIntervalMinutes,
                    quietHours: QuietHours(),
                    snoozeMinutes: type.defaultSnoozeMinutes
                )
            },
            set: { newValue in
                var settings = model.settingsStore.settings
                settings.plans[type] = newValue
                model.settingsStore.settings = settings
            }
        )
    }

    private func notificationsBinding() -> Binding<Bool> {
        Binding(
            get: { model.settingsStore.settings.notificationsEnabled },
            set: { newValue in
                var settings = model.settingsStore.settings
                settings.notificationsEnabled = newValue
                model.settingsStore.settings = settings
            }
        )
    }

    private func assistantEnabledBinding() -> Binding<Bool> {
        Binding(
            get: { model.settingsStore.settings.assistant.enabled },
            set: { newValue in
                var settings = model.settingsStore.settings
                settings.assistant.enabled = newValue
                model.settingsStore.settings = settings
            }
        )
    }
}
