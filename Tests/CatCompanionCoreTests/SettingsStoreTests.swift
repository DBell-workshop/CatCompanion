import XCTest
@testable import CatCompanionCore

final class SettingsStoreTests: XCTestCase {
    func testPersistsUpdatedSettings() {
        let suiteName = "CatCompanion.SettingsStoreTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create isolated UserDefaults suite")
            return
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
            KeychainHelper.delete(forKey: "gatewayToken")
        }

        let store = SettingsStore(userDefaults: defaults)
        var settings = store.settings
        var hydratePlan = settings.plans[.hydrate] ?? ReminderPlan(enabled: true, intervalMinutes: 60, quietHours: QuietHours(), snoozeMinutes: 15)
        hydratePlan.intervalMinutes = 30
        settings.plans[.hydrate] = hydratePlan
        settings.notificationsEnabled = true
        settings.remindersPaused = true
        settings.petShowOnlyWhenReminding = false
        settings.petMotionProfile = .subtle
        settings.petIdleLowPowerEnabled = false
        settings.petIdleLowPowerDelaySeconds = 20
        settings.interReminderCooldownMinutes = 3
        settings.assistant.enabled = true
        settings.assistant.routeStrategy = .localOnly
        settings.assistant.cloudPrimaryModel = "test/cloud-model"
        settings.assistant.localFallbackModel = "test/local-model"
        settings.assistant.gatewayURL = "ws://127.0.0.1:19999"
        settings.assistant.gatewayToken = "test-token"
        settings.assistant.gatewaySessionKey = "dev"
        settings.assistant.voiceSettings.voiceInputDeviceUID = "test-input-device"
        settings.assistant.voiceSettings.voiceOutputDeviceUID = "test-output-device"
        settings.assistant.skillPolicy.thirdPartySkillsEnabled = false
        store.settings = settings

        let reloaded = SettingsStore(userDefaults: defaults)
        XCTAssertEqual(reloaded.settings.plans[.hydrate]?.intervalMinutes, 30)
        XCTAssertTrue(reloaded.settings.notificationsEnabled)
        XCTAssertTrue(reloaded.settings.remindersPaused)
        XCTAssertFalse(reloaded.settings.petShowOnlyWhenReminding)
        XCTAssertEqual(reloaded.settings.petMotionProfile, .subtle)
        XCTAssertFalse(reloaded.settings.petIdleLowPowerEnabled)
        XCTAssertEqual(reloaded.settings.petIdleLowPowerDelaySeconds, 20)
        XCTAssertEqual(reloaded.settings.interReminderCooldownMinutes, 3)
        XCTAssertTrue(reloaded.settings.assistant.enabled)
        XCTAssertEqual(reloaded.settings.assistant.routeStrategy, .localOnly)
        XCTAssertEqual(reloaded.settings.assistant.cloudPrimaryModel, "test/cloud-model")
        XCTAssertEqual(reloaded.settings.assistant.localFallbackModel, "test/local-model")
        XCTAssertEqual(reloaded.settings.assistant.gatewayURL, "ws://127.0.0.1:19999")
        XCTAssertEqual(reloaded.settings.assistant.gatewayToken, "test-token")
        XCTAssertEqual(reloaded.settings.assistant.gatewaySessionKey, "dev")
        XCTAssertEqual(reloaded.settings.assistant.voiceSettings.voiceInputDeviceUID, "test-input-device")
        XCTAssertEqual(reloaded.settings.assistant.voiceSettings.voiceOutputDeviceUID, "test-output-device")
        XCTAssertFalse(reloaded.settings.assistant.skillPolicy.thirdPartySkillsEnabled)

        // Verify token is stored in Keychain, not in UserDefaults JSON
        XCTAssertEqual(KeychainHelper.load(forKey: "gatewayToken"), "test-token")
    }

    func testResetRestoresDefaultSettings() {
        let suiteName = "CatCompanion.SettingsStoreTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create isolated UserDefaults suite")
            return
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
            KeychainHelper.delete(forKey: "gatewayToken")
        }

        let store = SettingsStore(userDefaults: defaults)
        var settings = store.settings
        var standPlan = settings.plans[.stand] ?? ReminderPlan(enabled: true, intervalMinutes: 90, quietHours: QuietHours(), snoozeMinutes: 20)
        standPlan.intervalMinutes = 120
        settings.plans[.stand] = standPlan
        settings.petAlwaysOnTop = false
        store.settings = settings

        store.reset()

        XCTAssertEqual(store.settings, AppSettings.defaults())
    }

    func testLoadsLegacyPayloadWithoutCooldownOrPauseField() throws {
        let suiteName = "CatCompanion.SettingsStoreTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create isolated UserDefaults suite")
            return
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let fullData = try encoder.encode(AppSettings.defaults())

        guard var legacyObject = try JSONSerialization.jsonObject(with: fullData) as? [String: Any] else {
            XCTFail("Failed to build legacy payload object")
            return
        }
        legacyObject.removeValue(forKey: "remindersPaused")
        legacyObject.removeValue(forKey: "interReminderCooldownMinutes")
        legacyObject.removeValue(forKey: "assistant")
        let legacyData = try JSONSerialization.data(withJSONObject: legacyObject, options: [.prettyPrinted, .sortedKeys])
        defaults.set(legacyData, forKey: "CatCompanion.Settings")

        let store = SettingsStore(userDefaults: defaults)
        XCTAssertEqual(store.settings.remindersPaused, AppSettings.defaults().remindersPaused)
        XCTAssertEqual(
            store.settings.interReminderCooldownMinutes,
            AppSettings.defaults().interReminderCooldownMinutes
        )
        XCTAssertEqual(store.settings.assistant, AppSettings.defaults().assistant)
        XCTAssertEqual(
            store.settings.petShowOnlyWhenReminding,
            AppSettings.defaults().petShowOnlyWhenReminding
        )
        XCTAssertEqual(
            store.settings.petMotionProfile,
            AppSettings.defaults().petMotionProfile
        )
        XCTAssertEqual(
            store.settings.petIdleLowPowerEnabled,
            AppSettings.defaults().petIdleLowPowerEnabled
        )
        XCTAssertEqual(
            store.settings.petIdleLowPowerDelaySeconds,
            AppSettings.defaults().petIdleLowPowerDelaySeconds
        )
    }

    func testLoadsLegacyPayloadWithoutPetShowOnlyWhenRemindingField() throws {
        let suiteName = "CatCompanion.SettingsStoreTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create isolated UserDefaults suite")
            return
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let fullData = try encoder.encode(AppSettings.defaults())

        guard var legacyObject = try JSONSerialization.jsonObject(with: fullData) as? [String: Any] else {
            XCTFail("Failed to build legacy payload object")
            return
        }
        legacyObject.removeValue(forKey: "petShowOnlyWhenReminding")
        let legacyData = try JSONSerialization.data(withJSONObject: legacyObject, options: [.prettyPrinted, .sortedKeys])
        defaults.set(legacyData, forKey: "CatCompanion.Settings")

        let store = SettingsStore(userDefaults: defaults)
        XCTAssertEqual(
            store.settings.petShowOnlyWhenReminding,
            AppSettings.defaults().petShowOnlyWhenReminding
        )
    }

    func testLoadsLegacyPayloadWithoutPetMotionFields() throws {
        let suiteName = "CatCompanion.SettingsStoreTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create isolated UserDefaults suite")
            return
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let fullData = try encoder.encode(AppSettings.defaults())

        guard var legacyObject = try JSONSerialization.jsonObject(with: fullData) as? [String: Any] else {
            XCTFail("Failed to build legacy payload object")
            return
        }
        legacyObject.removeValue(forKey: "petMotionProfile")
        legacyObject.removeValue(forKey: "petIdleLowPowerEnabled")
        legacyObject.removeValue(forKey: "petIdleLowPowerDelaySeconds")
        let legacyData = try JSONSerialization.data(withJSONObject: legacyObject, options: [.prettyPrinted, .sortedKeys])
        defaults.set(legacyData, forKey: "CatCompanion.Settings")

        let store = SettingsStore(userDefaults: defaults)
        XCTAssertEqual(store.settings.petMotionProfile, AppSettings.defaults().petMotionProfile)
        XCTAssertEqual(store.settings.petIdleLowPowerEnabled, AppSettings.defaults().petIdleLowPowerEnabled)
        XCTAssertEqual(
            store.settings.petIdleLowPowerDelaySeconds,
            AppSettings.defaults().petIdleLowPowerDelaySeconds
        )
    }

    func testAssistantDefaultsCloudPreferredAndThirdPartySkillsDisabled() {
        let defaults = AppSettings.defaults().assistant
        XCTAssertEqual(defaults.routeStrategy, .cloudPreferred)
        XCTAssertEqual(defaults.cloudPrimaryModel, "openai-codex/gpt-5.3-codex")
        XCTAssertEqual(defaults.localFallbackModel, "ollama/qwen2.5-coder:14b")
        XCTAssertEqual(defaults.gatewayURL, "ws://127.0.0.1:18789")
        XCTAssertEqual(defaults.gatewayToken, "")
        XCTAssertEqual(defaults.gatewaySessionKey, "main")
        XCTAssertFalse(defaults.skillPolicy.thirdPartySkillsEnabled)
        XCTAssertTrue(defaults.skillPolicy.allowedSkillIDs.isEmpty)
        XCTAssertTrue(defaults.actionScope.allowReadOnlyActions)
        XCTAssertTrue(defaults.actionScope.allowFileActions)
        XCTAssertTrue(defaults.actionScope.allowTerminalActions)
        XCTAssertTrue(defaults.actionScope.allowBrowserActions)
        XCTAssertFalse(defaults.voiceSettings.enabled)
        XCTAssertTrue(defaults.voiceSettings.autoSpeakAssistantReplies)
        XCTAssertEqual(defaults.voiceSettings.voiceInputDeviceUID, "")
        XCTAssertEqual(defaults.voiceSettings.voiceOutputDeviceUID, "")
        XCTAssertEqual(defaults.voiceSettings.pythonCommand, "python3")
        XCTAssertEqual(defaults.voiceSettings.cosyVoiceModel, "iic/CosyVoice2-0.5B")
        XCTAssertEqual(defaults.voiceSettings.cosyVoiceSpeaker, "")
        XCTAssertEqual(defaults.voiceSettings.whisperCommand, "whisper-cli")
        XCTAssertEqual(defaults.voiceSettings.whisperModelPath, "")
        XCTAssertEqual(defaults.voiceSettings.whisperLanguage, "auto")
    }

    func testLoadsLegacyAssistantWithoutGatewayFields() throws {
        let suiteName = "CatCompanion.SettingsStoreTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create isolated UserDefaults suite")
            return
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let fullData = try encoder.encode(AppSettings.defaults())

        guard var rootObject = try JSONSerialization.jsonObject(with: fullData) as? [String: Any] else {
            XCTFail("Failed to decode settings JSON")
            return
        }
        guard var assistant = rootObject["assistant"] as? [String: Any] else {
            XCTFail("Missing assistant object")
            return
        }
        assistant.removeValue(forKey: "gatewayURL")
        assistant.removeValue(forKey: "gatewayToken")
        assistant.removeValue(forKey: "gatewaySessionKey")
        assistant.removeValue(forKey: "voiceSettings")
        rootObject["assistant"] = assistant

        let legacyData = try JSONSerialization.data(withJSONObject: rootObject, options: [.prettyPrinted, .sortedKeys])
        defaults.set(legacyData, forKey: "CatCompanion.Settings")

        let store = SettingsStore(userDefaults: defaults)
        XCTAssertEqual(store.settings.assistant.gatewayURL, AppSettings.defaults().assistant.gatewayURL)
        XCTAssertEqual(store.settings.assistant.gatewayToken, AppSettings.defaults().assistant.gatewayToken)
        XCTAssertEqual(store.settings.assistant.gatewaySessionKey, AppSettings.defaults().assistant.gatewaySessionKey)
        XCTAssertEqual(store.settings.assistant.voiceSettings, AppSettings.defaults().assistant.voiceSettings)
    }

    func testMigratesLegacyGatewayTokenToKeychain() throws {
        let suiteName = "CatCompanion.SettingsStoreTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create isolated UserDefaults suite")
            return
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
            KeychainHelper.delete(forKey: "gatewayToken")
        }

        // Ensure Keychain is clean before test
        KeychainHelper.delete(forKey: "gatewayToken")

        // Build a legacy JSON payload that still contains gatewayToken inline
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        var legacySettings = AppSettings.defaults()
        legacySettings.assistant.gatewayToken = "legacy-secret-token"

        // Manually encode with token included (simulating old format)
        let fullData = try encoder.encode(legacySettings)
        guard var rootObject = try JSONSerialization.jsonObject(with: fullData) as? [String: Any] else {
            XCTFail("Failed to decode settings JSON")
            return
        }
        // Re-inject token into assistant JSON (old format stored it here)
        if var assistant = rootObject["assistant"] as? [String: Any] {
            assistant["gatewayToken"] = "legacy-secret-token"
            rootObject["assistant"] = assistant
        }
        let legacyData = try JSONSerialization.data(withJSONObject: rootObject, options: [.prettyPrinted, .sortedKeys])
        defaults.set(legacyData, forKey: "CatCompanion.Settings")

        // Load should migrate the token to Keychain
        let store = SettingsStore(userDefaults: defaults)
        XCTAssertEqual(store.settings.assistant.gatewayToken, "legacy-secret-token")
        XCTAssertEqual(KeychainHelper.load(forKey: "gatewayToken"), "legacy-secret-token")
    }

    func testLoadsLegacyVoiceSettingsWithoutWhisperFields() throws {
        let suiteName = "CatCompanion.SettingsStoreTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create isolated UserDefaults suite")
            return
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let fullData = try encoder.encode(AppSettings.defaults())

        guard var rootObject = try JSONSerialization.jsonObject(with: fullData) as? [String: Any] else {
            XCTFail("Failed to decode settings JSON")
            return
        }
        guard var assistant = rootObject["assistant"] as? [String: Any] else {
            XCTFail("Missing assistant object")
            return
        }
        guard var voiceSettings = assistant["voiceSettings"] as? [String: Any] else {
            XCTFail("Missing voiceSettings object")
            return
        }
        voiceSettings.removeValue(forKey: "whisperCommand")
        voiceSettings.removeValue(forKey: "whisperModelPath")
        voiceSettings.removeValue(forKey: "whisperLanguage")
        voiceSettings.removeValue(forKey: "voiceInputDeviceUID")
        voiceSettings.removeValue(forKey: "voiceOutputDeviceUID")
        assistant["voiceSettings"] = voiceSettings
        rootObject["assistant"] = assistant

        let legacyData = try JSONSerialization.data(withJSONObject: rootObject, options: [.prettyPrinted, .sortedKeys])
        defaults.set(legacyData, forKey: "CatCompanion.Settings")

        let store = SettingsStore(userDefaults: defaults)
        XCTAssertEqual(
            store.settings.assistant.voiceSettings.whisperCommand,
            AppSettings.defaults().assistant.voiceSettings.whisperCommand
        )
        XCTAssertEqual(
            store.settings.assistant.voiceSettings.whisperModelPath,
            AppSettings.defaults().assistant.voiceSettings.whisperModelPath
        )
        XCTAssertEqual(
            store.settings.assistant.voiceSettings.whisperLanguage,
            AppSettings.defaults().assistant.voiceSettings.whisperLanguage
        )
        XCTAssertEqual(
            store.settings.assistant.voiceSettings.voiceInputDeviceUID,
            AppSettings.defaults().assistant.voiceSettings.voiceInputDeviceUID
        )
        XCTAssertEqual(
            store.settings.assistant.voiceSettings.voiceOutputDeviceUID,
            AppSettings.defaults().assistant.voiceSettings.voiceOutputDeviceUID
        )
    }
}
