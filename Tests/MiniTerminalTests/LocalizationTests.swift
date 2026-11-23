import AppKit
import XCTest
@testable import MiniTerminal

final class LocalizationTests: XCTestCase {
    func testPreferredLanguageMapping() {
        XCTAssertEqual(AppLanguage.fromPreferredLanguage("ja-JP"), .ja)
        XCTAssertEqual(AppLanguage.fromPreferredLanguage("en-US"), .en)
        XCTAssertEqual(AppLanguage.fromPreferredLanguage("zh-CN"), .zhHans)
        XCTAssertEqual(AppLanguage.fromPreferredLanguage("zh-TW"), .zhHant)
        XCTAssertEqual(AppLanguage.fromPreferredLanguage("ko-KR"), .ko)
        XCTAssertEqual(AppLanguage.fromPreferredLanguage("es-ES"), .es)
        XCTAssertEqual(AppLanguage.fromPreferredLanguage("fr-FR"), .fr)
        XCTAssertEqual(AppLanguage.fromPreferredLanguage("de-DE"), .de)
        XCTAssertEqual(AppLanguage.fromPreferredLanguage("pt-BR"), .pt)
        XCTAssertNil(AppLanguage.fromPreferredLanguage("it-IT"))
    }

    func testEnglishAndJapaneseStrings() {
        XCTAssertEqual(L10n.text(.menuSettings, language: .en), "Settings…")
        XCTAssertEqual(L10n.text(.menuSettings, language: .ja), "設定…")
        XCTAssertEqual(L10n.historyCount(2, language: .en), "2 items")
        XCTAssertEqual(L10n.historyCount(2, language: .ja), "2件")
    }

    func testLanguageSelectionPersists() {
        let suiteName = "MiniTerminalTests.Language.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = SettingsStore(defaults: defaults)
        XCTAssertEqual(settings.language, .system)

        settings.language = .fr
        let reloaded = SettingsStore(defaults: defaults)

        XCTAssertEqual(reloaded.language, .fr)
        XCTAssertEqual(reloaded.resolvedLanguage, .fr)
        XCTAssertEqual(reloaded.text(.settings), "Réglages")
    }

    func testEveryLocaleHasEveryVisibleStringAndSystemResolves() {
        for language in AppLanguage.allCases where language != .system {
            XCTAssertTrue(L10n.missingKeys(for: language).isEmpty, "Missing strings for \(language.rawValue)")
        }
        XCTAssertTrue(AppLanguage.allCases.contains(AppLanguage.systemPreferred()))
        let suiteName = "MiniTerminalTests.System.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        XCTAssertEqual(SettingsStore(defaults: defaults).language, .system)
    }

    func testSettingsWindowIsFrontLevel() {
        _ = NSApplication.shared
        let suite = "MiniTerminalTests.SettingsWindow.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let delegate = AppDelegate(model: AppModel(settings: SettingsStore(defaults: defaults), historyStore: HistoryStore(defaults: defaults), pasteboard: NSPasteboard(name: .init(suite))))
        let window = delegate.makeSettingsWindow()

        XCTAssertEqual(window.level, .floating)
        XCTAssertTrue(window.collectionBehavior.contains(.moveToActiveSpace))
        XCTAssertTrue(window.collectionBehavior.contains(.fullScreenAuxiliary))
        XCTAssertFalse(window.isReleasedWhenClosed)
    }

    func testPresentingSettingsShowsRetainedFocusableWindowWithoutPreparingLauncher() {
        _ = NSApplication.shared
        let suite = "MiniTerminalTests.SettingsPresentation.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let delegate = AppDelegate(model: AppModel(settings: SettingsStore(defaults: defaults), historyStore: HistoryStore(defaults: defaults), pasteboard: NSPasteboard(name: .init(suite))))
        delegate.model.settings.autoRunAfterPaste = true
        let window = delegate.presentSettingsWindow()
        let retainedWindow = delegate.presentSettingsWindow()
        RunLoop.main.run(until: Date().addingTimeInterval(0.15))

        XCTAssertTrue(window === retainedWindow)
        XCTAssertTrue(window.isVisible)
        XCTAssertTrue(window.canBecomeKey)
        XCTAssertEqual(delegate.model.command, "")
        XCTAssertFalse(delegate.model.isRunning)
        delegate.shortcutCapture.start { _ in }
        XCTAssertTrue(delegate.shortcutCapture.isRecording)
        window.close()
        XCTAssertFalse(delegate.shortcutCapture.isRecording)
    }
}
