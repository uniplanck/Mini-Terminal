import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @StateObject private var shortcutCapture = ShortcutCaptureController()

    var body: some View {
        Form {
            Section(settings.text(.languageSection)) {
                Picker(settings.text(.languageLabel), selection: $settings.language) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .pickerStyle(.menu)

                Text(settings.text(.languageSystemHelp))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(settings.text(.shortcutSection)) {
                HStack {
                    Text(settings.text(.shortcutOpen))
                    Spacer()
                    Button(
                        shortcutCapture.isRecording
                            ? settings.text(.shortcutWaiting)
                            : settings.shortcut.displayString
                    ) {
                        shortcutCapture.start { shortcut in
                            settings.shortcut = shortcut
                        }
                    }
                    .frame(minWidth: 130)
                }

                Text(settings.text(.shortcutHelp))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(settings.text(.clipboardSection)) {
                Toggle(settings.text(.clipboardPaste), isOn: $settings.pasteClipboardOnOpen)
                Toggle(settings.text(.clipboardAutoRun), isOn: $settings.autoRunAfterPaste)
                    .disabled(!settings.pasteClipboardOnOpen)
                Toggle(settings.text(.clipboardCopyOutput), isOn: $settings.copyOutputAfterRun)
            }

            Section(settings.text(.safetySection)) {
                Toggle(settings.text(.safetyConfirm), isOn: $settings.confirmDangerousCommands)

                Text(settings.text(.safetyHelp))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(settings.text(.shellSection)) {
                TextField("/bin/zsh", text: $settings.shellPath)
                    .textFieldStyle(.roundedBorder)

                TextField(settings.text(.workingDirectory), text: $settings.workingDirectory)
                    .textFieldStyle(.roundedBorder)

                Text(settings.text(.shellTildeHelp))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(4)
        .frame(width: 560, height: 520)
    }
}
