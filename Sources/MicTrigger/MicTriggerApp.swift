import AppKit
import SwiftUI

@main
struct MicTriggerApp: App {
    @StateObject private var model = AppModel()

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuPanelView()
                .environmentObject(model)
                .task { model.start() }
        } label: {
            Image(systemName: model.receiverConnected && model.preferences.isEnabled
                  ? "mic.fill"
                  : "mic.slash")
                .accessibilityLabel(model.receiverConnected ? "MicTrigger connected" : "MicTrigger disconnected")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(model)
        }
    }
}
