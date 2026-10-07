import SwiftUI

extension Notification.Name {
    static let miniTerminalFocusCommand = Notification.Name("MiniTerminalFocusCommand")
}

struct LauncherView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var settings: SettingsStore
    @ObservedObject var historyStore: HistoryStore
    let onClose: () -> Void
    let onOpenSettings: () -> Void
    let onSplitChanged: (Bool) -> Void
    let onExecutionStateChanged: () -> Void
    @FocusState private var commandFocused: Bool
    @State private var confirmsHistoryClear = false

    private var autoRunEnabled: Bool { settings.pasteClipboardOnOpen && settings.autoRunAfterPaste }

    var body: some View {
        VStack(spacing: 0) {
            commandBar
            if model.isHistoryVisible {
                historyContent
                historyFooter
            } else {
                if model.isSplitView { splitContent }
                statusBar
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: UIParameters.outerRadius))
        .clipShape(RoundedRectangle(cornerRadius: UIParameters.outerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: UIParameters.outerRadius)
                .strokeBorder(UIColors.separator.opacity(0.65), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .onExitCommand {
            if model.isHistoryVisible {
                model.isHistoryVisible = false
                onSplitChanged(model.isSplitView)
            } else { onClose() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .miniTerminalFocusCommand)) { _ in commandFocused = true }
        .onChange(of: model.isRunning) { _, running in
            onExecutionStateChanged()
            if !running && NSApp.keyWindow is LauncherPanel { commandFocused = true }
        }
        .onChange(of: model.exitCode) { _, _ in onExecutionStateChanged() }
        .alert(settings.text(.executionConfirmTitle), isPresented: $model.showDangerousAlert) {
            Button(settings.text(.cancel), role: .cancel) { model.cancelDangerousExecution() }
            Button(settings.text(.run), role: .destructive) { model.confirmDangerousExecution() }
        } message: {
            Text(settings.text(.executionConfirmMessage) + "\n\n" + model.command)
        }
        .confirmationDialog(settings.text(.clearHistoryConfirmTitle), isPresented: $confirmsHistoryClear, titleVisibility: .visible) {
            Button(settings.text(.clearHistory), role: .destructive) { historyStore.clear() }
            Button(settings.text(.cancel), role: .cancel) {}
        } message: { Text(settings.text(.clearHistoryConfirmMessage)) }
    }

    private var commandBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "terminal")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(UIColors.muted)
                .frame(width: 24)
            TextField(settings.text(.shellCommandPlaceholder), text: $model.command)
                .textFieldStyle(.plain)
                .font(UIParameters.codeFont)
                .frame(maxWidth: .infinity, minHeight: UIParameters.commandFieldHeight)
                .focused($commandFocused)
                .disabled(model.isRunning)
                .accessibilityIdentifier("launcher.command")
                .accessibilityLabel(settings.text(.inputTitle))
                .onSubmit { model.execute() }
                .onKeyPress(.upArrow) { model.recallPreviousCommand(); return .handled }
                .onKeyPress(.downArrow) { model.recallNextCommand(); return .handled }

            ToolbarButton(systemName: "play.fill", label: settings.text(.run), identifier: "launcher.run",
                          title: settings.text(.run), primary: true) { model.execute() }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(model.command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isRunning)

            AccessibleIconButton(systemName: model.isHistoryVisible ? "clock.fill" : "clock",
                                 label: settings.text(.history), identifier: "launcher.history", selected: model.isHistoryVisible) {
                model.isHistoryVisible.toggle()
                onSplitChanged(model.isSplitView)
            }
            AccessibleIconButton(systemName: autoRunEnabled ? "bolt.fill" : "bolt.slash",
                                 label: settings.text(autoRunEnabled ? .launchAutoRunOn : .launchAutoRunOff),
                                 identifier: "launcher.autoRun", selected: autoRunEnabled) { model.toggleLaunchAutoRun() }
                .accessibilityValue(settings.text(autoRunEnabled ? .enabled : .disabled))
            AccessibleIconButton(systemName: model.isSplitView ? "rectangle.compress.vertical" : "rectangle.split.2x1",
                                 label: settings.text(model.isSplitView ? .compactView : .splitView),
                                 identifier: "launcher.splitView", selected: model.isSplitView) {
                model.isSplitView.toggle()
                model.isHistoryVisible = false
                onSplitChanged(model.isSplitView)
            }
            AccessibleIconButton(systemName: "gearshape", label: settings.text(.settings), identifier: "launcher.settings", action: onOpenSettings)
        }
        .padding(.horizontal, 12)
        .frame(height: UIParameters.compactCommandHeight)
        .overlay(alignment: .bottom) { Divider() }
    }

    private var historyContent: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if historyStore.entries.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "clock").font(.system(size: 24, weight: .light))
                        Text(settings.text(.historyEmpty)).font(UIParameters.bodyFont)
                    }
                    .foregroundStyle(UIColors.muted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 64)
                } else {
                    ForEach(historyStore.entries) { entry in
                        HistoryRow(entry: entry, settings: settings, disabled: model.isRunning) {
                            model.restoreHistory(entry)
                            onSplitChanged(model.isSplitView)
                            commandFocused = true
                        }
                    }
                }
            }
        }
        .background(UIColors.surface)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var historyFooter: some View {
        HStack(spacing: 12) {
            Label(settings.historyCount(historyStore.entries.count), systemImage: "clock")
                .font(UIParameters.detailFont).foregroundStyle(UIColors.muted)
            Spacer()
            Button(settings.text(.clearHistory), role: .destructive) { confirmsHistoryClear = true }
                .buttonStyle(.borderless)
                .font(UIParameters.labelFont)
                .frame(minHeight: UIParameters.toolbarTarget)
                .disabled(historyStore.entries.isEmpty || model.isRunning)
                .accessibilityIdentifier("history.clear")
        }
        .padding(.horizontal, 16)
        .frame(height: UIParameters.statusHeight)
        .overlay(alignment: .top) { Divider() }
    }

    private var splitContent: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                paneHeader(.inputTitle, copy: .copyInput, identifier: "launcher.copyInput", action: model.copyInput)
                TextEditor(text: $model.command)
                    .font(UIParameters.codeFont)
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .disabled(model.isRunning)
                    .accessibilityLabel(settings.text(.inputTitle))
                    .accessibilityIdentifier("launcher.multilineCommand")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            VStack(spacing: 0) {
                paneHeader(.outputTitle, copy: .copyOutput, identifier: "launcher.copyOutput", action: model.copyOutput)
                GeometryReader { geometry in
                    ScrollView([.vertical, .horizontal]) {
                        Text(model.output.isEmpty ? outputPlaceholder : model.output)
                            .font(UIParameters.codeFont)
                            .foregroundStyle(model.output.isEmpty ? UIColors.muted : Color.primary)
                            .textSelection(.enabled)
                            .padding(16)
                            .frame(minWidth: geometry.size.width, minHeight: geometry.size.height, alignment: .topLeading)
                            .accessibilityIdentifier("launcher.output")
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(UIColors.surface)
    }

    private func paneHeader(_ title: L10n.Key, copy: L10n.Key, identifier: String, action: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Text(settings.text(title)).font(UIParameters.labelFont).foregroundStyle(UIColors.muted)
            Spacer()
            AccessibleIconButton(systemName: "doc.on.doc", label: settings.text(copy), identifier: identifier, action: action)
                .disabled(title == .outputTitle && (model.isRunning || model.exitCode == nil))
        }
        .padding(.horizontal, 16)
        .frame(height: UIParameters.paneHeaderHeight)
        .overlay(alignment: .bottom) { Divider() }
    }

    private var statusBar: some View {
        HStack(spacing: 12) {
            statusSummary.fixedSize()
            if let feedback = model.copyFeedback {
                Label(feedback, systemImage: "checkmark")
                    .font(UIParameters.labelFont)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .accessibilityIdentifier("launcher.copyFeedback")
            } else {
                Label(settings.workingDirectory, systemImage: "folder")
                    .font(UIParameters.detailFont)
                    .foregroundStyle(UIColors.muted)
                    .lineLimit(1).truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .help(settings.text(.workingDirectory) + ": " + settings.workingDirectory)
            }
            Text("⌘↩").font(UIParameters.detailFont).foregroundStyle(UIColors.muted)
                .help(settings.text(.keyboardRunHint))
            AccessibleIconButton(systemName: "doc.on.doc", label: settings.text(model.isSplitView ? .copyBoth : .copyOutput),
                                 identifier: model.isSplitView ? "launcher.copyBoth" : "launcher.copyOutputCompact") {
                if model.isSplitView { model.copyInputAndOutput() } else { model.copyOutput() }
            }
            .disabled(model.isRunning || model.exitCode == nil)
        }
        .padding(.horizontal, 16)
        .frame(height: UIParameters.statusHeight)
        .overlay(alignment: .top) { Divider() }
    }

    @ViewBuilder private var statusSummary: some View {
        if model.isRunning {
            ProgressView().controlSize(.small).frame(width: 16)
            Text(settings.text(.running)).font(UIParameters.detailFont).foregroundStyle(UIColors.muted)
        } else if let code = model.exitCode {
            Label("exit \(code)", systemImage: code == 0 ? "checkmark.circle" : "exclamationmark.circle.fill")
                .font(UIParameters.detailFont)
                .foregroundStyle(code == 0 ? Color.primary : UIColors.error)
                .accessibilityLabel(settings.text(code == 0 ? .completed : .executionFailed) + ", exit \(code)")
            if let duration = model.duration {
                Text(String(format: "%.0f ms", duration * 1_000)).font(UIParameters.detailFont).foregroundStyle(UIColors.muted)
            }
        } else {
            Label(settings.text(.ready), systemImage: "circle").font(UIParameters.detailFont).foregroundStyle(UIColors.muted)
        }
    }

    private var outputPlaceholder: String {
        if model.isRunning { return settings.text(.running) }
        if let code = model.exitCode { return settings.text(code == 0 ? .completedNoOutput : .executionFailed) }
        return settings.text(.outputPlaceholder)
    }
}

private struct HistoryRow: View {
    let entry: HistoryEntry
    let settings: SettingsStore
    let disabled: Bool
    let action: () -> Void
    @State private var hovered = false
    @FocusState private var focused: Bool

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(entry.createdAt.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                    .font(UIParameters.detailFont).foregroundStyle(UIColors.muted).frame(width: 120, alignment: .leading)
                Text(entry.command.replacingOccurrences(of: "\n", with: " "))
                    .font(UIParameters.codeFont).frame(maxWidth: .infinity, alignment: .leading)
                Label("\(entry.exitCode)", systemImage: entry.exitCode == 0 ? "checkmark.circle" : "exclamationmark.circle")
                    .font(UIParameters.detailFont).foregroundStyle(entry.exitCode == 0 ? UIColors.muted : UIColors.error)
                Text(String(format: "%.0f ms", entry.duration * 1_000))
                    .font(UIParameters.detailFont).foregroundStyle(UIColors.muted).frame(width: 64, alignment: .trailing)
            }
            .lineLimit(1)
            .padding(.horizontal, 16)
            .frame(height: UIParameters.historyRowHeight)
            .contentShape(Rectangle())
            .background(hovered && !disabled ? Color.primary.opacity(0.06) : Color.clear)
            .overlay(alignment: .bottom) { Rectangle().fill(UIColors.separator).frame(height: 0.5).padding(.leading, 16).allowsHitTesting(false) }
        }
        .buttonStyle(.plain)
        .focused($focused)
        .overlay { RoundedRectangle(cornerRadius: 4).strokeBorder(focused ? UIColors.focus : .clear, lineWidth: 2).allowsHitTesting(false) }
        .onHover { hovered = $0 }
        .disabled(disabled)
        .help(entry.command)
        .accessibilityLabel(entry.command + ", exit \(entry.exitCode)")
        .accessibilityIdentifier("history.entry.\(entry.id.uuidString)")
    }
}
