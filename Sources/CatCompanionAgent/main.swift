import Foundation
import Darwin

private struct GatewayConfig {
    var url: String
    var token: String
    var sessionKey: String

    static func defaults(from environment: [String: String] = ProcessInfo.processInfo.environment) -> GatewayConfig {
        GatewayConfig(
            url: environment["CATCOMPANION_GATEWAY_URL"] ?? "ws://127.0.0.1:18789",
            token: environment["CATCOMPANION_GATEWAY_TOKEN"] ?? "",
            sessionKey: environment["CATCOMPANION_GATEWAY_SESSION"] ?? "main"
        )
    }
}

private enum GatewayError: Error {
    case invalidURL
    case websocketUnavailable
    case invalidFrame
    case timeout
    case protocolError(String)
    case serverError(String)

    var message: String {
        switch self {
        case .invalidURL:
            return "invalid_gateway_url"
        case .websocketUnavailable:
            return "websocket_unavailable"
        case .invalidFrame:
            return "invalid_gateway_frame"
        case .timeout:
            return "gateway_timeout"
        case .protocolError(let reason):
            return "protocol_error:\(reason)"
        case .serverError(let reason):
            return "server_error:\(reason)"
        }
    }
}

private enum OutputMessage {
    static func emit(_ payload: [String: String]) {
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let line = String(data: data, encoding: .utf8) else {
            return
        }
        print(line)
        fflush(stdout)
    }
}

private final class OpenClawGatewayClient {
    private let config: GatewayConfig
    private let session: URLSession
    private var websocket: URLSessionWebSocketTask?

    init(config: GatewayConfig) {
        self.config = config
        self.session = URLSession(configuration: .default)
    }

    deinit {
        close()
        session.invalidateAndCancel()
    }

    func probe() async throws {
        try await connectAndHandshake()
        close()
    }

    func sendChat(requestID: String, text: String) async throws -> String {
        try await connectAndHandshake()
        defer { close() }

        let sendRequestID = "chat-\(UUID().uuidString)"
        let idempotencyKey = "catcompanion-\(requestID)"
        let chatRequestFrame: [String: Any] = [
            "type": "req",
            "id": sendRequestID,
            "method": "chat.send",
            "params": [
                "sessionKey": config.sessionKey,
                "message": text,
                "idempotencyKey": idempotencyKey
            ]
        ]
        try await sendFrame(chatRequestFrame)

        var resolvedRunID = idempotencyKey

        while true {
            let frame = try await receiveFrame(timeoutSeconds: 120)
            guard let frameType = frame["type"] as? String else {
                throw GatewayError.invalidFrame
            }

            if frameType == "res", (frame["id"] as? String) == sendRequestID {
                guard jsonBool(frame["ok"]) else {
                    throw GatewayError.serverError(extractErrorMessage(from: frame) ?? "chat_send_failed")
                }
                if let payload = frame["payload"] as? [String: Any],
                   let runID = payload["runId"] as? String,
                   !runID.isEmpty {
                    resolvedRunID = runID
                }
                continue
            }

            guard frameType == "event",
                  (frame["event"] as? String) == "chat",
                  let payload = frame["payload"] as? [String: Any],
                  let runID = payload["runId"] as? String,
                  runID == resolvedRunID,
                  let state = payload["state"] as? String else {
                continue
            }

            switch state {
            case "final":
                let message = extractAssistantText(from: payload["message"]) ?? ""
                return message
            case "error":
                if let errorMessage = payload["errorMessage"] as? String, !errorMessage.isEmpty {
                    throw GatewayError.serverError(errorMessage)
                }
                throw GatewayError.serverError("chat_error")
            case "aborted":
                throw GatewayError.serverError("chat_aborted")
            default:
                continue
            }
        }
    }

    private func connectAndHandshake() async throws {
        guard websocket == nil else {
            return
        }

        guard let url = normalizedGatewayURL(from: config.url) else {
            throw GatewayError.invalidURL
        }

        let task = session.webSocketTask(with: url)
        websocket = task
        task.resume()

        let connectRequestID = "connect-\(UUID().uuidString)"
        var connectParams: [String: Any] = [
            "minProtocol": 3,
            "maxProtocol": 3,
            "client": [
                "id": "catcompanion-agent",
                "displayName": "Cat Companion",
                "version": "0.1.0",
                "platform": "macos",
                "mode": "operator"
            ],
            "role": "operator",
            "scopes": [
                "operator.read",
                "operator.write",
                "operator.approvals"
            ],
            "locale": Locale.current.identifier,
            "userAgent": "cat-companion-agent/0.1.0"
        ]
        if !config.token.isEmpty {
            connectParams["auth"] = ["token": config.token]
        }

        let connectFrame: [String: Any] = [
            "type": "req",
            "id": connectRequestID,
            "method": "connect",
            "params": connectParams
        ]
        try await sendFrame(connectFrame)

        var connected = false
        while !connected {
            let frame = try await receiveFrame(timeoutSeconds: 20)
            guard let frameType = frame["type"] as? String else {
                throw GatewayError.invalidFrame
            }

            if frameType == "event", (frame["event"] as? String) == "connect.challenge" {
                continue
            }

            guard frameType == "res", (frame["id"] as? String) == connectRequestID else {
                continue
            }

            guard jsonBool(frame["ok"]) else {
                throw GatewayError.serverError(extractErrorMessage(from: frame) ?? "connect_failed")
            }
            connected = true
        }

        let healthRequestID = "health-\(UUID().uuidString)"
        let healthFrame: [String: Any] = [
            "type": "req",
            "id": healthRequestID,
            "method": "health",
            "params": [:]
        ]
        try await sendFrame(healthFrame)

        while true {
            let frame = try await receiveFrame(timeoutSeconds: 20)
            guard let frameType = frame["type"] as? String else {
                throw GatewayError.invalidFrame
            }
            guard frameType == "res", (frame["id"] as? String) == healthRequestID else {
                continue
            }
            guard jsonBool(frame["ok"]) else {
                throw GatewayError.serverError(extractErrorMessage(from: frame) ?? "health_failed")
            }
            return
        }
    }

    private func close() {
        websocket?.cancel(with: .normalClosure, reason: nil)
        websocket = nil
    }

    private func sendFrame(_ frame: [String: Any]) async throws {
        guard let websocket else {
            throw GatewayError.websocketUnavailable
        }
        let data = try JSONSerialization.data(withJSONObject: frame)
        guard let text = String(data: data, encoding: .utf8) else {
            throw GatewayError.protocolError("invalid_utf8")
        }
        try await websocket.send(.string(text))
    }

    private func receiveFrame(timeoutSeconds: Double) async throws -> [String: Any] {
        guard let websocket else {
            throw GatewayError.websocketUnavailable
        }

        let message = try await withTimeout(seconds: timeoutSeconds) {
            try await websocket.receive()
        }

        let data: Data
        switch message {
        case .string(let string):
            guard let encoded = string.data(using: .utf8) else {
                throw GatewayError.invalidFrame
            }
            data = encoded
        case .data(let bytes):
            data = bytes
        @unknown default:
            throw GatewayError.invalidFrame
        }

        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw GatewayError.invalidFrame
        }
        return object
    }
}

private func normalizedGatewayURL(from rawValue: String) -> URL? {
    guard var components = URLComponents(string: rawValue.trimmingCharacters(in: .whitespacesAndNewlines)) else {
        return nil
    }
    if components.scheme == "http" {
        components.scheme = "ws"
    }
    if components.scheme == "https" {
        components.scheme = "wss"
    }
    guard let scheme = components.scheme?.lowercased(), scheme == "ws" || scheme == "wss" else {
        return nil
    }
    return components.url
}

private func jsonBool(_ value: Any?) -> Bool {
    if let bool = value as? Bool {
        return bool
    }
    if let number = value as? NSNumber {
        return number.boolValue
    }
    return false
}

private func extractErrorMessage(from frame: [String: Any]) -> String? {
    guard let error = frame["error"] as? [String: Any] else { return nil }
    if let message = error["message"] as? String, !message.isEmpty {
        return message
    }
    if let code = error["code"] as? String, !code.isEmpty {
        return code
    }
    return nil
}

private func extractAssistantText(from message: Any?) -> String? {
    guard let messageObject = message as? [String: Any] else {
        return nil
    }

    if let direct = messageObject["content"] as? String, !direct.isEmpty {
        return direct
    }
    if let direct = messageObject["text"] as? String, !direct.isEmpty {
        return direct
    }

    guard let parts = messageObject["content"] as? [Any] else {
        return nil
    }

    var texts: [String] = []
    for part in parts {
        guard let object = part as? [String: Any] else { continue }
        if let text = object["text"] as? String, !text.isEmpty {
            texts.append(text)
        } else if let nested = object["content"] as? String, !nested.isEmpty {
            texts.append(nested)
        }
    }

    if texts.isEmpty {
        return nil
    }
    return texts.joined(separator: "\n")
}

private func withTimeout<T>(seconds: Double, operation: @escaping @Sendable () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        group.addTask {
            let duration = UInt64((seconds * 1_000_000_000).rounded())
            try await Task.sleep(nanoseconds: duration)
            throw GatewayError.timeout
        }

        guard let first = try await group.next() else {
            throw GatewayError.timeout
        }
        group.cancelAll()
        return first
    }
}

private func parseJSONLine(_ line: String) -> [String: Any]? {
    guard let data = line.data(using: .utf8),
          let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        return nil
    }
    return payload
}

private func stringValue(_ payload: [String: Any], key: String) -> String? {
    payload[key] as? String
}

@main
struct CatCompanionAgentMain {
    static func main() async {
        let arguments = Set(CommandLine.arguments.dropFirst())
        guard arguments.contains("--stdio") else {
            fputs("CatCompanionAgent only supports --stdio mode.\n", stderr)
            Darwin.exit(64)
        }

        var gatewayConfig = GatewayConfig.defaults()

        while let line = readLine(strippingNewline: true) {
            guard !line.isEmpty else { continue }
            guard let payload = parseJSONLine(line),
                  let messageType = stringValue(payload, key: "type") else {
                OutputMessage.emit(["type": "error", "reason": "invalid_payload"])
                continue
            }

            switch messageType {
            case "ping":
                OutputMessage.emit([
                    "type": "pong",
                    "id": stringValue(payload, key: "id") ?? ""
                ])

            case "config":
                if let value = stringValue(payload, key: "gatewayUrl"), !value.isEmpty {
                    gatewayConfig.url = value
                }
                if let value = stringValue(payload, key: "gatewayToken") {
                    gatewayConfig.token = value
                }
                if let value = stringValue(payload, key: "sessionKey"), !value.isEmpty {
                    gatewayConfig.sessionKey = value
                }

                let client = OpenClawGatewayClient(config: gatewayConfig)
                do {
                    try await client.probe()
                    OutputMessage.emit([
                        "type": "gateway",
                        "status": "ready"
                    ])
                } catch let gatewayError as GatewayError {
                    OutputMessage.emit([
                        "type": "gateway",
                        "status": "unavailable",
                        "error": gatewayError.message
                    ])
                } catch {
                    OutputMessage.emit([
                        "type": "gateway",
                        "status": "unavailable",
                        "error": error.localizedDescription
                    ])
                }

            case "ask":
                let requestID = stringValue(payload, key: "id") ?? UUID().uuidString
                guard let text = stringValue(payload, key: "text"), !text.isEmpty else {
                    OutputMessage.emit([
                        "type": "ask_result",
                        "id": requestID,
                        "status": "error",
                        "error": "missing_prompt"
                    ])
                    continue
                }

                let client = OpenClawGatewayClient(config: gatewayConfig)
                do {
                    let answer = try await client.sendChat(requestID: requestID, text: text)
                    OutputMessage.emit([
                        "type": "ask_result",
                        "id": requestID,
                        "status": "final",
                        "text": answer
                    ])
                } catch let gatewayError as GatewayError {
                    OutputMessage.emit([
                        "type": "ask_result",
                        "id": requestID,
                        "status": "error",
                        "error": gatewayError.message
                    ])
                } catch {
                    OutputMessage.emit([
                        "type": "ask_result",
                        "id": requestID,
                        "status": "error",
                        "error": error.localizedDescription
                    ])
                }

            case "shutdown":
                OutputMessage.emit([
                    "type": "bye",
                    "id": stringValue(payload, key: "id") ?? ""
                ])
                Darwin.exit(0)

            default:
                OutputMessage.emit([
                    "type": "error",
                    "reason": "unknown_command"
                ])
            }
        }

        Darwin.exit(0)
    }
}
