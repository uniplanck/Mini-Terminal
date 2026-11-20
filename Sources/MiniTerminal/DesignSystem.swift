import SwiftUI

enum UIParameters {
    static let compactWidth: CGFloat = 720
    static let minimumWidth: CGFloat = 640
    static let splitWidth: CGFloat = 900
    static let historyHeight: CGFloat = 416
    static let expandedHeight: CGFloat = 480
    static let compactCommandHeight: CGFloat = 56
    static let toolbarTarget: CGFloat = 32
    static let paneHeaderHeight: CGFloat = 40
    static let statusHeight: CGFloat = 40
    static let historyRowHeight: CGFloat = 40
    static let outerRadius: CGFloat = 16
    static let controlRadius: CGFloat = 10
    static let settingsSize = CGSize(width: 600, height: 480)
    static let bodyFont = Font.system(size: 14)
    static let labelFont = Font.system(size: 13, weight: .medium)
    static let codeFont = Font.system(size: 14, design: .monospaced)
    static let detailFont = Font.system(size: 12, design: .monospaced)
    static let codeNSFont = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
    static let codeLineHeight = ceil(NSLayoutManager().defaultLineHeight(for: codeNSFont))
    static let commandFieldMaximumLines: CGFloat = 6
    static let compactOutputHeight: CGFloat = 280

    /// Height of the command field for text that needs `contentHeight`. The compact
    /// field grows with its text up to a few lines; beside the split editor it stays one line.
    static func commandFieldHeight(contentHeight: CGFloat, split: Bool) -> CGFloat {
        split ? codeLineHeight : min(max(contentHeight, codeLineHeight), codeLineHeight * commandFieldMaximumLines)
    }

    static func commandBarHeight(fieldHeight: CGFloat) -> CGFloat {
        compactCommandHeight + max(0, fieldHeight - codeLineHeight)
    }

    static func launcherSize(split: Bool, history: Bool, showsOutput: Bool = false,
                             commandFieldHeight: CGFloat = codeLineHeight, available: CGSize? = nil) -> CGSize {
        let body = history ? historyHeight - compactCommandHeight
            : split ? expandedHeight - compactCommandHeight
            : (showsOutput ? compactOutputHeight : 0) + statusHeight
        let desired = CGSize(width: split ? splitWidth : compactWidth,
                             height: commandBarHeight(fieldHeight: commandFieldHeight) + body)
        guard let available else { return desired }
        return CGSize(width: min(desired.width, max(0, available.width - 32)),
                      height: min(desired.height, max(0, available.height - 32)))
    }
}

enum UIColors {
    static let surface = Color(nsColor: .textBackgroundColor)
    static let secondarySurface = Color(nsColor: .controlBackgroundColor)
    static let separator = Color(nsColor: .separatorColor)
    static let muted = Color(nsColor: .secondaryLabelColor)
    static let error = Color(nsColor: .systemRed)
    static let focus = Color(nsColor: .keyboardFocusIndicatorColor)
}

struct ToolbarButtonStyle: ButtonStyle {
    var primary = false
    var selected = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        Surface(configuration: configuration, primary: primary, selected: selected, enabled: isEnabled)
    }

    private struct Surface: View {
        let configuration: Configuration
        let primary: Bool
        let selected: Bool
        let enabled: Bool
        @State private var hovered = false
        var body: some View {
            configuration.label
                .font(UIParameters.labelFont)
                .foregroundStyle(primary && enabled ? Color.white : Color.primary)
                .frame(height: UIParameters.toolbarTarget)
                .background {
                    RoundedRectangle(cornerRadius: UIParameters.controlRadius, style: .continuous)
                        .fill(primary && enabled ? Color.accentColor : UIColors.secondarySurface)
                    RoundedRectangle(cornerRadius: UIParameters.controlRadius, style: .continuous)
                        .fill(Color.primary.opacity(enabled && configuration.isPressed ? 0.14 : (enabled && hovered ? 0.07 : (selected ? 0.05 : 0))))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: UIParameters.controlRadius, style: .continuous)
                        .strokeBorder(selected ? Color.accentColor : UIColors.separator.opacity(0.55), lineWidth: selected ? 1.5 : 0.5)
                }
                .opacity(enabled ? 1 : 0.45)
                .contentShape(RoundedRectangle(cornerRadius: UIParameters.controlRadius))
                .onHover { hovered = $0 }
        }
    }
}

struct ToolbarButton: View {
    let systemName: String
    let label: String
    let identifier: String
    var title: String? = nil
    var selected = false
    var primary = false
    let action: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemName).frame(width: 16)
                if let title { Text(title).lineLimit(1) }
            }
            .padding(.horizontal, title == nil ? 8 : 12)
            .frame(minWidth: UIParameters.toolbarTarget)
        }
        .buttonStyle(ToolbarButtonStyle(primary: primary, selected: selected))
        .focused($focused)
        .overlay {
            RoundedRectangle(cornerRadius: UIParameters.controlRadius + 2)
                .strokeBorder(focused ? UIColors.focus : .clear, lineWidth: 2)
                .padding(-3)
                .allowsHitTesting(false)
        }
        .accessibleControl(label, identifier: identifier)
    }
}

struct AccessibleIconButton: View {
    let systemName: String
    let label: String
    let identifier: String
    var selected = false
    let action: () -> Void
    var body: some View {
        ToolbarButton(systemName: systemName, label: label, identifier: identifier, selected: selected, action: action)
    }
}

extension View {
    func accessibleControl(_ label: String, identifier: String) -> some View {
        self.help(label).accessibilityLabel(label).accessibilityIdentifier(identifier)
    }
}

enum DurationFormat {
    /// "850 ms", "12.3 s", "20m 05s", "1h 02m 03s": the unit follows the length of the run.
    static func string(_ duration: TimeInterval) -> String {
        let milliseconds = (max(0, duration) * 1_000).rounded()
        if milliseconds < 1_000 { return String(format: "%.0f ms", milliseconds) }
        let tenths = (duration * 10).rounded() / 10
        if tenths < 60 { return String(format: "%.1f s", tenths) }
        let seconds = Int(duration.rounded())
        if seconds < 3_600 { return String(format: "%dm %02ds", seconds / 60, seconds % 60) }
        return String(format: "%dh %02dm %02ds", seconds / 3_600, seconds % 3_600 / 60, seconds % 60)
    }
}
