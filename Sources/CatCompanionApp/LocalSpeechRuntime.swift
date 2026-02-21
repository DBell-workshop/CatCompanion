import Foundation
import AVFoundation
import CatCompanionCore

enum LocalSpeechRuntimeError: Error {
    case scriptNotFound
    case outputMissing
    case outputDeviceMissing
    case processFailed(code: Int32, message: String)
    case playbackFailed
    case cancelled

    var message: String {
        switch self {
        case .scriptNotFound:
            return "cosyvoice_script_not_found"
        case .outputMissing:
            return "speech_output_missing"
        case .outputDeviceMissing:
            return "speech_output_device_missing"
        case .processFailed(let code, let message):
            if message.isEmpty {
                return "speech_process_failed:\(code)"
            }
            return "speech_process_failed:\(code):\(message)"
        case .playbackFailed:
            return "speech_playback_failed"
        case .cancelled:
            return "speech_cancelled"
        }
    }
}

@MainActor
final class LocalSpeechRuntime: NSObject {
    private var player: AVAudioPlayer?
    private var meterTask: Task<Void, Never>?
    private var playbackContinuation: CheckedContinuation<Void, Error>?
    private var activeAudioURL: URL?
    private var shouldRemoveActiveAudioURL = false
    var onPlaybackLevelChanged: ((Double) -> Void)?

    func stop() {
        stopMeterUpdates()
        player?.stop()
        player = nil
        if let continuation = playbackContinuation {
            playbackContinuation = nil
            continuation.resume(throwing: LocalSpeechRuntimeError.cancelled)
        }
        if let activeAudioURL {
            if shouldRemoveActiveAudioURL {
                try? FileManager.default.removeItem(at: activeAudioURL)
            }
            self.activeAudioURL = nil
            shouldRemoveActiveAudioURL = false
        }
    }

    func speak(text: String, voiceSettings: AssistantVoiceSettings) async throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let scriptURL = try resolveScriptPath(configuredPath: voiceSettings.cosyVoiceScriptPath)
        let outputURL = try await synthesize(
            text: trimmed,
            scriptURL: scriptURL,
            pythonCommand: voiceSettings.pythonCommand,
            model: voiceSettings.cosyVoiceModel,
            speaker: voiceSettings.cosyVoiceSpeaker
        )
        try await playAudioAndWait(
            outputURL,
            outputDeviceUID: voiceSettings.voiceOutputDeviceUID,
            removeAfterPlayback: true
        )
    }

    func testOutputDevice(voiceSettings: AssistantVoiceSettings) async throws {
        let candidatePaths = [
            "/System/Library/Sounds/Glass.aiff",
            "/System/Library/Sounds/Funk.aiff",
            "/System/Library/Sounds/Ping.aiff"
        ]
        guard let soundPath = candidatePaths.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            throw LocalSpeechRuntimeError.outputMissing
        }
        try await playAudioAndWait(
            URL(fileURLWithPath: soundPath),
            outputDeviceUID: voiceSettings.voiceOutputDeviceUID,
            removeAfterPlayback: false
        )
    }

    private func finishPlayback(successfully: Bool) {
        if let continuation = playbackContinuation {
            playbackContinuation = nil
            if successfully {
                continuation.resume()
            } else {
                continuation.resume(throwing: LocalSpeechRuntimeError.playbackFailed)
            }
        }
        cleanupAfterPlayback()
    }

    private func finishPlayback(error: Error) {
        if let continuation = playbackContinuation {
            playbackContinuation = nil
            continuation.resume(throwing: error)
        }
        cleanupAfterPlayback()
    }

    private func cleanupAfterPlayback() {
        stopMeterUpdates()
        player = nil
        if let activeAudioURL {
            if shouldRemoveActiveAudioURL {
                try? FileManager.default.removeItem(at: activeAudioURL)
            }
            self.activeAudioURL = nil
            shouldRemoveActiveAudioURL = false
        }
    }

    private func resolveScriptPath(configuredPath: String) throws -> URL {
        let fileManager = FileManager.default
        let trimmed = configuredPath.trimmingCharacters(in: .whitespacesAndNewlines)

        if !trimmed.isEmpty, fileManager.isReadableFile(atPath: trimmed) {
            return URL(fileURLWithPath: trimmed)
        }

        if let environmentPath = ProcessInfo.processInfo.environment["CATCOMPANION_COSYVOICE_SCRIPT"],
           fileManager.isReadableFile(atPath: environmentPath) {
            return URL(fileURLWithPath: environmentPath)
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

        for candidate in candidates where fileManager.isReadableFile(atPath: candidate.path) {
            return candidate.standardizedFileURL
        }

        throw LocalSpeechRuntimeError.scriptNotFound
    }

    private func synthesize(
        text: String,
        scriptURL: URL,
        pythonCommand: String,
        model: String,
        speaker: String
    ) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let outputURL = try Self.runSynthesisProcess(
                        text: text,
                        scriptURL: scriptURL,
                        pythonCommand: pythonCommand,
                        model: model,
                        speaker: speaker
                    )
                    continuation.resume(returning: outputURL)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private nonisolated static func runSynthesisProcess(
        text: String,
        scriptURL: URL,
        pythonCommand: String,
        model: String,
        speaker: String
    ) throws -> URL {
        let outputURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("catcompanion-tts-\(UUID().uuidString).wav")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")

        let python = pythonCommand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "python3"
            : pythonCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        let modelID = model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "iic/CosyVoice2-0.5B"
            : model.trimmingCharacters(in: .whitespacesAndNewlines)

        var arguments = [
            python,
            scriptURL.path,
            "--text", text,
            "--output", outputURL.path,
            "--model", modelID
        ]
        let speakerName = speaker.trimmingCharacters(in: .whitespacesAndNewlines)
        if !speakerName.isEmpty {
            arguments.append(contentsOf: ["--speaker", speakerName])
        }

        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice

        let stderrPipe = Pipe()
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrMessage = String(data: stderrData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard process.terminationStatus == 0 else {
            throw LocalSpeechRuntimeError.processFailed(code: process.terminationStatus, message: stderrMessage)
        }

        guard FileManager.default.fileExists(atPath: outputURL.path) else {
            throw LocalSpeechRuntimeError.outputMissing
        }

        return outputURL
    }

    private func playAudioAndWait(
        _ audioURL: URL,
        outputDeviceUID: String,
        removeAfterPlayback: Bool
    ) async throws {
        stop()

        let player = try AVAudioPlayer(contentsOf: audioURL)
        let targetUID = outputDeviceUID.trimmingCharacters(in: .whitespacesAndNewlines)
        if !targetUID.isEmpty {
            player.currentDevice = targetUID
            guard player.currentDevice == targetUID else {
                throw LocalSpeechRuntimeError.outputDeviceMissing
            }
        }
        player.delegate = self
        player.isMeteringEnabled = true
        self.player = player
        self.activeAudioURL = audioURL
        self.shouldRemoveActiveAudioURL = removeAfterPlayback

        guard player.prepareToPlay(), player.play() else {
            throw LocalSpeechRuntimeError.playbackFailed
        }
        startMeterUpdates()

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                playbackContinuation = continuation
            }
        } onCancel: {
            Task { @MainActor in
                self.stop()
            }
        }
    }

    private func startMeterUpdates() {
        stopMeterUpdates()
        onPlaybackLevelChanged?(0)
        meterTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                if let player = self.player, player.isPlaying {
                    player.updateMeters()
                    let level = Self.normalizedMeterLevel(power: player.averagePower(forChannel: 0))
                    self.onPlaybackLevelChanged?(level)
                }
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
        }
    }

    private func stopMeterUpdates() {
        meterTask?.cancel()
        meterTask = nil
        onPlaybackLevelChanged?(0)
    }

    private static func normalizedMeterLevel(power: Float) -> Double {
        guard power.isFinite else { return 0 }
        if power <= -80 {
            return 0
        }
        let linear = pow(10.0, Double(power) / 20.0)
        let boosted = sqrt(linear)
        return min(1, max(0, boosted))
    }
}

extension LocalSpeechRuntime: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.finishPlayback(successfully: flag)
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            self.finishPlayback(error: error ?? LocalSpeechRuntimeError.playbackFailed)
        }
    }
}

enum LocalTranscriptionRuntimeError: Error {
    case microphonePermissionDenied
    case inputDeviceMissing
    case inputDeviceNotFound
    case recordStartFailed
    case recordStopFailed(String)
    case missingRecording
    case whisperModelPathMissing
    case whisperModelNotFound
    case recordingConvertFailed(Int32, String)
    case processFailed(code: Int32, message: String)
    case transcriptMissing
    case cancelled

    var message: String {
        switch self {
        case .microphonePermissionDenied:
            return "microphone_permission_denied"
        case .inputDeviceMissing:
            return "voice_input_device_missing"
        case .inputDeviceNotFound:
            return "voice_input_device_not_found"
        case .recordStartFailed:
            return "voice_record_start_failed"
        case .recordStopFailed(let message):
            if message.isEmpty {
                return "voice_record_stop_failed"
            }
            return "voice_record_stop_failed:\(message)"
        case .missingRecording:
            return "voice_record_missing"
        case .whisperModelPathMissing:
            return "whisper_model_missing"
        case .whisperModelNotFound:
            return "whisper_model_not_found"
        case .recordingConvertFailed(let code, let message):
            if message.isEmpty {
                return "voice_record_convert_failed:\(code)"
            }
            return "voice_record_convert_failed:\(code):\(message)"
        case .processFailed(let code, let message):
            if message.isEmpty {
                return "voice_transcribe_failed:\(code)"
            }
            return "voice_transcribe_failed:\(code):\(message)"
        case .transcriptMissing:
            return "voice_transcript_missing"
        case .cancelled:
            return "voice_transcription_cancelled"
        }
    }
}

@MainActor
final class LocalTranscriptionRuntime: NSObject {
    private var captureSession: AVCaptureSession?
    private var captureOutput: AVCaptureAudioFileOutput?
    private var activeRecordingURL: URL?
    private var stopRecordingContinuation: CheckedContinuation<URL, Error>?
    private var cancelRequested = false

    var isRecording: Bool {
        captureOutput?.isRecording == true
    }

    func startRecording(voiceSettings: AssistantVoiceSettings) async throws {
        guard !isRecording else { return }
        guard await hasMicrophonePermission() else {
            throw LocalTranscriptionRuntimeError.microphonePermissionDenied
        }

        let inputDevice = try resolveInputDevice(uid: voiceSettings.voiceInputDeviceUID)
        let session = AVCaptureSession()
        session.beginConfiguration()

        let input = try AVCaptureDeviceInput(device: inputDevice)
        guard session.canAddInput(input) else {
            throw LocalTranscriptionRuntimeError.recordStartFailed
        }
        session.addInput(input)

        let output = AVCaptureAudioFileOutput()
        guard session.canAddOutput(output) else {
            throw LocalTranscriptionRuntimeError.recordStartFailed
        }
        session.addOutput(output)
        session.commitConfiguration()

        let supportsWav = AVCaptureAudioFileOutput.availableOutputFileTypes().contains(.wav)
        let fileType: AVFileType = supportsWav ? .wav : .caf
        let fileExtension = supportsWav ? "wav" : "caf"
        let recordingURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("catcompanion-stt-\(UUID().uuidString).\(fileExtension)")

        session.startRunning()
        output.startRecording(to: recordingURL, outputFileType: fileType, recordingDelegate: self)
        if !output.isRecording {
            session.stopRunning()
            throw LocalTranscriptionRuntimeError.recordStartFailed
        }

        self.captureSession = session
        self.captureOutput = output
        self.activeRecordingURL = recordingURL
        self.cancelRequested = false
    }

    func stopAndTranscribe(voiceSettings: AssistantVoiceSettings) async throws -> String {
        let recordingURL = try await stopCaptureRecording()

        defer {
            try? FileManager.default.removeItem(at: recordingURL)
            if activeRecordingURL == recordingURL {
                activeRecordingURL = nil
            }
        }

        return try await transcribe(recordingURL: recordingURL, voiceSettings: voiceSettings)
    }

    func probeInput(voiceSettings: AssistantVoiceSettings, durationSeconds: Double = 1.2) async throws {
        try await startRecording(voiceSettings: voiceSettings)
        try await Task.sleep(nanoseconds: UInt64((durationSeconds * 1_000_000_000).rounded()))
        let recordingURL = try await stopCaptureRecording()
        defer { try? FileManager.default.removeItem(at: recordingURL) }

        let attributes = try FileManager.default.attributesOfItem(atPath: recordingURL.path)
        let fileSize = (attributes[.size] as? NSNumber)?.intValue ?? 0
        // WAV header is 44 bytes; anything above this means audio frames were written.
        guard fileSize > 44 else {
            throw LocalTranscriptionRuntimeError.recordStopFailed("empty_capture")
        }
    }

    func cancel() {
        cancelRequested = true
        if let continuation = stopRecordingContinuation {
            stopRecordingContinuation = nil
            continuation.resume(throwing: LocalTranscriptionRuntimeError.cancelled)
        }
        if let output = captureOutput, output.isRecording {
            output.stopRecording()
        }
        teardownCapture()
        cleanupRecording()
    }

    private func cleanupRecording() {
        if let activeRecordingURL {
            try? FileManager.default.removeItem(at: activeRecordingURL)
            self.activeRecordingURL = nil
        }
    }

    private func stopCaptureRecording() async throws -> URL {
        guard let output = captureOutput, output.isRecording else {
            throw LocalTranscriptionRuntimeError.missingRecording
        }
        let recordedURL = try await withCheckedThrowingContinuation { continuation in
            stopRecordingContinuation = continuation
            output.stopRecording()
        }
        teardownCapture()
        activeRecordingURL = recordedURL
        return recordedURL
    }

    private func teardownCapture() {
        if let session = captureSession, session.isRunning {
            session.stopRunning()
        }
        captureOutput = nil
        captureSession = nil
    }

    private func resolveInputDevice(uid: String) throws -> AVCaptureDevice {
        let trimmed = uid.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            guard let specific = AVCaptureDevice(uniqueID: trimmed) else {
                throw LocalTranscriptionRuntimeError.inputDeviceNotFound
            }
            return specific
        }
        guard let fallback = AVCaptureDevice.default(for: .audio) else {
            throw LocalTranscriptionRuntimeError.inputDeviceMissing
        }
        return fallback
    }

    private func hasMicrophonePermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    continuation.resume(returning: granted)
                }
            }
        case .restricted, .denied:
            return false
        @unknown default:
            return false
        }
    }

    private func transcribe(
        recordingURL: URL,
        voiceSettings: AssistantVoiceSettings
    ) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let text = try Self.runTranscriptionProcess(
                        recordingURL: recordingURL,
                        voiceSettings: voiceSettings
                    )
                    continuation.resume(returning: text)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private nonisolated static func runTranscriptionProcess(
        recordingURL: URL,
        voiceSettings: AssistantVoiceSettings
    ) throws -> String {
        let fileManager = FileManager.default
        let trimmedModelPath = voiceSettings.whisperModelPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedModelPath.isEmpty else {
            throw LocalTranscriptionRuntimeError.whisperModelPathMissing
        }
        guard fileManager.fileExists(atPath: trimmedModelPath) else {
            throw LocalTranscriptionRuntimeError.whisperModelNotFound
        }

        let whisperCommand = voiceSettings.whisperCommand
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedCommand = whisperCommand.isEmpty ? "whisper-cli" : whisperCommand

        let whisperInputURL = try convertToWavIfNeeded(recordingURL: recordingURL)
        defer {
            if whisperInputURL != recordingURL {
                try? fileManager.removeItem(at: whisperInputURL)
            }
        }

        let outputPrefix = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("catcompanion-stt-\(UUID().uuidString)")
        let outputTextURL = URL(fileURLWithPath: outputPrefix.path + ".txt")

        var arguments = [
            resolvedCommand,
            "-m", trimmedModelPath,
            "-f", whisperInputURL.path,
            "-otxt",
            "-of", outputPrefix.path
        ]
        let language = voiceSettings.whisperLanguage.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !language.isEmpty, language != "auto" {
            arguments.append(contentsOf: ["-l", language])
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrMessage = String(data: stderrData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        defer {
            try? fileManager.removeItem(at: outputTextURL)
        }

        guard process.terminationStatus == 0 else {
            throw LocalTranscriptionRuntimeError.processFailed(code: process.terminationStatus, message: stderrMessage)
        }

        if let content = try? String(contentsOf: outputTextURL, encoding: .utf8) {
            let cleaned = content
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleaned.isEmpty {
                return cleaned
            }
        }

        let fallback = String(data: stdoutData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !fallback.isEmpty {
            return fallback
        }

        throw LocalTranscriptionRuntimeError.transcriptMissing
    }

    private nonisolated static func convertToWavIfNeeded(recordingURL: URL) throws -> URL {
        if recordingURL.pathExtension.lowercased() == "wav" {
            return recordingURL
        }

        let convertedURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("catcompanion-stt-converted-\(UUID().uuidString).wav")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/afconvert")
        process.arguments = [
            recordingURL.path,
            convertedURL.path,
            "-f", "WAVE",
            "-d", "LEI16@16000",
            "-c", "1"
        ]
        let stderrPipe = Pipe()
        process.standardError = stderrPipe
        process.standardOutput = FileHandle.nullDevice

        try process.run()
        process.waitUntilExit()

        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrMessage = String(data: stderrData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard process.terminationStatus == 0 else {
            throw LocalTranscriptionRuntimeError.recordingConvertFailed(
                process.terminationStatus,
                stderrMessage
            )
        }
        guard FileManager.default.fileExists(atPath: convertedURL.path) else {
            throw LocalTranscriptionRuntimeError.recordingConvertFailed(
                process.terminationStatus,
                "output_missing"
            )
        }
        return convertedURL
    }
}

extension LocalTranscriptionRuntime: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        Task { @MainActor in
            let continuation = self.stopRecordingContinuation
            self.stopRecordingContinuation = nil

            if self.cancelRequested {
                continuation?.resume(throwing: LocalTranscriptionRuntimeError.cancelled)
                self.cancelRequested = false
                return
            }

            if let error {
                continuation?.resume(
                    throwing: LocalTranscriptionRuntimeError.recordStopFailed(error.localizedDescription)
                )
                return
            }

            continuation?.resume(returning: outputFileURL)
        }
    }
}
