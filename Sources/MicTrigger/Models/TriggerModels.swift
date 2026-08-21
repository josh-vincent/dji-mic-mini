import AppKit
import CoreGraphics
import Foundation

struct DeviceIdentity: Codable, Equatable, Hashable {
    static let djiMicMini = DeviceIdentity(
        vendorID: 0x2CA3,
        productID: 0x4011,
        productName: "Wireless Mic Rx"
    )

    var vendorID: Int
    var productID: Int
    var productName: String

    var identifierSummary: String {
        String(format: "%04X:%04X", vendorID, productID)
    }
}

struct ShortcutModifiers: OptionSet, Codable, Equatable, Hashable {
    let rawValue: Int

    static let command = ShortcutModifiers(rawValue: 1 << 0)
    static let option = ShortcutModifiers(rawValue: 1 << 1)
    static let control = ShortcutModifiers(rawValue: 1 << 2)
    static let shift = ShortcutModifiers(rawValue: 1 << 3)
    static let function = ShortcutModifiers(rawValue: 1 << 4)

    init(rawValue: Int) {
        self.rawValue = rawValue
    }

    var cgEventFlags: CGEventFlags {
        var flags: CGEventFlags = []
        if contains(.command) { flags.insert(.maskCommand) }
        if contains(.option) { flags.insert(.maskAlternate) }
        if contains(.control) { flags.insert(.maskControl) }
        if contains(.shift) { flags.insert(.maskShift) }
        if contains(.function) { flags.insert(.maskSecondaryFn) }
        return flags
    }

    var display: String {
        var result = ""
        if contains(.control) { result += "⌃" }
        if contains(.option) { result += "⌥" }
        if contains(.shift) { result += "⇧" }
        if contains(.command) { result += "⌘" }
        if contains(.function) { result += "fn " }
        return result
    }

    static func from(_ flags: NSEvent.ModifierFlags) -> ShortcutModifiers {
        var result: ShortcutModifiers = []
        if flags.contains(.command) { result.insert(.command) }
        if flags.contains(.option) { result.insert(.option) }
        if flags.contains(.control) { result.insert(.control) }
        if flags.contains(.shift) { result.insert(.shift) }
        if flags.contains(.function) { result.insert(.function) }
        return result
    }
}

enum ModifierKey: String, Codable, CaseIterable, Equatable {
    case option
    case control
    case shift
    case command
    case function
    case capsLock

    var keyCode: CGKeyCode {
        switch self {
        case .option: 58
        case .control: 59
        case .shift: 56
        case .command: 55
        case .function: 63
        case .capsLock: 57
        }
    }

    var flag: CGEventFlags {
        switch self {
        case .option: .maskAlternate
        case .control: .maskControl
        case .shift: .maskShift
        case .command: .maskCommand
        case .function: .maskSecondaryFn
        case .capsLock: []
        }
    }

    var symbol: String {
        switch self {
        case .option: "⌥"
        case .control: "⌃"
        case .shift: "⇧"
        case .command: "⌘"
        case .function: "fn"
        case .capsLock: "⇪"
        }
    }
}

struct KeyChord: Codable, Equatable {
    var keyCode: CGKeyCode
    var modifiers: ShortcutModifiers
    var keyLabel: String

    var display: String { modifiers.display + keyLabel.uppercased() }
}

enum ShortcutAction: Codable, Equatable {
    case keyChord(KeyChord)
    case modifierTaps(key: ModifierKey, count: Int)
    case disabled

    var display: String {
        switch self {
        case let .keyChord(chord):
            chord.display
        case let .modifierTaps(key, count):
            Array(repeating: key.symbol, count: count).joined(separator: "  ")
        case .disabled:
            "No action"
        }
    }

    var isCodexDictationChord: Bool {
        guard case let .keyChord(chord) = self, chord.keyCode == 2 else { return false }
        return chord.modifiers.contains(.shift)
            && (chord.modifiers.contains(.control) || chord.modifiers.contains(.option))
    }
}

enum TriggerBehavior: String, Codable, CaseIterable, Identifiable {
    case tap
    case toggleHold

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tap: "Tap shortcut"
        case .toggleHold: "Press once to hold · again to release"
        }
    }

    var shortLabel: String {
        switch self {
        case .tap: "Tap"
        case .toggleHold: "Toggle hold"
        }
    }
}

enum ReleaseFollowUp: String, Codable, CaseIterable, Identifiable {
    case none
    case pressReturn

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: "Do nothing"
        case .pressReturn: "Press Return"
        }
    }
}

enum LinkedShortcut: String, Codable, CaseIterable, Identifiable {
    case codexVoiceChat
    case codexHoldToDictate
    case codexToggleDictation
    case claudeQuickEntry
    case claudeVoiceDictation

    var id: String { rawValue }

    var title: String {
        switch self {
        case .codexVoiceChat: "Codex Voice Chat"
        case .codexHoldToDictate: "Codex Hold to Dictate"
        case .codexToggleDictation: "Codex Toggle Dictation"
        case .claudeQuickEntry: "Claude Quick Entry"
        case .claudeVoiceDictation: "Claude Voice Dictation"
        }
    }

    var appName: String {
        switch self {
        case .codexVoiceChat, .codexHoldToDictate, .codexToggleDictation: "Codex"
        case .claudeQuickEntry, .claudeVoiceDictation: "Claude"
        }
    }

    var fallbackAction: ShortcutAction {
        switch self {
        case .codexHoldToDictate:
            .keyChord(KeyChord(keyCode: 2, modifiers: [.control, .shift], keyLabel: "D"))
        case .claudeQuickEntry:
            .modifierTaps(key: .option, count: 2)
        case .codexVoiceChat, .codexToggleDictation, .claudeVoiceDictation:
            .disabled
        }
    }

    var defaultBehavior: TriggerBehavior {
        self == .codexHoldToDictate ? .toggleHold : .tap
    }

    var defaultReleaseFollowUp: ReleaseFollowUp {
        self == .codexHoldToDictate ? .pressReturn : .none
    }
}

struct TriggerMapping: Codable, Equatable, Identifiable {
    var pressCount: Int
    var title: String
    var action: ShortcutAction
    var behavior: TriggerBehavior
    var releaseFollowUp: ReleaseFollowUp
    var linkedShortcut: LinkedShortcut?

    init(
        pressCount: Int,
        title: String,
        action: ShortcutAction,
        behavior: TriggerBehavior = .tap,
        releaseFollowUp: ReleaseFollowUp = .none,
        linkedShortcut: LinkedShortcut? = nil
    ) {
        self.pressCount = pressCount
        self.title = title
        self.action = action
        self.behavior = behavior
        self.releaseFollowUp = releaseFollowUp
        self.linkedShortcut = linkedShortcut
    }

    private enum CodingKeys: String, CodingKey {
        case pressCount, title, action, behavior, releaseFollowUp, linkedShortcut
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        pressCount = try container.decode(Int.self, forKey: .pressCount)
        title = try container.decode(String.self, forKey: .title)
        action = try container.decode(ShortcutAction.self, forKey: .action)
        behavior = try container.decodeIfPresent(TriggerBehavior.self, forKey: .behavior)
            ?? (action.isCodexDictationChord ? .toggleHold : .tap)
        releaseFollowUp = try container.decodeIfPresent(ReleaseFollowUp.self, forKey: .releaseFollowUp)
            ?? (action.isCodexDictationChord ? .pressReturn : .none)
        linkedShortcut = try container.decodeIfPresent(LinkedShortcut.self, forKey: .linkedShortcut)
    }

    var id: Int { pressCount }

    var pressLabel: String {
        switch pressCount {
        case 1: "Single press"
        case 2: "Double press"
        default: "Triple press"
        }
    }
}

enum ActionPreset: String, CaseIterable, Identifiable {
    case codexVoiceChat
    case codexDictate
    case codexToggleDictation
    case claudeQuickEntry
    case claudeVoiceDictation
    case wisprHandsFree
    case wisprOptionDouble
    case macOSDictation
    case custom
    case disabled

    var id: String { rawValue }

    var title: String {
        switch self {
        case .codexVoiceChat: "Codex Voice Chat · linked"
        case .codexDictate: "Codex Hold to Dictate · linked"
        case .codexToggleDictation: "Codex Toggle Dictation · linked"
        case .claudeQuickEntry: "Claude Quick Entry · linked"
        case .claudeVoiceDictation: "Claude Voice Dictation · linked"
        case .wisprHandsFree: "Wispr Flow Hands-free"
        case .wisprOptionDouble: "Wispr Flow Double Option"
        case .macOSDictation: "macOS Dictation"
        case .custom: "Custom shortcut"
        case .disabled: "No action"
        }
    }

    var action: ShortcutAction {
        switch self {
        case .codexVoiceChat:
            LinkedShortcut.codexVoiceChat.fallbackAction
        case .codexDictate:
            LinkedShortcut.codexHoldToDictate.fallbackAction
        case .codexToggleDictation:
            LinkedShortcut.codexToggleDictation.fallbackAction
        case .claudeQuickEntry:
            LinkedShortcut.claudeQuickEntry.fallbackAction
        case .claudeVoiceDictation:
            LinkedShortcut.claudeVoiceDictation.fallbackAction
        case .wisprHandsFree:
            .keyChord(KeyChord(keyCode: 49, modifiers: [.function], keyLabel: "Space"))
        case .wisprOptionDouble:
            .modifierTaps(key: .option, count: 2)
        case .macOSDictation:
            .modifierTaps(key: .function, count: 2)
        case .custom, .disabled:
            .disabled
        }
    }

    var defaultBehavior: TriggerBehavior {
        linkedShortcut?.defaultBehavior ?? (self == .codexDictate ? .toggleHold : .tap)
    }

    var defaultReleaseFollowUp: ReleaseFollowUp {
        linkedShortcut?.defaultReleaseFollowUp ?? (self == .codexDictate ? .pressReturn : .none)
    }

    var linkedShortcut: LinkedShortcut? {
        switch self {
        case .codexVoiceChat: .codexVoiceChat
        case .codexDictate: .codexHoldToDictate
        case .codexToggleDictation: .codexToggleDictation
        case .claudeQuickEntry: .claudeQuickEntry
        case .claudeVoiceDictation: .claudeVoiceDictation
        case .wisprHandsFree, .wisprOptionDouble, .macOSDictation, .custom, .disabled: nil
        }
    }

    static func matching(_ mapping: TriggerMapping) -> ActionPreset {
        if let linked = mapping.linkedShortcut,
           let preset = allCases.first(where: { $0.linkedShortcut == linked }) {
            return preset
        }
        for preset in allCases where preset != .custom && preset.linkedShortcut == nil {
            if preset.action == mapping.action { return preset }
        }
        return .custom
    }
}

extension TriggerMapping {
    static let defaults: [TriggerMapping] = [
        TriggerMapping(
            pressCount: 1,
            title: LinkedShortcut.codexHoldToDictate.title,
            action: ActionPreset.codexDictate.action,
            behavior: .toggleHold,
            releaseFollowUp: .pressReturn,
            linkedShortcut: .codexHoldToDictate
        ),
        TriggerMapping(pressCount: 2, title: "Wispr Flow", action: ActionPreset.wisprOptionDouble.action),
        TriggerMapping(pressCount: 3, title: "macOS Dictation", action: ActionPreset.macOSDictation.action),
    ]
}
