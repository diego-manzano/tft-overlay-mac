import SwiftUI

@main
struct TFTOverlayApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @ObservedObject private var lcu = LCUClient.shared
    @AppStorage(LCUClient.autoShowKey) private var autoShow = true

    var body: some Scene {
        MenuBarExtra {
            Button("Toggle Overlay") { OverlayPanelController.shared.toggle() }
                .keyboardShortcut(.space, modifiers: .option)
            Toggle("Auto-show in game", isOn: $autoShow)
            Divider()
            Text(lcu.phase == "Disconnected"
                ? "League: not running"
                : "League: \(lcu.phase)\(lcu.isTFTGame ? " (TFT)" : "")")
            Text("Data: \(MetaStore.shared.snapshotLabel)")
            Divider()
            Button("Quit TFT Overlay") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        } label: {
            Image(systemName: "square.stack.3d.up.fill")
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        HotkeyManager.shared.register { OverlayPanelController.shared.toggle() }
        LCUClient.shared.start()
        OverlayPanelController.shared.show()
    }
}
