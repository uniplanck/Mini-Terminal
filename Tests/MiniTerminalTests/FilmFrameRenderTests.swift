#if FILM_CAPTURE
import AppKit
import SwiftUI
import XCTest
@testable import MiniTerminal

/// Renders the launch film's UI states from the app's own views (LauncherView + the real
/// AppModel/ShellRunner), driven by the film-capture scenes in film-fixture.json. Every command is
/// actually executed in the deterministic workspace; nothing in the output is typed in by hand.
///
/// This is an offscreen render, not a screen recording: no desktop behind the panel (the
/// .regularMaterial background shows its flat fallback), no window shadow and no text caret.
///
///   bash launch-video/assets/ui/fixtures/make-film-workspace.sh
///   MINI_TERMINAL_FILM_FRAMES_DIR=$PWD/launch-video/assets/ui/stills/film \
///   MINI_TERMINAL_FILM_FIXTURE=$PWD/launch-video/assets/ui/fixtures/film-fixture.json \
///   swift test --filter FilmFrameRenderTests
final class FilmFrameRenderTests: XCTestCase {
    private var outputDirectory: URL!
    private var manifest: [[String: Any]] = []

    @MainActor
    func testRenderLaunchFilmUIStates() throws {
        let env = ProcessInfo.processInfo.environment
        guard let out = env["MINI_TERMINAL_FILM_FRAMES_DIR"], !out.isEmpty,
              let fixture = env["MINI_TERMINAL_FILM_FIXTURE"], !fixture.isEmpty else {
            throw XCTSkip("Set MINI_TERMINAL_FILM_FRAMES_DIR and MINI_TERMINAL_FILM_FIXTURE to render the film UI states.")
        }
        // The film uses the macOS default accent (blue). Pin it for this process only, so the
        // renderer's machine settings (e.g. a red accent) do not leak into the film. Nothing is written
        // to the user's global defaults.
        UserDefaults.standard.setVolatileDomain(["AppleAccentColor": 4, "AppleHighlightColor": "0.698039 0.843137 1.000000 Blue"],
                                                forName: UserDefaults.argumentDomain)
        _ = NSApplication.shared
        NSApp.appearance = NSAppearance(named: .darkAqua)
        outputDirectory = URL(fileURLWithPath: out, isDirectory: true).standardizedFileURL
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        // S03 — summon, type, run (UI_T01)
        try scene("S03", fixture: fixture) { s in
            try s.render("s03_idle")
            let typed = "git rev-parse --short HEAD"
            for count in 1...typed.count {
                s.model.command = String(typed.prefix(count))
                try s.render(String(format: "s03_type_%02d", count), quick: true)
            }
            try s.run()
            try s.render("s03_result")
            try s.waitForFeedbackToClear()
            try s.render("s03_result_settled")
        }

        // S04 — clipboard auto paste → run → copy (UI_T02). prepareForPresentation is what the hotkey calls.
        try scene("S04", fixture: fixture) { s in
            try s.render("s04_idle_before_paste")
            s.model.prepareForPresentation()
            try s.waitUntilIdle()
            try s.render("s04_result")
            try s.waitForFeedbackToClear()
            try s.render("s04_result_settled")
        }

        // S05 — split view, run, output + exit code (UI_T03)
        try scene("S05", fixture: fixture) { s in
            try s.render("s05_compact")
            s.model.isSplitView = true
            try s.render("s05_split_ready")
            try s.run()
            try s.render("s05_split_result")
            try s.waitForFeedbackToClear()
            try s.render("s05_split_result_settled")
        }

        // S06 — history, then the destructive-command confirmation (UI_T04)
        try scene("S06", fixture: fixture) { s in
            try s.render("s06_compact")
            s.model.isHistoryVisible = true
            try s.render("s06_history")
            s.model.isHistoryVisible = false
            s.model.command = "rm -rf ./build"
            try s.render("s06_rm_typed")
            s.model.execute()   // CommandSafety stops it and raises the alert; nothing is deleted
            XCTAssertTrue(s.model.showDangerousAlert)
            XCTAssertFalse(s.model.isRunning)
            try s.renderAlert("s06_alert")
            s.model.cancelDangerousExecution()
            try s.render("s06_after_cancel")
            XCTAssertTrue(FileManager.default.fileExists(atPath: "/tmp/mini-terminal-film/demo/build/.keep"))
        }

        // S08 — idle panel for the end card (UI_T05)
        try scene("S08", fixture: fixture) { s in
            try s.render("s08_idle")
        }

        // Film HUD key chips (not app UI). Rendered with the macOS system font so ⌥ ⌘ ↩ always have glyphs.
        for (slug, label) in [("option_space", "⌥ Space"), ("cmd_c", "⌘C"), ("cmd_return", "⌘↩")] {
            try renderChip(label, name: "hud_chip_\(slug)")
        }

        let data = try JSONSerialization.data(withJSONObject: ["source": "FilmFrameRenderTests (offscreen render of LauncherView, real execution)", "states": manifest],
                                              options: [.prettyPrinted, .sortedKeys])
        try data.write(to: outputDirectory.appendingPathComponent("states.json"), options: .atomic)
    }

    /// Film-px sized chip (28 px semibold label, 10 px radius, hairline border), rendered at 2x.
    @MainActor
    private func renderChip(_ label: String, name: String) throws {
        let chip = Text(label)
            .font(.system(size: 28, weight: .semibold))
            .foregroundStyle(Color(red: 0.96, green: 0.96, blue: 0.97))
            .padding(.horizontal, 18)
            .frame(height: 52)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(red: 0.11, green: 0.11, blue: 0.12).opacity(0.92)))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.white.opacity(0.22), lineWidth: 1))
            .fixedSize()
            .environment(\.colorScheme, .dark)
        let hosting = NSHostingView(rootView: chip)
        let size = hosting.fittingSize
        hosting.frame = CGRect(origin: .zero, size: size)
        let window = NSWindow(contentRect: CGRect(origin: CGPoint(x: -4000, y: -4000), size: size), styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.backgroundColor = .clear
        window.contentView = hosting
        window.orderFront(nil)
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        hosting.layoutSubtreeIfNeeded()
        guard let rep = SceneRenderer.bitmap(points: size, scale: 2) else { throw NSError(domain: "FilmFrames", code: 3) }
        hosting.cacheDisplay(in: hosting.bounds, to: rep)
        guard let png = rep.representation(using: .png, properties: [:]) else { throw NSError(domain: "FilmFrames", code: 4) }
        try png.write(to: outputDirectory.appendingPathComponent("\(name).png"), options: .atomic)
        manifest.append(["scene": "HUD", "state": name, "file": "\(name).png", "label": label,
                         "points": [size.width, size.height], "pixels": [rep.pixelsWide, rep.pixelsHigh]])
        window.close()
    }

    @MainActor
    private func scene(_ id: String, fixture: String, _ body: (SceneRenderer) throws -> Void) throws {
        let suite = "MiniTerminal.FilmFrames.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = SettingsStore(defaults: defaults)
        settings.shortcut = Shortcut(keyCode: 49, modifierFlagsRawValue: NSEvent.ModifierFlags([.option]).rawValue, keyLabel: "Space")
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("MiniTerminal.FilmFrames.\(UUID().uuidString)"))
        let session = try FilmCapture.prepare(request: FilmCaptureRequest(scene: id, fixturePath: fixture),
                                              settings: settings, defaults: defaults, pasteboard: pasteboard)
        let model = AppModel(settings: settings, historyStore: HistoryStore(defaults: defaults), pasteboard: pasteboard)
        session.configure(model)
        let renderer = SceneRenderer(scene: id, model: model, settings: settings, directory: outputDirectory) { [unowned self] entry in
            self.manifest.append(entry)
        }
        try body(renderer)
        renderer.close()
    }
}

@MainActor
final class SceneRenderer {
    let scene: String
    let model: AppModel
    let settings: SettingsStore
    let directory: URL
    let record: ([String: Any]) -> Void
    private var window: NSWindow?
    private var hosting: NSHostingView<AnyView>?

    init(scene: String, model: AppModel, settings: SettingsStore, directory: URL, record: @escaping ([String: Any]) -> Void) {
        self.scene = scene
        self.model = model
        self.settings = settings
        self.directory = directory
        self.record = record
    }

    private func ensureWindow(size: CGSize) {
        let view = LauncherView(model: model, settings: settings, historyStore: model.historyStore,
                                onClose: {}, onOpenSettings: {}, onSplitChanged: { _ in }, onExecutionStateChanged: {})
        if hosting == nil {
            let hostingView = NSHostingView(rootView: AnyView(view.environment(\.colorScheme, .dark)))
            let window = NSWindow(contentRect: CGRect(origin: CGPoint(x: -4000, y: -4000), size: size),
                                  styleMask: .borderless, backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.appearance = NSAppearance(named: .darkAqua)
            window.isOpaque = false
            window.backgroundColor = .clear
            window.contentView = hostingView
            window.orderFront(nil)
            self.window = window
            self.hosting = hostingView
        }
        window?.setContentSize(size)
        hosting?.frame = CGRect(origin: .zero, size: size)
    }

    /// Retina output regardless of which screen the offscreen window lands on.
    let scale: CGFloat = 2

    static func bitmap(points: CGSize, scale: CGFloat) -> NSBitmapImageRep? {
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(points.width * scale), pixelsHigh: Int(points.height * scale),
                                   bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                   colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
        rep?.size = points
        return rep
    }

    private var currentSize: CGSize { UIParameters.launcherSize(split: model.isSplitView, history: model.isHistoryVisible) }

    func render(_ name: String, quick: Bool = false) throws {
        let size = currentSize
        ensureWindow(size: size)
        RunLoop.main.run(until: Date().addingTimeInterval(quick ? 0.05 : 0.2))
        guard let hosting else { return }
        hosting.layoutSubtreeIfNeeded()
        hosting.displayIfNeeded()
        guard let bitmap = Self.bitmap(points: size, scale: scale) else { throw NSError(domain: "FilmFrames", code: 1) }
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        try write(bitmap, name: name, points: size)
    }

    /// The confirmation is a SwiftUI .alert, presented by AppKit in its own window/sheet, which the
    /// hosting view's cache does not contain. Render the panel, then every other visible window the
    /// app opened for the alert, so both come from the real presentation.
    func renderAlert(_ name: String) throws {
        try render(name + "_panel")
        let deadline = Date().addingTimeInterval(2)
        var alertWindows: [NSWindow] = []
        while Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.1))
            alertWindows = NSApp.windows.filter { $0 !== window && $0.isVisible && $0.contentView != nil }
            if !alertWindows.isEmpty || window?.attachedSheet != nil { break }
        }
        if let sheet = window?.attachedSheet, !alertWindows.contains(where: { $0 === sheet }) { alertWindows.append(sheet) }
        for (index, alertWindow) in alertWindows.enumerated() {
            alertWindow.appearance = NSAppearance(named: .darkAqua)
            alertWindow.display()
            RunLoop.main.run(until: Date().addingTimeInterval(0.6))
            guard let frameView = alertWindow.contentView?.superview ?? alertWindow.contentView else { continue }
            frameView.layoutSubtreeIfNeeded()
            frameView.display()
            let extra: [String: Any] = ["windowClass": String(describing: type(of: alertWindow)), "isSheet": alertWindow.isSheet]
            // Variant A: AppKit view cache.
            if let bitmap = frameView.bitmapImageRepForCachingDisplay(in: frameView.bounds) {
                frameView.cacheDisplay(in: frameView.bounds, to: bitmap)
                try write(bitmap, name: "\(name)_window\(index)_cache", points: frameView.bounds.size, extra: extra)
            }
            // Variant C: AppKit PDF drawing path (replays draw(_:) of every subview, text included).
            let pdf = frameView.dataWithPDF(inside: frameView.bounds)
            try pdf.write(to: directory.appendingPathComponent("\(name)_window\(index).pdf"))
            if let pdfRep = NSPDFImageRep(data: pdf), let rep = Self.bitmap(points: frameView.bounds.size, scale: scale) {
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
                pdfRep.draw(in: CGRect(origin: .zero, size: frameView.bounds.size))
                NSGraphicsContext.restoreGraphicsState()
                try write(rep, name: "\(name)_window\(index)_text", points: frameView.bounds.size, extra: extra)
            }
            // Variant B: Core Animation layer tree (keeps layer-backed text; backdrop blur is not captured).
            if let layer = frameView.layer, let rep = Self.bitmap(points: frameView.bounds.size, scale: scale) {
                NSGraphicsContext.saveGraphicsState()
                if let ctx = NSGraphicsContext(bitmapImageRep: rep) {
                    ctx.cgContext.scaleBy(x: scale, y: scale)
                    layer.render(in: ctx.cgContext)
                }
                NSGraphicsContext.restoreGraphicsState()
                try write(rep, name: "\(name)_window\(index)_layer", points: frameView.bounds.size, extra: extra)
            }
        }
        record(["scene": scene, "state": name, "alertWindows": alertWindows.count])
    }

    func run() throws {
        model.execute()
        try waitUntilIdle()
    }

    func waitUntilIdle() throws {
        let deadline = Date().addingTimeInterval(10)
        while (model.isRunning || model.exitCode == nil) && Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.005))
        }
        XCTAssertFalse(model.isRunning, "\(scene): command did not finish")
    }

    func waitForFeedbackToClear() throws {
        let deadline = Date().addingTimeInterval(3)
        while model.copyFeedback != nil && Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }
    }

    private func write(_ bitmap: NSBitmapImageRep, name: String, points: CGSize, extra: [String: Any] = [:]) throws {
        guard let png = bitmap.representation(using: .png, properties: [:]) else { throw NSError(domain: "FilmFrames", code: 2) }
        try png.write(to: directory.appendingPathComponent("\(name).png"), options: .atomic)
        var entry: [String: Any] = [
            "scene": scene, "state": name, "file": "\(name).png",
            "points": [points.width, points.height], "pixels": [bitmap.pixelsWide, bitmap.pixelsHigh],
            "command": model.command, "split": model.isSplitView, "history": model.isHistoryVisible,
            "feedback": model.copyFeedback ?? NSNull()
        ]
        if let code = model.exitCode { entry["exitCode"] = Int(code) }
        if let duration = model.duration { entry["durationMs"] = Int((duration * 1000).rounded()) }
        if !model.output.isEmpty { entry["output"] = model.output }
        extra.forEach { entry[$0.key] = $0.value }
        record(entry)
    }

    func close() {
        window?.close()
        window = nil
        hosting = nil
    }
}
#endif
