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

    func testSettingsWindowIsFrontLevel() {
        _ = NSApplication.shared
        let delegate = AppDelegate()
        let window = delegate.makeSettingsWindow()

        XCTAssertEqual(window.level, .floating)
        XCTAssertTrue(window.collectionBehavior.contains(.moveToActiveSpace))
        XCTAssertTrue(window.collectionBehavior.contains(.fullScreenAuxiliary))
        XCTAssertFalse(window.isReleasedWhenClosed)
    }
}
