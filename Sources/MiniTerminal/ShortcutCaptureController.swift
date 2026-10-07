import AppKit

final class ShortcutCaptureController: ObservableObject {
    @Published var isRecording = false
    private var monitor: Any?

    deinit {
        stop()
    }

    func start(onCapture: @escaping (Shortcut) -> Void) {
        stop()
        isRecording = true

        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }

            if event.keyCode == 53 {
                self.stop()
                return nil
            }

            guard let shortcut = Shortcut.from(event: event) else {
                NSSound.beep()
                return nil
            }

            onCapture(shortcut)
            self.stop()
            return nil
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        isRecording = false
    }
}
