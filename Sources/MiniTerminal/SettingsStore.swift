import Foundation

final class SettingsStore: ObservableObject {
    private enum Keys {
        static let shortcut = "shortcut"
        static let pasteClipboardOnOpen = "pasteClipboardOnOpen"
        static let autoRunAfterPaste = "autoRunAfterPaste"
        static let copyOutputAfterRun = "copyOutputAfterRun"
        static let confirmDangerousCommands = "confirmDangerousCommands"
        static let shellPath = "shellPath"
        static let workingDirectory = "workingDirectory"
        static let language = "language"
    }

    private let defaults: UserDefaults
    var onShortcutChanged: ((Shortcut) -> Void)?
    var onLanguageChanged: (() -> Void)?

    @Published var shortcut: Shortcut {
        didSet {
            if let data = try? JSONEncoder().encode(shortcut) {
                defaults.set(data, forKey: Keys.shortcut)
            }
            onShortcutChanged?(shortcut)
        }
    }

    @Published var pasteClipboardOnOpen: Bool {
        didSet { defaults.set(pasteClipboardOnOpen, forKey: Keys.pasteClipboardOnOpen) }
    }

    @Published var autoRunAfterPaste: Bool {
        didSet { defaults.set(autoRunAfterPaste, forKey: Keys.autoRunAfterPaste) }
    }

    @Published var copyOutputAfterRun: Bool {
        didSet { defaults.set(copyOutputAfterRun, forKey: Keys.copyOutputAfterRun) }
    }

    @Published var confirmDangerousCommands: Bool {
        didSet { defaults.set(confirmDangerousCommands, forKey: Keys.confirmDangerousCommands) }
    }

    @Published var shellPath: String {
        didSet { defaults.set(shellPath, forKey: Keys.shellPath) }
    }

    @Published var workingDirectory: String {
        didSet { defaults.set(workingDirectory, forKey: Keys.workingDirectory) }
    }

    @Published var language: AppLanguage {
        didSet {
            defaults.set(language.rawValue, forKey: Keys.language)
            onLanguageChanged?()
        }
    }

    var resolvedLanguage: AppLanguage {
        language == .system ? AppLanguage.systemPreferred() : language
    }

    func text(_ key: L10n.Key) -> String {
        L10n.text(key, language: language)
    }

    func historyCount(_ count: Int) -> String {
        L10n.historyCount(count, language: language)
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if let data = defaults.data(forKey: Keys.shortcut),
           let decoded = try? JSONDecoder().decode(Shortcut.self, from: data) {
            shortcut = decoded
        } else {
            shortcut = .defaultShortcut
        }

        pasteClipboardOnOpen = defaults.object(forKey: Keys.pasteClipboardOnOpen) as? Bool ?? true
        autoRunAfterPaste = defaults.object(forKey: Keys.autoRunAfterPaste) as? Bool ?? false
        copyOutputAfterRun = defaults.object(forKey: Keys.copyOutputAfterRun) as? Bool ?? true
        confirmDangerousCommands = defaults.object(forKey: Keys.confirmDangerousCommands) as? Bool ?? true
        shellPath = defaults.string(forKey: Keys.shellPath) ?? "/bin/zsh"
        workingDirectory = defaults.string(forKey: Keys.workingDirectory) ?? "~"
        language = AppLanguage(rawValue: defaults.string(forKey: Keys.language) ?? "") ?? .system
    }
}
