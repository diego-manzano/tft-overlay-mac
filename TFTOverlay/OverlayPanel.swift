import AppKit
import SwiftUI

/// Borderless floating panel that stays above fullscreen games.
/// No injection, no hooks — just a very insistent window.
final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

final class OverlayPanelController {
    static let shared = OverlayPanelController()
    private var panel: OverlayPanel?

    func toggle() {
        if let panel, panel.isVisible {
            panel.orderOut(nil)
        } else {
            show()
        }
    }

    func show() {
        if panel == nil { panel = makePanel() }
        panel?.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func makePanel() -> OverlayPanel {
        let panel = OverlayPanel(
            contentRect: NSRect(x: 120, y: 140, width: 390, height: 580),
            styleMask: [.borderless, .nonactivatingPanel, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.minSize = NSSize(width: 300, height: 460)
        let hosting = NSHostingView(rootView: OverlayRootView())
        // Push SwiftUI's min frame up to the window so edge-drag resizing
        // can't squeeze the panel below a readable width.
        hosting.sizingOptions = [.minSize]
        panel.contentView = hosting
        panel.setFrameAutosaveName("TFTOverlayPanel")
        // A previously saved frame may be smaller than the current minimum.
        if panel.frame.width < panel.minSize.width || panel.frame.height < panel.minSize.height {
            var frame = panel.frame
            frame.size.width = max(frame.width, panel.minSize.width)
            frame.size.height = max(frame.height, panel.minSize.height)
            panel.setFrame(frame, display: false)
        }
        return panel
    }
}
