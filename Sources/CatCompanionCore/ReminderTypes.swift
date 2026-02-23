import Foundation

public enum AppLanguage: String, CaseIterable, Codable {
    case zhHans = "zh-Hans"
    case zhHant = "zh-Hant"
    case en
    case ja

    public static func current(
        preferredLanguages: [String] = Bundle.main.preferredLocalizations + Locale.preferredLanguages
    ) -> AppLanguage {
        guard let first = preferredLanguages.first?.lowercased() else { return .en }
        if first.hasPrefix("zh-hant") || first.hasPrefix("zh-tw") || first.hasPrefix("zh-hk") || first.hasPrefix("zh-mo") {
            return .zhHant
        }
        if first.hasPrefix("zh") {
            return .zhHans
        }
        if first.hasPrefix("ja") {
            return .ja
        }
        return .en
    }
}

public enum AssistantRouteStrategy: String, CaseIterable, Codable {
    case cloudPreferred
    case cloudOnly
    case localOnly
}

public enum PetMotionProfile: String, CaseIterable, Codable {
    case subtle
    case vivid
}

public struct AssistantActionScope: Codable, Equatable {
    public var allowReadOnlyActions: Bool
    public var allowFileActions: Bool
    public var allowTerminalActions: Bool
    public var allowBrowserActions: Bool

    public init(
        allowReadOnlyActions: Bool,
        allowFileActions: Bool,
        allowTerminalActions: Bool,
        allowBrowserActions: Bool
    ) {
        self.allowReadOnlyActions = allowReadOnlyActions
        self.allowFileActions = allowFileActions
        self.allowTerminalActions = allowTerminalActions
        self.allowBrowserActions = allowBrowserActions
    }

    public static func defaults() -> AssistantActionScope {
        AssistantActionScope(
            allowReadOnlyActions: true,
            allowFileActions: true,
            allowTerminalActions: true,
            allowBrowserActions: true
        )
    }
}

public struct AssistantSkillPolicy: Codable, Equatable {
    public var thirdPartySkillsEnabled: Bool
    public var allowedSkillIDs: [String]

    public init(thirdPartySkillsEnabled: Bool, allowedSkillIDs: [String]) {
        self.thirdPartySkillsEnabled = thirdPartySkillsEnabled
        self.allowedSkillIDs = allowedSkillIDs
    }

    public static func defaults() -> AssistantSkillPolicy {
        AssistantSkillPolicy(thirdPartySkillsEnabled: false, allowedSkillIDs: [])
    }
}

public struct AssistantVoiceSettings: Codable, Equatable, Sendable {
    public var enabled: Bool
    public var autoSpeakAssistantReplies: Bool
    public var voiceInputDeviceUID: String
    public var voiceOutputDeviceUID: String
    public var pythonCommand: String
    public var cosyVoiceModel: String
    public var cosyVoiceSpeaker: String
    public var cosyVoiceScriptPath: String
    public var whisperCommand: String
    public var whisperModelPath: String
    public var whisperLanguage: String

    public init(
        enabled: Bool,
        autoSpeakAssistantReplies: Bool,
        voiceInputDeviceUID: String,
        voiceOutputDeviceUID: String,
        pythonCommand: String,
        cosyVoiceModel: String,
        cosyVoiceSpeaker: String,
        cosyVoiceScriptPath: String,
        whisperCommand: String,
        whisperModelPath: String,
        whisperLanguage: String
    ) {
        self.enabled = enabled
        self.autoSpeakAssistantReplies = autoSpeakAssistantReplies
        self.voiceInputDeviceUID = voiceInputDeviceUID
        self.voiceOutputDeviceUID = voiceOutputDeviceUID
        self.pythonCommand = pythonCommand
        self.cosyVoiceModel = cosyVoiceModel
        self.cosyVoiceSpeaker = cosyVoiceSpeaker
        self.cosyVoiceScriptPath = cosyVoiceScriptPath
        self.whisperCommand = whisperCommand
        self.whisperModelPath = whisperModelPath
        self.whisperLanguage = whisperLanguage
    }

    private enum CodingKeys: String, CodingKey {
        case enabled
        case autoSpeakAssistantReplies
        case voiceInputDeviceUID
        case voiceOutputDeviceUID
        case pythonCommand
        case cosyVoiceModel
        case cosyVoiceSpeaker
        case cosyVoiceScriptPath
        case whisperCommand
        case whisperModelPath
        case whisperLanguage
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = AssistantVoiceSettings.defaults()
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? defaults.enabled
        autoSpeakAssistantReplies = try container.decodeIfPresent(Bool.self, forKey: .autoSpeakAssistantReplies) ?? defaults.autoSpeakAssistantReplies
        voiceInputDeviceUID = try container.decodeIfPresent(String.self, forKey: .voiceInputDeviceUID) ?? defaults.voiceInputDeviceUID
        voiceOutputDeviceUID = try container.decodeIfPresent(String.self, forKey: .voiceOutputDeviceUID) ?? defaults.voiceOutputDeviceUID
        pythonCommand = try container.decodeIfPresent(String.self, forKey: .pythonCommand) ?? defaults.pythonCommand
        cosyVoiceModel = try container.decodeIfPresent(String.self, forKey: .cosyVoiceModel) ?? defaults.cosyVoiceModel
        cosyVoiceSpeaker = try container.decodeIfPresent(String.self, forKey: .cosyVoiceSpeaker) ?? defaults.cosyVoiceSpeaker
        cosyVoiceScriptPath = try container.decodeIfPresent(String.self, forKey: .cosyVoiceScriptPath) ?? defaults.cosyVoiceScriptPath
        whisperCommand = try container.decodeIfPresent(String.self, forKey: .whisperCommand) ?? defaults.whisperCommand
        whisperModelPath = try container.decodeIfPresent(String.self, forKey: .whisperModelPath) ?? defaults.whisperModelPath
        whisperLanguage = try container.decodeIfPresent(String.self, forKey: .whisperLanguage) ?? defaults.whisperLanguage
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(enabled, forKey: .enabled)
        try container.encode(autoSpeakAssistantReplies, forKey: .autoSpeakAssistantReplies)
        try container.encode(voiceInputDeviceUID, forKey: .voiceInputDeviceUID)
        try container.encode(voiceOutputDeviceUID, forKey: .voiceOutputDeviceUID)
        try container.encode(pythonCommand, forKey: .pythonCommand)
        try container.encode(cosyVoiceModel, forKey: .cosyVoiceModel)
        try container.encode(cosyVoiceSpeaker, forKey: .cosyVoiceSpeaker)
        try container.encode(cosyVoiceScriptPath, forKey: .cosyVoiceScriptPath)
        try container.encode(whisperCommand, forKey: .whisperCommand)
        try container.encode(whisperModelPath, forKey: .whisperModelPath)
        try container.encode(whisperLanguage, forKey: .whisperLanguage)
    }

    public static func defaults() -> AssistantVoiceSettings {
        AssistantVoiceSettings(
            enabled: false,
            autoSpeakAssistantReplies: true,
            voiceInputDeviceUID: "",
            voiceOutputDeviceUID: "",
            pythonCommand: "python3",
            cosyVoiceModel: "iic/CosyVoice2-0.5B",
            cosyVoiceSpeaker: "",
            cosyVoiceScriptPath: "",
            whisperCommand: "whisper-cli",
            whisperModelPath: "",
            whisperLanguage: "auto"
        )
    }
}

public struct AssistantSettings: Codable, Equatable {
    public var enabled: Bool
    public var autoStartHelper: Bool
    public var routeStrategy: AssistantRouteStrategy
    public var cloudPrimaryModel: String
    public var localFallbackModel: String
    public var gatewayURL: String
    public var gatewayToken: String
    public var gatewaySessionKey: String
    public var actionScope: AssistantActionScope
    public var skillPolicy: AssistantSkillPolicy
    public var voiceSettings: AssistantVoiceSettings

    public init(
        enabled: Bool,
        autoStartHelper: Bool,
        routeStrategy: AssistantRouteStrategy,
        cloudPrimaryModel: String,
        localFallbackModel: String,
        gatewayURL: String,
        gatewayToken: String,
        gatewaySessionKey: String,
        actionScope: AssistantActionScope,
        skillPolicy: AssistantSkillPolicy,
        voiceSettings: AssistantVoiceSettings
    ) {
        self.enabled = enabled
        self.autoStartHelper = autoStartHelper
        self.routeStrategy = routeStrategy
        self.cloudPrimaryModel = cloudPrimaryModel
        self.localFallbackModel = localFallbackModel
        self.gatewayURL = gatewayURL
        self.gatewayToken = gatewayToken
        self.gatewaySessionKey = gatewaySessionKey
        self.actionScope = actionScope
        self.skillPolicy = skillPolicy
        self.voiceSettings = voiceSettings
    }

    private enum CodingKeys: String, CodingKey {
        case enabled
        case autoStartHelper
        case routeStrategy
        case cloudPrimaryModel
        case localFallbackModel
        case gatewayURL
        case gatewayToken
        case gatewaySessionKey
        case actionScope
        case skillPolicy
        case voiceSettings
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = AssistantSettings.defaults()
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? defaults.enabled
        autoStartHelper = try container.decodeIfPresent(Bool.self, forKey: .autoStartHelper) ?? defaults.autoStartHelper
        routeStrategy = try container.decodeIfPresent(AssistantRouteStrategy.self, forKey: .routeStrategy) ?? defaults.routeStrategy
        cloudPrimaryModel = try container.decodeIfPresent(String.self, forKey: .cloudPrimaryModel) ?? defaults.cloudPrimaryModel
        localFallbackModel = try container.decodeIfPresent(String.self, forKey: .localFallbackModel) ?? defaults.localFallbackModel
        gatewayURL = try container.decodeIfPresent(String.self, forKey: .gatewayURL) ?? defaults.gatewayURL
        // gatewayToken: prefer Keychain; fall back to legacy JSON value for migration
        let legacyToken = try container.decodeIfPresent(String.self, forKey: .gatewayToken)
        gatewayToken = KeychainHelper.load(forKey: "gatewayToken") ?? legacyToken ?? defaults.gatewayToken
        // Migrate legacy token to Keychain if present
        if let legacy = legacyToken, !legacy.isEmpty, KeychainHelper.load(forKey: "gatewayToken") == nil {
            KeychainHelper.save(legacy, forKey: "gatewayToken")
        }
        gatewaySessionKey = try container.decodeIfPresent(String.self, forKey: .gatewaySessionKey) ?? defaults.gatewaySessionKey
        actionScope = try container.decodeIfPresent(AssistantActionScope.self, forKey: .actionScope) ?? defaults.actionScope
        skillPolicy = try container.decodeIfPresent(AssistantSkillPolicy.self, forKey: .skillPolicy) ?? defaults.skillPolicy
        voiceSettings = try container.decodeIfPresent(AssistantVoiceSettings.self, forKey: .voiceSettings) ?? defaults.voiceSettings
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(enabled, forKey: .enabled)
        try container.encode(autoStartHelper, forKey: .autoStartHelper)
        try container.encode(routeStrategy, forKey: .routeStrategy)
        try container.encode(cloudPrimaryModel, forKey: .cloudPrimaryModel)
        try container.encode(localFallbackModel, forKey: .localFallbackModel)
        try container.encode(gatewayURL, forKey: .gatewayURL)
        // gatewayToken is stored in Keychain, not serialized to JSON
        try container.encode(gatewaySessionKey, forKey: .gatewaySessionKey)
        try container.encode(actionScope, forKey: .actionScope)
        try container.encode(skillPolicy, forKey: .skillPolicy)
        try container.encode(voiceSettings, forKey: .voiceSettings)
    }

    public static func defaults() -> AssistantSettings {
        AssistantSettings(
            enabled: false,
            autoStartHelper: true,
            routeStrategy: .cloudPreferred,
            cloudPrimaryModel: "openai-codex/gpt-5.3-codex",
            localFallbackModel: "ollama/qwen2.5-coder:14b",
            gatewayURL: "ws://127.0.0.1:18789",
            gatewayToken: "",
            gatewaySessionKey: "main",
            actionScope: .defaults(),
            skillPolicy: .defaults(),
            voiceSettings: .defaults()
        )
    }
}

public enum AppStringKey: String {
    case appName
    case menuShowPet
    case menuHidePet
    case menuSystemNotification
    case menuPauseReminders
    case menuResumeReminders
    case menuRemindersPaused
    case menuNextReminder
    case menuSnooze5Min
    case menuSnooze10Min
    case menuSnooze30Min
    case menuAssistantEnabled
    case menuAssistantChat
    case menuDiagnostics
    case menuCheckForUpdates
    case menuSettings
    case menuQuit

    case reminderHydrateName
    case reminderStandName
    case reminderRestEyesName
    case reminderHydratePrompt
    case reminderStandPrompt
    case reminderRestEyesPrompt

    case actionComplete
    case actionSnooze

    case settingsReminderSection
    case settingsPetSection
    case settingsNotificationSection
    case settingsGroup
    case settingsAlwaysOnTop
    case settingsPetShowOnlyWhenReminding
    case settingsPetShowOnlyWhenRemindingHelp
    case settingsPetMotionProfile
    case settingsPetMotionProfileSubtle
    case settingsPetMotionProfileVivid
    case settingsPetMotionProfileHelp
    case settingsPetIdleLowPowerEnabled
    case settingsPetIdleLowPowerHelp
    case settingsPetIdleLowPowerDelay
    case settingsPetIdleLowPowerDelayHelp
    case settingsEnableSystemNotification
    case settingsNotificationHelp
    case settingsAuthorizationStatus
    case settingsAuthorizationAllowed
    case settingsAuthorizationDenied
    case settingsAuthorizationNotDetermined
    case settingsAuthorizationUnknown
    case settingsOpenSystemSettings
    case settingsIntervalMinutes
    case settingsQuietHours
    case settingsQuietStart
    case settingsQuietEnd
    case settingsSnoozeReminder
    case settingsPauseAllReminders
    case settingsPauseAllRemindersHelp
    case settingsReminderCooldown
    case settingsReminderCooldownHelp
    case settingsReminderCooldownOff

    case settingsAssistantSection
    case settingsAssistantSecuritySection
    case settingsAssistantEnabled
    case settingsAssistantAutoStart
    case settingsAssistantConnectionStatus
    case settingsAssistantStatusIdle
    case settingsAssistantStatusStarting
    case settingsAssistantStatusReady
    case settingsAssistantStatusUnavailable
    case settingsAssistantStatusError
    case settingsAssistantRouteStrategy
    case settingsAssistantRouteCloudPreferred
    case settingsAssistantRouteCloudOnly
    case settingsAssistantRouteLocalOnly
    case settingsAssistantCloudPrimaryModel
    case settingsAssistantLocalFallbackModel
    case settingsAssistantGatewayURL
    case settingsAssistantGatewayToken
    case settingsAssistantGatewaySessionKey
    case settingsAssistantAllowReadOnly
    case settingsAssistantAllowFileActions
    case settingsAssistantAllowTerminalActions
    case settingsAssistantAllowBrowserActions
    case settingsAssistantThirdPartySkillsDisabledHint
    case settingsAssistantTestPrompt
    case settingsAssistantSendTest
    case settingsAssistantOpenChat
    case settingsAssistantSending
    case settingsAssistantLastResponse
    case settingsAssistantLastError
    case settingsAssistantVoiceSection
    case settingsAssistantVoiceEnabled
    case settingsAssistantVoiceAutoSpeak
    case settingsAssistantVoiceInputDevice
    case settingsAssistantVoiceOutputDevice
    case settingsAssistantVoiceDeviceSystemDefault
    case settingsAssistantVoiceRefreshDevices
    case settingsAssistantVoiceTestInput
    case settingsAssistantVoiceTestOutput
    case settingsAssistantVoiceInputTestResult
    case settingsAssistantVoiceOutputTestResult
    case settingsAssistantVoiceTestPassed
    case settingsAssistantVoiceTestRunning
    case settingsAssistantVoicePythonCommand
    case settingsAssistantVoiceSTTCommand
    case settingsAssistantVoiceSTTModelPath
    case settingsAssistantVoiceSTTLanguage
    case settingsAssistantVoiceModel
    case settingsAssistantVoiceSpeaker
    case settingsAssistantVoiceScriptPath
    case settingsAssistantVoiceAdvanced
    case settingsAssistantVoiceAdvancedHint
    case settingsAssistantVoiceHint

    case assistantChatWindowTitle
    case assistantChatEmptyState
    case assistantChatInputPlaceholder
    case assistantChatSend
    case assistantChatClear
    case assistantChatSpeakLatest
    case assistantChatVoiceInput
    case assistantChatStopRecording
    case assistantChatConnectionHint
    case assistantChatSending
    case assistantChatRecording
    case assistantChatTranscribing
    case assistantChatSpeaking
    case assistantChatSpeechError
    case assistantChatTranscriptionError
    case assistantChatErrorPrefix
    case assistantChatRoleUser
    case assistantChatRoleAssistant
    case assistantChatRoleSystem

    case diagnosticsGuideTitle
    case diagnosticsGuideSubtitle
    case diagnosticsGuideChecking
    case diagnosticsGuideLastChecked
    case diagnosticsGuideRunAgain
    case diagnosticsGuideOpenSettings
    case diagnosticsGuideDone
    case diagnosticsGuideSkip
    case diagnosticsGuidePhaseBasicTitle
    case diagnosticsGuidePhaseBasicSubtitle
    case diagnosticsGuidePhaseAdvancedTitle
    case diagnosticsGuidePhaseAdvancedSubtitle
    case diagnosticsGuidePhaseAdvancedSkipHint
    case diagnosticsGuideNextStep
    case diagnosticsGuidePreviousStep
    case diagnosticsQuickStartTitle
    case diagnosticsQuickStartNotificationsTitle
    case diagnosticsQuickStartNotificationsDetail
    case diagnosticsQuickStartGatewayTitle
    case diagnosticsQuickStartGatewayDetail
    case diagnosticsQuickStartDisplayTitle
    case diagnosticsQuickStartDisplayDetail
    case diagnosticsStatusPass
    case diagnosticsStatusWarning
    case diagnosticsStatusFailed
    case diagnosticsCheckHelper
    case diagnosticsCheckGateway
    case diagnosticsCheckMicrophone
    case diagnosticsCheckWhisperCommand
    case diagnosticsCheckWhisperModel
    case diagnosticsCheckCosyScript
    case diagnosticsCheckPythonDependencies
    case diagnosticsCheckInputDevice
    case diagnosticsCheckOutputDevice
    case diagnosticsDetailFound
    case diagnosticsDetailMissing
    case diagnosticsDetailNotConfigured
    case diagnosticsDetailUsingSystemDefault
    case diagnosticsDetailPermissionUnknown
    case diagnosticsDetailPermissionDenied
    case diagnosticsDetailPermissionGranted
    case diagnosticsDetailConnected
    case diagnosticsDetailConnectionFailed
    case diagnosticsDetailAssistantDisabled
    case diagnosticsDetailVoiceDisabled
}

public enum AppStrings {
    public static func text(
        _ key: AppStringKey,
        language: AppLanguage = .current()
    ) -> String {
        if let localized = localizedText(for: key, language: language) {
            return localized
        }
        let table = fallbackTable(for: language)
        return table[key] ?? enTable[key] ?? key.rawValue
    }

    public static func minutesText(
        _ minutes: Int,
        language: AppLanguage = .current()
    ) -> String {
        switch language {
        case .zhHans:
            return "\(minutes) 分钟"
        case .zhHant:
            return "\(minutes) 分鐘"
        case .en:
            return "\(minutes) min"
        case .ja:
            return "\(minutes)分"
        }
    }

    private static func localizedText(
        for key: AppStringKey,
        language: AppLanguage
    ) -> String? {
        guard let bundle = localizedBundle(for: language) else { return nil }
        let rawKey = key.rawValue
        let value = bundle.localizedString(forKey: rawKey, value: rawKey, table: "Localizable")
        return value == rawKey ? nil : value
    }

    private static func localizedBundle(for language: AppLanguage) -> Bundle? {
        let main = Bundle.main
        let candidates: [String]
        switch language {
        case .zhHans:
            candidates = ["zh-Hans", "zh"]
        case .zhHant:
            candidates = ["zh-Hant", "zh-TW", "zh-HK"]
        case .en:
            candidates = ["en"]
        case .ja:
            candidates = ["ja"]
        }

        for code in candidates {
            guard let path = main.path(forResource: code, ofType: "lproj") else { continue }
            if let bundle = Bundle(path: path) {
                return bundle
            }
        }
        return nil
    }

    private static func fallbackTable(for language: AppLanguage) -> [AppStringKey: String] {
        switch language {
        case .zhHans:
            return zhHansTable
        case .zhHant:
            return zhHantTable
        case .en:
            return enTable
        case .ja:
            return jaTable
        }
    }

    private static let zhHansTable: [AppStringKey: String] = [
        .appName: "猫咪伴侣",
        .menuShowPet: "显示助手",
        .menuHidePet: "隐藏助手",
        .menuSystemNotification: "系统通知",
        .menuPauseReminders: "暂停提醒",
        .menuResumeReminders: "恢复提醒",
        .menuRemindersPaused: "提醒已暂停",
        .menuNextReminder: "下次提醒",
        .menuSnooze5Min: "5 分钟后再提醒",
        .menuSnooze10Min: "10 分钟后再提醒",
        .menuSnooze30Min: "30 分钟后再提醒",
        .menuAssistantEnabled: "AI 助理",
        .menuAssistantChat: "打开 AI 对话",
        .menuDiagnostics: "环境诊断…",
        .menuCheckForUpdates: "检查更新…",
        .menuSettings: "设置…",
        .menuQuit: "退出",
        .reminderHydrateName: "喝水",
        .reminderStandName: "站立走动",
        .reminderRestEyesName: "闭眼休息",
        .reminderHydratePrompt: "喝点水吧，身体会感谢你。",
        .reminderStandPrompt: "站起来走动一下。",
        .reminderRestEyesPrompt: "闭眼休息 20 秒，放松眼睛。",
        .actionComplete: "完成",
        .actionSnooze: "稍后",
        .settingsReminderSection: "提醒设置",
        .settingsPetSection: "宠物",
        .settingsNotificationSection: "通知",
        .settingsGroup: "设置分组",
        .settingsAlwaysOnTop: "始终置顶",
        .settingsPetShowOnlyWhenReminding: "仅在提醒时自动显示猫咪",
        .settingsPetShowOnlyWhenRemindingHelp: "关闭后，你可以从菜单手动常驻显示猫咪",
        .settingsPetMotionProfile: "面板动效",
        .settingsPetMotionProfileSubtle: "极简",
        .settingsPetMotionProfileVivid: "高动效",
        .settingsPetMotionProfileHelp: "高动效更炫但更耗电；极简更克制",
        .settingsPetIdleLowPowerEnabled: "空闲时降低动画频率",
        .settingsPetIdleLowPowerHelp: "长时间无交互时自动进入低功耗动画",
        .settingsPetIdleLowPowerDelay: "进入低功耗前延迟（秒）",
        .settingsPetIdleLowPowerDelayHelp: "设置空闲多少秒后切换为低功耗动画",
        .settingsEnableSystemNotification: "启用系统通知",
        .settingsNotificationHelp: "系统通知需要用户授权",
        .settingsAuthorizationStatus: "权限状态",
        .settingsAuthorizationAllowed: "已允许",
        .settingsAuthorizationDenied: "已拒绝",
        .settingsAuthorizationNotDetermined: "未决定",
        .settingsAuthorizationUnknown: "未知",
        .settingsOpenSystemSettings: "打开系统设置",
        .settingsIntervalMinutes: "间隔（分钟）",
        .settingsQuietHours: "安静时段",
        .settingsQuietStart: "开始",
        .settingsQuietEnd: "结束",
        .settingsSnoozeReminder: "稍后提醒",
        .settingsPauseAllReminders: "暂停全部提醒",
        .settingsPauseAllRemindersHelp: "开启后不会触发新的提醒",
        .settingsReminderCooldown: "提醒间冷却（分钟）",
        .settingsReminderCooldownHelp: "0 表示不启用冷却",
        .settingsReminderCooldownOff: "关闭",
        .settingsAssistantSection: "AI 助理",
        .settingsAssistantSecuritySection: "执行与安全",
        .settingsAssistantEnabled: "启用 AI 助理",
        .settingsAssistantAutoStart: "启动时自动连接 Helper",
        .settingsAssistantConnectionStatus: "连接状态",
        .settingsAssistantStatusIdle: "空闲",
        .settingsAssistantStatusStarting: "连接中",
        .settingsAssistantStatusReady: "已连接",
        .settingsAssistantStatusUnavailable: "不可用",
        .settingsAssistantStatusError: "错误",
        .settingsAssistantRouteStrategy: "模型路由",
        .settingsAssistantRouteCloudPreferred: "云优先（本地兜底）",
        .settingsAssistantRouteCloudOnly: "仅云端",
        .settingsAssistantRouteLocalOnly: "仅本地",
        .settingsAssistantCloudPrimaryModel: "云端主模型",
        .settingsAssistantLocalFallbackModel: "本地兜底模型",
        .settingsAssistantGatewayURL: "Gateway 地址",
        .settingsAssistantGatewayToken: "Gateway Token（可选）",
        .settingsAssistantGatewaySessionKey: "会话标识",
        .settingsAssistantAllowReadOnly: "允许只读建议",
        .settingsAssistantAllowFileActions: "允许文件操作",
        .settingsAssistantAllowTerminalActions: "允许终端命令",
        .settingsAssistantAllowBrowserActions: "允许浏览器自动化",
        .settingsAssistantThirdPartySkillsDisabledHint: "第三方 skills 默认禁用，仅白名单可启用",
        .settingsAssistantTestPrompt: "测试消息",
        .settingsAssistantSendTest: "发送测试消息",
        .settingsAssistantOpenChat: "打开连续对话",
        .settingsAssistantSending: "发送中…",
        .settingsAssistantLastResponse: "最近回复",
        .settingsAssistantLastError: "最近错误",
        .settingsAssistantVoiceSection: "本地语音（CosyVoice）",
        .settingsAssistantVoiceEnabled: "启用本地语音播报",
        .settingsAssistantVoiceAutoSpeak: "AI 回复后自动播报",
        .settingsAssistantVoiceInputDevice: "输入设备（麦克风）",
        .settingsAssistantVoiceOutputDevice: "输出设备（扬声器）",
        .settingsAssistantVoiceDeviceSystemDefault: "系统默认",
        .settingsAssistantVoiceRefreshDevices: "刷新设备列表",
        .settingsAssistantVoiceTestInput: "测试输入设备",
        .settingsAssistantVoiceTestOutput: "测试输出设备",
        .settingsAssistantVoiceInputTestResult: "输入测试结果",
        .settingsAssistantVoiceOutputTestResult: "输出测试结果",
        .settingsAssistantVoiceTestPassed: "测试通过",
        .settingsAssistantVoiceTestRunning: "测试中…",
        .settingsAssistantVoicePythonCommand: "Python 命令",
        .settingsAssistantVoiceSTTCommand: "Whisper 命令",
        .settingsAssistantVoiceSTTModelPath: "Whisper 模型路径",
        .settingsAssistantVoiceSTTLanguage: "Whisper 语言（auto/zh/en/ja）",
        .settingsAssistantVoiceModel: "CosyVoice 模型（ID/路径）",
        .settingsAssistantVoiceSpeaker: "说话人（可选）",
        .settingsAssistantVoiceScriptPath: "脚本路径（可选）",
        .settingsAssistantVoiceAdvanced: "高级语音参数",
        .settingsAssistantVoiceAdvancedHint: "仅在你自定义本地语音栈时修改以下参数",
        .settingsAssistantVoiceHint: "需要先安装 CosyVoice 依赖。可运行 scripts/check_voice_stack.py 查看环境状态。",
        .assistantChatWindowTitle: "AI 连续对话",
        .assistantChatEmptyState: "开始第一条消息吧。",
        .assistantChatInputPlaceholder: "输入你的问题或指令…",
        .assistantChatSend: "发送",
        .assistantChatClear: "清空会话",
        .assistantChatSpeakLatest: "播报最新回复",
        .assistantChatVoiceInput: "语音输入",
        .assistantChatStopRecording: "停止录音",
        .assistantChatConnectionHint: "需要先连接 Helper 和 Gateway。",
        .assistantChatSending: "AI 正在回复…",
        .assistantChatRecording: "录音中…再次点击结束",
        .assistantChatTranscribing: "语音转写中…",
        .assistantChatSpeaking: "语音播报中…",
        .assistantChatSpeechError: "语音错误",
        .assistantChatTranscriptionError: "转写错误",
        .assistantChatErrorPrefix: "错误",
        .assistantChatRoleUser: "你",
        .assistantChatRoleAssistant: "猫咪伴侣",
        .assistantChatRoleSystem: "系统",
        .diagnosticsGuideTitle: "欢迎使用猫咪伴侣",
        .diagnosticsGuideSubtitle: "只需几步即可完成基本设置，开始使用健康提醒和 AI 助理。",
        .diagnosticsGuideChecking: "正在检测…",
        .diagnosticsGuideLastChecked: "最近检测",
        .diagnosticsGuideRunAgain: "重新检测",
        .diagnosticsGuideOpenSettings: "打开设置",
        .diagnosticsGuideDone: "开始使用",
        .diagnosticsGuideSkip: "跳过，稍后配置",
        .diagnosticsGuidePhaseBasicTitle: "基本设置",
        .diagnosticsGuidePhaseBasicSubtitle: "配置通知和提醒偏好，即可开始使用。",
        .diagnosticsGuidePhaseAdvancedTitle: "高级功能",
        .diagnosticsGuidePhaseAdvancedSubtitle: "AI 助理和语音功能需要额外配置。可以稍后在设置中完成。",
        .diagnosticsGuidePhaseAdvancedSkipHint: "这些功能是可选的，可随时在设置中配置。",
        .diagnosticsGuideNextStep: "下一步",
        .diagnosticsGuidePreviousStep: "上一步",
        .diagnosticsQuickStartTitle: "快速上手",
        .diagnosticsQuickStartNotificationsTitle: "开启通知",
        .diagnosticsQuickStartNotificationsDetail: "允许系统通知，确保提醒准时送达。",
        .diagnosticsQuickStartGatewayTitle: "AI 服务连接",
        .diagnosticsQuickStartGatewayDetail: "配置 AI 服务地址以启用智能助理对话。",
        .diagnosticsQuickStartDisplayTitle: "显示偏好",
        .diagnosticsQuickStartDisplayDetail: "选择助理图标的显示方式和提醒风格。",
        .diagnosticsStatusPass: "通过",
        .diagnosticsStatusWarning: "警告",
        .diagnosticsStatusFailed: "失败",
        .diagnosticsCheckHelper: "助理服务",
        .diagnosticsCheckGateway: "AI 服务连接",
        .diagnosticsCheckMicrophone: "麦克风权限",
        .diagnosticsCheckWhisperCommand: "语音识别引擎",
        .diagnosticsCheckWhisperModel: "语音识别模型",
        .diagnosticsCheckCosyScript: "语音合成引擎",
        .diagnosticsCheckPythonDependencies: "语音运行环境",
        .diagnosticsCheckInputDevice: "语音输入设备",
        .diagnosticsCheckOutputDevice: "语音输出设备",
        .diagnosticsDetailFound: "已找到",
        .diagnosticsDetailMissing: "缺失",
        .diagnosticsDetailNotConfigured: "未配置",
        .diagnosticsDetailUsingSystemDefault: "使用系统默认",
        .diagnosticsDetailPermissionUnknown: "尚未授权（首次使用会弹窗）",
        .diagnosticsDetailPermissionDenied: "已拒绝（请到系统设置开启）",
        .diagnosticsDetailPermissionGranted: "已授权",
        .diagnosticsDetailConnected: "已连接",
        .diagnosticsDetailConnectionFailed: "连接失败",
        .diagnosticsDetailAssistantDisabled: "AI 助理未启用，已跳过实时连通性检测",
        .diagnosticsDetailVoiceDisabled: "本地语音未启用，已跳过"
    ]

    private static let zhHantTable: [AppStringKey: String] = [
        .appName: "貓咪伴侶",
        .menuShowPet: "顯示助理",
        .menuHidePet: "隱藏助理",
        .menuSystemNotification: "系統通知",
        .menuPauseReminders: "暫停提醒",
        .menuResumeReminders: "恢復提醒",
        .menuRemindersPaused: "提醒已暫停",
        .menuNextReminder: "下次提醒",
        .menuSnooze5Min: "5 分鐘後再提醒",
        .menuSnooze10Min: "10 分鐘後再提醒",
        .menuSnooze30Min: "30 分鐘後再提醒",
        .menuAssistantEnabled: "AI 助理",
        .menuAssistantChat: "開啟 AI 對話",
        .menuDiagnostics: "環境診斷…",
        .menuCheckForUpdates: "檢查更新…",
        .menuSettings: "設定…",
        .menuQuit: "結束",
        .reminderHydrateName: "喝水",
        .reminderStandName: "站立走動",
        .reminderRestEyesName: "閉眼休息",
        .reminderHydratePrompt: "喝點水吧，身體會感謝你。",
        .reminderStandPrompt: "站起來走動一下。",
        .reminderRestEyesPrompt: "閉眼休息 20 秒，放鬆眼睛。",
        .actionComplete: "完成",
        .actionSnooze: "稍後",
        .settingsReminderSection: "提醒設定",
        .settingsPetSection: "寵物",
        .settingsNotificationSection: "通知",
        .settingsGroup: "設定分組",
        .settingsAlwaysOnTop: "始終置頂",
        .settingsPetShowOnlyWhenReminding: "僅在提醒時自動顯示貓咪",
        .settingsPetShowOnlyWhenRemindingHelp: "關閉後，你可以從選單手動常駐顯示貓咪",
        .settingsPetMotionProfile: "面板動效",
        .settingsPetMotionProfileSubtle: "極簡",
        .settingsPetMotionProfileVivid: "高動效",
        .settingsPetMotionProfileHelp: "高動效更炫但更耗電；極簡更克制",
        .settingsPetIdleLowPowerEnabled: "閒置時降低動畫頻率",
        .settingsPetIdleLowPowerHelp: "長時間無互動時自動進入低功耗動畫",
        .settingsPetIdleLowPowerDelay: "進入低功耗前延遲（秒）",
        .settingsPetIdleLowPowerDelayHelp: "設定閒置多少秒後切換為低功耗動畫",
        .settingsEnableSystemNotification: "啟用系統通知",
        .settingsNotificationHelp: "系統通知需要使用者授權",
        .settingsAuthorizationStatus: "權限狀態",
        .settingsAuthorizationAllowed: "已允許",
        .settingsAuthorizationDenied: "已拒絕",
        .settingsAuthorizationNotDetermined: "未決定",
        .settingsAuthorizationUnknown: "未知",
        .settingsOpenSystemSettings: "打開系統設定",
        .settingsIntervalMinutes: "間隔（分鐘）",
        .settingsQuietHours: "安靜時段",
        .settingsQuietStart: "開始",
        .settingsQuietEnd: "結束",
        .settingsSnoozeReminder: "稍後提醒",
        .settingsPauseAllReminders: "暫停全部提醒",
        .settingsPauseAllRemindersHelp: "開啟後不會觸發新的提醒",
        .settingsReminderCooldown: "提醒間冷卻（分鐘）",
        .settingsReminderCooldownHelp: "0 表示不啟用冷卻",
        .settingsReminderCooldownOff: "關閉",
        .settingsAssistantSection: "AI 助理",
        .settingsAssistantSecuritySection: "執行與安全",
        .settingsAssistantEnabled: "啟用 AI 助理",
        .settingsAssistantAutoStart: "啟動時自動連線 Helper",
        .settingsAssistantConnectionStatus: "連線狀態",
        .settingsAssistantStatusIdle: "閒置",
        .settingsAssistantStatusStarting: "連線中",
        .settingsAssistantStatusReady: "已連線",
        .settingsAssistantStatusUnavailable: "不可用",
        .settingsAssistantStatusError: "錯誤",
        .settingsAssistantRouteStrategy: "模型路由",
        .settingsAssistantRouteCloudPreferred: "雲端優先（本機兜底）",
        .settingsAssistantRouteCloudOnly: "僅雲端",
        .settingsAssistantRouteLocalOnly: "僅本機",
        .settingsAssistantCloudPrimaryModel: "雲端主模型",
        .settingsAssistantLocalFallbackModel: "本機兜底模型",
        .settingsAssistantGatewayURL: "Gateway 位址",
        .settingsAssistantGatewayToken: "Gateway Token（選填）",
        .settingsAssistantGatewaySessionKey: "工作階段識別",
        .settingsAssistantAllowReadOnly: "允許只讀建議",
        .settingsAssistantAllowFileActions: "允許檔案操作",
        .settingsAssistantAllowTerminalActions: "允許終端機命令",
        .settingsAssistantAllowBrowserActions: "允許瀏覽器自動化",
        .settingsAssistantThirdPartySkillsDisabledHint: "第三方 skills 預設禁用，僅白名單可啟用",
        .settingsAssistantTestPrompt: "測試訊息",
        .settingsAssistantSendTest: "送出測試訊息",
        .settingsAssistantOpenChat: "開啟連續對話",
        .settingsAssistantSending: "傳送中…",
        .settingsAssistantLastResponse: "最近回覆",
        .settingsAssistantLastError: "最近錯誤",
        .settingsAssistantVoiceSection: "本機語音（CosyVoice）",
        .settingsAssistantVoiceEnabled: "啟用本機語音播報",
        .settingsAssistantVoiceAutoSpeak: "AI 回覆後自動播報",
        .settingsAssistantVoiceInputDevice: "輸入裝置（麥克風）",
        .settingsAssistantVoiceOutputDevice: "輸出裝置（喇叭）",
        .settingsAssistantVoiceDeviceSystemDefault: "系統預設",
        .settingsAssistantVoiceRefreshDevices: "重新整理裝置列表",
        .settingsAssistantVoiceTestInput: "測試輸入裝置",
        .settingsAssistantVoiceTestOutput: "測試輸出裝置",
        .settingsAssistantVoiceInputTestResult: "輸入測試結果",
        .settingsAssistantVoiceOutputTestResult: "輸出測試結果",
        .settingsAssistantVoiceTestPassed: "測試通過",
        .settingsAssistantVoiceTestRunning: "測試中…",
        .settingsAssistantVoicePythonCommand: "Python 指令",
        .settingsAssistantVoiceSTTCommand: "Whisper 指令",
        .settingsAssistantVoiceSTTModelPath: "Whisper 模型路徑",
        .settingsAssistantVoiceSTTLanguage: "Whisper 語言（auto/zh/en/ja）",
        .settingsAssistantVoiceModel: "CosyVoice 模型（ID/路徑）",
        .settingsAssistantVoiceSpeaker: "說話人（選填）",
        .settingsAssistantVoiceScriptPath: "腳本路徑（選填）",
        .settingsAssistantVoiceAdvanced: "進階語音參數",
        .settingsAssistantVoiceAdvancedHint: "僅在你自訂本機語音堆疊時修改以下參數",
        .settingsAssistantVoiceHint: "請先安裝 CosyVoice 依賴。可執行 scripts/check_voice_stack.py 檢查環境。",
        .assistantChatWindowTitle: "AI 連續對話",
        .assistantChatEmptyState: "先傳送第一則訊息吧。",
        .assistantChatInputPlaceholder: "輸入你的問題或指令…",
        .assistantChatSend: "送出",
        .assistantChatClear: "清空對話",
        .assistantChatSpeakLatest: "播報最新回覆",
        .assistantChatVoiceInput: "語音輸入",
        .assistantChatStopRecording: "停止錄音",
        .assistantChatConnectionHint: "需要先連線 Helper 與 Gateway。",
        .assistantChatSending: "AI 回覆中…",
        .assistantChatRecording: "錄音中…再次點擊結束",
        .assistantChatTranscribing: "語音轉寫中…",
        .assistantChatSpeaking: "語音播報中…",
        .assistantChatSpeechError: "語音錯誤",
        .assistantChatTranscriptionError: "轉寫錯誤",
        .assistantChatErrorPrefix: "錯誤",
        .assistantChatRoleUser: "你",
        .assistantChatRoleAssistant: "貓咪伴侶",
        .assistantChatRoleSystem: "系統",
        .diagnosticsGuideTitle: "歡迎使用貓咪伴侶",
        .diagnosticsGuideSubtitle: "只需幾步即可完成基本設定，開始使用健康提醒和 AI 助理。",
        .diagnosticsGuideChecking: "檢查中…",
        .diagnosticsGuideLastChecked: "最近檢查",
        .diagnosticsGuideRunAgain: "重新檢查",
        .diagnosticsGuideOpenSettings: "開啟設定",
        .diagnosticsGuideDone: "開始使用",
        .diagnosticsGuideSkip: "跳過，稍後設定",
        .diagnosticsGuidePhaseBasicTitle: "基本設定",
        .diagnosticsGuidePhaseBasicSubtitle: "設定通知和提醒偏好，即可開始使用。",
        .diagnosticsGuidePhaseAdvancedTitle: "進階功能",
        .diagnosticsGuidePhaseAdvancedSubtitle: "AI 助理和語音功能需要額外設定。可以稍後在設定中完成。",
        .diagnosticsGuidePhaseAdvancedSkipHint: "這些功能是可選的，可隨時在設定中配置。",
        .diagnosticsGuideNextStep: "下一步",
        .diagnosticsGuidePreviousStep: "上一步",
        .diagnosticsQuickStartTitle: "快速上手",
        .diagnosticsQuickStartNotificationsTitle: "開啟通知",
        .diagnosticsQuickStartNotificationsDetail: "允許系統通知，確保提醒準時送達。",
        .diagnosticsQuickStartGatewayTitle: "AI 服務連線",
        .diagnosticsQuickStartGatewayDetail: "設定 AI 服務位址以啟用智慧助理對話。",
        .diagnosticsQuickStartDisplayTitle: "顯示偏好",
        .diagnosticsQuickStartDisplayDetail: "選擇助理圖示的顯示方式和提醒風格。",
        .diagnosticsStatusPass: "通過",
        .diagnosticsStatusWarning: "警告",
        .diagnosticsStatusFailed: "失敗",
        .diagnosticsCheckHelper: "助理服務",
        .diagnosticsCheckGateway: "AI 服務連線",
        .diagnosticsCheckMicrophone: "麥克風權限",
        .diagnosticsCheckWhisperCommand: "語音辨識引擎",
        .diagnosticsCheckWhisperModel: "語音辨識模型",
        .diagnosticsCheckCosyScript: "語音合成引擎",
        .diagnosticsCheckPythonDependencies: "語音執行環境",
        .diagnosticsCheckInputDevice: "語音輸入裝置",
        .diagnosticsCheckOutputDevice: "語音輸出裝置",
        .diagnosticsDetailFound: "已找到",
        .diagnosticsDetailMissing: "缺失",
        .diagnosticsDetailNotConfigured: "未設定",
        .diagnosticsDetailUsingSystemDefault: "使用系統預設",
        .diagnosticsDetailPermissionUnknown: "尚未授權（首次使用會跳出提示）",
        .diagnosticsDetailPermissionDenied: "已拒絕（請到系統設定開啟）",
        .diagnosticsDetailPermissionGranted: "已授權",
        .diagnosticsDetailConnected: "已連線",
        .diagnosticsDetailConnectionFailed: "連線失敗",
        .diagnosticsDetailAssistantDisabled: "AI 助理未啟用，已跳過即時連線檢查",
        .diagnosticsDetailVoiceDisabled: "本機語音未啟用，已跳過"
    ]

    private static let enTable: [AppStringKey: String] = [
        .appName: "Cat Companion",
        .menuShowPet: "Show Assistant",
        .menuHidePet: "Hide Assistant",
        .menuSystemNotification: "System Notifications",
        .menuPauseReminders: "Pause Reminders",
        .menuResumeReminders: "Resume Reminders",
        .menuRemindersPaused: "Reminders Paused",
        .menuNextReminder: "Next Reminder",
        .menuSnooze5Min: "Remind in 5 min",
        .menuSnooze10Min: "Remind in 10 min",
        .menuSnooze30Min: "Remind in 30 min",
        .menuAssistantEnabled: "AI Assistant",
        .menuAssistantChat: "Open AI Chat",
        .menuDiagnostics: "Environment Diagnostics…",
        .menuCheckForUpdates: "Check for Updates…",
        .menuSettings: "Settings…",
        .menuQuit: "Quit",
        .reminderHydrateName: "Hydrate",
        .reminderStandName: "Stand & Move",
        .reminderRestEyesName: "Rest Eyes",
        .reminderHydratePrompt: "Drink some water. Your body will thank you.",
        .reminderStandPrompt: "Stand up and move around.",
        .reminderRestEyesPrompt: "Close your eyes for 20 seconds and relax.",
        .actionComplete: "Done",
        .actionSnooze: "Snooze",
        .settingsReminderSection: "Reminders",
        .settingsPetSection: "Pet",
        .settingsNotificationSection: "Notifications",
        .settingsGroup: "Settings Group",
        .settingsAlwaysOnTop: "Always on Top",
        .settingsPetShowOnlyWhenReminding: "Show cat only for active reminders",
        .settingsPetShowOnlyWhenRemindingHelp: "Turn off to keep the cat visible manually from the menu",
        .settingsPetMotionProfile: "Panel Animation",
        .settingsPetMotionProfileSubtle: "Subtle",
        .settingsPetMotionProfileVivid: "Vivid",
        .settingsPetMotionProfileHelp: "Vivid looks richer but uses more power; Subtle is lighter",
        .settingsPetIdleLowPowerEnabled: "Reduce animation when idle",
        .settingsPetIdleLowPowerHelp: "Automatically switch to low-power animation after inactivity",
        .settingsPetIdleLowPowerDelay: "Low-power delay (seconds)",
        .settingsPetIdleLowPowerDelayHelp: "How long to stay idle before switching to low-power animation",
        .settingsEnableSystemNotification: "Enable System Notifications",
        .settingsNotificationHelp: "System notifications require permission.",
        .settingsAuthorizationStatus: "Authorization",
        .settingsAuthorizationAllowed: "Allowed",
        .settingsAuthorizationDenied: "Denied",
        .settingsAuthorizationNotDetermined: "Not Determined",
        .settingsAuthorizationUnknown: "Unknown",
        .settingsOpenSystemSettings: "Open System Settings",
        .settingsIntervalMinutes: "Interval (minutes)",
        .settingsQuietHours: "Quiet Hours",
        .settingsQuietStart: "Start",
        .settingsQuietEnd: "End",
        .settingsSnoozeReminder: "Snooze Duration",
        .settingsPauseAllReminders: "Pause All Reminders",
        .settingsPauseAllRemindersHelp: "No new reminders will trigger while enabled.",
        .settingsReminderCooldown: "Reminder Cooldown (minutes)",
        .settingsReminderCooldownHelp: "Set to 0 to disable cooldown.",
        .settingsReminderCooldownOff: "Off",
        .settingsAssistantSection: "AI Assistant",
        .settingsAssistantSecuritySection: "Execution & Security",
        .settingsAssistantEnabled: "Enable AI Assistant",
        .settingsAssistantAutoStart: "Auto-connect helper on launch",
        .settingsAssistantConnectionStatus: "Connection Status",
        .settingsAssistantStatusIdle: "Idle",
        .settingsAssistantStatusStarting: "Starting",
        .settingsAssistantStatusReady: "Ready",
        .settingsAssistantStatusUnavailable: "Unavailable",
        .settingsAssistantStatusError: "Error",
        .settingsAssistantRouteStrategy: "Model Routing",
        .settingsAssistantRouteCloudPreferred: "Cloud first (local fallback)",
        .settingsAssistantRouteCloudOnly: "Cloud only",
        .settingsAssistantRouteLocalOnly: "Local only",
        .settingsAssistantCloudPrimaryModel: "Cloud primary model",
        .settingsAssistantLocalFallbackModel: "Local fallback model",
        .settingsAssistantGatewayURL: "Gateway URL",
        .settingsAssistantGatewayToken: "Gateway token (optional)",
        .settingsAssistantGatewaySessionKey: "Session key",
        .settingsAssistantAllowReadOnly: "Allow read-only suggestions",
        .settingsAssistantAllowFileActions: "Allow file actions",
        .settingsAssistantAllowTerminalActions: "Allow terminal commands",
        .settingsAssistantAllowBrowserActions: "Allow browser automation",
        .settingsAssistantThirdPartySkillsDisabledHint: "Third-party skills are disabled by default and only allowed via whitelist.",
        .settingsAssistantTestPrompt: "Test prompt",
        .settingsAssistantSendTest: "Send test prompt",
        .settingsAssistantOpenChat: "Open Continuous Chat",
        .settingsAssistantSending: "Sending…",
        .settingsAssistantLastResponse: "Last response",
        .settingsAssistantLastError: "Last error",
        .settingsAssistantVoiceSection: "Local Voice (CosyVoice)",
        .settingsAssistantVoiceEnabled: "Enable local voice playback",
        .settingsAssistantVoiceAutoSpeak: "Auto-speak AI replies",
        .settingsAssistantVoiceInputDevice: "Input Device (Microphone)",
        .settingsAssistantVoiceOutputDevice: "Output Device (Speaker)",
        .settingsAssistantVoiceDeviceSystemDefault: "System Default",
        .settingsAssistantVoiceRefreshDevices: "Refresh Device List",
        .settingsAssistantVoiceTestInput: "Test Input Device",
        .settingsAssistantVoiceTestOutput: "Test Output Device",
        .settingsAssistantVoiceInputTestResult: "Input Test Result",
        .settingsAssistantVoiceOutputTestResult: "Output Test Result",
        .settingsAssistantVoiceTestPassed: "Test Passed",
        .settingsAssistantVoiceTestRunning: "Testing…",
        .settingsAssistantVoicePythonCommand: "Python command",
        .settingsAssistantVoiceSTTCommand: "Whisper command",
        .settingsAssistantVoiceSTTModelPath: "Whisper model path",
        .settingsAssistantVoiceSTTLanguage: "Whisper language (auto/zh/en/ja)",
        .settingsAssistantVoiceModel: "CosyVoice model (ID/path)",
        .settingsAssistantVoiceSpeaker: "Speaker (optional)",
        .settingsAssistantVoiceScriptPath: "Script path (optional)",
        .settingsAssistantVoiceAdvanced: "Advanced Voice Parameters",
        .settingsAssistantVoiceAdvancedHint: "Change these only if you customize your local voice stack",
        .settingsAssistantVoiceHint: "Install CosyVoice dependencies first. Run scripts/check_voice_stack.py to verify your environment.",
        .assistantChatWindowTitle: "AI Continuous Chat",
        .assistantChatEmptyState: "Send your first message.",
        .assistantChatInputPlaceholder: "Type your question or instruction…",
        .assistantChatSend: "Send",
        .assistantChatClear: "Clear Chat",
        .assistantChatSpeakLatest: "Speak Last Reply",
        .assistantChatVoiceInput: "Voice Input",
        .assistantChatStopRecording: "Stop Recording",
        .assistantChatConnectionHint: "Connect helper and gateway first.",
        .assistantChatSending: "AI is replying…",
        .assistantChatRecording: "Recording… tap again to finish",
        .assistantChatTranscribing: "Transcribing voice…",
        .assistantChatSpeaking: "Playing voice…",
        .assistantChatSpeechError: "Voice Error",
        .assistantChatTranscriptionError: "Transcription Error",
        .assistantChatErrorPrefix: "Error",
        .assistantChatRoleUser: "You",
        .assistantChatRoleAssistant: "Cat Companion",
        .assistantChatRoleSystem: "System",
        .diagnosticsGuideTitle: "Welcome to Cat Companion",
        .diagnosticsGuideSubtitle: "A few quick steps to set up health reminders and AI assistant.",
        .diagnosticsGuideChecking: "Running checks…",
        .diagnosticsGuideLastChecked: "Last checked",
        .diagnosticsGuideRunAgain: "Run Again",
        .diagnosticsGuideOpenSettings: "Open Settings",
        .diagnosticsGuideDone: "Get Started",
        .diagnosticsGuideSkip: "Skip, configure later",
        .diagnosticsGuidePhaseBasicTitle: "Basic Setup",
        .diagnosticsGuidePhaseBasicSubtitle: "Configure notifications and reminder preferences to get started.",
        .diagnosticsGuidePhaseAdvancedTitle: "Advanced Features",
        .diagnosticsGuidePhaseAdvancedSubtitle: "AI assistant and voice features require additional setup. You can complete this later in Settings.",
        .diagnosticsGuidePhaseAdvancedSkipHint: "These features are optional and can be configured anytime in Settings.",
        .diagnosticsGuideNextStep: "Next",
        .diagnosticsGuidePreviousStep: "Back",
        .diagnosticsQuickStartTitle: "Quick Start",
        .diagnosticsQuickStartNotificationsTitle: "Enable Notifications",
        .diagnosticsQuickStartNotificationsDetail: "Allow system notifications so reminders arrive on time.",
        .diagnosticsQuickStartGatewayTitle: "AI Service Connection",
        .diagnosticsQuickStartGatewayDetail: "Configure the AI service URL to enable assistant conversations.",
        .diagnosticsQuickStartDisplayTitle: "Display Preferences",
        .diagnosticsQuickStartDisplayDetail: "Choose how the assistant icon appears and the reminder style.",
        .diagnosticsStatusPass: "Pass",
        .diagnosticsStatusWarning: "Warning",
        .diagnosticsStatusFailed: "Failed",
        .diagnosticsCheckHelper: "Assistant Service",
        .diagnosticsCheckGateway: "AI Service Connection",
        .diagnosticsCheckMicrophone: "Microphone Permission",
        .diagnosticsCheckWhisperCommand: "Speech Recognition Engine",
        .diagnosticsCheckWhisperModel: "Speech Recognition Model",
        .diagnosticsCheckCosyScript: "Voice Synthesis Engine",
        .diagnosticsCheckPythonDependencies: "Voice Runtime Environment",
        .diagnosticsCheckInputDevice: "Voice Input Device",
        .diagnosticsCheckOutputDevice: "Voice Output Device",
        .diagnosticsDetailFound: "Found",
        .diagnosticsDetailMissing: "Missing",
        .diagnosticsDetailNotConfigured: "Not configured",
        .diagnosticsDetailUsingSystemDefault: "Using system default",
        .diagnosticsDetailPermissionUnknown: "Not requested yet (prompt appears on first use)",
        .diagnosticsDetailPermissionDenied: "Denied (enable in System Settings)",
        .diagnosticsDetailPermissionGranted: "Granted",
        .diagnosticsDetailConnected: "Connected",
        .diagnosticsDetailConnectionFailed: "Connection failed",
        .diagnosticsDetailAssistantDisabled: "Assistant is disabled, skipped live connectivity probe",
        .diagnosticsDetailVoiceDisabled: "Local voice is disabled, skipped"
    ]

    private static let jaTable: [AppStringKey: String] = [
        .appName: "猫咪コンパニオン",
        .menuShowPet: "アシスタントを表示",
        .menuHidePet: "アシスタントを隠す",
        .menuSystemNotification: "システム通知",
        .menuPauseReminders: "リマインダーを一時停止",
        .menuResumeReminders: "リマインダーを再開",
        .menuRemindersPaused: "リマインダーは一時停止中",
        .menuNextReminder: "次のリマインダー",
        .menuSnooze5Min: "5 分後に再通知",
        .menuSnooze10Min: "10 分後に再通知",
        .menuSnooze30Min: "30 分後に再通知",
        .menuAssistantEnabled: "AI アシスタント",
        .menuAssistantChat: "AI 会話を開く",
        .menuDiagnostics: "環境診断…",
        .menuCheckForUpdates: "アップデートを確認…",
        .menuSettings: "設定…",
        .menuQuit: "終了",
        .reminderHydrateName: "水分補給",
        .reminderStandName: "立って移動",
        .reminderRestEyesName: "目を休める",
        .reminderHydratePrompt: "水を飲みましょう。体が喜びます。",
        .reminderStandPrompt: "立ち上がって少し歩きましょう。",
        .reminderRestEyesPrompt: "20秒間目を閉じて、目を休めましょう。",
        .actionComplete: "完了",
        .actionSnooze: "あとで",
        .settingsReminderSection: "リマインダー設定",
        .settingsPetSection: "ペット",
        .settingsNotificationSection: "通知",
        .settingsGroup: "設定グループ",
        .settingsAlwaysOnTop: "常に最前面",
        .settingsPetShowOnlyWhenReminding: "リマインダー時のみ猫を自動表示",
        .settingsPetShowOnlyWhenRemindingHelp: "オフにすると、メニューから手動で常時表示できます",
        .settingsPetMotionProfile: "パネルアニメーション",
        .settingsPetMotionProfileSubtle: "最小",
        .settingsPetMotionProfileVivid: "高演出",
        .settingsPetMotionProfileHelp: "高演出は見栄えが良いですが消費電力が増えます",
        .settingsPetIdleLowPowerEnabled: "アイドル時にアニメーションを抑える",
        .settingsPetIdleLowPowerHelp: "一定時間操作がない場合は省電力アニメーションへ切替",
        .settingsPetIdleLowPowerDelay: "省電力移行までの遅延（秒）",
        .settingsPetIdleLowPowerDelayHelp: "何秒アイドル状態が続いたら省電力アニメーションへ切替えるか",
        .settingsEnableSystemNotification: "システム通知を有効化",
        .settingsNotificationHelp: "システム通知には許可が必要です。",
        .settingsAuthorizationStatus: "許可状態",
        .settingsAuthorizationAllowed: "許可済み",
        .settingsAuthorizationDenied: "拒否済み",
        .settingsAuthorizationNotDetermined: "未決定",
        .settingsAuthorizationUnknown: "不明",
        .settingsOpenSystemSettings: "システム設定を開く",
        .settingsIntervalMinutes: "間隔（分）",
        .settingsQuietHours: "静かな時間帯",
        .settingsQuietStart: "開始",
        .settingsQuietEnd: "終了",
        .settingsSnoozeReminder: "再通知",
        .settingsPauseAllReminders: "すべてのリマインダーを一時停止",
        .settingsPauseAllRemindersHelp: "有効中は新しいリマインダーを表示しません。",
        .settingsReminderCooldown: "リマインダー間クールダウン（分）",
        .settingsReminderCooldownHelp: "0でクールダウンを無効化",
        .settingsReminderCooldownOff: "オフ",
        .settingsAssistantSection: "AI アシスタント",
        .settingsAssistantSecuritySection: "実行とセキュリティ",
        .settingsAssistantEnabled: "AI アシスタントを有効化",
        .settingsAssistantAutoStart: "起動時に Helper へ自動接続",
        .settingsAssistantConnectionStatus: "接続状態",
        .settingsAssistantStatusIdle: "待機中",
        .settingsAssistantStatusStarting: "接続中",
        .settingsAssistantStatusReady: "接続済み",
        .settingsAssistantStatusUnavailable: "利用不可",
        .settingsAssistantStatusError: "エラー",
        .settingsAssistantRouteStrategy: "モデルルーティング",
        .settingsAssistantRouteCloudPreferred: "クラウド優先（ローカルにフォールバック）",
        .settingsAssistantRouteCloudOnly: "クラウドのみ",
        .settingsAssistantRouteLocalOnly: "ローカルのみ",
        .settingsAssistantCloudPrimaryModel: "クラウド主モデル",
        .settingsAssistantLocalFallbackModel: "ローカルフォールバックモデル",
        .settingsAssistantGatewayURL: "Gateway URL",
        .settingsAssistantGatewayToken: "Gateway トークン（任意）",
        .settingsAssistantGatewaySessionKey: "セッションキー",
        .settingsAssistantAllowReadOnly: "読み取り専用提案を許可",
        .settingsAssistantAllowFileActions: "ファイル操作を許可",
        .settingsAssistantAllowTerminalActions: "ターミナル実行を許可",
        .settingsAssistantAllowBrowserActions: "ブラウザ自動化を許可",
        .settingsAssistantThirdPartySkillsDisabledHint: "サードパーティ skills は既定で無効。ホワイトリストのみ有効化できます。",
        .settingsAssistantTestPrompt: "テストメッセージ",
        .settingsAssistantSendTest: "テスト送信",
        .settingsAssistantOpenChat: "連続会話を開く",
        .settingsAssistantSending: "送信中…",
        .settingsAssistantLastResponse: "最新の応答",
        .settingsAssistantLastError: "最新のエラー",
        .settingsAssistantVoiceSection: "ローカル音声（CosyVoice）",
        .settingsAssistantVoiceEnabled: "ローカル音声再生を有効化",
        .settingsAssistantVoiceAutoSpeak: "AI 応答を自動で読み上げ",
        .settingsAssistantVoiceInputDevice: "入力デバイス（マイク）",
        .settingsAssistantVoiceOutputDevice: "出力デバイス（スピーカー）",
        .settingsAssistantVoiceDeviceSystemDefault: "システムデフォルト",
        .settingsAssistantVoiceRefreshDevices: "デバイス一覧を更新",
        .settingsAssistantVoiceTestInput: "入力デバイスをテスト",
        .settingsAssistantVoiceTestOutput: "出力デバイスをテスト",
        .settingsAssistantVoiceInputTestResult: "入力テスト結果",
        .settingsAssistantVoiceOutputTestResult: "出力テスト結果",
        .settingsAssistantVoiceTestPassed: "テスト成功",
        .settingsAssistantVoiceTestRunning: "テスト中…",
        .settingsAssistantVoicePythonCommand: "Python コマンド",
        .settingsAssistantVoiceSTTCommand: "Whisper コマンド",
        .settingsAssistantVoiceSTTModelPath: "Whisper モデルパス",
        .settingsAssistantVoiceSTTLanguage: "Whisper 言語（auto/zh/en/ja）",
        .settingsAssistantVoiceModel: "CosyVoice モデル（ID/パス）",
        .settingsAssistantVoiceSpeaker: "話者（任意）",
        .settingsAssistantVoiceScriptPath: "スクリプトパス（任意）",
        .settingsAssistantVoiceAdvanced: "音声の詳細設定",
        .settingsAssistantVoiceAdvancedHint: "ローカル音声スタックをカスタマイズする場合のみ変更してください",
        .settingsAssistantVoiceHint: "先に CosyVoice 依存をインストールしてください。scripts/check_voice_stack.py で確認できます。",
        .assistantChatWindowTitle: "AI 連続会話",
        .assistantChatEmptyState: "最初のメッセージを送信してください。",
        .assistantChatInputPlaceholder: "質問や指示を入力…",
        .assistantChatSend: "送信",
        .assistantChatClear: "会話をクリア",
        .assistantChatSpeakLatest: "最新応答を読み上げ",
        .assistantChatVoiceInput: "音声入力",
        .assistantChatStopRecording: "録音停止",
        .assistantChatConnectionHint: "先に Helper と Gateway を接続してください。",
        .assistantChatSending: "AI が応答中…",
        .assistantChatRecording: "録音中…もう一度押すと終了",
        .assistantChatTranscribing: "音声を文字起こし中…",
        .assistantChatSpeaking: "音声再生中…",
        .assistantChatSpeechError: "音声エラー",
        .assistantChatTranscriptionError: "文字起こしエラー",
        .assistantChatErrorPrefix: "エラー",
        .assistantChatRoleUser: "あなた",
        .assistantChatRoleAssistant: "猫咪コンパニオン",
        .assistantChatRoleSystem: "システム",
        .diagnosticsGuideTitle: "Cat Companion へようこそ",
        .diagnosticsGuideSubtitle: "数ステップで基本設定を完了し、リマインダーと AI アシスタントを使い始めましょう。",
        .diagnosticsGuideChecking: "チェック中…",
        .diagnosticsGuideLastChecked: "最終チェック",
        .diagnosticsGuideRunAgain: "再チェック",
        .diagnosticsGuideOpenSettings: "設定を開く",
        .diagnosticsGuideDone: "使い始める",
        .diagnosticsGuideSkip: "スキップして後で設定",
        .diagnosticsGuidePhaseBasicTitle: "基本設定",
        .diagnosticsGuidePhaseBasicSubtitle: "通知とリマインダーの設定を行えば、すぐに使い始められます。",
        .diagnosticsGuidePhaseAdvancedTitle: "高度な機能",
        .diagnosticsGuidePhaseAdvancedSubtitle: "AI アシスタントと音声機能には追加設定が必要です。後から設定で完了できます。",
        .diagnosticsGuidePhaseAdvancedSkipHint: "これらの機能はオプションです。いつでも設定から構成できます。",
        .diagnosticsGuideNextStep: "次へ",
        .diagnosticsGuidePreviousStep: "戻る",
        .diagnosticsQuickStartTitle: "クイックスタート",
        .diagnosticsQuickStartNotificationsTitle: "通知を有効にする",
        .diagnosticsQuickStartNotificationsDetail: "システム通知を許可して、リマインダーを確実に受け取りましょう。",
        .diagnosticsQuickStartGatewayTitle: "AI サービス接続",
        .diagnosticsQuickStartGatewayDetail: "AI サービスの URL を設定してアシスタント会話を有効にします。",
        .diagnosticsQuickStartDisplayTitle: "表示設定",
        .diagnosticsQuickStartDisplayDetail: "アシスタントアイコンの表示方法とリマインダーのスタイルを選択します。",
        .diagnosticsStatusPass: "正常",
        .diagnosticsStatusWarning: "警告",
        .diagnosticsStatusFailed: "失敗",
        .diagnosticsCheckHelper: "アシスタントサービス",
        .diagnosticsCheckGateway: "AI サービス接続",
        .diagnosticsCheckMicrophone: "マイク権限",
        .diagnosticsCheckWhisperCommand: "音声認識エンジン",
        .diagnosticsCheckWhisperModel: "音声認識モデル",
        .diagnosticsCheckCosyScript: "音声合成エンジン",
        .diagnosticsCheckPythonDependencies: "音声ランタイム環境",
        .diagnosticsCheckInputDevice: "音声入力デバイス",
        .diagnosticsCheckOutputDevice: "音声出力デバイス",
        .diagnosticsDetailFound: "検出済み",
        .diagnosticsDetailMissing: "不足",
        .diagnosticsDetailNotConfigured: "未設定",
        .diagnosticsDetailUsingSystemDefault: "システムデフォルトを使用",
        .diagnosticsDetailPermissionUnknown: "未要求（初回利用時に許可ダイアログ表示）",
        .diagnosticsDetailPermissionDenied: "拒否済み（システム設定で許可してください）",
        .diagnosticsDetailPermissionGranted: "許可済み",
        .diagnosticsDetailConnected: "接続済み",
        .diagnosticsDetailConnectionFailed: "接続失敗",
        .diagnosticsDetailAssistantDisabled: "AI アシスタント無効のため接続チェックをスキップ",
        .diagnosticsDetailVoiceDisabled: "ローカル音声は無効のためスキップ"
    ]
}

public enum ReminderType: String, CaseIterable, Codable, Identifiable {
    case hydrate
    case stand
    case restEyes

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .hydrate: return AppStrings.text(.reminderHydrateName)
        case .stand: return AppStrings.text(.reminderStandName)
        case .restEyes: return AppStrings.text(.reminderRestEyesName)
        }
    }

    public var prompt: String {
        switch self {
        case .hydrate: return AppStrings.text(.reminderHydratePrompt)
        case .stand: return AppStrings.text(.reminderStandPrompt)
        case .restEyes: return AppStrings.text(.reminderRestEyesPrompt)
        }
    }

    public var defaultIntervalMinutes: Int {
        switch self {
        case .hydrate: return 60
        case .stand: return 90
        case .restEyes: return 45
        }
    }

    public var defaultSnoozeMinutes: Int {
        switch self {
        case .hydrate: return 15
        case .stand: return 20
        case .restEyes: return 10
        }
    }
}

public struct QuietHours: Codable, Equatable {
    public var startHour: Int
    public var endHour: Int

    public init(startHour: Int = 23, endHour: Int = 8) {
        self.startHour = startHour
        self.endHour = endHour
    }

    public var isDisabled: Bool {
        startHour == endHour
    }
}

public struct ReminderPlan: Codable, Equatable {
    public var enabled: Bool
    public var intervalMinutes: Int
    public var quietHours: QuietHours
    public var snoozeMinutes: Int

    public init(
        enabled: Bool,
        intervalMinutes: Int,
        quietHours: QuietHours,
        snoozeMinutes: Int
    ) {
        self.enabled = enabled
        self.intervalMinutes = intervalMinutes
        self.quietHours = quietHours
        self.snoozeMinutes = snoozeMinutes
    }
}

public struct ReminderState: Codable, Equatable {
    public var lastCompletedAt: Date?
    public var lastTriggeredAt: Date?
    public var snoozedUntil: Date?

    public init(lastCompletedAt: Date? = nil, lastTriggeredAt: Date? = nil, snoozedUntil: Date? = nil) {
        self.lastCompletedAt = lastCompletedAt
        self.lastTriggeredAt = lastTriggeredAt
        self.snoozedUntil = snoozedUntil
    }
}

public struct AppSettings: Codable, Equatable {
    public var plans: [ReminderType: ReminderPlan]
    public var states: [ReminderType: ReminderState]
    public var notificationsEnabled: Bool
    public var petAlwaysOnTop: Bool
    public var petShowOnlyWhenReminding: Bool
    public var petMotionProfile: PetMotionProfile
    public var petIdleLowPowerEnabled: Bool
    public var petIdleLowPowerDelaySeconds: Int
    public var remindersPaused: Bool
    public var interReminderCooldownMinutes: Int
    public var assistant: AssistantSettings

    private static let defaultInterReminderCooldownMinutes = 2

    public init(
        plans: [ReminderType: ReminderPlan],
        states: [ReminderType: ReminderState],
        notificationsEnabled: Bool,
        petAlwaysOnTop: Bool,
        petShowOnlyWhenReminding: Bool,
        petMotionProfile: PetMotionProfile,
        petIdleLowPowerEnabled: Bool,
        petIdleLowPowerDelaySeconds: Int,
        remindersPaused: Bool,
        interReminderCooldownMinutes: Int,
        assistant: AssistantSettings
    ) {
        self.plans = plans
        self.states = states
        self.notificationsEnabled = notificationsEnabled
        self.petAlwaysOnTop = petAlwaysOnTop
        self.petShowOnlyWhenReminding = petShowOnlyWhenReminding
        self.petMotionProfile = petMotionProfile
        self.petIdleLowPowerEnabled = petIdleLowPowerEnabled
        self.petIdleLowPowerDelaySeconds = max(5, petIdleLowPowerDelaySeconds)
        self.remindersPaused = remindersPaused
        self.interReminderCooldownMinutes = max(0, interReminderCooldownMinutes)
        self.assistant = assistant
    }

    private enum CodingKeys: String, CodingKey {
        case plans
        case states
        case notificationsEnabled
        case petAlwaysOnTop
        case petShowOnlyWhenReminding
        case petMotionProfile
        case petIdleLowPowerEnabled
        case petIdleLowPowerDelaySeconds
        case remindersPaused
        case interReminderCooldownMinutes
        case assistant
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaultSettings = AppSettings.defaults()
        plans = try container.decodeIfPresent([ReminderType: ReminderPlan].self, forKey: .plans) ?? defaultSettings.plans
        states = try container.decodeIfPresent([ReminderType: ReminderState].self, forKey: .states) ?? defaultSettings.states
        notificationsEnabled = try container.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? defaultSettings.notificationsEnabled
        petAlwaysOnTop = try container.decodeIfPresent(Bool.self, forKey: .petAlwaysOnTop) ?? defaultSettings.petAlwaysOnTop
        petShowOnlyWhenReminding = try container.decodeIfPresent(Bool.self, forKey: .petShowOnlyWhenReminding)
            ?? defaultSettings.petShowOnlyWhenReminding
        petMotionProfile = try container.decodeIfPresent(PetMotionProfile.self, forKey: .petMotionProfile)
            ?? defaultSettings.petMotionProfile
        petIdleLowPowerEnabled = try container.decodeIfPresent(Bool.self, forKey: .petIdleLowPowerEnabled)
            ?? defaultSettings.petIdleLowPowerEnabled
        let lowPowerDelay = try container.decodeIfPresent(Int.self, forKey: .petIdleLowPowerDelaySeconds)
            ?? defaultSettings.petIdleLowPowerDelaySeconds
        petIdleLowPowerDelaySeconds = max(5, lowPowerDelay)
        remindersPaused = try container.decodeIfPresent(Bool.self, forKey: .remindersPaused) ?? defaultSettings.remindersPaused
        let cooldown = try container.decodeIfPresent(Int.self, forKey: .interReminderCooldownMinutes)
            ?? Self.defaultInterReminderCooldownMinutes
        interReminderCooldownMinutes = max(0, cooldown)
        assistant = try container.decodeIfPresent(AssistantSettings.self, forKey: .assistant) ?? defaultSettings.assistant
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(plans, forKey: .plans)
        try container.encode(states, forKey: .states)
        try container.encode(notificationsEnabled, forKey: .notificationsEnabled)
        try container.encode(petAlwaysOnTop, forKey: .petAlwaysOnTop)
        try container.encode(petShowOnlyWhenReminding, forKey: .petShowOnlyWhenReminding)
        try container.encode(petMotionProfile, forKey: .petMotionProfile)
        try container.encode(petIdleLowPowerEnabled, forKey: .petIdleLowPowerEnabled)
        try container.encode(petIdleLowPowerDelaySeconds, forKey: .petIdleLowPowerDelaySeconds)
        try container.encode(remindersPaused, forKey: .remindersPaused)
        try container.encode(interReminderCooldownMinutes, forKey: .interReminderCooldownMinutes)
        try container.encode(assistant, forKey: .assistant)
    }

    public static func defaults() -> AppSettings {
        var planDefaults: [ReminderType: ReminderPlan] = [:]
        var stateDefaults: [ReminderType: ReminderState] = [:]
        for type in ReminderType.allCases {
            planDefaults[type] = ReminderPlan(
                enabled: true,
                intervalMinutes: type.defaultIntervalMinutes,
                quietHours: QuietHours(),
                snoozeMinutes: type.defaultSnoozeMinutes
            )
            stateDefaults[type] = ReminderState()
        }
        return AppSettings(
            plans: planDefaults,
            states: stateDefaults,
            notificationsEnabled: false,
            petAlwaysOnTop: true,
            petShowOnlyWhenReminding: true,
            petMotionProfile: .vivid,
            petIdleLowPowerEnabled: true,
            petIdleLowPowerDelaySeconds: 12,
            remindersPaused: false,
            interReminderCooldownMinutes: Self.defaultInterReminderCooldownMinutes,
            assistant: .defaults()
        )
    }
}
