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
    #if FILM_CAPTURE
    // Debug builds only: `--film <scene>` layers a launch-film scene over this fixture session.
    let film = FilmCapture.prepareOrExit(arguments: CommandLine.arguments, settings: settings,
                                         defaults: defaults, pasteboard: pasteboard)
    #endif
    let model = AppModel(settings: settings, historyStore: HistoryStore(defaults: defaults), pasteboard: pasteboard)
    model.command = "printf 'Mini-Terminal v0.4 ready\\n'"
    model.isSplitView = true
    #if FILM_CAPTURE
    film?.configure(model)
    delegate = AppDelegate(model: model, showOnLaunch: film?.panelVisibleAtLaunch ?? true)
    application.appearance = NSAppearance(named: film?.dark == true || CommandLine.arguments.contains("--dark") ? .darkAqua : .aqua)
    #else
    delegate = AppDelegate(model: model, showOnLaunch: true)
    application.appearance = NSAppearance(named: CommandLine.arguments.contains("--dark") ? .darkAqua : .aqua)
    #endif
} else {
    delegate = AppDelegate()
}
application.delegate = delegate
application.run()
if let fixtureSuite { UserDefaults.standard.removePersistentDomain(forName: fixtureSuite) }
