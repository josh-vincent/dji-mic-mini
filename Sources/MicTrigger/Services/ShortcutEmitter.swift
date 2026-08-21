import CoreGraphics
import Foundation

enum ShortcutEmission: Equatable {
    case tapped
    case held
    case released
    case failed
}

final class ShortcutEmitter {
    typealias EventPoster = (CGKeyCode, CGEventFlags, Bool) -> Bool

    private(set) var heldChord: KeyChord?
    private let permissionCheck: () -> Bool
    private let eventPoster: EventPoster

    init(
        permissionCheck: @escaping () -> Bool = { PermissionService.hasAccessibility },
        eventPoster: EventPoster? = nil
    ) {
        self.permissionCheck = permissionCheck
        self.eventPoster = eventPoster ?? Self.postKeyEvent
    }

    deinit {
        releaseHeld()
    }

    @discardableResult
    func emit(
        _ action: ShortcutAction,
        behavior: TriggerBehavior,
        releaseFollowUp: ReleaseFollowUp = .none
    ) -> ShortcutEmission {
        guard permissionCheck() else { return .failed }

        if behavior == .toggleHold, case let .keyChord(chord) = action {
            if heldChord == chord {
                guard releaseHeld() else { return .failed }
                guard perform(releaseFollowUp) else { return .failed }
                return .released
            }
            _ = releaseHeld()
            guard postKey(code: chord.keyCode, flags: chord.modifiers.cgEventFlags, keyDown: true) else {
                return .failed
            }
            heldChord = chord
            return .held
        }

        _ = releaseHeld()

        switch action {
        case let .keyChord(chord):
            return postTap(code: chord.keyCode, flags: chord.modifiers.cgEventFlags) ? .tapped : .failed
        case let .modifierTaps(key, count):
            for index in 0..<max(1, count) {
                guard postModifier(key) else { return .failed }
                if index < count - 1 {
                    Thread.sleep(forTimeInterval: 0.055)
                }
            }
            return .tapped
        case .disabled:
            return .tapped
        }
    }

    @discardableResult
    func releaseHeld() -> Bool {
        guard let chord = heldChord else { return true }
        let released = postKey(code: chord.keyCode, flags: chord.modifiers.cgEventFlags, keyDown: false)
        heldChord = nil
        return released
    }

    private func postTap(code: CGKeyCode, flags: CGEventFlags) -> Bool {
        guard postKey(code: code, flags: flags, keyDown: true) else { return false }
        return postKey(code: code, flags: flags, keyDown: false)
    }

    private func perform(_ followUp: ReleaseFollowUp) -> Bool {
        switch followUp {
        case .none:
            return true
        case .pressReturn:
            // Give the target app a moment to process the shortcut release first.
            Thread.sleep(forTimeInterval: 0.12)
            return postTap(code: 36, flags: [])
        }
    }

    private func postKey(code: CGKeyCode, flags: CGEventFlags, keyDown: Bool) -> Bool {
        eventPoster(code, flags, keyDown)
    }

    private static func postKeyEvent(code: CGKeyCode, flags: CGEventFlags, keyDown: Bool) -> Bool {
        guard let source = CGEventSource(stateID: .hidSystemState),
              let event = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: keyDown)
        else { return false }

        event.flags = flags
        event.post(tap: .cgSessionEventTap)
        return true
    }

    private func postModifier(_ key: ModifierKey) -> Bool {
        guard postKey(code: key.keyCode, flags: key.flag, keyDown: true) else { return false }
        Thread.sleep(forTimeInterval: 0.035)
        return postKey(code: key.keyCode, flags: [], keyDown: false)
    }
}
