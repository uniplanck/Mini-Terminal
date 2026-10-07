import AppKit
import SwiftUI
import XCTest
@testable import MiniTerminal

final class NativeRenderingSmokeTests: XCTestCase {
    @MainActor
    func testRenderFictionalLauncherAndSettingsStatesWhenOutputDirectoryIsProvided() throws {
        guard let outputPath = ProcessInfo.processInfo.environment["MINI_TERMINAL_UI_SMOKE_DIR"], !outputPath.isEmpty else {
            throw XCTSkip("Set MINI_TERMINAL_UI_SMOKE_DIR to an ignored output directory to render native UI fixtures.")
        }
        _ = NSApplication.shared

        let outputDirectory = URL(fileURLWithPath: outputPath, isDirectory: true).standardizedFileURL
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        var rendered: [String] = []

        for appearance in [ColorScheme.light, .dark] {
            let appearanceName = appearance == .dark ? "dark" : "light"
            try renderLauncher(name: "compact-idle-\(appearanceName)", appearance: appearance, directory: outputDirectory, rendered: &rendered) { _, _ in }
            try renderLauncher(name: "compact-success-\(appearanceName)", appearance: appearance, directory: outputDirectory, rendered: &rendered) { model, _ in
                model.command = "printf 'fixture complete'"
                model.exitCode = 0
                model.duration = 0.012
            }
            try renderLauncher(name: "compact-error-\(appearanceName)", appearance: appearance, directory: outputDirectory, rendered: &rendered) { model, _ in
                model.command = "fictional missing-command"
                model.output = "fixture: command unavailable"
                model.exitCode = 127
                model.duration = 0.004
            }
            try renderLauncher(name: "compact-running-\(appearanceName)", appearance: appearance, directory: outputDirectory, rendered: &rendered) { model, _ in
                model.command = "sleep 1"
                model.isRunning = true
            }
            try renderLauncher(name: "compact-copy-feedback-\(appearanceName)", appearance: appearance, directory: outputDirectory, rendered: &rendered) { model, _ in
                model.command = "printf 'fixture copied'"
                model.copyFeedback = "Fixture copied"
            }
            try renderLauncher(name: "split-\(appearanceName)", appearance: appearance, directory: outputDirectory, rendered: &rendered) { model, _ in
                model.isSplitView = true
                model.command = "printf 'fixture split'\nprintf 'second line'"
                model.output = "fixture split output\nsecond line"
                model.exitCode = 0
            }
            try renderLauncher(name: "history-from-split-\(appearanceName)", appearance: appearance, directory: outputDirectory, rendered: &rendered) { model, store in
                model.isSplitView = true
                model.isHistoryVisible = true
                store.add(command: "printf 'fictional history'", output: "fixture history output", exitCode: 0, duration: 0.02)
            }
            for language in [AppLanguage.en, .ja, .de, .pt] {
                for section in 0...2 {
                    try renderSettings(name: "settings-\(language.rawValue)-\(section)-\(appearanceName)", language: language, section: section, appearance: appearance, directory: outputDirectory, rendered: &rendered)
                }
            }
        }

        let summary: [String: Any] = [
            "fixture": "fictional-only",
            "rendered": rendered.sorted(),
            "count": rendered.count
        ]
        let data = try JSONSerialization.data(withJSONObject: summary, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: outputDirectory.appendingPathComponent("summary.json"), options: .atomic)
    }

    @MainActor
    private func renderLauncher(
        name: String,
        appearance: ColorScheme,
        directory: URL,
        rendered: inout [String],
        configure: (AppModel, HistoryStore) -> Void
    ) throws {
        let suite = "MiniTerminal.UISmoke.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = SettingsStore(defaults: defaults)
        settings.language = .de
        let history = HistoryStore(defaults: defaults)
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("MiniTerminal.UISmoke.\(UUID().uuidString)"))
        let model = AppModel(settings: settings, historyStore: history, pasteboard: pasteboard)
        configure(model, history)
        let view = LauncherView(
            model: model,
            settings: settings,
            historyStore: history,
            onClose: {}, onOpenSettings: {}, onSplitChanged: { _ in }, onExecutionStateChanged: {}
        )
        let normalSize = UIParameters.launcherSize(split: model.isSplitView, history: model.isHistoryVisible)
        try render(view.environment(\.colorScheme, appearance), size: normalSize, name: name, directory: directory)
        rendered.append(name)
        if name.hasPrefix("compact-copy") || name.hasPrefix("split-") {
            let narrowSize = CGSize(width: UIParameters.minimumWidth, height: normalSize.height)
            let narrowName = "narrow-" + name
            try render(view.environment(\.colorScheme, appearance), size: narrowSize, name: narrowName, directory: directory)
            rendered.append(narrowName)
        }
    }

    @MainActor
    private func renderSettings(name: String, language: AppLanguage, section: Int, appearance: ColorScheme, directory: URL, rendered: inout [String]) throws {
        let suite = "MiniTerminal.UISmoke.Settings.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = SettingsStore(defaults: defaults)
        settings.language = language
        try render(SettingsView(settings: settings, initialSection: section).environment(\.colorScheme, appearance), size: UIParameters.settingsSize, name: name, directory: directory)
        rendered.append(name)
    }

    @MainActor
    private func render<Content: View>(_ content: Content, size: CGSize, name: String, directory: URL) throws {
        let hostingView = NSHostingView(rootView: content.frame(width: size.width, height: size.height))
        hostingView.frame = CGRect(origin: .zero, size: size)
        let window = NSWindow(contentRect: hostingView.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: name.hasSuffix("dark") ? .darkAqua : .aqua)
        window.contentView = hostingView
        window.orderFront(nil)
        RunLoop.main.run(until: Date().addingTimeInterval(0.15))
        hostingView.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
        hostingView.displayIfNeeded()

        guard let bitmap = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else {
            throw NSError(domain: "MiniTerminal.UISmoke", code: 1)
        }
        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "MiniTerminal.UISmoke", code: 2)
        }
        try png.write(to: directory.appendingPathComponent("\(name).png"), options: .atomic)
        window.close()
    }
}
