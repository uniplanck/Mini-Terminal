import AppKit
import Foundation

final class AppModel: ObservableObject {
    @Published var command = ""
    @Published var output = ""
    @Published var isRunning = false
    @Published var isSplitView = false
    @Published var exitCode: Int32?
    @Published var duration: TimeInterval?
    @Published var showDangerousAlert = false
    @Published var isHistoryVisible = false
    @Published var copyFeedback: String?

    let settings: SettingsStore
    let historyStore: HistoryStore

    private let runner = ShellRunner()
    private var pendingDangerousCommand: String?
    private var historyCursor: Int?
    private var commandBeforeHistoryRecall = ""
    private var copyFeedbackWorkItem: DispatchWorkItem?

    init(
        settings: SettingsStore = SettingsStore(),
        historyStore: HistoryStore = HistoryStore()
    ) {
        self.settings = settings
        self.historyStore = historyStore
    }

    func prepareForPresentation() {
        guard settings.pasteClipboardOnOpen,
              let clipboard = NSPasteboard.general.string(forType: .string),
              !clipboard.isEmpty else {
            return
        }

        command = clipboard

        if settings.autoRunAfterPaste {
            execute()
        }
    }

    func execute(force: Bool = false) {
        let candidate = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidate.isEmpty, !isRunning else { return }

        if settings.confirmDangerousCommands,
           !force,
           CommandSafety.requiresConfirmation(candidate) {
            pendingDangerousCommand = candidate
            showDangerousAlert = true
            return
        }

        output = ""
        exitCode = nil
        duration = nil
        historyCursor = nil
        commandBeforeHistoryRecall = ""
        isRunning = true

        runner.run(
            command: candidate,
            shellPath: settings.shellPath,
            workingDirectory: settings.workingDirectory
        ) { [weak self] result in
            guard let self else { return }
            self.output = result.combinedOutput
            self.duration = result.duration

            self.historyStore.add(
                command: candidate,
                output: result.combinedOutput,
                exitCode: result.exitCode,
                duration: result.duration
            )

            if self.settings.copyOutputAfterRun {
                self.copyToClipboard(
                    result.combinedOutput,
                    feedback: self.settings.text(.copyOutputFeedback)
                )
            }

            self.isRunning = false
            self.exitCode = result.exitCode
        }
    }

    func confirmDangerousExecution() {
        guard let pendingDangerousCommand else { return }
        command = pendingDangerousCommand
        self.pendingDangerousCommand = nil
        showDangerousAlert = false
        execute(force: true)
    }

    func cancelDangerousExecution() {
        pendingDangerousCommand = nil
        showDangerousAlert = false
    }

    func copyInput() {
        copyToClipboard(command, feedback: settings.text(.copyInputFeedback))
    }

    func copyOutput() {
        copyToClipboard(output, feedback: settings.text(.copyOutputFeedback))
    }

    func copyInputAndOutput() {
        let combined = """
        INPUT
        \(command)

        OUTPUT
        \(output)
        """
        copyToClipboard(combined, feedback: settings.text(.copyBothFeedback))
    }

    func toggleLaunchAutoRun() {
        if settings.autoRunAfterPaste {
            settings.autoRunAfterPaste = false
        } else {
            settings.pasteClipboardOnOpen = true
            settings.autoRunAfterPaste = true
        }
    }

    func restoreHistory(_ entry: HistoryEntry) {
        command = entry.command
        output = entry.output
        exitCode = entry.exitCode
        duration = entry.duration
        historyCursor = nil
        commandBeforeHistoryRecall = ""
        isHistoryVisible = false
    }

    func recallPreviousCommand() {
        let entries = historyStore.entries
        guard !entries.isEmpty else { return }

        if historyCursor == nil {
            commandBeforeHistoryRecall = command
            historyCursor = 0
        } else if let cursor = historyCursor, cursor < entries.count - 1 {
            historyCursor = cursor + 1
        }

        if let cursor = historyCursor {
            command = entries[cursor].command
        }
    }

    func recallNextCommand() {
        guard let cursor = historyCursor else { return }

        if cursor > 0 {
            historyCursor = cursor - 1
            command = historyStore.entries[cursor - 1].command
        } else {
            historyCursor = nil
            command = commandBeforeHistoryRecall
            commandBeforeHistoryRecall = ""
        }
    }

    private func copyToClipboard(_ value: String, feedback: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)

        copyFeedbackWorkItem?.cancel()
        copyFeedback = feedback

        let workItem = DispatchWorkItem { [weak self] in
            self?.copyFeedback = nil
        }
        copyFeedbackWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: workItem)
    }
}
