import AppKit
import SwiftUI

struct MenuPanelView: View {
    @EnvironmentObject private var model: AppModel

    private var isReady: Bool {
        model.receiverConnected && model.hasInputMonitoring && model.hasAccessibility
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "waveform.badge.mic")
                    .font(.title2)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("MicTrigger")
                        .font(.headline)
                    Text(isReady ? "Ready for remote presses" : "Setup needs attention")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("Enabled", isOn: $model.preferences.isEnabled)
                    .labelsHidden()
            }

            if !model.hasInputMonitoring || !model.hasAccessibility {
                VStack(alignment: .leading, spacing: 9) {
                    Label("Two permissions are needed to receive the button and send shortcuts.", systemImage: "lock.shield")
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Enable MicTrigger") {
                        model.requestPermissions()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(12)
                .background(Color.accentColor.opacity(0.09), in: RoundedRectangle(cornerRadius: 12))
            }

            HStack(spacing: 7) {
                StatusBadge(label: "Receiver", isReady: model.receiverConnected)
                StatusBadge(label: "Input", isReady: model.hasInputMonitoring)
                StatusBadge(label: "Shortcuts", isReady: model.hasAccessibility)
            }

            Divider()

            VStack(spacing: 8) {
                ForEach(model.preferences.mappings.sorted(by: { $0.pressCount < $1.pressCount })) { mapping in
                    HStack {
                        Text("\(mapping.pressCount)×")
                            .font(.system(.callout, design: .rounded, weight: .semibold))
                            .frame(width: 28, height: 28)
                            .background(.quaternary, in: Circle())
                        VStack(alignment: .leading, spacing: 1) {
                            Text(mapping.title)
                                .font(.callout.weight(.medium))
                            Text(mapping.behavior == .toggleHold
                                 ? "\(mapping.action.display) · Toggle hold\(mapping.releaseFollowUp == .pressReturn ? " → ↩" : "")"
                                 : mapping.action.display)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
            }

            Text(model.lastTrigger)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                SettingsLink {
                    Text("Settings…")
                }
                Spacer()
                Button("Quit") {
                    model.shutdown()
                    NSApp.terminate(nil)
                }
            }
        }
        .padding(16)
        .frame(width: 340)
    }
}
