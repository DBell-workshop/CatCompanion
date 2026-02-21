import Foundation
import SwiftUI
import Combine
import AppKit
import AVFoundation
import CatCompanionCore

@MainActor
final class AppModel: ObservableObject {
    let settingsStore: SettingsStore
    let reminderEngine: ReminderEngine
    let petWindowController: PetWindowController
    let assistantRuntime: AssistantRuntime
    let assistantChatWindowController: AssistantChatWindowController

    private let notifications = NotificationManager()
    private let startupDefaults = UserDefaults.standard
    private let startupDiagnosticsSeenKey = "CatCompanion.StartupDiagnosticsSeen"
    private var cancellables = Set<AnyCancellable>()
    private var petPinnedByUser = false
    private lazy var diagnosticsGuideWindowController = DiagnosticsGuideWindowController(appModel: self)
    private lazy var settingsWindowController = AppSettingsWindowController(
        settingsStore: settingsStore,
        assistantRuntime: assistantRuntime,
        onOpenAssistantChat: { [weak self] in
            self?.showAssistantChat()
        }
    )

    @Published var petVisible: Bool = false
    @Published private(set) var assistantState: AssistantConnectionState = .idle
    @Published private(set) var diagnosticsChecks: [StartupDiagnosticCheck] = []
    @Published private(set) var isRunningDiagnostics: Bool = false
    @Published private(set) var diagnosticsLastCheckedAt: Date?

    init() {
        let store = SettingsStore()
        let assistantRuntime = AssistantRuntime(settingsStore: store)
        self.settingsStore = store
        self.reminderEngine = ReminderEngine(settingsStore: store)
        self.assistantRuntime = assistantRuntime
        self.petWindowController = PetWindowController(
            settingsStore: store,
            reminderEngine: reminderEngine,
            assistantRuntime: assistantRuntime
        )
        self.assistantChatWindowController = AssistantChatWindowController(assistantRuntime: assistantRuntime)
        self.notifications.delegate = self
        bind()
    }

    func start() {
        reminderEngine.start()
        petPinnedByUser = false
        setPetVisible(false)

        assistantRuntime.applySettings()
        runStartupDiagnosticsIfNeeded()

        if settingsStore.settings.notificationsEnabled {
            notifications.requestAuthorizationIfNeeded { [weak self] granted in
                guard let self, !granted else { return }
                Task { @MainActor in
                    self.disableNotifications()
                }
            }
        }
    }

    func togglePetVisibility() {
        if petVisible {
            petPinnedByUser = false
            setPetVisible(false)
        } else {
            petPinnedByUser = true
            setPetVisible(true)
        }
    }

    func updateAlwaysOnTop() {
        petWindowController.setAlwaysOnTop(settingsStore.settings.petAlwaysOnTop)
    }

    func showAssistantChat() {
        RuntimeAutomationLog.record("assistant_chat_open")
        assistantChatWindowController.show()
    }

    func showDiagnosticsGuide() {
        RuntimeAutomationLog.record("diagnostics_open")
        diagnosticsGuideWindowController.show()
        runStartupDiagnostics()
    }

    func runDiagnostics() {
        runStartupDiagnostics()
    }

    func completeDiagnosticsGuide() {
        startupDefaults.set(true, forKey: startupDiagnosticsSeenKey)
        diagnosticsGuideWindowController.close()
    }

    func openSettingsWindow() {
        RuntimeAutomationLog.record("settings_open")
        settingsWindowController.show()
    }

    var assistantStatusText: String {
        assistantState.displayText
    }

    private func runStartupDiagnosticsIfNeeded() {
        if startupDefaults.bool(forKey: startupDiagnosticsSeenKey) {
            return
        }
        diagnosticsGuideWindowController.show()
        runStartupDiagnostics()
    }

    private func runStartupDiagnostics() {
        if isRunningDiagnostics { return }
        let input = StartupDiagnosticInput(
            assistantEnabled: settingsStore.settings.assistant.enabled,
            gatewayURL: settingsStore.settings.assistant.gatewayURL,
            gatewayToken: settingsStore.settings.assistant.gatewayToken,
            whisperCommand: settingsStore.settings.assistant.voiceSettings.whisperCommand,
            whisperModelPath: settingsStore.settings.assistant.voiceSettings.whisperModelPath,
            pythonCommand: settingsStore.settings.assistant.voiceSettings.pythonCommand,
            cosyVoiceScriptPath: settingsStore.settings.assistant.voiceSettings.cosyVoiceScriptPath,
            voiceInputDeviceUID: settingsStore.settings.assistant.voiceSettings.voiceInputDeviceUID,
            voiceOutputDeviceUID: settingsStore.settings.assistant.voiceSettings.voiceOutputDeviceUID,
            voiceEnabled: settingsStore.settings.assistant.voiceSettings.enabled
        )

        isRunningDiagnostics = true
        Task {
            let checks = await StartupDiagnosticsRunner.run(input: input)
            diagnosticsChecks = checks
            diagnosticsLastCheckedAt = Date()
            isRunningDiagnostics = false
        }
    }

    private func bind() {
        reminderEngine.$activeReminder
            .receive(on: RunLoop.main)
            .sink { [weak self] reminder in
                guard let self else { return }
                if let reminder {
                    if self.settingsStore.settings.notificationsEnabled {
                        self.notifications.sendNotification(for: reminder)
                    } else if !self.petVisible {
                        self.setPetVisible(true)
                    }
                } else {
                    self.syncAutoPetVisibility()
                }
            }
            .store(in: &cancellables)

        settingsStore.$settings
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateAlwaysOnTop()
                self?.syncAutoPetVisibility()
            }
            .store(in: &cancellables)

        settingsStore.$settings
            .map(\AppSettings.notificationsEnabled)
            .removeDuplicates()
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] enabled in
                guard let self, enabled else { return }
                self.notifications.requestAuthorizationIfNeeded { [weak self] granted in
                    guard let self, !granted else { return }
                    Task { @MainActor in
                        self.disableNotifications()
                    }
                }
            }
            .store(in: &cancellables)

        settingsStore.$settings
            .map(\AppSettings.assistant)
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.assistantRuntime.applySettings()
            }
            .store(in: &cancellables)

        assistantRuntime.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                self?.assistantState = state
            }
            .store(in: &cancellables)
    }

    private func disableNotifications() {
        var settings = settingsStore.settings
        settings.notificationsEnabled = false
        settingsStore.settings = settings
    }

    private func presentPetWindow() {
        petPinnedByUser = true
        setPetVisible(true)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    private func syncAutoPetVisibility() {
        guard !petPinnedByUser else { return }
        guard settingsStore.settings.petShowOnlyWhenReminding else { return }

        let shouldShow = reminderEngine.activeReminder != nil && !settingsStore.settings.notificationsEnabled
        setPetVisible(shouldShow)
    }

    private func setPetVisible(_ visible: Bool) {
        petVisible = visible
        if visible {
            petWindowController.show()
        } else {
            petWindowController.hide()
        }
    }
}

extension AppModel: NotificationManagerDelegate {
    func notificationManager(
        _ manager: NotificationManager,
        didReceive action: NotificationAction,
        reminderType: ReminderType?
    ) {
        switch action {
        case .open:
            break
        case .complete:
            if let reminderType {
                reminderEngine.completeReminder(reminderType)
            } else {
                reminderEngine.completeActiveReminder()
            }
        case .snooze:
            if let reminderType {
                reminderEngine.snoozeReminder(reminderType)
            } else {
                reminderEngine.snoozeActiveReminder()
            }
        }
        if case .open = action {
            presentPetWindow()
        }
    }
}

enum StartupDiagnosticStatus: Equatable, Sendable {
    case pass
    case warning
    case failed

    var code: String {
        switch self {
        case .pass:
            return "pass"
        case .warning:
            return "warning"
        case .failed:
            return "failed"
        }
    }

    var label: String {
        switch self {
        case .pass:
            return AppStrings.text(.diagnosticsStatusPass)
        case .warning:
            return AppStrings.text(.diagnosticsStatusWarning)
        case .failed:
            return AppStrings.text(.diagnosticsStatusFailed)
        }
    }
}

struct StartupDiagnosticCheck: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let detail: String
    let status: StartupDiagnosticStatus
}

struct StartupDiagnosticInput: Sendable {
    let assistantEnabled: Bool
    let gatewayURL: String
    let gatewayToken: String
    let whisperCommand: String
    let whisperModelPath: String
    let pythonCommand: String
    let cosyVoiceScriptPath: String
    let voiceInputDeviceUID: String
    let voiceOutputDeviceUID: String
    let voiceEnabled: Bool
}

enum StartupDiagnosticsRunner {
    static func run(input: StartupDiagnosticInput) async -> [StartupDiagnosticCheck] {
        await Task.detached(priority: .userInitiated) {
            await buildChecks(input: input)
        }.value
    }

    private static func buildChecks(input: StartupDiagnosticInput) async -> [StartupDiagnosticCheck] {
        var checks: [StartupDiagnosticCheck] = []

        checks.append(buildHelperCheck())
        checks.append(await buildGatewayCheck(
            assistantEnabled: input.assistantEnabled,
            gatewayURL: input.gatewayURL,
            gatewayToken: input.gatewayToken
        ))
        checks.append(buildMicrophoneCheck())
        checks.append(buildInputDeviceCheck(deviceUID: input.voiceInputDeviceUID, voiceEnabled: input.voiceEnabled))
        checks.append(buildOutputDeviceCheck(deviceUID: input.voiceOutputDeviceUID, voiceEnabled: input.voiceEnabled))
        checks.append(buildWhisperCommandCheck(command: input.whisperCommand, voiceEnabled: input.voiceEnabled))
        checks.append(buildWhisperModelCheck(modelPath: input.whisperModelPath, voiceEnabled: input.voiceEnabled))
        checks.append(buildCosyScriptCheck(scriptPath: input.cosyVoiceScriptPath, voiceEnabled: input.voiceEnabled))
        checks.append(buildPythonDependenciesCheck(pythonCommand: input.pythonCommand, voiceEnabled: input.voiceEnabled))

        return checks
    }

    private static func buildHelperCheck() -> StartupDiagnosticCheck {
        if let path = resolveHelperExecutablePath() {
            return StartupDiagnosticCheck(
                id: "helper",
                title: AppStrings.text(.diagnosticsCheckHelper),
                detail: "\(AppStrings.text(.diagnosticsDetailFound)): \(path)",
                status: .pass
            )
        }
        return StartupDiagnosticCheck(
            id: "helper",
            title: AppStrings.text(.diagnosticsCheckHelper),
            detail: AppStrings.text(.diagnosticsDetailMissing),
            status: .failed
        )
    }

    private static func buildGatewayCheck(
        assistantEnabled: Bool,
        gatewayURL: String,
        gatewayToken: String
    ) async -> StartupDiagnosticCheck {
        if !assistantEnabled {
            return StartupDiagnosticCheck(
                id: "gateway",
                title: AppStrings.text(.diagnosticsCheckGateway),
                detail: AppStrings.text(.diagnosticsDetailAssistantDisabled),
                status: .warning
            )
        }

        let trimmed = gatewayURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return StartupDiagnosticCheck(
                id: "gateway",
                title: AppStrings.text(.diagnosticsCheckGateway),
                detail: AppStrings.text(.diagnosticsDetailNotConfigured),
                status: .failed
            )
        }
        guard var components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased() else {
            return StartupDiagnosticCheck(
                id: "gateway",
                title: AppStrings.text(.diagnosticsCheckGateway),
                detail: "\(AppStrings.text(.diagnosticsDetailMissing)): \(trimmed)",
                status: .failed
            )
        }

        if scheme == "http" {
            components.scheme = "ws"
        } else if scheme == "https" {
            components.scheme = "wss"
        }

        guard let normalizedScheme = components.scheme?.lowercased(),
              normalizedScheme == "ws" || normalizedScheme == "wss",
              let url = components.url else {
            return StartupDiagnosticCheck(
                id: "gateway",
                title: AppStrings.text(.diagnosticsCheckGateway),
                detail: "\(AppStrings.text(.diagnosticsDetailMissing)): \(trimmed)",
                status: .failed
            )
        }

        let probeResult = await probeGateway(url: url, token: gatewayToken)
        switch probeResult {
        case .ok:
            return StartupDiagnosticCheck(
                id: "gateway",
                title: AppStrings.text(.diagnosticsCheckGateway),
                detail: "\(AppStrings.text(.diagnosticsDetailConnected)): \(trimmed)",
                status: .pass
            )
        case .failed(let reason):
            return StartupDiagnosticCheck(
                id: "gateway",
                title: AppStrings.text(.diagnosticsCheckGateway),
                detail: "\(AppStrings.text(.diagnosticsDetailConnectionFailed)): \(reason)",
                status: .failed
            )
        }
    }

    private static func buildMicrophoneCheck() -> StartupDiagnosticCheck {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .authorized:
            return StartupDiagnosticCheck(
                id: "microphone",
                title: AppStrings.text(.diagnosticsCheckMicrophone),
                detail: AppStrings.text(.diagnosticsDetailPermissionGranted),
                status: .pass
            )
        case .notDetermined:
            return StartupDiagnosticCheck(
                id: "microphone",
                title: AppStrings.text(.diagnosticsCheckMicrophone),
                detail: AppStrings.text(.diagnosticsDetailPermissionUnknown),
                status: .warning
            )
        case .denied, .restricted:
            return StartupDiagnosticCheck(
                id: "microphone",
                title: AppStrings.text(.diagnosticsCheckMicrophone),
                detail: AppStrings.text(.diagnosticsDetailPermissionDenied),
                status: .failed
            )
        @unknown default:
            return StartupDiagnosticCheck(
                id: "microphone",
                title: AppStrings.text(.diagnosticsCheckMicrophone),
                detail: AppStrings.text(.diagnosticsDetailPermissionUnknown),
                status: .warning
            )
        }
    }

    private static func buildInputDeviceCheck(deviceUID: String, voiceEnabled: Bool) -> StartupDiagnosticCheck {
        if !voiceEnabled {
            return StartupDiagnosticCheck(
                id: "voice-input-device",
                title: AppStrings.text(.diagnosticsCheckInputDevice),
                detail: AppStrings.text(.diagnosticsDetailVoiceDisabled),
                status: .warning
            )
        }

        let trimmed = deviceUID.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return StartupDiagnosticCheck(
                id: "voice-input-device",
                title: AppStrings.text(.diagnosticsCheckInputDevice),
                detail: AppStrings.text(.diagnosticsDetailUsingSystemDefault),
                status: .pass
            )
        }

        if AudioDeviceCatalog.hasInputDevice(uid: trimmed) {
            return StartupDiagnosticCheck(
                id: "voice-input-device",
                title: AppStrings.text(.diagnosticsCheckInputDevice),
                detail: "\(AppStrings.text(.diagnosticsDetailFound)): \(trimmed)",
                status: .pass
            )
        }

        return StartupDiagnosticCheck(
            id: "voice-input-device",
            title: AppStrings.text(.diagnosticsCheckInputDevice),
            detail: "\(AppStrings.text(.diagnosticsDetailMissing)): \(trimmed)",
            status: .failed
        )
    }

    private static func buildOutputDeviceCheck(deviceUID: String, voiceEnabled: Bool) -> StartupDiagnosticCheck {
        if !voiceEnabled {
            return StartupDiagnosticCheck(
                id: "voice-output-device",
                title: AppStrings.text(.diagnosticsCheckOutputDevice),
                detail: AppStrings.text(.diagnosticsDetailVoiceDisabled),
                status: .warning
            )
        }

        let trimmed = deviceUID.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return StartupDiagnosticCheck(
                id: "voice-output-device",
                title: AppStrings.text(.diagnosticsCheckOutputDevice),
                detail: AppStrings.text(.diagnosticsDetailUsingSystemDefault),
                status: .pass
            )
        }

        if AudioDeviceCatalog.hasOutputDevice(uid: trimmed) {
            return StartupDiagnosticCheck(
                id: "voice-output-device",
                title: AppStrings.text(.diagnosticsCheckOutputDevice),
                detail: "\(AppStrings.text(.diagnosticsDetailFound)): \(trimmed)",
                status: .pass
            )
        }

        return StartupDiagnosticCheck(
            id: "voice-output-device",
            title: AppStrings.text(.diagnosticsCheckOutputDevice),
            detail: "\(AppStrings.text(.diagnosticsDetailMissing)): \(trimmed)",
            status: .failed
        )
    }

    private static func buildWhisperCommandCheck(command: String, voiceEnabled: Bool) -> StartupDiagnosticCheck {
        if !voiceEnabled {
            return StartupDiagnosticCheck(
                id: "whisper-command",
                title: AppStrings.text(.diagnosticsCheckWhisperCommand),
                detail: AppStrings.text(.diagnosticsDetailVoiceDisabled),
                status: .warning
            )
        }

        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return StartupDiagnosticCheck(
                id: "whisper-command",
                title: AppStrings.text(.diagnosticsCheckWhisperCommand),
                detail: AppStrings.text(.diagnosticsDetailNotConfigured),
                status: .failed
            )
        }
        if let path = resolveExecutablePath(trimmed) {
            return StartupDiagnosticCheck(
                id: "whisper-command",
                title: AppStrings.text(.diagnosticsCheckWhisperCommand),
                detail: "\(AppStrings.text(.diagnosticsDetailFound)): \(path)",
                status: .pass
            )
        }
        return StartupDiagnosticCheck(
            id: "whisper-command",
            title: AppStrings.text(.diagnosticsCheckWhisperCommand),
            detail: "\(AppStrings.text(.diagnosticsDetailMissing)): \(trimmed)",
            status: .failed
        )
    }

    private static func buildWhisperModelCheck(modelPath: String, voiceEnabled: Bool) -> StartupDiagnosticCheck {
        if !voiceEnabled {
            return StartupDiagnosticCheck(
                id: "whisper-model",
                title: AppStrings.text(.diagnosticsCheckWhisperModel),
                detail: AppStrings.text(.diagnosticsDetailVoiceDisabled),
                status: .warning
            )
        }

        let trimmed = modelPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return StartupDiagnosticCheck(
                id: "whisper-model",
                title: AppStrings.text(.diagnosticsCheckWhisperModel),
                detail: AppStrings.text(.diagnosticsDetailNotConfigured),
                status: .failed
            )
        }
        if FileManager.default.fileExists(atPath: trimmed) {
            return StartupDiagnosticCheck(
                id: "whisper-model",
                title: AppStrings.text(.diagnosticsCheckWhisperModel),
                detail: "\(AppStrings.text(.diagnosticsDetailFound)): \(trimmed)",
                status: .pass
            )
        }
        return StartupDiagnosticCheck(
            id: "whisper-model",
            title: AppStrings.text(.diagnosticsCheckWhisperModel),
            detail: "\(AppStrings.text(.diagnosticsDetailMissing)): \(trimmed)",
            status: .failed
        )
    }

    private static func buildCosyScriptCheck(scriptPath: String, voiceEnabled: Bool) -> StartupDiagnosticCheck {
        if !voiceEnabled {
            return StartupDiagnosticCheck(
                id: "cosy-script",
                title: AppStrings.text(.diagnosticsCheckCosyScript),
                detail: AppStrings.text(.diagnosticsDetailVoiceDisabled),
                status: .warning
            )
        }

        let fileManager = FileManager.default
        let trimmed = scriptPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            if fileManager.isReadableFile(atPath: trimmed) {
                return StartupDiagnosticCheck(
                    id: "cosy-script",
                    title: AppStrings.text(.diagnosticsCheckCosyScript),
                    detail: "\(AppStrings.text(.diagnosticsDetailFound)): \(trimmed)",
                    status: .pass
                )
            }
            return StartupDiagnosticCheck(
                id: "cosy-script",
                title: AppStrings.text(.diagnosticsCheckCosyScript),
                detail: "\(AppStrings.text(.diagnosticsDetailMissing)): \(trimmed)",
                status: .failed
            )
        }

        let executableDir = URL(fileURLWithPath: CommandLine.arguments.first ?? "")
            .deletingLastPathComponent()
        let currentDirectory = URL(fileURLWithPath: fileManager.currentDirectoryPath)
        let appBundle = Bundle.main.bundleURL
        let candidates = [
            currentDirectory.appendingPathComponent("scripts/cosyvoice_tts.py"),
            executableDir.appendingPathComponent("../../../scripts/cosyvoice_tts.py"),
            appBundle.appendingPathComponent("Contents/Resources/cosyvoice_tts.py")
        ]

        if let path = candidates
            .first(where: { fileManager.isReadableFile(atPath: $0.path) })?
            .standardizedFileURL.path {
            return StartupDiagnosticCheck(
                id: "cosy-script",
                title: AppStrings.text(.diagnosticsCheckCosyScript),
                detail: "\(AppStrings.text(.diagnosticsDetailFound)): \(path)",
                status: .pass
            )
        }

        return StartupDiagnosticCheck(
            id: "cosy-script",
            title: AppStrings.text(.diagnosticsCheckCosyScript),
            detail: AppStrings.text(.diagnosticsDetailMissing),
            status: .failed
        )
    }

    private static func buildPythonDependenciesCheck(pythonCommand: String, voiceEnabled: Bool) -> StartupDiagnosticCheck {
        if !voiceEnabled {
            return StartupDiagnosticCheck(
                id: "python-deps",
                title: AppStrings.text(.diagnosticsCheckPythonDependencies),
                detail: AppStrings.text(.diagnosticsDetailVoiceDisabled),
                status: .warning
            )
        }

        let trimmed = pythonCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        let command = trimmed.isEmpty ? "python3" : trimmed
        if resolveExecutablePath(command) == nil {
            return StartupDiagnosticCheck(
                id: "python-deps",
                title: AppStrings.text(.diagnosticsCheckPythonDependencies),
                detail: "\(AppStrings.text(.diagnosticsDetailMissing)): \(command)",
                status: .failed
            )
        }

        let modules = ["modelscope", "torch", "torchaudio"]
        let missingModules = modules.filter { !pythonModuleExists(module: $0, pythonCommand: command) }
        if missingModules.isEmpty {
            return StartupDiagnosticCheck(
                id: "python-deps",
                title: AppStrings.text(.diagnosticsCheckPythonDependencies),
                detail: AppStrings.text(.diagnosticsDetailFound),
                status: .pass
            )
        }

        return StartupDiagnosticCheck(
            id: "python-deps",
            title: AppStrings.text(.diagnosticsCheckPythonDependencies),
            detail: "\(AppStrings.text(.diagnosticsDetailMissing)): \(missingModules.joined(separator: ", "))",
            status: .failed
        )
    }

    private enum GatewayProbeResult {
        case ok
        case failed(String)
    }

    private enum GatewayProbeError: Error {
        case connectTimeout
        case receiveTimeout
        case invalidFrame
        case connectRejected(String)
        case healthRejected(String)
        case transport(String)

        var message: String {
            switch self {
            case .connectTimeout:
                return "connect_timeout"
            case .receiveTimeout:
                return "receive_timeout"
            case .invalidFrame:
                return "invalid_frame"
            case .connectRejected(let reason):
                return "connect_rejected:\(reason)"
            case .healthRejected(let reason):
                return "health_rejected:\(reason)"
            case .transport(let reason):
                return "transport_error:\(reason)"
            }
        }
    }

    private static func probeGateway(url: URL, token: String) async -> GatewayProbeResult {
        let session = URLSession(configuration: .ephemeral)
        let websocket = session.webSocketTask(with: url)
        websocket.resume()

        defer {
            websocket.cancel(with: .goingAway, reason: nil)
            session.invalidateAndCancel()
        }

        let connectID = "diag-connect-\(UUID().uuidString)"
        var connectParams: [String: Any] = [
            "minProtocol": 3,
            "maxProtocol": 3,
            "client": [
                "id": "catcompanion-diagnostics",
                "displayName": "Cat Companion Diagnostics",
                "version": "0.1.0",
                "platform": "macos",
                "mode": "operator"
            ],
            "role": "operator",
            "scopes": [
                "operator.read",
                "operator.write"
            ],
            "locale": Locale.current.identifier,
            "userAgent": "cat-companion-diagnostics/0.1.0"
        ]
        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedToken.isEmpty {
            connectParams["auth"] = ["token": trimmedToken]
        }

        do {
            try await sendFrame(
                websocket: websocket,
                frame: [
                    "type": "req",
                    "id": connectID,
                    "method": "connect",
                    "params": connectParams
                ]
            )

            let connectResponse = try await awaitResponse(
                websocket: websocket,
                requestID: connectID,
                timeoutSeconds: 5
            )
            guard jsonBool(connectResponse["ok"]) else {
                let reason = extractErrorMessage(from: connectResponse) ?? "connect_failed"
                throw GatewayProbeError.connectRejected(reason)
            }

            let healthID = "diag-health-\(UUID().uuidString)"
            try await sendFrame(
                websocket: websocket,
                frame: [
                    "type": "req",
                    "id": healthID,
                    "method": "health",
                    "params": [:]
                ]
            )

            let healthResponse = try await awaitResponse(
                websocket: websocket,
                requestID: healthID,
                timeoutSeconds: 5
            )
            guard jsonBool(healthResponse["ok"]) else {
                let reason = extractErrorMessage(from: healthResponse) ?? "health_failed"
                throw GatewayProbeError.healthRejected(reason)
            }

            return .ok
        } catch let error as GatewayProbeError {
            return .failed(error.message)
        } catch {
            return .failed("unexpected_error")
        }
    }

    private static func sendFrame(
        websocket: URLSessionWebSocketTask,
        frame: [String: Any]
    ) async throws {
        let data = try JSONSerialization.data(withJSONObject: frame)
        guard let text = String(data: data, encoding: .utf8) else {
            throw GatewayProbeError.invalidFrame
        }
        do {
            try await websocket.send(.string(text))
        } catch {
            throw GatewayProbeError.transport(error.localizedDescription)
        }
    }

    private static func awaitResponse(
        websocket: URLSessionWebSocketTask,
        requestID: String,
        timeoutSeconds: Double
    ) async throws -> [String: Any] {
        while true {
            let frame = try await receiveFrameWithTimeout(websocket: websocket, timeoutSeconds: timeoutSeconds)
            guard let type = frame["type"] as? String else {
                throw GatewayProbeError.invalidFrame
            }

            if type == "event",
               (frame["event"] as? String) == "connect.challenge" {
                continue
            }

            if type == "res",
               (frame["id"] as? String) == requestID {
                return frame
            }
        }
    }

    private static func receiveFrameWithTimeout(
        websocket: URLSessionWebSocketTask,
        timeoutSeconds: Double
    ) async throws -> [String: Any] {
        try await withThrowingTaskGroup(of: [String: Any].self) { group in
            group.addTask {
                try await receiveFrame(websocket: websocket)
            }
            group.addTask {
                let duration = UInt64((timeoutSeconds * 1_000_000_000).rounded())
                try await Task.sleep(nanoseconds: duration)
                throw GatewayProbeError.receiveTimeout
            }

            guard let first = try await group.next() else {
                throw GatewayProbeError.connectTimeout
            }
            group.cancelAll()
            return first
        }
    }

    private static func receiveFrame(
        websocket: URLSessionWebSocketTask
    ) async throws -> [String: Any] {
        let message: URLSessionWebSocketTask.Message
        do {
            message = try await websocket.receive()
        } catch {
            throw GatewayProbeError.transport(error.localizedDescription)
        }

        let data: Data
        switch message {
        case .string(let text):
            guard let encoded = text.data(using: .utf8) else {
                throw GatewayProbeError.invalidFrame
            }
            data = encoded
        case .data(let bytes):
            data = bytes
        @unknown default:
            throw GatewayProbeError.invalidFrame
        }

        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw GatewayProbeError.invalidFrame
        }
        return object
    }

    private static func jsonBool(_ value: Any?) -> Bool {
        if let bool = value as? Bool {
            return bool
        }
        if let number = value as? NSNumber {
            return number.boolValue
        }
        return false
    }

    private static func extractErrorMessage(from frame: [String: Any]) -> String? {
        guard let error = frame["error"] as? [String: Any] else { return nil }
        if let message = error["message"] as? String, !message.isEmpty {
            return message
        }
        if let code = error["code"] as? String, !code.isEmpty {
            return code
        }
        return nil
    }

    private static func resolveExecutablePath(_ command: String) -> String? {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let fileManager = FileManager.default
        if trimmed.contains("/") {
            return fileManager.isExecutableFile(atPath: trimmed) ? trimmed : nil
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["which", trimmed]
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        guard process.terminationStatus == 0 else { return nil }
        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let path = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return path.isEmpty ? nil : path
    }

    private static func pythonModuleExists(module: String, pythonCommand: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [
            pythonCommand,
            "-c",
            "import importlib.util,sys;sys.exit(0 if importlib.util.find_spec('\(module)') else 1)"
        ]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return false
        }
        return process.terminationStatus == 0
    }

    private static func resolveHelperExecutablePath() -> String? {
        let environment = ProcessInfo.processInfo.environment
        let fileManager = FileManager.default

        if let override = environment["CATCOMPANION_AGENT_PATH"],
           fileManager.isExecutableFile(atPath: override) {
            return override
        }

        let appBundle = Bundle.main.bundleURL
        let executableDir = URL(fileURLWithPath: CommandLine.arguments.first ?? "").deletingLastPathComponent()
        let currentDirectory = URL(fileURLWithPath: fileManager.currentDirectoryPath)

        let candidates = [
            appBundle.appendingPathComponent("Contents/MacOS/CatCompanionAgent"),
            appBundle.appendingPathComponent("Contents/Helpers/CatCompanionAgent"),
            appBundle.appendingPathComponent("Contents/Library/LoginItems/CatCompanionAgent.app/Contents/MacOS/CatCompanionAgent"),
            executableDir.appendingPathComponent("CatCompanionAgent"),
            currentDirectory.appendingPathComponent(".build/debug/CatCompanionAgent"),
            currentDirectory.appendingPathComponent(".build/arm64-apple-macosx/debug/CatCompanionAgent"),
            currentDirectory.appendingPathComponent(".build/x86_64-apple-macosx/debug/CatCompanionAgent")
        ]

        return candidates.first(where: { fileManager.isExecutableFile(atPath: $0.path) })?.path
    }
}

final class DiagnosticsGuideWindowController {
    private let window: NSWindow

    init(appModel: AppModel) {
        let rootView = DiagnosticsGuideView(appModel: appModel)
        let hosting = NSHostingView(rootView: rootView)

        let window = NSWindow(
            contentRect: NSRect(x: 220, y: 160, width: 620, height: 520),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = AppStrings.text(.diagnosticsGuideTitle)
        window.isReleasedWhenClosed = false
        window.contentView = hosting
        window.setFrameAutosaveName("DiagnosticsGuideWindow")
        self.window = window
    }

    func show() {
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    func close() {
        window.close()
    }
}

private struct DiagnosticsGuideView: View {
    @ObservedObject var appModel: AppModel
    @State private var currentPhase: Int = 0

    private var basicChecks: [StartupDiagnosticCheck] {
        appModel.diagnosticsChecks.filter {
            ["helper", "gateway", "microphone"].contains($0.id)
        }
    }

    private var advancedChecks: [StartupDiagnosticCheck] {
        appModel.diagnosticsChecks.filter {
            !["helper", "gateway", "microphone"].contains($0.id)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text(AppStrings.text(.diagnosticsGuideTitle))
                    .font(.title2)
                    .fontWeight(.bold)
                Text(AppStrings.text(.diagnosticsGuideSubtitle))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 16)

            // Phase indicator
            HStack(spacing: 12) {
                DiagnosticsPhaseTab(
                    title: AppStrings.text(.diagnosticsGuidePhaseBasicTitle),
                    index: 0,
                    currentPhase: currentPhase,
                    action: { currentPhase = 0 }
                )
                DiagnosticsPhaseTab(
                    title: AppStrings.text(.diagnosticsGuidePhaseAdvancedTitle),
                    index: 1,
                    currentPhase: currentPhase,
                    action: { currentPhase = 1 }
                )
            }
            .padding(.bottom, 12)

            Divider()
                .padding(.bottom, 12)

            // Phase content
            if currentPhase == 0 {
                phaseBasicContent
            } else {
                phaseAdvancedContent
            }

            Spacer(minLength: 8)

            Divider()
                .padding(.vertical, 8)

            // Bottom navigation
            bottomBar
        }
        .padding(20)
        .frame(minWidth: 580, minHeight: 520)
    }

    // MARK: - Phase 1: Basic Setup

    private var phaseBasicContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(AppStrings.text(.diagnosticsGuidePhaseBasicSubtitle))
                .font(.callout)
                .foregroundStyle(.secondary)

            DiagnosticsQuickStartCard(
                onOpenSettings: { appModel.openSettingsWindow() }
            )

            if !basicChecks.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(basicChecks) { check in
                        DiagnosticsCheckRow(check: check)
                    }
                }
                .padding(.top, 4)
            }

            if appModel.isRunningDiagnostics {
                Text(AppStrings.text(.diagnosticsGuideChecking))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else if let lastChecked = appModel.diagnosticsLastCheckedAt {
                Text("\(AppStrings.text(.diagnosticsGuideLastChecked)): \(Self.dateFormatter.string(from: lastChecked))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Phase 2: Advanced Features

    private var phaseAdvancedContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(AppStrings.text(.diagnosticsGuidePhaseAdvancedSubtitle))
                .font(.callout)
                .foregroundStyle(.secondary)

            // Skip hint
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .foregroundStyle(.blue)
                    .font(.caption)
                Text(AppStrings.text(.diagnosticsGuidePhaseAdvancedSkipHint))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.blue.opacity(0.06))
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(advancedChecks) { check in
                        DiagnosticsCheckRow(check: check)
                    }
                }
            }

            if appModel.isRunningDiagnostics {
                Text(AppStrings.text(.diagnosticsGuideChecking))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack {
            if currentPhase == 1 {
                Button(AppStrings.text(.diagnosticsGuidePreviousStep)) {
                    currentPhase = 0
                }
            }

            Button(AppStrings.text(.diagnosticsGuideRunAgain)) {
                appModel.runDiagnostics()
            }
            .disabled(appModel.isRunningDiagnostics)

            Button(AppStrings.text(.diagnosticsGuideOpenSettings)) {
                appModel.openSettingsWindow()
            }

            Spacer()

            if currentPhase == 0 {
                Button(AppStrings.text(.diagnosticsGuideSkip)) {
                    appModel.completeDiagnosticsGuide()
                }

                Button(AppStrings.text(.diagnosticsGuideNextStep)) {
                    currentPhase = 1
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button(AppStrings.text(.diagnosticsGuideSkip)) {
                    appModel.completeDiagnosticsGuide()
                }

                Button(AppStrings.text(.diagnosticsGuideDone)) {
                    appModel.completeDiagnosticsGuide()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

// MARK: - Phase Tab

private struct DiagnosticsPhaseTab: View {
    let title: String
    let index: Int
    let currentPhase: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(index == currentPhase ? .semibold : .regular)
                .foregroundStyle(index == currentPhase ? .primary : .secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(index == currentPhase ? Color.accentColor.opacity(0.12) : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Quick Start Card

private struct DiagnosticsQuickStartCard: View {
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(AppStrings.text(.diagnosticsQuickStartTitle))
                .font(.headline)

            DiagnosticsQuickStartRow(
                step: 1,
                title: AppStrings.text(.diagnosticsQuickStartNotificationsTitle),
                detail: AppStrings.text(.diagnosticsQuickStartNotificationsDetail),
                actionTitle: AppStrings.text(.diagnosticsGuideOpenSettings),
                action: onOpenSettings
            )

            DiagnosticsQuickStartRow(
                step: 2,
                title: AppStrings.text(.diagnosticsQuickStartGatewayTitle),
                detail: AppStrings.text(.diagnosticsQuickStartGatewayDetail),
                actionTitle: AppStrings.text(.diagnosticsGuideOpenSettings),
                action: onOpenSettings
            )

            DiagnosticsQuickStartRow(
                step: 3,
                title: AppStrings.text(.diagnosticsQuickStartDisplayTitle),
                detail: AppStrings.text(.diagnosticsQuickStartDisplayDetail),
                actionTitle: AppStrings.text(.diagnosticsGuideOpenSettings),
                action: onOpenSettings
            )
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
    }
}

// MARK: - Quick Start Row

private struct DiagnosticsQuickStartRow: View {
    let step: Int
    let title: String
    let detail: String
    let actionTitle: String
    let action: () -> Void
    var actionDisabled: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(step)")
                .font(.caption)
                .fontWeight(.semibold)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.accentColor.opacity(0.16)))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Button(actionTitle) {
                action()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(actionDisabled)
        }
    }
}

// MARK: - Check Row

private struct DiagnosticsCheckRow: View {
    let check: StartupDiagnosticCheck

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 8) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(check.title)
                    .font(.headline)
                Text(check.status.label)
                    .font(.caption)
                    .foregroundStyle(statusColor)
            }
            Text(check.detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }

    private var statusColor: Color {
        switch check.status {
        case .pass:
            return .green
        case .warning:
            return .orange
        case .failed:
            return .red
        }
    }
}

final class AppSettingsWindowController {
    private let window: NSWindow

    init(
        settingsStore: SettingsStore,
        assistantRuntime: AssistantRuntime,
        onOpenAssistantChat: @escaping () -> Void
    ) {
        let rootView = SettingsView(
            settingsStore: settingsStore,
            assistantRuntime: assistantRuntime,
            onOpenAssistantChat: onOpenAssistantChat
        )
        let hosting = NSHostingView(rootView: rootView)

        let window = NSWindow(
            contentRect: NSRect(x: 220, y: 160, width: 760, height: 780),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "“\(AppStrings.text(.appName))”\(AppStrings.text(.menuSettings))"
        window.isReleasedWhenClosed = false
        window.contentView = hosting
        window.setFrameAutosaveName("AppSettingsWindow")
        window.minSize = NSSize(width: 680, height: 700)
        self.window = window
    }

    func show() {
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}

@MainActor
enum AssistantConnectionState: Equatable {
    case idle
    case starting
    case ready
    case unavailable(String)
    case failed(String)

    var displayText: String {
        switch self {
        case .idle:
            return AppStrings.text(.settingsAssistantStatusIdle)
        case .starting:
            return AppStrings.text(.settingsAssistantStatusStarting)
        case .ready:
            return AppStrings.text(.settingsAssistantStatusReady)
        case .unavailable:
            return AppStrings.text(.settingsAssistantStatusUnavailable)
        case .failed:
            return AppStrings.text(.settingsAssistantStatusError)
        }
    }
}

enum AssistantChatRole: Equatable {
    case user
    case assistant
    case system
}

struct AssistantChatMessage: Identifiable, Equatable {
    let id: UUID
    let role: AssistantChatRole
    let text: String
    let createdAt: Date

    init(id: UUID = UUID(), role: AssistantChatRole, text: String, createdAt: Date = Date()) {
        self.id = id
        self.role = role
        self.text = text
        self.createdAt = createdAt
    }
}

@MainActor
final class AssistantRuntime: ObservableObject {
    @Published private(set) var state: AssistantConnectionState = .idle
    @Published private(set) var isSendingPrompt: Bool = false
    @Published private(set) var lastResponse: String = ""
    @Published private(set) var lastError: String = ""
    @Published private(set) var conversation: [AssistantChatMessage] = []
    @Published private(set) var isSpeakingResponse: Bool = false
    @Published private(set) var speechActivityLevel: Double = 0
    @Published private(set) var lastSpeechError: String = ""
    @Published private(set) var isRecordingVoiceInput: Bool = false
    @Published private(set) var isTranscribingVoiceInput: Bool = false
    @Published private(set) var lastTranscriptionError: String = ""
    @Published private(set) var isTestingVoiceInputDevice: Bool = false
    @Published private(set) var isTestingVoiceOutputDevice: Bool = false
    @Published private(set) var lastVoiceInputDeviceTestResult: String = ""
    @Published private(set) var lastVoiceOutputDeviceTestResult: String = ""

    private let settingsStore: SettingsStore
    private let speechRuntime = LocalSpeechRuntime()
    private let transcriptionRuntime = LocalTranscriptionRuntime()
    private var helperProcess: Process?
    private var stdinHandle: FileHandle?
    private var stdoutHandle: FileHandle?
    private var outputBuffer = Data()
    private var pingTimeoutTask: Task<Void, Never>?
    private var pendingPingID: String?
    private var expectedTerminationPID: Int32?
    private var pendingAskIDs = Set<String>()
    private var speechTask: Task<Void, Never>?
    private var voiceInputTask: Task<Void, Never>?
    private var voiceInputTestTask: Task<Void, Never>?
    private var voiceOutputTestTask: Task<Void, Never>?

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
        speechRuntime.onPlaybackLevelChanged = { [weak self] level in
            self?.speechActivityLevel = min(1, max(0, level))
        }
    }

    func applySettings() {
        let assistant = settingsStore.settings.assistant

        guard assistant.enabled else {
            stop()
            return
        }

        if !assistant.voiceSettings.enabled {
            speechTask?.cancel()
            speechTask = nil
            speechRuntime.stop()
            isSpeakingResponse = false
            speechActivityLevel = 0
            voiceInputTask?.cancel()
            voiceInputTask = nil
            voiceInputTestTask?.cancel()
            voiceInputTestTask = nil
            voiceOutputTestTask?.cancel()
            voiceOutputTestTask = nil
            transcriptionRuntime.cancel()
            isRecordingVoiceInput = false
            isTranscribingVoiceInput = false
            isTestingVoiceInputDevice = false
            isTestingVoiceOutputDevice = false
            lastVoiceInputDeviceTestResult = ""
            lastVoiceOutputDeviceTestResult = ""
        }

        guard assistant.autoStartHelper else {
            stop()
            state = .idle
            return
        }

        ensureRunning()
    }

    func sendPrompt(_ prompt: String) {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard state == .ready else {
            lastError = "assistant_not_ready"
            conversation.append(
                AssistantChatMessage(
                    role: .system,
                    text: "\(AppStrings.text(.assistantChatErrorPrefix)): assistant_not_ready"
                )
            )
            return
        }

        let requestID = UUID().uuidString
        pendingAskIDs.insert(requestID)
        isSendingPrompt = true
        lastError = ""
        lastSpeechError = ""
        lastTranscriptionError = ""
        conversation.append(AssistantChatMessage(role: .user, text: trimmed))

        let payload: [String: Any] = [
            "type": "ask",
            "id": requestID,
            "text": trimmed
        ]

        if !writeMessage(payload) {
            pendingAskIDs.remove(requestID)
            isSendingPrompt = false
            lastError = "failed_to_send_prompt"
            conversation.append(
                AssistantChatMessage(
                    role: .system,
                    text: "\(AppStrings.text(.assistantChatErrorPrefix)): failed_to_send_prompt"
                )
            )
        }
    }

    func clearConversation() {
        conversation.removeAll(keepingCapacity: false)
        lastResponse = ""
        lastError = ""
        lastSpeechError = ""
        lastTranscriptionError = ""
    }

    var canSpeakLatestResponse: Bool {
        settingsStore.settings.assistant.voiceSettings.enabled &&
            !isSpeakingResponse &&
            conversation.contains(where: { $0.role == .assistant })
    }

    var canToggleVoiceInput: Bool {
        settingsStore.settings.assistant.voiceSettings.enabled &&
            state == .ready &&
            !isSendingPrompt &&
            !isSpeakingResponse &&
            !isTranscribingVoiceInput &&
            !isTestingVoiceInputDevice &&
            !isTestingVoiceOutputDevice &&
            voiceInputTask == nil
    }

    func speakLastAssistantMessage() {
        guard settingsStore.settings.assistant.voiceSettings.enabled else {
            lastSpeechError = "voice_disabled"
            return
        }
        guard let message = conversation.last(where: { $0.role == .assistant }) else {
            lastSpeechError = "no_assistant_reply"
            return
        }
        triggerSpeech(message.text, automatic: false)
    }

    func toggleVoiceInput() {
        if isRecordingVoiceInput {
            stopVoiceInputAndTranscribe()
        } else {
            startVoiceInput()
        }
    }

    var canTestVoiceInputDevice: Bool {
        settingsStore.settings.assistant.voiceSettings.enabled &&
            !isSendingPrompt &&
            !isRecordingVoiceInput &&
            !isTranscribingVoiceInput &&
            !isSpeakingResponse &&
            !isTestingVoiceInputDevice &&
            !isTestingVoiceOutputDevice
    }

    var canTestVoiceOutputDevice: Bool {
        settingsStore.settings.assistant.voiceSettings.enabled &&
            !isSendingPrompt &&
            !isRecordingVoiceInput &&
            !isTranscribingVoiceInput &&
            !isSpeakingResponse &&
            !isTestingVoiceInputDevice &&
            !isTestingVoiceOutputDevice
    }

    func testVoiceInputDevice() {
        guard canTestVoiceInputDevice else { return }
        let voiceSettings = settingsStore.settings.assistant.voiceSettings

        voiceInputTestTask?.cancel()
        voiceInputTestTask = Task { [weak self] in
            guard let self else { return }
            defer {
                self.isTestingVoiceInputDevice = false
                self.voiceInputTestTask = nil
            }
            self.isTestingVoiceInputDevice = true
            self.lastVoiceInputDeviceTestResult = AppStrings.text(.settingsAssistantVoiceTestRunning)
            do {
                try await self.transcriptionRuntime.probeInput(
                    voiceSettings: voiceSettings,
                    durationSeconds: 1.2
                )
                self.lastVoiceInputDeviceTestResult = AppStrings.text(.settingsAssistantVoiceTestPassed)
            } catch {
                if Task.isCancelled { return }
                self.lastVoiceInputDeviceTestResult = self.transcriptionErrorMessage(error)
            }
        }
    }

    func testVoiceOutputDevice() {
        guard canTestVoiceOutputDevice else { return }
        let voiceSettings = settingsStore.settings.assistant.voiceSettings

        voiceOutputTestTask?.cancel()
        voiceOutputTestTask = Task { [weak self] in
            guard let self else { return }
            defer {
                self.isTestingVoiceOutputDevice = false
                self.voiceOutputTestTask = nil
            }
            self.isTestingVoiceOutputDevice = true
            self.lastVoiceOutputDeviceTestResult = AppStrings.text(.settingsAssistantVoiceTestRunning)
            do {
                try await self.speechRuntime.testOutputDevice(voiceSettings: voiceSettings)
                self.lastVoiceOutputDeviceTestResult = AppStrings.text(.settingsAssistantVoiceTestPassed)
            } catch {
                if Task.isCancelled { return }
                if let runtimeError = error as? LocalSpeechRuntimeError {
                    self.lastVoiceOutputDeviceTestResult = runtimeError.message
                } else {
                    self.lastVoiceOutputDeviceTestResult = error.localizedDescription
                }
            }
        }
    }

    private func ensureRunning() {
        if helperProcess?.isRunning == true {
            if state != .starting {
                sendHealthCheck()
            }
            return
        }

        guard let helperURL = resolveHelperExecutableURL() else {
            state = .unavailable("helper_not_found")
            return
        }

        let process = Process()
        let inputPipe = Pipe()
        let outputPipe = Pipe()

        process.executableURL = helperURL
        process.arguments = ["--stdio"]
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = FileHandle.nullDevice

        process.terminationHandler = { [weak self] process in
            Task { @MainActor in
                guard let self else { return }
                self.cleanupFileHandles()
                self.pendingAskIDs.removeAll()
                self.isSendingPrompt = false
                if self.expectedTerminationPID == process.processIdentifier {
                    self.expectedTerminationPID = nil
                    self.state = .idle
                } else {
                    let reason = "exit_\(process.terminationStatus)"
                    self.state = .failed(reason)
                }
                self.helperProcess = nil
            }
        }

        do {
            try process.run()
        } catch {
            state = .failed("run_failed")
            return
        }

        helperProcess = process
        stdinHandle = inputPipe.fileHandleForWriting
        stdoutHandle = outputPipe.fileHandleForReading
        outputBuffer.removeAll(keepingCapacity: true)
        state = .starting

        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            Task { @MainActor in
                self?.consumeOutput(data)
            }
        }

        sendHealthCheck()
    }

    func stop(preservedState: AssistantConnectionState? = nil) {
        pingTimeoutTask?.cancel()
        pingTimeoutTask = nil
        pendingPingID = nil
        pendingAskIDs.removeAll()
        isSendingPrompt = false
        speechTask?.cancel()
        speechTask = nil
        speechRuntime.stop()
        isSpeakingResponse = false
        speechActivityLevel = 0
        voiceInputTask?.cancel()
        voiceInputTask = nil
        voiceInputTestTask?.cancel()
        voiceInputTestTask = nil
        voiceOutputTestTask?.cancel()
        voiceOutputTestTask = nil
        transcriptionRuntime.cancel()
        isRecordingVoiceInput = false
        isTranscribingVoiceInput = false
        isTestingVoiceInputDevice = false
        isTestingVoiceOutputDevice = false

        stdoutHandle?.readabilityHandler = nil

        if let helperProcess, helperProcess.isRunning {
            expectedTerminationPID = helperProcess.processIdentifier
            helperProcess.terminate()
        } else {
            expectedTerminationPID = nil
        }

        helperProcess = nil
        cleanupFileHandles()
        if let preservedState {
            state = preservedState
        } else {
            state = .idle
        }
    }

    private func cleanupFileHandles() {
        stdinHandle = nil
        stdoutHandle = nil
        outputBuffer.removeAll(keepingCapacity: false)
    }

    private func sendHealthCheck() {
        let pingID = UUID().uuidString
        pendingPingID = pingID
        _ = writeMessage(["type": "ping", "id": pingID])

        pingTimeoutTask?.cancel()
        pingTimeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard let self else { return }
            guard self.state == .starting else { return }
            self.stop(preservedState: .unavailable("health_timeout"))
        }
    }

    private func sendGatewayConfig() {
        let assistant = settingsStore.settings.assistant
        _ = writeMessage([
            "type": "config",
            "gatewayUrl": assistant.gatewayURL,
            "gatewayToken": assistant.gatewayToken,
            "sessionKey": assistant.gatewaySessionKey
        ])
    }

    @discardableResult
    private func writeMessage(_ message: [String: Any]) -> Bool {
        guard let stdinHandle else { return false }
        guard var data = try? JSONSerialization.data(withJSONObject: message) else { return false }
        data.append(0x0A)
        do {
            try stdinHandle.write(contentsOf: data)
            return true
        } catch {
            return false
        }
    }

    private func consumeOutput(_ data: Data) {
        outputBuffer.append(data)
        let newline = Data([0x0A])

        while let newlineRange = outputBuffer.range(of: newline) {
            let lineData = outputBuffer.subdata(in: outputBuffer.startIndex..<newlineRange.lowerBound)
            outputBuffer.removeSubrange(outputBuffer.startIndex..<newlineRange.upperBound)
            handleLine(lineData)
        }
    }

    private func handleLine(_ lineData: Data) {
        guard !lineData.isEmpty else { return }
        guard let payload = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
              let type = payload["type"] as? String else {
            return
        }

        switch type {
        case "pong":
            if (payload["id"] as? String) == pendingPingID {
                pendingPingID = nil
                pingTimeoutTask?.cancel()
                pingTimeoutTask = nil
                sendGatewayConfig()
            }

        case "gateway":
            let status = (payload["status"] as? String) ?? "unknown"
            if status == "ready" {
                state = .ready
                lastError = ""
            } else {
                let reason = (payload["error"] as? String) ?? "gateway_unavailable"
                state = .unavailable(reason)
            }

        case "ask_result":
            let requestID = (payload["id"] as? String) ?? ""
            if !requestID.isEmpty {
                pendingAskIDs.remove(requestID)
            }
            isSendingPrompt = !pendingAskIDs.isEmpty

            let status = (payload["status"] as? String) ?? "unknown"
            if status == "final" {
                let response = (payload["text"] as? String) ?? ""
                lastResponse = response
                lastError = ""
                if !response.isEmpty {
                    conversation.append(AssistantChatMessage(role: .assistant, text: response))
                    if settingsStore.settings.assistant.voiceSettings.enabled &&
                        settingsStore.settings.assistant.voiceSettings.autoSpeakAssistantReplies {
                        triggerSpeech(response, automatic: true)
                    }
                }
            } else {
                let errorText = (payload["error"] as? String) ?? "ask_failed"
                lastError = errorText
                conversation.append(
                    AssistantChatMessage(
                        role: .system,
                        text: "\(AppStrings.text(.assistantChatErrorPrefix)): \(errorText)"
                    )
                )
            }

        case "error":
            if let reason = payload["reason"] as? String {
                lastError = reason
                conversation.append(
                    AssistantChatMessage(
                        role: .system,
                        text: "\(AppStrings.text(.assistantChatErrorPrefix)): \(reason)"
                    )
                )
            }

        default:
            break
        }
    }

    private func resolveHelperExecutableURL() -> URL? {
        let environment = ProcessInfo.processInfo.environment
        let fileManager = FileManager.default

        if let override = environment["CATCOMPANION_AGENT_PATH"],
           fileManager.isExecutableFile(atPath: override) {
            return URL(fileURLWithPath: override)
        }

        let appBundle = Bundle.main.bundleURL
        let executableDir = URL(fileURLWithPath: CommandLine.arguments.first ?? "").deletingLastPathComponent()
        let currentDirectory = URL(fileURLWithPath: fileManager.currentDirectoryPath)

        let candidates = [
            appBundle.appendingPathComponent("Contents/MacOS/CatCompanionAgent"),
            appBundle.appendingPathComponent("Contents/Helpers/CatCompanionAgent"),
            appBundle.appendingPathComponent("Contents/Library/LoginItems/CatCompanionAgent.app/Contents/MacOS/CatCompanionAgent"),
            executableDir.appendingPathComponent("CatCompanionAgent"),
            currentDirectory.appendingPathComponent(".build/debug/CatCompanionAgent"),
            currentDirectory.appendingPathComponent(".build/arm64-apple-macosx/debug/CatCompanionAgent"),
            currentDirectory.appendingPathComponent(".build/x86_64-apple-macosx/debug/CatCompanionAgent")
        ]

        for candidate in candidates where fileManager.isExecutableFile(atPath: candidate.path) {
            return candidate
        }

        return nil
    }

    private func startVoiceInput() {
        guard settingsStore.settings.assistant.voiceSettings.enabled else {
            lastTranscriptionError = "voice_disabled"
            appendSystemMessage("\(AppStrings.text(.assistantChatTranscriptionError)): voice_disabled")
            return
        }
        guard state == .ready else {
            lastTranscriptionError = "assistant_not_ready"
            appendSystemMessage("\(AppStrings.text(.assistantChatTranscriptionError)): assistant_not_ready")
            return
        }
        guard !isSendingPrompt,
              !isSpeakingResponse,
              !isTranscribingVoiceInput,
              !isTestingVoiceInputDevice,
              !isTestingVoiceOutputDevice else {
            return
        }

        voiceInputTask?.cancel()
        voiceInputTask = Task { [weak self] in
            guard let self else { return }
            defer { self.voiceInputTask = nil }
            self.lastTranscriptionError = ""
            do {
                try await self.transcriptionRuntime.startRecording(
                    voiceSettings: self.settingsStore.settings.assistant.voiceSettings
                )
                self.isRecordingVoiceInput = true
            } catch {
                self.isRecordingVoiceInput = false
                if Task.isCancelled {
                    return
                }
                let message = self.transcriptionErrorMessage(error)
                self.lastTranscriptionError = message
                self.appendSystemMessage("\(AppStrings.text(.assistantChatTranscriptionError)): \(message)")
            }
        }
    }

    private func stopVoiceInputAndTranscribe() {
        guard isRecordingVoiceInput else { return }
        let voiceSettings = settingsStore.settings.assistant.voiceSettings

        voiceInputTask?.cancel()
        voiceInputTask = Task { [weak self] in
            guard let self else { return }
            defer { self.voiceInputTask = nil }
            self.isRecordingVoiceInput = false
            self.isTranscribingVoiceInput = true
            self.lastTranscriptionError = ""

            do {
                let transcript = try await self.transcriptionRuntime.stopAndTranscribe(voiceSettings: voiceSettings)
                self.isTranscribingVoiceInput = false
                let cleaned = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !cleaned.isEmpty else {
                    throw LocalTranscriptionRuntimeError.transcriptMissing
                }
                self.sendPrompt(cleaned)
            } catch {
                self.isTranscribingVoiceInput = false
                if Task.isCancelled {
                    return
                }
                let message = self.transcriptionErrorMessage(error)
                self.lastTranscriptionError = message
                self.appendSystemMessage("\(AppStrings.text(.assistantChatTranscriptionError)): \(message)")
            }
        }
    }

    private func transcriptionErrorMessage(_ error: Error) -> String {
        if let runtimeError = error as? LocalTranscriptionRuntimeError {
            return runtimeError.message
        }
        return error.localizedDescription
    }

    private func appendSystemMessage(_ text: String) {
        conversation.append(
            AssistantChatMessage(
                role: .system,
                text: text
            )
        )
    }

    private func triggerSpeech(_ text: String, automatic: Bool) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let voiceSettings = settingsStore.settings.assistant.voiceSettings
        guard voiceSettings.enabled else { return }
        if automatic && !voiceSettings.autoSpeakAssistantReplies {
            return
        }

        speechTask?.cancel()
        speechTask = Task { [weak self] in
            guard let self else { return }
            self.isSpeakingResponse = true
            self.lastSpeechError = ""
            do {
                try await self.speechRuntime.speak(text: trimmed, voiceSettings: voiceSettings)
                self.isSpeakingResponse = false
            } catch {
                self.isSpeakingResponse = false
                if Task.isCancelled {
                    return
                }
                let errorMessage: String
                if let runtimeError = error as? LocalSpeechRuntimeError {
                    errorMessage = runtimeError.message
                } else {
                    errorMessage = error.localizedDescription
                }
                self.lastSpeechError = errorMessage
                self.appendSystemMessage("\(AppStrings.text(.assistantChatSpeechError)): \(errorMessage)")
            }
        }
    }
}
