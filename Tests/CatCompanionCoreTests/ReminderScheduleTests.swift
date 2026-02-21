import XCTest
@testable import CatCompanionCore

final class ReminderScheduleTests: XCTestCase {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return cal
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)) ?? Date()
    }

    func testQuietHoursSameDay() {
        let quiet = QuietHours(startHour: 13, endHour: 15)
        XCTAssertTrue(ReminderSchedule.isInQuietHours(date(2025, 1, 1, 14, 0), quietHours: quiet, calendar: calendar))
        XCTAssertFalse(ReminderSchedule.isInQuietHours(date(2025, 1, 1, 12, 0), quietHours: quiet, calendar: calendar))
    }

    func testQuietHoursOvernight() {
        let quiet = QuietHours(startHour: 22, endHour: 7)
        XCTAssertTrue(ReminderSchedule.isInQuietHours(date(2025, 1, 1, 23, 0), quietHours: quiet, calendar: calendar))
        XCTAssertTrue(ReminderSchedule.isInQuietHours(date(2025, 1, 2, 6, 0), quietHours: quiet, calendar: calendar))
        XCTAssertFalse(ReminderSchedule.isInQuietHours(date(2025, 1, 2, 10, 0), quietHours: quiet, calendar: calendar))
    }

    func testNextDueDateRespectsQuietHours() {
        let quiet = QuietHours(startHour: 23, endHour: 7)
        let plan = ReminderPlan(enabled: true, intervalMinutes: 60, quietHours: quiet, snoozeMinutes: 10)
        let state = ReminderState(lastCompletedAt: nil, lastTriggeredAt: nil, snoozedUntil: nil)
        let now = date(2025, 1, 1, 22, 30)

        let due = ReminderSchedule.nextDueDate(for: .hydrate, plan: plan, state: state, now: now, calendar: calendar)
        let expected = date(2025, 1, 2, 7, 0)
        XCTAssertEqual(due, expected)
    }

    func testNextDueDateUsesFutureSnoozeFirst() {
        let quiet = QuietHours(startHour: 23, endHour: 7)
        let plan = ReminderPlan(enabled: true, intervalMinutes: 60, quietHours: quiet, snoozeMinutes: 10)
        let now = date(2025, 1, 1, 10, 0)
        let snoozedUntil = date(2025, 1, 1, 10, 20)
        let state = ReminderState(lastCompletedAt: nil, lastTriggeredAt: nil, snoozedUntil: snoozedUntil)

        let due = ReminderSchedule.nextDueDate(for: .hydrate, plan: plan, state: state, now: now, calendar: calendar)
        XCTAssertEqual(due, snoozedUntil)
    }

    func testNextDueDateReturnsNilWhenPlanDisabled() {
        let plan = ReminderPlan(enabled: false, intervalMinutes: 60, quietHours: QuietHours(), snoozeMinutes: 10)
        let state = ReminderState()
        let now = date(2025, 1, 1, 10, 0)

        let due = ReminderSchedule.nextDueDate(for: .hydrate, plan: plan, state: state, now: now, calendar: calendar)
        XCTAssertNil(due)
    }

    func testLanguageDetectionSupportsAllConfiguredLocales() {
        XCTAssertEqual(AppLanguage.current(preferredLanguages: ["zh-Hans-CN"]), .zhHans)
        XCTAssertEqual(AppLanguage.current(preferredLanguages: ["zh-Hant-HK"]), .zhHant)
        XCTAssertEqual(AppLanguage.current(preferredLanguages: ["en-US"]), .en)
        XCTAssertEqual(AppLanguage.current(preferredLanguages: ["ja-JP"]), .ja)
    }

    func testLocalizedActionCompleteForFourLanguages() {
        XCTAssertEqual(AppStrings.text(.actionComplete, language: .zhHans), "完成")
        XCTAssertEqual(AppStrings.text(.actionComplete, language: .zhHant), "完成")
        XCTAssertEqual(AppStrings.text(.actionComplete, language: .en), "Done")
        XCTAssertEqual(AppStrings.text(.actionComplete, language: .ja), "完了")
    }

    func testLocalizedReminderCooldownLabelForFourLanguages() {
        XCTAssertEqual(AppStrings.text(.settingsReminderCooldown, language: .zhHans), "提醒间冷却（分钟）")
        XCTAssertEqual(AppStrings.text(.settingsReminderCooldown, language: .zhHant), "提醒間冷卻（分鐘）")
        XCTAssertEqual(AppStrings.text(.settingsReminderCooldown, language: .en), "Reminder Cooldown (minutes)")
        XCTAssertEqual(AppStrings.text(.settingsReminderCooldown, language: .ja), "リマインダー間クールダウン（分）")
    }

    func testLocalizedReminderCooldownOffForFourLanguages() {
        XCTAssertEqual(AppStrings.text(.settingsReminderCooldownOff, language: .zhHans), "关闭")
        XCTAssertEqual(AppStrings.text(.settingsReminderCooldownOff, language: .zhHant), "關閉")
        XCTAssertEqual(AppStrings.text(.settingsReminderCooldownOff, language: .en), "Off")
        XCTAssertEqual(AppStrings.text(.settingsReminderCooldownOff, language: .ja), "オフ")
    }

    func testLocalizedPetVisibilityLabelForFourLanguages() {
        XCTAssertEqual(AppStrings.text(.settingsPetShowOnlyWhenReminding, language: .zhHans), "仅在提醒时自动显示猫咪")
        XCTAssertEqual(AppStrings.text(.settingsPetShowOnlyWhenReminding, language: .zhHant), "僅在提醒時自動顯示貓咪")
        XCTAssertEqual(AppStrings.text(.settingsPetShowOnlyWhenReminding, language: .en), "Show cat only for active reminders")
        XCTAssertEqual(AppStrings.text(.settingsPetShowOnlyWhenReminding, language: .ja), "リマインダー時のみ猫を自動表示")
    }

    func testLocalizedPetAnimationLabelsForFourLanguages() {
        XCTAssertEqual(AppStrings.text(.settingsPetMotionProfile, language: .zhHans), "面板动效")
        XCTAssertEqual(AppStrings.text(.settingsPetMotionProfile, language: .zhHant), "面板動效")
        XCTAssertEqual(AppStrings.text(.settingsPetMotionProfile, language: .en), "Panel Animation")
        XCTAssertEqual(AppStrings.text(.settingsPetMotionProfile, language: .ja), "パネルアニメーション")

        XCTAssertEqual(AppStrings.text(.settingsPetMotionProfileSubtle, language: .zhHans), "极简")
        XCTAssertEqual(AppStrings.text(.settingsPetMotionProfileSubtle, language: .zhHant), "極簡")
        XCTAssertEqual(AppStrings.text(.settingsPetMotionProfileSubtle, language: .en), "Subtle")
        XCTAssertEqual(AppStrings.text(.settingsPetMotionProfileSubtle, language: .ja), "最小")

        XCTAssertEqual(AppStrings.text(.settingsPetMotionProfileVivid, language: .zhHans), "高动效")
        XCTAssertEqual(AppStrings.text(.settingsPetMotionProfileVivid, language: .zhHant), "高動效")
        XCTAssertEqual(AppStrings.text(.settingsPetMotionProfileVivid, language: .en), "Vivid")
        XCTAssertEqual(AppStrings.text(.settingsPetMotionProfileVivid, language: .ja), "高演出")

        XCTAssertEqual(AppStrings.text(.settingsPetIdleLowPowerDelay, language: .zhHans), "进入低功耗前延迟（秒）")
        XCTAssertEqual(AppStrings.text(.settingsPetIdleLowPowerDelay, language: .zhHant), "進入低功耗前延遲（秒）")
        XCTAssertEqual(AppStrings.text(.settingsPetIdleLowPowerDelay, language: .en), "Low-power delay (seconds)")
        XCTAssertEqual(AppStrings.text(.settingsPetIdleLowPowerDelay, language: .ja), "省電力移行までの遅延（秒）")
    }

    func testLocalizedVoiceAdvancedLabelForFourLanguages() {
        XCTAssertEqual(AppStrings.text(.settingsAssistantVoiceAdvanced, language: .zhHans), "高级语音参数")
        XCTAssertEqual(AppStrings.text(.settingsAssistantVoiceAdvanced, language: .zhHant), "進階語音參數")
        XCTAssertEqual(AppStrings.text(.settingsAssistantVoiceAdvanced, language: .en), "Advanced Voice Parameters")
        XCTAssertEqual(AppStrings.text(.settingsAssistantVoiceAdvanced, language: .ja), "音声の詳細設定")
    }

    func testLocalizedVoiceDeviceLabelsForFourLanguages() {
        XCTAssertEqual(AppStrings.text(.settingsAssistantVoiceInputDevice, language: .zhHans), "输入设备（麦克风）")
        XCTAssertEqual(AppStrings.text(.settingsAssistantVoiceInputDevice, language: .zhHant), "輸入裝置（麥克風）")
        XCTAssertEqual(AppStrings.text(.settingsAssistantVoiceInputDevice, language: .en), "Input Device (Microphone)")
        XCTAssertEqual(AppStrings.text(.settingsAssistantVoiceInputDevice, language: .ja), "入力デバイス（マイク）")

        XCTAssertEqual(AppStrings.text(.settingsAssistantVoiceOutputDevice, language: .zhHans), "输出设备（扬声器）")
        XCTAssertEqual(AppStrings.text(.settingsAssistantVoiceOutputDevice, language: .zhHant), "輸出裝置（喇叭）")
        XCTAssertEqual(AppStrings.text(.settingsAssistantVoiceOutputDevice, language: .en), "Output Device (Speaker)")
        XCTAssertEqual(AppStrings.text(.settingsAssistantVoiceOutputDevice, language: .ja), "出力デバイス（スピーカー）")

        XCTAssertEqual(AppStrings.text(.settingsAssistantVoiceDeviceSystemDefault, language: .zhHans), "系统默认")
        XCTAssertEqual(AppStrings.text(.settingsAssistantVoiceDeviceSystemDefault, language: .zhHant), "系統預設")
        XCTAssertEqual(AppStrings.text(.settingsAssistantVoiceDeviceSystemDefault, language: .en), "System Default")
        XCTAssertEqual(AppStrings.text(.settingsAssistantVoiceDeviceSystemDefault, language: .ja), "システムデフォルト")
    }

    func testLocalizedDiagnosticsQuickStartTitleForFourLanguages() {
        XCTAssertEqual(AppStrings.text(.diagnosticsQuickStartTitle, language: .zhHans), "快速上手（3 步）")
        XCTAssertEqual(AppStrings.text(.diagnosticsQuickStartTitle, language: .zhHant), "快速上手（3 步）")
        XCTAssertEqual(AppStrings.text(.diagnosticsQuickStartTitle, language: .en), "Quick Start (3 Steps)")
        XCTAssertEqual(AppStrings.text(.diagnosticsQuickStartTitle, language: .ja), "クイックスタート（3 ステップ）")
    }

    func testLocalizedPauseReminderLabelsForFourLanguages() {
        XCTAssertEqual(AppStrings.text(.menuPauseReminders, language: .zhHans), "暂停提醒")
        XCTAssertEqual(AppStrings.text(.menuPauseReminders, language: .zhHant), "暫停提醒")
        XCTAssertEqual(AppStrings.text(.menuPauseReminders, language: .en), "Pause Reminders")
        XCTAssertEqual(AppStrings.text(.menuPauseReminders, language: .ja), "リマインダーを一時停止")

        XCTAssertEqual(AppStrings.text(.settingsPauseAllReminders, language: .zhHans), "暂停全部提醒")
        XCTAssertEqual(AppStrings.text(.settingsPauseAllReminders, language: .zhHant), "暫停全部提醒")
        XCTAssertEqual(AppStrings.text(.settingsPauseAllReminders, language: .en), "Pause All Reminders")
        XCTAssertEqual(AppStrings.text(.settingsPauseAllReminders, language: .ja), "すべてのリマインダーを一時停止")
    }

    func testLocalizedAssistantVisibilityLabelsForFourLanguages() {
        XCTAssertEqual(AppStrings.text(.menuShowPet, language: .zhHans), "显示助手")
        XCTAssertEqual(AppStrings.text(.menuShowPet, language: .zhHant), "顯示助理")
        XCTAssertEqual(AppStrings.text(.menuShowPet, language: .en), "Show Assistant")
        XCTAssertEqual(AppStrings.text(.menuShowPet, language: .ja), "アシスタントを表示")

        XCTAssertEqual(AppStrings.text(.menuHidePet, language: .zhHans), "隐藏助手")
        XCTAssertEqual(AppStrings.text(.menuHidePet, language: .zhHant), "隱藏助理")
        XCTAssertEqual(AppStrings.text(.menuHidePet, language: .en), "Hide Assistant")
        XCTAssertEqual(AppStrings.text(.menuHidePet, language: .ja), "アシスタントを隠す")
    }

    func testLocalizedAssistantSectionLabelsForFourLanguages() {
        XCTAssertEqual(AppStrings.text(.menuAssistantEnabled, language: .zhHans), "AI 助理")
        XCTAssertEqual(AppStrings.text(.menuAssistantEnabled, language: .zhHant), "AI 助理")
        XCTAssertEqual(AppStrings.text(.menuAssistantEnabled, language: .en), "AI Assistant")
        XCTAssertEqual(AppStrings.text(.menuAssistantEnabled, language: .ja), "AI アシスタント")

        XCTAssertEqual(AppStrings.text(.settingsAssistantSection, language: .zhHans), "AI 助理")
        XCTAssertEqual(AppStrings.text(.settingsAssistantSection, language: .zhHant), "AI 助理")
        XCTAssertEqual(AppStrings.text(.settingsAssistantSection, language: .en), "AI Assistant")
        XCTAssertEqual(AppStrings.text(.settingsAssistantSection, language: .ja), "AI アシスタント")
    }

    func testLocalizedSettingsGroupLabelForFourLanguages() {
        XCTAssertEqual(AppStrings.text(.settingsGroup, language: .zhHans), "设置分组")
        XCTAssertEqual(AppStrings.text(.settingsGroup, language: .zhHant), "設定分組")
        XCTAssertEqual(AppStrings.text(.settingsGroup, language: .en), "Settings Group")
        XCTAssertEqual(AppStrings.text(.settingsGroup, language: .ja), "設定グループ")
    }

    func testLocalizedAssistantGatewayLabelsForFourLanguages() {
        XCTAssertEqual(AppStrings.text(.settingsAssistantGatewayURL, language: .zhHans), "Gateway 地址")
        XCTAssertEqual(AppStrings.text(.settingsAssistantGatewayURL, language: .zhHant), "Gateway 位址")
        XCTAssertEqual(AppStrings.text(.settingsAssistantGatewayURL, language: .en), "Gateway URL")
        XCTAssertEqual(AppStrings.text(.settingsAssistantGatewayURL, language: .ja), "Gateway URL")
    }

    func testLocalizedAssistantChatLabelsForFourLanguages() {
        XCTAssertEqual(AppStrings.text(.menuAssistantChat, language: .zhHans), "打开 AI 对话")
        XCTAssertEqual(AppStrings.text(.menuAssistantChat, language: .zhHant), "開啟 AI 對話")
        XCTAssertEqual(AppStrings.text(.menuAssistantChat, language: .en), "Open AI Chat")
        XCTAssertEqual(AppStrings.text(.menuAssistantChat, language: .ja), "AI 会話を開く")

        XCTAssertEqual(AppStrings.text(.assistantChatSend, language: .zhHans), "发送")
        XCTAssertEqual(AppStrings.text(.assistantChatSend, language: .zhHant), "送出")
        XCTAssertEqual(AppStrings.text(.assistantChatSend, language: .en), "Send")
        XCTAssertEqual(AppStrings.text(.assistantChatSend, language: .ja), "送信")

        XCTAssertEqual(AppStrings.text(.assistantChatSpeakLatest, language: .zhHans), "播报最新回复")
        XCTAssertEqual(AppStrings.text(.assistantChatSpeakLatest, language: .zhHant), "播報最新回覆")
        XCTAssertEqual(AppStrings.text(.assistantChatSpeakLatest, language: .en), "Speak Last Reply")
        XCTAssertEqual(AppStrings.text(.assistantChatSpeakLatest, language: .ja), "最新応答を読み上げ")

        XCTAssertEqual(AppStrings.text(.assistantChatVoiceInput, language: .zhHans), "语音输入")
        XCTAssertEqual(AppStrings.text(.assistantChatVoiceInput, language: .zhHant), "語音輸入")
        XCTAssertEqual(AppStrings.text(.assistantChatVoiceInput, language: .en), "Voice Input")
        XCTAssertEqual(AppStrings.text(.assistantChatVoiceInput, language: .ja), "音声入力")

        XCTAssertEqual(AppStrings.text(.menuDiagnostics, language: .zhHans), "环境诊断…")
        XCTAssertEqual(AppStrings.text(.menuDiagnostics, language: .zhHant), "環境診斷…")
        XCTAssertEqual(AppStrings.text(.menuDiagnostics, language: .en), "Environment Diagnostics…")
        XCTAssertEqual(AppStrings.text(.menuDiagnostics, language: .ja), "環境診断…")

        XCTAssertEqual(AppStrings.text(.diagnosticsGuideTitle, language: .zhHans), "首次运行诊断")
        XCTAssertEqual(AppStrings.text(.diagnosticsGuideTitle, language: .zhHant), "首次執行診斷")
        XCTAssertEqual(AppStrings.text(.diagnosticsGuideTitle, language: .en), "First-Run Diagnostics")
        XCTAssertEqual(AppStrings.text(.diagnosticsGuideTitle, language: .ja), "初回起動診断")

        XCTAssertEqual(AppStrings.text(.diagnosticsDetailConnectionFailed, language: .zhHans), "连接失败")
        XCTAssertEqual(AppStrings.text(.diagnosticsDetailConnectionFailed, language: .zhHant), "連線失敗")
        XCTAssertEqual(AppStrings.text(.diagnosticsDetailConnectionFailed, language: .en), "Connection failed")
        XCTAssertEqual(AppStrings.text(.diagnosticsDetailConnectionFailed, language: .ja), "接続失敗")

        XCTAssertEqual(AppStrings.text(.settingsAssistantVoiceSection, language: .zhHans), "本地语音（CosyVoice）")
        XCTAssertEqual(AppStrings.text(.settingsAssistantVoiceSection, language: .zhHant), "本機語音（CosyVoice）")
        XCTAssertEqual(AppStrings.text(.settingsAssistantVoiceSection, language: .en), "Local Voice (CosyVoice)")
        XCTAssertEqual(AppStrings.text(.settingsAssistantVoiceSection, language: .ja), "ローカル音声（CosyVoice）")

        XCTAssertEqual(AppStrings.text(.settingsAssistantVoiceSTTCommand, language: .zhHans), "Whisper 命令")
        XCTAssertEqual(AppStrings.text(.settingsAssistantVoiceSTTCommand, language: .zhHant), "Whisper 指令")
        XCTAssertEqual(AppStrings.text(.settingsAssistantVoiceSTTCommand, language: .en), "Whisper command")
        XCTAssertEqual(AppStrings.text(.settingsAssistantVoiceSTTCommand, language: .ja), "Whisper コマンド")
    }
}
