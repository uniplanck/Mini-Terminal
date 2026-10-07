import AppKit
import SwiftUI

final class LauncherPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let model: AppModel
    let shortcutCapture = ShortcutCaptureController()
    private let showOnLaunch: Bool

    init(model: AppModel = AppModel(), showOnLaunch: Bool = false) {
        self.model = model
        self.showOnLaunch = showOnLaunch
        super.init()
    }

    private let hotKeyManager = HotKeyManager()
    private var statusItem: NSStatusItem?
    private var launcherPanel: LauncherPanel?
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        model.settings.onShortcutChanged = { [weak self] shortcut in
            guard let self else { return }
            if !self.hotKeyManager.register(shortcut),
               let previous = self.hotKeyManager.registeredShortcut {
                self.model.settings.shortcut = previous
            }
        }

        model.settings.onLanguageChanged = { [weak self] in
            self?.refreshLocalizedChrome()
        }

        hotKeyManager.onHotKey = { [weak self] in
            self?.toggleLauncher()
        }

        _ = hotKeyManager.register(model.settings.shortcut)
        configureStatusItem()
        if showOnLaunch {
            DispatchQueue.main.async { [weak self] in self?.presentLauncher(prepareClipboard: false) }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    @objc private func toggleLauncher() {
        if launcherPanel?.isVisible == true {
            hideLauncher()
        } else {
            showLauncher()
        }
    }

    @objc private func showLauncher() {
        presentLauncher()
    }

    @discardableResult
    func presentLauncher(prepareClipboard: Bool = true) -> NSPanel {
        let panel = launcherPanel ?? makeLauncherPanel()
        launcherPanel = panel
        resizeLauncher(split: model.isSplitView, animated: false)
        positionLauncher(panel)

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)

        if prepareClipboard {
            model.prepareForPresentation()
            resizeLauncher(split: model.isSplitView, animated: false)
        }
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .miniTerminalFocusCommand, object: nil)
        }
        return panel
    }

    private func hideLauncher() {
        launcherPanel?.orderOut(nil)
    }

    @objc private func showSettings() {
        presentSettingsWindow()
    }

    @discardableResult
    func presentSettingsWindow() -> NSWindow {
        hideLauncher()

        let window = settingsWindow ?? makeSettingsWindow()
        settingsWindow = window
        window.title = model.settings.text(.settingsTitle)

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        window.makeKey()
        return window
    }

    @objc private func quitApplication() {
        NSApp.terminate(nil)
    }

    private func refreshLocalizedChrome() {
        configureStatusItem()
        settingsWindow?.title = model.settings.text(.settingsTitle)
    }

    private func configureStatusItem() {
        let item: NSStatusItem
        if let statusItem {
            item = statusItem
        } else {
            item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            statusItem = item
        }

        if let button = item.button {
            button.image = NSImage(systemSymbolName: "terminal.fill", accessibilityDescription: "Mini-Terminal")
            button.toolTip = "Mini-Terminal"
        }

        let menu = NSMenu()

        let openItem = NSMenuItem(
            title: model.settings.text(.menuOpen),
            action: #selector(showLauncher),
            keyEquivalent: ""
        )
        openItem.target = self
        menu.addItem(openItem)

        let settingsItem = NSMenuItem(
            title: model.settings.text(.menuSettings),
            action: #selector(showSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: model.settings.text(.menuQuit),
            action: #selector(quitApplication),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        item.menu = menu
    }

    private func makeLauncherPanel() -> LauncherPanel {
        let panel = LauncherPanel(
            contentRect: NSRect(x: 0, y: 0, width: UIParameters.compactWidth, height: 96),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.hidesOnDeactivate = !showOnLaunch
        panel.title = "Mini-Terminal"
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true

        let rootView = LauncherView(
            model: model,
            settings: model.settings,
            historyStore: model.historyStore,
            onClose: { [weak self] in self?.hideLauncher() },
            onOpenSettings: { [weak self] in self?.showSettings() },
            onSplitChanged: { [weak self] split in
                self?.resizeLauncher(split: split, animated: true)
            },
            onExecutionStateChanged: { [weak self] in
                guard let self else { return }
                self.resizeLauncher(split: self.model.isSplitView, animated: true)
            }
        )

        panel.contentView = NSHostingView(rootView: rootView)
        return panel
    }

    func makeSettingsWindow() -> NSWindow {
        let content = SettingsView(settings: model.settings, shortcutCapture: shortcutCapture)
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: UIParameters.settingsSize),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        window.title = model.settings.text(.settingsTitle)
        window.contentView = NSHostingView(rootView: content)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.level = .floating
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        window.center()
        return window
    }

    func windowWillClose(_ notification: Notification) { shortcutCapture.stop() }
    func windowDidResignKey(_ notification: Notification) { shortcutCapture.stop() }

    private func resizeLauncher(split: Bool, animated: Bool) {
        guard let panel = launcherPanel else { return }
        let visible = (panel.screen ?? NSScreen.main)?.visibleFrame
        let targetSize = UIParameters.launcherSize(split: split, history: model.isHistoryVisible, available: visible?.size)
        var frame = panel.frame
        let top = frame.maxY
        let center = frame.midX
        frame.size = targetSize
        frame.origin = NSPoint(x: center - targetSize.width / 2, y: top - targetSize.height)
        if let visible {
            frame.origin.x = max(visible.minX + 16, min(frame.origin.x, visible.maxX - frame.width - 16))
            frame.origin.y = max(visible.minY + 16, min(frame.origin.y, visible.maxY - frame.height - 16))
        }
        if animated && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.12
                panel.animator().setFrame(frame, display: true)
            }
        } else { panel.setFrame(frame, display: true) }
    }

    private func positionLauncher(_ panel: NSPanel) {
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) } ?? NSScreen.main

        guard let visibleFrame = screen?.visibleFrame else {
            panel.center()
            return
        }

        var frame = panel.frame
        frame.size = UIParameters.launcherSize(split: model.isSplitView, history: model.isHistoryVisible, available: visibleFrame.size)
        frame.origin.x = visibleFrame.midX - frame.width / 2
        frame.origin.y = max(visibleFrame.minY + 16, visibleFrame.maxY - frame.height - 112)
        panel.setFrame(frame, display: false)
    }
}
