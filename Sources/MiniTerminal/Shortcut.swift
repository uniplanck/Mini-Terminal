import AppKit

struct Shortcut: Codable, Equatable {
    var keyCode: UInt32
    var modifierFlagsRawValue: UInt
    var keyLabel: String

    static let defaultShortcut = Shortcut(
        keyCode: 49,
        modifierFlagsRawValue: NSEvent.ModifierFlags.option.rawValue,
        keyLabel: "Space"
    )

    var modifierFlags: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: modifierFlagsRawValue)
            .intersection([.command, .option, .control, .shift])
    }

    var displayString: String {
        var pieces: [String] = []
        if modifierFlags.contains(.control) { pieces.append("⌃") }
        if modifierFlags.contains(.option) { pieces.append("⌥") }
        if modifierFlags.contains(.shift) { pieces.append("⇧") }
        if modifierFlags.contains(.command) { pieces.append("⌘") }
        pieces.append(keyLabel)
        return pieces.joined(separator: " ")
    }

    static func from(event: NSEvent) -> Shortcut? {
        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        guard !modifiers.isEmpty else { return nil }

        let label: String
        switch event.keyCode {
        case 36: label = "Return"
        case 48: label = "Tab"
        case 49: label = "Space"
        case 51: label = "Delete"
        case 53: label = "Esc"
        case 123: label = "←"
        case 124: label = "→"
        case 125: label = "↓"
        case 126: label = "↑"
        default:
            let raw = event.charactersIgnoringModifiers?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            label = raw.isEmpty ? "Key \(event.keyCode)" : raw.uppercased()
        }

        return Shortcut(
            keyCode: UInt32(event.keyCode),
            modifierFlagsRawValue: modifiers.rawValue,
            keyLabel: label
        )
    }
}
