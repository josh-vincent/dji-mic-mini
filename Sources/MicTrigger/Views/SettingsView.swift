import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                connectionSection
                permissionSection
                mappingsSection
                generalSection

                if let error = model.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(24)
        }
        .frame(width: 520, height: 650)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            model.start()
            model.refreshPermissions()
            model.refreshLinkedShortcuts()
        }
    }

    private var connectionSection: some View {
        SettingsSection(title: "Receiver", symbol: "cable.connector") {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: model.receiverConnected ? "checkmark.circle.fill" : "circle.dashed")
                    .font(.title2)
                    .foregroundStyle(model.receiverConnected ? .green : .secondary)
                VStack(alignment: .leading, spacing: 3) {
                    Text(model.receiverConnected ? "DJI receiver connected" : "Connect the receiver over USB-C")
                        .font(.headline)
                    Text("\(model.preferences.selectedDevice.productName) · \(model.preferences.selectedDevice.identifierSummary)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                Spacer()
            }

            HStack {
                Button(model.isLearning ? "Waiting for press…" : "Identify Shutter Button") {
                    model.isLearning ? model.cancelLearning() : model.beginLearning()
                }
                .buttonStyle(.borderedProminent)
                if model.isLearning {
                    ProgressView()
                        .controlSize(.small)
                    Button("Cancel") { model.cancelLearning() }
                        .buttonStyle(.plain)
                }
            }

            Text("Plug in the receiver, then press the transmitter’s link button once. Bluetooth-only audio does not expose the shutter event.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var permissionSection: some View {
        SettingsSection(title: "Permissions", symbol: "lock.shield") {
            PermissionRow(
                title: "Input Monitoring",
                detail: "Reads only the selected receiver’s shutter control.",
                isGranted: model.hasInputMonitoring,
                request: { _ = PermissionService.requestInputMonitoring() },
                openSettings: { model.openPermissionSettings(.inputMonitoring) }
            )
            Divider()
            PermissionRow(
                title: "Accessibility",
                detail: "Sends your configured shortcut to the active app.",
                isGranted: model.hasAccessibility,
                request: { _ = PermissionService.requestAccessibility() },
                openSettings: { model.openPermissionSettings(.accessibility) }
            )
        }
    }

    private var mappingsSection: some View {
        SettingsSection(title: "Press Actions", symbol: "hand.tap") {
            ForEach(model.preferences.mappings.sorted(by: { $0.pressCount < $1.pressCount })) { mapping in
                MappingEditor(mapping: mapping) { model.updateMapping($0) }
                if mapping.pressCount != 3 { Divider() }
            }

            HStack {
                Label("Linked actions follow the hotkeys saved by Codex or Claude.", systemImage: "link")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Refresh Hotkeys") { model.refreshLinkedShortcuts() }
                    .controlSize(.small)
            }

            Text("A single press waits 420 ms to distinguish it from a double or triple press. Toggle Hold lets one click start a held shortcut and the next click release it—no physical long-press required. A two-second hardware hold remains reserved for DJI pairing.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var generalSection: some View {
        SettingsSection(title: "General", symbol: "gearshape") {
            Toggle("MicTrigger enabled", isOn: $model.preferences.isEnabled)
            Toggle("Prevent the shutter press from changing volume", isOn: $model.preferences.suppressOriginalVolume)
            Toggle("Launch at login", isOn: Binding(
                get: { model.launchAtLogin },
                set: { model.setLaunchAtLogin($0) }
            ))
        }
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    let symbol: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: symbol)
                .font(.headline)
            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(.separator.opacity(0.45), lineWidth: 0.5)
            }
        }
    }
}

private struct PermissionRow: View {
    let title: String
    let detail: String
    let isGranted: Bool
    let request: () -> Void
    let openSettings: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isGranted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(isGranted ? .green : .orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.callout.weight(.medium))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if isGranted {
                Text("Allowed")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.green)
            } else {
                Button("Allow") {
                    request()
                    openSettings()
                }
            }
        }
    }
}
