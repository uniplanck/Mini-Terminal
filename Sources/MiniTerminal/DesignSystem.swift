import SwiftUI

enum UIParameters {
    static let compactWidth: CGFloat = 720
    static let minimumWidth: CGFloat = 640
    static let splitWidth: CGFloat = 900
    static let historyHeight: CGFloat = 416
    static let expandedHeight: CGFloat = 480
    static let compactCommandHeight: CGFloat = 56
    static let toolbarTarget: CGFloat = 32
    static let commandFieldHeight: CGFloat = 40
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

    static func launcherSize(split: Bool, history: Bool, available: CGSize? = nil) -> CGSize {
        let desired = CGSize(width: split ? splitWidth : compactWidth,
                             height: history ? historyHeight : (split ? expandedHeight : compactCommandHeight + statusHeight))
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
