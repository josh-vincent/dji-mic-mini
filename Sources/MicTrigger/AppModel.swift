import AppKit
import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published var preferences: AppPreferences {
        didSet {
            preferences.save()
            if oldValue.selectedDevice != preferences.selectedDevice ||
                oldValue.suppressOriginalVolume != preferences.suppressOriginalVolume ||
                oldValue.isEnabled != preferences.isEnabled {
                restartMonitoring()
            }
        }
    }
    @Published private(set) var receiverConnected = false
    @Published private(set) var hasInputMonitoring = false
    @Published private(set) var hasAccessibility = false
    @Published private(set) var isLearning = false
    @Published private(set) var lastTrigger = "Waiting for the Mic Mini"
    @Published private(set) var errorMessage: String?
    @Published var launchAtLogin = false

    private let monitor = DJIButtonMonitor()
    private let recognizer = PressSequenceRecognizer()
    private let shortcutEmitter = ShortcutEmitter()
    private let appHotkeys = AppHotkeyConfigurationService()
    private var permissionTimer: Timer?
    private var hasStarted = false

    init() {
        preferences = AppPreferences.load()
        launchAtLogin = LoginItemService.isEnabled

        monitor.onConnectionChanged = { [weak self] connected, device in
            Task { @MainActor in
                guard let self else { return }
                if device == nil || device == self.preferences.selectedDevice || self.isLearning {
                    self.receiverConnected = connected
                    if !connected {
                        self.releaseHeldShortcut(reason: "Receiver disconnected — shortcut released")
                    }
                }
            }
        }
        monitor.onButtonPress = { [weak self] device in
            Task { @MainActor in
                self?.handleButtonPress(from: device)
            }
        }
        monitor.onError = { [weak self] message in
            Task { @MainActor in self?.errorMessage = message }
        }
        recognizer.onSequence = { [weak self] count in
            Task { @MainActor in self?.runMapping(for: count) }
        }

        Task { @MainActor [weak self] in
            self?.start()
        }
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        refreshLinkedShortcuts()
        refreshPermissions()
        restartMonitoring()
        permissionTimer?.invalidate()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshPermissions()
                self?.refreshLinkedShortcuts()
            }
        }
    }

    func requestPermissions() {
        let inputGranted = PermissionService.requestInputMonitoring()
        let postingGranted = PermissionService.requestAccessibility()
        refreshPermissions()
        if !inputGranted {
            PermissionService.openSettings(for: .inputMonitoring)
        } else if !postingGranted {
            PermissionService.openSettings(for: .accessibility)
        }
    }

    func openPermissionSettings(_ kind: PermissionKind) {
        PermissionService.openSettings(for: kind)
    }

    func refreshPermissions() {
        let newInput = PermissionService.hasInputMonitoring
        let newAccessibility = PermissionService.hasAccessibility
        let inputChanged = newInput != hasInputMonitoring
        hasInputMonitoring = newInput
        hasAccessibility = newAccessibility
        if inputChanged, newInput { restartMonitoring() }
    }

    func beginLearning() {
        isLearning = true
        receiverConnected = false
        lastTrigger = "Press the link/shutter button once…"
        errorMessage = nil
        monitor.start(mode: .learning)
    }

    func cancelLearning() {
        isLearning = false
        restartMonitoring()
    }

    func updateMapping(_ mapping: TriggerMapping) {
        guard let index = preferences.mappings.firstIndex(where: { $0.pressCount == mapping.pressCount }) else {
            return
        }
        releaseHeldShortcut(reason: "Mapping changed — shortcut released")
        var updatedMapping = mapping
        if let linked = mapping.linkedShortcut {
            updatedMapping.title = linked.title
            updatedMapping.action = appHotkeys.action(for: linked) ?? linked.fallbackAction
        }
        preferences.mappings[index] = updatedMapping
    }

    func refreshLinkedShortcuts() {
        var updated = preferences
        for index in updated.mappings.indices {
            guard let linked = updated.mappings[index].linkedShortcut else { continue }
            updated.mappings[index].title = linked.title
            updated.mappings[index].action = appHotkeys.action(for: linked) ?? linked.fallbackAction
        }
        if updated != preferences {
            releaseHeldShortcut(reason: "App hotkey changed — held shortcut released")
            preferences = updated
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LoginItemService.setEnabled(enabled)
            launchAtLogin = enabled
            errorMessage = nil
        } catch {
            launchAtLogin = LoginItemService.isEnabled
            errorMessage = "Could not update Launch at Login: \(error.localizedDescription)"
        }
    }

    func dismissError() {
        errorMessage = nil
    }

    func shutdown() {
        _ = shortcutEmitter.releaseHeld()
        monitor.stop()
    }

    private func restartMonitoring() {
        guard !isLearning else { return }
        guard preferences.isEnabled else {
            releaseHeldShortcut(reason: "MicTrigger disabled — shortcut released")
            monitor.stop()
            return
        }
        monitor.start(mode: .active(
            preferences.selectedDevice,
            suppressOriginal: preferences.suppressOriginalVolume
        ))
    }

    private func handleButtonPress(from device: DeviceIdentity) {
        if isLearning {
            preferences.selectedDevice = device
            isLearning = false
            receiverConnected = true
            lastTrigger = "Found \(device.productName) · \(device.identifierSummary)"
            restartMonitoring()
            return
        }

        guard device.vendorID == preferences.selectedDevice.vendorID,
              device.productID == preferences.selectedDevice.productID,
              preferences.isEnabled
        else { return }
        lastTrigger = "Button received — recognizing presses…"
        recognizer.registerPress()
    }

    private func runMapping(for count: Int) {
        guard let mapping = preferences.mappings.first(where: { $0.pressCount == count }) else { return }
        guard mapping.action != .disabled else {
            lastTrigger = "\(mapping.pressLabel) · No action"
            return
        }
        if !hasAccessibility {
            _ = PermissionService.requestAccessibility()
            refreshPermissions()
            guard hasAccessibility else {
                lastTrigger = "\(mapping.pressLabel) blocked — approve MicTrigger in Accessibility"
                PermissionService.openSettings(for: .accessibility)
                return
            }
        }

        let emitted = shortcutEmitter.emit(
            mapping.action,
            behavior: mapping.behavior,
            releaseFollowUp: mapping.releaseFollowUp
        )
        switch emitted {
        case .tapped:
            lastTrigger = "\(mapping.pressLabel) → \(mapping.title)"
        case .held:
            lastTrigger = "\(mapping.title) held — press once again to release"
        case .released:
            lastTrigger = mapping.releaseFollowUp == .pressReturn
                ? "\(mapping.title) released → Return"
                : "\(mapping.title) released"
        case .failed:
            lastTrigger = "Could not send \(mapping.action.display)"
        }
    }

    private func releaseHeldShortcut(reason: String) {
        guard shortcutEmitter.heldChord != nil else { return }
        _ = shortcutEmitter.releaseHeld()
        lastTrigger = reason
    }
}
