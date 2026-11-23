import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var shortcutCapture: ShortcutCaptureController
    @State private var selectedSection: Int

    init(settings: SettingsStore, shortcutCapture: ShortcutCaptureController = ShortcutCaptureController(), initialSection: Int = 0) {
        self.settings = settings
        self.shortcutCapture = shortcutCapture
        _selectedSection = State(initialValue: initialSection)
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker(settings.text(.settings), selection: $selectedSection) {
                Text(settings.text(.shortcutSection)).tag(0)
                Text(settings.text(.clipboardSection)).tag(1)
                Text(settings.text(.shellSection)).tag(2)
            }
            .pickerStyle(.segmented).labelsHidden()
            .frame(minHeight: UIParameters.toolbarTarget)
            .padding(.horizontal, 24).padding(.vertical, 12)
            .accessibilityIdentifier("settings.sections")
            Divider()
            Group {
                if selectedSection == 0 { generalForm }
                else if selectedSection == 1 { clipboardForm }
                else { shellForm }
            }
            .formStyle(.grouped)
        }
        .font(UIParameters.bodyFont)
        .background(Color(nsColor: .windowBackgroundColor))
        .frame(minWidth: 520, idealWidth: UIParameters.settingsSize.width,
               minHeight: 420, idealHeight: UIParameters.settingsSize.height)
        .onChange(of: selectedSection) { _, _ in shortcutCapture.stop() }
        .onDisappear { shortcutCapture.stop() }
    }

    private var generalForm: some View {
        Form {
            Section(settings.text(.shortcutSection)) {
                HStack(spacing: 16) {
                    Text(settings.text(.shortcutOpen)).font(UIParameters.labelFont)
                    Spacer()
                    Button(shortcutCapture.isRecording ? settings.text(.shortcutWaiting) : settings.shortcut.displayString) {
                        shortcutCapture.start { settings.shortcut = $0 }
                    }
                    .buttonStyle(.bordered)
                    .font(UIParameters.detailFont)
                    .frame(minWidth: 144, minHeight: UIParameters.toolbarTarget)
                    .accessibilityIdentifier("settings.shortcut")
                }
                Text(settings.text(.shortcutHelp)).font(UIParameters.bodyFont).foregroundStyle(UIColors.muted)
            }
            Section(settings.text(.languageSection)) {
                Picker(settings.text(.languageLabel), selection: $settings.language) {
                    ForEach(AppLanguage.allCases) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.menu).frame(minHeight: UIParameters.toolbarTarget)
                .accessibilityIdentifier("settings.language")
                Text(settings.text(.languageSystemHelp)).font(UIParameters.bodyFont).foregroundStyle(UIColors.muted)
            }
        }
    }

    private var clipboardForm: some View {
        Form {
            Section(settings.text(.clipboardSection)) {
                Toggle(settings.text(.clipboardPaste), isOn: $settings.pasteClipboardOnOpen)
                    .frame(minHeight: UIParameters.toolbarTarget)
                    .accessibilityIdentifier("settings.pasteClipboard")
                Toggle(settings.text(.clipboardAutoRun), isOn: $settings.autoRunAfterPaste)
                    .frame(minHeight: UIParameters.toolbarTarget)
                    .disabled(!settings.pasteClipboardOnOpen)
                    .help(settings.text(.clipboardPaste))
                    .accessibilityIdentifier("settings.autoRun")
                Toggle(settings.text(.clipboardCopyOutput), isOn: $settings.copyOutputAfterRun)
                    .frame(minHeight: UIParameters.toolbarTarget)
                    .accessibilityIdentifier("settings.copyOutput")
            }
            Section(settings.text(.safetySection)) {
                Toggle(settings.text(.safetyConfirm), isOn: $settings.confirmDangerousCommands)
                    .frame(minHeight: UIParameters.toolbarTarget)
                    .accessibilityIdentifier("settings.safety")
                Text(settings.text(.safetyHelp)).font(UIParameters.bodyFont).foregroundStyle(UIColors.muted)
            }
        }
        .toggleStyle(.switch)
    }

    private var shellForm: some View {
        Form {
            Section(settings.text(.shellSection)) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(settings.text(.shellPathLabel)).font(UIParameters.labelFont)
                    TextField("", text: $settings.shellPath, prompt: Text("/bin/zsh"))
                        .labelsHidden().multilineTextAlignment(.leading)
                        .textFieldStyle(.roundedBorder).font(UIParameters.codeFont)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: UIParameters.toolbarTarget)
                        .accessibilityLabel(settings.text(.shellPathLabel))
                        .accessibilityIdentifier("settings.shellPath")
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text(settings.text(.workingDirectory)).font(UIParameters.labelFont)
                    TextField("", text: $settings.workingDirectory, prompt: Text("~"))
                        .labelsHidden().multilineTextAlignment(.leading)
                        .textFieldStyle(.roundedBorder).font(UIParameters.codeFont)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: UIParameters.toolbarTarget)
                        .accessibilityLabel(settings.text(.workingDirectory))
                        .accessibilityIdentifier("settings.workingDirectory")
                }
                Text(settings.text(.shellTildeHelp)).font(UIParameters.bodyFont).foregroundStyle(UIColors.muted)
            }
        }
    }
}
