import CoreGraphics
import Foundation

/// Reads shortcuts persisted by the installed Codex and Claude desktop apps.
/// These files are treated as optional inputs: malformed or unavailable values
/// never prevent MicTrigger from using its built-in fallback actions.
struct AppHotkeyConfigurationService {
    let codexKeybindingsURL: URL
    let claudeConfigURL: URL

    init(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) {
        codexKeybindingsURL = homeDirectory
            .appendingPathComponent(".codex", isDirectory: true)
            .appendingPathComponent("keybindings.json")
        claudeConfigURL = homeDirectory
            .appendingPathComponent("Library/Application Support/Claude", isDirectory: true)
            .appendingPathComponent("config.json")
    }

    init(codexKeybindingsURL: URL, claudeConfigURL: URL) {
        self.codexKeybindingsURL = codexKeybindingsURL
        self.claudeConfigURL = claudeConfigURL
    }

    func action(for shortcut: LinkedShortcut) -> ShortcutAction? {
        switch shortcut {
        case .codexVoiceChat:
            codexAction(command: "realtimeVoice")
        case .codexHoldToDictate:
            codexAction(command: "globalDictationHold")
        case .codexToggleDictation:
            codexAction(command: "globalDictationToggle")
        case .claudeQuickEntry:
            claudeAction(preference: "quickEntryShortcut", defaultAction: .modifierTaps(key: .option, count: 2))
        case .claudeVoiceDictation:
            claudeAction(preference: "quickEntryDictationShortcut", defaultAction: .disabled)
        }
    }

    private func codexAction(command: String) -> ShortcutAction? {
        struct Binding: Decodable {
            let command: String
            let key: String?
        }

        guard let data = try? Data(contentsOf: codexKeybindingsURL),
              let bindings = try? JSONDecoder().decode([Binding].self, from: data),
              let binding = bindings.first(where: { $0.command == command })
        else { return nil }

        guard let key = binding.key, !key.isEmpty else { return .disabled }
        return ElectronAcceleratorParser.action(from: key)
    }

    private func claudeAction(preference: String, defaultAction: ShortcutAction) -> ShortcutAction? {
        guard let data = try? Data(contentsOf: claudeConfigURL),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let preferences = root["preferences"] as? [String: Any]
        else { return nil }

        guard let value = preferences[preference] else { return defaultAction }

        if let namedValue = value as? String {
            switch namedValue.lowercased() {
            case "double-tap-option":
                return .modifierTaps(key: .option, count: 2)
            case "capslock", "caps-lock":
                return .modifierTaps(key: .capsLock, count: 1)
            case "double-tap-capslock", "double-tap-caps-lock":
                return .modifierTaps(key: .capsLock, count: 2)
            case "off":
                return .disabled
            default:
                return ElectronAcceleratorParser.action(from: namedValue)
            }
        }

        if let customValue = value as? [String: Any],
           let accelerator = customValue["accelerator"] as? String {
            return ElectronAcceleratorParser.action(from: accelerator)
        }

        return nil
    }
}

enum ElectronAcceleratorParser {
    static func action(from accelerator: String) -> ShortcutAction? {
        let tokens = accelerator
            .split(separator: "+")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !tokens.isEmpty else { return nil }

        var modifiers: ShortcutModifiers = []
        var keyToken: String?

        for token in tokens {
            if let modifier = shortcutModifier(for: token) {
                modifiers.insert(modifier)
            } else {
                keyToken = token
            }
        }

        if let keyToken, let key = keyDefinition(for: keyToken) {
            return .keyChord(KeyChord(keyCode: key.code, modifiers: modifiers, keyLabel: key.label))
        }

        // Electron permits a modifier-only accelerator in some preference UIs.
        // Emit the final modifier as the key and retain any preceding modifiers.
        guard keyToken == nil,
              let finalToken = tokens.last,
              let modifierKey = modifierKey(for: finalToken)
        else { return nil }

        modifiers.remove(shortcutModifier(for: finalToken) ?? [])
        if modifiers.isEmpty {
            return .modifierTaps(key: modifierKey, count: 1)
        }
        return .keyChord(KeyChord(
            keyCode: modifierKey.keyCode,
            modifiers: modifiers,
            keyLabel: modifierKey.symbol
        ))
    }

    private static func shortcutModifier(for token: String) -> ShortcutModifiers? {
        switch normalized(token) {
        case "command", "cmd", "super", "meta", "commandorcontrol", "cmdorctrl": .command
        case "control", "ctrl": .control
        case "option", "alt": .option
        case "shift": .shift
        case "function", "fn": .function
        default: nil
        }
    }

    private static func modifierKey(for token: String) -> ModifierKey? {
        switch normalized(token) {
        case "command", "cmd", "super", "meta", "commandorcontrol", "cmdorctrl": .command
        case "control", "ctrl": .control
        case "option", "alt": .option
        case "shift": .shift
        case "function", "fn": .function
        case "capslock": .capsLock
        default: nil
        }
    }

    private static func keyDefinition(for token: String) -> (code: CGKeyCode, label: String)? {
        let keys: [String: (CGKeyCode, String)] = [
            "a": (0, "A"), "s": (1, "S"), "d": (2, "D"), "f": (3, "F"),
            "h": (4, "H"), "g": (5, "G"), "z": (6, "Z"), "x": (7, "X"),
            "c": (8, "C"), "v": (9, "V"), "b": (11, "B"), "q": (12, "Q"),
            "w": (13, "W"), "e": (14, "E"), "r": (15, "R"), "y": (16, "Y"),
            "t": (17, "T"), "1": (18, "1"), "2": (19, "2"), "3": (20, "3"),
            "4": (21, "4"), "6": (22, "6"), "5": (23, "5"), "=": (24, "="),
            "9": (25, "9"), "7": (26, "7"), "-": (27, "-"), "8": (28, "8"),
            "0": (29, "0"), "]": (30, "]"), "o": (31, "O"), "u": (32, "U"),
            "[": (33, "["), "i": (34, "I"), "p": (35, "P"), "return": (36, "Return"),
            "enter": (36, "Return"), "l": (37, "L"), "j": (38, "J"), "'": (39, "'"),
            "k": (40, "K"), ";": (41, ";"), "\\": (42, "\\"), ",": (43, ","),
            "/": (44, "/"), "n": (45, "N"), "m": (46, "M"), ".": (47, "."),
            "tab": (48, "Tab"), "space": (49, "Space"), "spacebar": (49, "Space"),
            "`": (50, "`"), "backspace": (51, "Delete"), "delete": (51, "Delete"),
            "escape": (53, "Esc"), "esc": (53, "Esc"), "capslock": (57, "⇪"),
            "left": (123, "←"), "leftarrow": (123, "←"),
            "right": (124, "→"), "rightarrow": (124, "→"),
            "down": (125, "↓"), "downarrow": (125, "↓"),
            "up": (126, "↑"), "uparrow": (126, "↑"),
        ]
        return keys[normalized(token)]
    }

    private static func normalized(_ token: String) -> String {
        token.lowercased().replacingOccurrences(of: "-", with: "")
    }
}
