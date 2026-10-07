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

    var body: some View {
        VStack(spacing: 0) {
            commandBar

            if model.isHistoryVisible {
                Divider()
                historyContent
                Divider()
                historyFooter
            } else if model.isSplitView {
                Divider()
                splitContent
                Divider()
                statusBar
            } else if model.isRunning || model.exitCode != nil {
                compactStatus
            }
        }
        .frame(minWidth: model.isSplitView ? 900 : 720)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.10), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onExitCommand(perform: onClose)
        .onReceive(NotificationCenter.default.publisher(for: .miniTerminalFocusCommand)) { _ in
            commandFocused = true
        }
        .onChange(of: model.isRunning) { _, _ in
            onExecutionStateChanged()
        }
        .onChange(of: model.exitCode) { _, _ in
            onExecutionStateChanged()
        }
        .alert(settings.text(.executionConfirmTitle), isPresented: $model.showDangerousAlert) {
            Button(settings.text(.cancel), role: .cancel) {
                model.cancelDangerousExecution()
            }
            Button(settings.text(.run), role: .destructive) {
                model.confirmDangerousExecution()
            }
        } message: {
            Text(settings.text(.executionConfirmMessage))
        }
    }

    private var commandBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "terminal")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.secondary)

            TextField(settings.text(.shellCommandPlaceholder), text: $model.command)
                .textFieldStyle(.plain)
                .font(.system(.body, design: .monospaced))
                .focused($commandFocused)
                .onSubmit {
                    model.execute()
                }
                .onKeyPress(.upArrow) {
                    model.recallPreviousCommand()
                    return .handled
                }
                .onKeyPress(.downArrow) {
                    model.recallNextCommand()
                    return .handled
                }

            if let feedback = model.copyFeedback {
                Label(feedback, systemImage: "checkmark")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .transition(.opacity)
            }

            if model.isRunning {
                ProgressView()
                    .controlSize(.small)
            }

            Button {
                model.execute()
            } label: {
                Image(systemName: "play.fill")
            }
            .buttonStyle(.plain)
            .help(settings.text(.run))
            .disabled(model.command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isRunning)

            Button {
                withAnimation(.easeOut(duration: 0.12)) {
                    model.isHistoryVisible.toggle()
                }
                onSplitChanged(model.isSplitView)
            } label: {
                Image(systemName: model.isHistoryVisible ? "clock.fill" : "clock")
            }
            .buttonStyle(.plain)
            .help(settings.text(.history))

            Button {
                model.toggleLaunchAutoRun()
            } label: {
                Image(systemName: settings.autoRunAfterPaste ? "bolt.fill" : "bolt.slash")
                    .foregroundStyle(settings.autoRunAfterPaste ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)
            .help(
                settings.autoRunAfterPaste
                    ? settings.text(.launchAutoRunOn)
                    : settings.text(.launchAutoRunOff)
            )

            Button {
                model.isSplitView.toggle()
                model.isHistoryVisible = false
                onSplitChanged(model.isSplitView)
            } label: {
                Image(systemName: model.isSplitView ? "rectangle.compress.vertical" : "rectangle.split.2x1")
            }
            .buttonStyle(.plain)
            .help(model.isSplitView ? settings.text(.compactView) : settings.text(.splitView))

            Button(action: onOpenSettings) {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.plain)
            .help(settings.text(.settings))
        }
        .padding(.horizontal, 18)
        .frame(height: 58)
    }

    private var historyContent: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if historyStore.entries.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "clock")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text(settings.text(.historyEmpty))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 80)
                } else {
                    ForEach(historyStore.entries) { entry in
                        Button {
                            model.restoreHistory(entry)
                            onSplitChanged(model.isSplitView)
                        } label: {
                            HStack(spacing: 12) {
                                Text(entry.createdAt.formatted(date: .omitted, time: .shortened))
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 58, alignment: .leading)

                                Text(entry.command.replacingOccurrences(of: "\n", with: " "))
                                    .font(.system(.body, design: .monospaced))
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                Text("exit \(entry.exitCode)")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(entry.exitCode == 0 ? Color.secondary : Color.red)

                                Text(String(format: "%.0f ms", entry.duration * 1_000))
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 62, alignment: .trailing)
                            }
                            .contentShape(Rectangle())
                            .padding(.horizontal, 16)
                            .frame(height: 42)
                        }
                        .buttonStyle(.plain)

                        Divider()
                            .padding(.leading, 16)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var historyFooter: some View {
        HStack {
            Text(settings.historyCount(historyStore.entries.count))
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button(settings.text(.clearHistory), role: .destructive) {
                historyStore.clear()
            }
            .buttonStyle(.borderless)
            .disabled(historyStore.entries.isEmpty)
        }
        .padding(.horizontal, 14)
        .frame(height: 38)
    }

    private var splitContent: some View {
        HStack(spacing: 0) {
            inputPane

            Divider()

            outputPane
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var inputPane: some View {
        VStack(spacing: 0) {
            HStack {
                Text(settings.text(.inputTitle))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: model.copyInput) {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.plain)
                .help(settings.text(.copyInput))
            }
            .padding(.horizontal, 14)
            .frame(height: 36)

            Divider()

            TextEditor(text: $model.command)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var outputPane: some View {
        VStack(spacing: 0) {
            HStack {
                Text(settings.text(.outputTitle))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: model.copyOutput) {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.plain)
                .help(settings.text(.copyOutput))
            }
            .padding(.horizontal, 14)
            .frame(height: 36)

            Divider()

            ScrollView {
                Text(model.output.isEmpty ? outputPlaceholder : model.output)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(model.output.isEmpty ? .secondary : .primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var compactStatus: some View {
        HStack(spacing: 10) {
            statusSummary
            Spacer()
            if !model.output.isEmpty {
                Text(model.output.replacingOccurrences(of: "\n", with: " "))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Button(action: model.copyOutput) {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.plain)
                .help(settings.text(.copyOutput))
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 34)
        .background(Color.primary.opacity(0.035))
    }

    private var statusBar: some View {
        HStack(spacing: 14) {
            statusSummary
            Spacer()
            Button(settings.text(.copyBoth), action: model.copyInputAndOutput)
                .buttonStyle(.borderless)
        }
        .padding(.horizontal, 14)
        .frame(height: 38)
    }

    @ViewBuilder
    private var statusSummary: some View {
        if model.isRunning {
            Text(settings.text(.running))
                .font(.caption)
                .foregroundStyle(.secondary)
        } else if let exitCode = model.exitCode {
            Text("exit \(exitCode)")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(exitCode == 0 ? Color.secondary : Color.red)

            if let duration = model.duration {
                Text(String(format: "%.0f ms", duration * 1_000))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var outputPlaceholder: String {
        model.isRunning ? settings.text(.running) : settings.text(.outputPlaceholder)
    }
}
