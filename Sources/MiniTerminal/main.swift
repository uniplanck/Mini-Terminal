import AppKit

let application = NSApplication.shared
let fixtureMode = CommandLine.arguments.contains("--ui-fixture")
let delegate: AppDelegate
var fixtureSuite: String?

if fixtureMode {
    // An explicit, isolated test session. Never reads the user's clipboard,
    // history or preferences, and never executes a command at startup.
    let suite = "MiniTerminal.UIFixture.\(UUID().uuidString)"
    fixtureSuite = suite
    let defaults = UserDefaults(suiteName: suite)!
    let settings = SettingsStore(defaults: defaults)
    settings.language = .en
    settings.pasteClipboardOnOpen = false
    settings.autoRunAfterPaste = false
    settings.copyOutputAfterRun = true
    settings.workingDirectory = "/tmp"
    settings.shortcut = Shortcut(keyCode: 49,
                                modifierFlagsRawValue: NSEvent.ModifierFlags([.control, .option, .shift]).rawValue,
                                keyLabel: "Space")
    let pasteboard = NSPasteboard(name: .init("com.nao.mini-terminal.ui-fixture"))
    pasteboard.clearContents()
    let model = AppModel(settings: settings, historyStore: HistoryStore(defaults: defaults), pasteboard: pasteboard)
    model.command = "printf 'Mini-Terminal v0.4 ready\\n'"
    model.isSplitView = true
    delegate = AppDelegate(model: model, showOnLaunch: true)
    application.appearance = NSAppearance(named: CommandLine.arguments.contains("--dark") ? .darkAqua : .aqua)
} else {
    delegate = AppDelegate()
}
application.delegate = delegate
application.run()
if let fixtureSuite { UserDefaults.standard.removePersistentDomain(forName: fixtureSuite) }
