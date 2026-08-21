import AppKit
import ApplicationServices
import CoreGraphics
import Foundation
import IOKit.hid

enum PermissionKind {
    case inputMonitoring
    case accessibility
}

enum PermissionService {
    static var hasInputMonitoring: Bool {
        IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
    }

    static var hasAccessibility: Bool {
        CGPreflightPostEventAccess()
    }

    @discardableResult
    static func requestInputMonitoring() -> Bool {
        IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
    }

    @discardableResult
    static func requestAccessibility() -> Bool {
        _ = CGRequestPostEventAccess()
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)
        return hasAccessibility
    }

    static func openSettings(for kind: PermissionKind) {
        let anchor: String
        switch kind {
        case .inputMonitoring:
            anchor = "Privacy_ListenEvent"
        case .accessibility:
            anchor = "Privacy_Accessibility"
        }

        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)"
        ) else { return }
        NSWorkspace.shared.open(url)
    }
}
