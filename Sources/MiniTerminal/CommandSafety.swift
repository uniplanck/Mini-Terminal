import Foundation

enum CommandSafety {
    private static let dangerousPatterns = [
        #"(^|[;&|]\s*)sudo\b"#,
        #"(^|[;&|]\s*)rm\s+[^\n]*-[^\n]*[rf]"#,
        #"\bgit\s+reset\s+--hard\b"#,
        #"\bgit\s+clean\s+[^\n]*-[^\n]*[fdx]"#,
        #"\bdd\s+[^\n]*\bif="#,
        #"\bmkfs(?:\.|\s)"#,
        #"\bdiskutil\s+(?:erase|partition|apfs\s+delete)"#,
        #"(^|[;&|]\s*)(?:shutdown|reboot|halt)\b"#,
        #"(^|[;&|]\s*)(?:killall|pkill)\b"#,
        #"\blaunchctl\s+(?:bootout|unload|remove)\b"#,
        #"\b(?:chmod|chown)\s+-R\b"#
    ]

    static func requiresConfirmation(_ command: String) -> Bool {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        if trimmed.contains("\n") || trimmed.contains("\r") {
            return true
        }

        return dangerousPatterns.contains { pattern in
            trimmed.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
        }
    }
}
