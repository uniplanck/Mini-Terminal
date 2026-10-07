import AppKit
import SwiftUI

final class LauncherPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()

    private let hotKeyManager = HotKeyManager()
    private var statusItem: NSStatusItem?
    private var launcherPanel: LauncherPanel?
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        model.settings.onShortcutChanged = { [weak self] shortcut in
            _ = self?.hotKeyManager.register(shortcut)
        }

        model.settings.onLanguageChanged = { [weak self] in
            self?.refreshLocalizedChrome()
        }

        hotKeyManager.onHotKey = { [weak self] in
            self?.toggleLauncher()
        }

        _ = hotKeyManager.register(model.settings.shortcut)
        configureStatusItem()
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
        model.prepareForPresentation()

        let panel = launcherPanel ?? makeLauncherPanel()
        launcherPanel = panel
        resizeLauncher(split: model.isSplitView, animated: false)
        positionLauncher(panel)

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
            NotificationCenter.default.post(name: .miniTerminalFocusCommand, object: nil)
        }
    }

    private func hideLauncher() {
        launcherPanel?.orderOut(nil)
    }

    @objc private func showSettings() {
        hideLauncher()

        let window = settingsWindow ?? makeSettingsWindow()
        settingsWindow = window
        window.title = model.settings.text(.settingsTitle)

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
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
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 92),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.hidesOnDeactivate = true
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
        let content = SettingsView(settings: model.settings)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 520),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        window.title = model.settings.text(.settingsTitle)
        window.contentView = NSHostingView(rootView: content)
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        window.center()
        return window
    }

    private func resizeLauncher(split: Bool, animated: Bool) {
        guard let panel = launcherPanel else { return }

        let targetSize: NSSize
        if model.isHistoryVisible {
            targetSize = NSSize(width: 720, height: 430)
        } else if split {
            targetSize = NSSize(width: 900, height: 430)
        } else {
            targetSize = NSSize(width: 720, height: model.exitCode == nil && !model.isRunning ? 58 : 92)
        }

        var frame = panel.frame
        let top = frame.maxY
        frame.size = targetSize
        frame.origin.y = top - targetSize.height

        if animated {
            panel.animator().setFrame(frame, display: true)
        } else {
            panel.setFrame(frame, display: true)
        }
    }

    private func positionLauncher(_ panel: NSPanel) {
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) } ?? NSScreen.main

        guard let visibleFrame = screen?.visibleFrame else {
            panel.center()
            return
        }

        var frame = panel.frame
        frame.origin.x = visibleFrame.midX - frame.width / 2
        frame.origin.y = visibleFrame.maxY - frame.height - 110
        panel.setFrame(frame, display: false)
    }
}
