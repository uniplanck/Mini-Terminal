import AppKit
import SwiftUI

/// Text view that reports Esc instead of swallowing it, unless an input method
/// is composing text and needs the key itself.
final class LauncherTextView: NSTextView {
    var onEscape: () -> Void = {}

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53, !hasMarkedText() {
            onEscape()
            return
        }
        super.keyDown(with: event)
    }
}

private func makeScrollableTextView(inset: NSSize, identifier: String) -> (NSScrollView, LauncherTextView) {
    let textView = LauncherTextView(usingTextLayoutManager: false)
    textView.minSize = .zero
    textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
    textView.isVerticallyResizable = true
    textView.isHorizontallyResizable = false
    textView.autoresizingMask = [.width]
    textView.textContainer?.widthTracksTextView = true
    textView.textContainerInset = inset
    textView.drawsBackground = false
    textView.isRichText = false
    textView.importsGraphics = false
    textView.usesFontPanel = false
    textView.font = UIParameters.codeNSFont
    textView.textColor = .labelColor
    textView.setAccessibilityIdentifier(identifier)

    // Shell text must reach the shell exactly as typed.
    textView.isAutomaticQuoteSubstitutionEnabled = false
    textView.isAutomaticDashSubstitutionEnabled = false
    textView.isAutomaticTextReplacementEnabled = false
    textView.isAutomaticSpellingCorrectionEnabled = false
    textView.isAutomaticTextCompletionEnabled = false
    textView.isAutomaticLinkDetectionEnabled = false
    textView.isAutomaticDataDetectionEnabled = false
    textView.isContinuousSpellCheckingEnabled = false
    textView.isGrammarCheckingEnabled = false

    let scrollView = NSScrollView()
    scrollView.drawsBackground = false
    scrollView.borderType = .noBorder
    scrollView.hasVerticalScroller = true
    scrollView.autohidesScrollers = true
    scrollView.documentView = textView
    return (scrollView, textView)
}

// MARK: - Command input

/// Editable command text. Stays selectable and scrollable while a command runs.
final class CommandInputController: NSObject, NSTextViewDelegate {
    let scrollView: NSScrollView
    let textView: LauncherTextView
    private let inset: NSSize

    var returnRuns = false
    var takesFocusOnRequest = false
    var onTextChange: (String) -> Void = { _ in }
    var onSubmit: () -> Void = {}
    var onHistoryPrevious: (() -> Void)?
    var onHistoryNext: (() -> Void)?
    var onContentHeightChange: ((CGFloat) -> Void)?
    private var reportedHeight: CGFloat = -1

    init(inset: NSSize, identifier: String) {
        self.inset = inset
        (scrollView, textView) = makeScrollableTextView(inset: inset, identifier: identifier)
        super.init()
        textView.allowsUndo = true
        textView.delegate = self
        textView.postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(self, selector: #selector(frameChanged),
                                               name: NSView.frameDidChangeNotification, object: textView)
        NotificationCenter.default.addObserver(self, selector: #selector(focusRequested),
                                               name: .miniTerminalFocusCommand, object: nil)
    }

    func apply(text: String, isEditable: Bool) {
        if textView.string != text {
            textView.string = text
            textView.setSelectedRange(NSRange(location: (text as NSString).length, length: 0))
            reportContentHeight()
        }
        if textView.isEditable != isEditable { textView.isEditable = isEditable }
        textView.isSelectable = true
    }

    /// Height the text needs, including the vertical inset.
    var contentHeight: CGFloat {
        guard let layoutManager = textView.layoutManager, let container = textView.textContainer else { return 0 }
        layoutManager.ensureLayout(for: container)
        let lineHeight = layoutManager.defaultLineHeight(for: UIParameters.codeNSFont)
        return ceil(max(layoutManager.usedRect(for: container).height, lineHeight)) + inset.height * 2
    }

    func handle(_ selector: Selector, modifiers: NSEvent.ModifierFlags) -> Bool {
        switch selector {
        case #selector(NSResponder.insertNewline(_:)):
            guard returnRuns else { return false }
            if modifiers.contains(.shift) {
                textView.insertNewlineIgnoringFieldEditor(nil)
            } else {
                onSubmit()
            }
            return true
        case #selector(NSResponder.moveUp(_:)):
            guard let onHistoryPrevious, caretLine.isFirst else { return false }
            onHistoryPrevious()
            return true
        case #selector(NSResponder.moveDown(_:)):
            guard let onHistoryNext, caretLine.isLast else { return false }
            onHistoryNext()
            return true
        default:
            return false
        }
    }

    func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        handle(commandSelector, modifiers: NSApp.currentEvent?.modifierFlags ?? [])
    }

    func textDidChange(_ notification: Notification) {
        onTextChange(textView.string)
        reportContentHeight()
    }

    /// Whether the caret sits on the first or last displayed line, where ↑ and ↓
    /// have nowhere to go inside the text and recall history instead.
    private var caretLine: (isFirst: Bool, isLast: Bool) {
        let length = (textView.string as NSString).length
        guard length > 0, let layoutManager = textView.layoutManager else { return (true, true) }
        let selection = textView.selectedRange()
        guard selection.length == 0 else { return (false, false) }
        let endsWithNewline = textView.string.hasSuffix("\n")
        if selection.location == length && endsWithNewline { return (false, true) }

        let glyph = layoutManager.glyphIndexForCharacter(at: min(selection.location, length - 1))
        var fragment = NSRange()
        layoutManager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: &fragment)
        return (fragment.location == 0, NSMaxRange(fragment) >= layoutManager.numberOfGlyphs && !endsWithNewline)
    }

    private func reportContentHeight() {
        guard let onContentHeightChange, textView.bounds.width > 0 else { return }
        let height = contentHeight
        guard height != reportedHeight else { return }
        reportedHeight = height
        DispatchQueue.main.async { onContentHeightChange(height) }
    }

    @objc private func frameChanged() { reportContentHeight() }

    @objc private func focusRequested() {
        guard takesFocusOnRequest else { return }
        textView.window?.makeFirstResponder(textView)
    }
}

struct CommandInput: NSViewRepresentable {
    @Binding var text: String
    var isEditable = true
    /// Return runs the command and ↑ / ↓ recall history, as in a one-line field.
    var actsAsField = false
    var takesFocusOnRequest = false
    var showsScroller = true
    var inset = NSSize(width: 12, height: 12)
    let identifier: String
    let label: String
    var onSubmit: () -> Void = {}
    var onHistoryPrevious: () -> Void = {}
    var onHistoryNext: () -> Void = {}
    var onEscape: () -> Void = {}
    var onContentHeightChange: ((CGFloat) -> Void)?

    func makeCoordinator() -> CommandInputController {
        CommandInputController(inset: inset, identifier: identifier)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let controller = context.coordinator
        if actsAsField { controller.textView.textContainer?.lineFragmentPadding = 0 }
        return controller.scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let controller = context.coordinator
        let binding = $text
        controller.onTextChange = { binding.wrappedValue = $0 }
        controller.returnRuns = actsAsField
        controller.takesFocusOnRequest = takesFocusOnRequest
        controller.onSubmit = onSubmit
        controller.onHistoryPrevious = actsAsField ? onHistoryPrevious : nil
        controller.onHistoryNext = actsAsField ? onHistoryNext : nil
        controller.onContentHeightChange = onContentHeightChange
        controller.textView.onEscape = onEscape
        controller.textView.setAccessibilityLabel(label)
        scrollView.hasVerticalScroller = showsScroller
        controller.apply(text: text, isEditable: isEditable)
    }
}

// MARK: - Output

/// Shared between the output view and the button that returns to the newest output.
final class OutputScrollState: ObservableObject {
    /// False once the reader has scrolled away from the end; new output then leaves the view alone.
    @Published fileprivate(set) var isFollowing = true
    fileprivate weak var controller: OutputTextController?

    func jumpToLatest() {
        controller?.jumpToLatest()
    }
}

/// Read-only output text that appends as output arrives and keeps the end in
/// view only while the reader is already there.
final class OutputTextController: NSObject {
    let scrollView: NSScrollView
    let textView: LauncherTextView
    private(set) var isFollowing = true
    private(set) var wrapsLines = true
    weak var state: OutputScrollState? {
        didSet {
            state?.controller = self
            DispatchQueue.main.async { [state, isFollowing] in state?.isFollowing = isFollowing }
        }
    }

    private var shownGeneration: UUID?
    private var shownCommittedCount = 0
    private var shownCurrentLine = ""
    private var isAdjusting = false
    private let attributes: [NSAttributedString.Key: Any] = [
        .font: UIParameters.codeNSFont,
        .foregroundColor: NSColor.labelColor
    ]

    init(identifier: String) {
        (scrollView, textView) = makeScrollableTextView(inset: NSSize(width: 12, height: 12), identifier: identifier)
        super.init()
        textView.isEditable = false
        textView.isSelectable = true
        scrollView.contentView.postsBoundsChangedNotifications = true
        scrollView.postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(self, selector: #selector(clipBoundsChanged),
                                               name: NSView.boundsDidChangeNotification, object: scrollView.contentView)
        NotificationCenter.default.addObserver(self, selector: #selector(scrollViewResized),
                                               name: NSView.frameDidChangeNotification, object: scrollView)
    }

    func render(_ buffer: OutputBuffer) {
        guard let storage = textView.textStorage else { return }
        let sameGeneration = buffer.generation == shownGeneration
        if sameGeneration, buffer.committedUTF16Count == shownCommittedCount, buffer.currentLine == shownCurrentLine {
            return
        }
        // A cleared buffer is a new run: start at the end again.
        if buffer.isEmpty { setFollowing(true) }

        // Everything before `stable` is already on screen and unchanged.
        let stable = sameGeneration ? min(shownCommittedCount, buffer.committedUTF16Count) : 0
        let tail = (buffer.committed as NSString).substring(from: stable) + buffer.currentLine
        isAdjusting = true
        storage.replaceCharacters(in: NSRange(location: stable, length: storage.length - stable),
                                  with: NSAttributedString(string: tail, attributes: attributes))
        isAdjusting = false

        shownGeneration = buffer.generation
        shownCommittedCount = buffer.committedUTF16Count
        shownCurrentLine = buffer.currentLine
        if isFollowing { scrollToEnd() }
    }

    func setWrapsLines(_ wraps: Bool) {
        guard wraps != wrapsLines, let container = textView.textContainer else { return }
        wrapsLines = wraps
        isAdjusting = true
        if wraps {
            scrollView.hasHorizontalScroller = false
            textView.isHorizontallyResizable = false
            container.widthTracksTextView = true
            textView.setFrameSize(NSSize(width: scrollView.contentSize.width, height: textView.frame.height))
        } else {
            scrollView.hasHorizontalScroller = true
            container.widthTracksTextView = false
            container.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            textView.isHorizontallyResizable = true
        }
        isAdjusting = false
        if isFollowing { scrollToEnd() }
    }

    func jumpToLatest() {
        setFollowing(true)
        scrollToEnd()
    }

    /// Re-reads the scroll position after the reader moved it.
    func readerDidScroll() {
        setFollowing(isAtEnd)
    }

    var isAtEnd: Bool {
        scrollView.contentView.bounds.maxY >= textView.frame.maxY - 8
    }

    private func scrollToEnd() {
        let clip = scrollView.contentView
        let horizontal = clip.bounds.origin.x
        isAdjusting = true
        textView.scrollRangeToVisible(NSRange(location: textView.textStorage?.length ?? 0, length: 0))
        // Following is about the newest line, not the far end of a long unwrapped one.
        if clip.bounds.origin.x != horizontal {
            clip.setBoundsOrigin(NSPoint(x: horizontal, y: clip.bounds.origin.y))
            scrollView.reflectScrolledClipView(clip)
        }
        isAdjusting = false
    }

    private func setFollowing(_ following: Bool) {
        guard following != isFollowing else { return }
        isFollowing = following
        DispatchQueue.main.async { [state] in state?.isFollowing = following }
    }

    @objc private func clipBoundsChanged() {
        // Only the reader can leave or rejoin the end; layout and our own scrolling cannot.
        guard !isAdjusting, let event = NSApp.currentEvent else { return }
        switch event.type {
        case .scrollWheel, .leftMouseDown, .leftMouseDragged, .leftMouseUp, .keyDown:
            readerDidScroll()
        default:
            break
        }
    }

    @objc private func scrollViewResized() {
        if isFollowing { scrollToEnd() }
    }
}

struct OutputPane: NSViewRepresentable {
    let buffer: OutputBuffer
    var wrapsLines = true
    let state: OutputScrollState
    let identifier: String
    let label: String
    var onEscape: () -> Void = {}

    func makeCoordinator() -> OutputTextController {
        OutputTextController(identifier: identifier)
    }

    func makeNSView(context: Context) -> NSScrollView {
        context.coordinator.state = state
        return context.coordinator.scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let controller = context.coordinator
        controller.textView.onEscape = onEscape
        controller.textView.setAccessibilityLabel(label)
        controller.setWrapsLines(wrapsLines)
        controller.render(buffer)
    }
}
