import Foundation
import Combine

enum ConsoleLogLevel: String, CaseIterable, Identifiable {
    case info = "INFO"
    case warning = "WARN"
    case error = "ERROR"

    var id: String { rawValue }
}

struct ConsoleLogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let level: ConsoleLogLevel
    let message: String

    var formatted: String {
        "\(timestamp.formatted(date: .omitted, time: .standard)) [\(level.rawValue)] \(message)"
    }
}

@MainActor
final class ConsoleLogStore: ObservableObject {
    static let shared = ConsoleLogStore()
    private static let maximumEntries = 500

    @Published private(set) var entries: [ConsoleLogEntry] = []

    private init() {
        log("コンソールを開始しました")
    }

    func log(_ message: String, level: ConsoleLogLevel = .info) {
        let safeMessage = Self.redact(message)
        entries.append(ConsoleLogEntry(timestamp: Date(), level: level, message: safeMessage))
        if entries.count > Self.maximumEntries {
            entries.removeFirst(entries.count - Self.maximumEntries)
        }
    }

    func clear() {
        entries.removeAll()
    }

    private static func redact(_ message: String) -> String {
        // Avoid accidentally logging common pairing PIN patterns or plist payloads.
        let pinPattern = #"(?<![0-9])[0-9]{6}(?![0-9])"#
        let withoutPIN = message.replacingOccurrences(
            of: pinPattern,
            with: "[PIN省略]",
            options: .regularExpression
        )
        if withoutPIN.localizedCaseInsensitiveContains("rp_pairing") ||
            withoutPIN.localizedCaseInsensitiveContains("pairing file contents") {
            return "[機密情報の可能性があるログを省略]"
        }
        return String(withoutPIN.prefix(500))
    }
}
