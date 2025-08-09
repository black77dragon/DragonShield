import SwiftUI
import AppKit

@MainActor
final class TargetEditWindowController: NSWindowController, NSWindowDelegate {
    private let onClose: () -> Void

    init(classId: Int, dbManager: DatabaseManager, onClose: @escaping () -> Void) {
        self.onClose = onClose

        let window = NSWindow()
        let root = TargetEditPanel(classId: classId) { [weak window] in
            window?.performClose(nil)
        }
        .environmentObject(dbManager)
        .frame(minWidth: 800, minHeight: 600)

        let hosting = NSHostingController(rootView: root)
        window.contentViewController = hosting
        window.styleMask = [.titled, .closable, .resizable]
        window.level = .floating
        window.isReleasedWhenClosed = false
        let title = dbManager.fetchAssetClassDetails(id: classId)?.name ?? ""
        window.title = "Asset Allocation for \(title)"
        window.center()
        window.setFrameAutosaveName("TargetEditWindow-\(classId)")

        super.init(window: window)
        window.delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}

@MainActor
final class TargetEditorWindowManager {
    static let shared = TargetEditorWindowManager()
    private var controllers: [Int: TargetEditWindowController] = [:]

    func open(classId: Int, dbManager: DatabaseManager) {
        if let controller = controllers[classId] {
            controller.showWindow(nil)
            controller.window?.makeKeyAndOrderFront(nil)
            return
        }
        let controller = TargetEditWindowController(classId: classId, dbManager: dbManager) { [weak self] in
            NotificationCenter.default.post(name: .targetEditorClosed, object: classId)
            self?.controllers[classId] = nil
        }
        controllers[classId] = controller
        controller.showWindow(nil)
    }
}

extension Notification.Name {
    static let targetEditorClosed = Notification.Name("TargetEditorClosed")
}

