import XCTest
@testable import MicTrigger

final class ModelTests: XCTestCase {
    func testDefaultMappingsCoverSingleDoubleAndTriplePresses() {
        XCTAssertEqual(TriggerMapping.defaults.map(\.pressCount), [1, 2, 3])
        XCTAssertEqual(TriggerMapping.defaults[0].action.display, "⌃⇧D")
        XCTAssertEqual(TriggerMapping.defaults[0].behavior, .toggleHold)
        XCTAssertEqual(TriggerMapping.defaults[0].releaseFollowUp, .pressReturn)
        XCTAssertEqual(TriggerMapping.defaults[0].linkedShortcut, .codexHoldToDictate)
        XCTAssertEqual(TriggerMapping.defaults[1].action.display, "⌥  ⌥")
        XCTAssertEqual(TriggerMapping.defaults[2].action.display, "fn  fn")
    }

    func testPreferencesRoundTrip() throws {
        let suite = "MicTriggerTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        var preferences = AppPreferences()
        preferences.isEnabled = false
        preferences.selectedDevice = DeviceIdentity(vendorID: 12, productID: 34, productName: "Test")
        preferences.save(to: defaults)

        XCTAssertEqual(AppPreferences.load(from: defaults), preferences)
    }

    func testPresetRecognition() {
        XCTAssertEqual(ActionPreset.matching(TriggerMapping.defaults[0]), .codexDictate)
        XCTAssertEqual(ActionPreset.matching(TriggerMapping(
            pressCount: 2,
            title: "Wispr",
            action: ActionPreset.wisprOptionDouble.action
        )), .wisprOptionDouble)
        XCTAssertEqual(
            ActionPreset.matching(TriggerMapping(
                pressCount: 3,
                title: "Custom",
                action: .keyChord(KeyChord(keyCode: 0, modifiers: [.command], keyLabel: "A"))
            )),
            .custom
        )
    }

    func testElectronAcceleratorParser() {
        XCTAssertEqual(
            ElectronAcceleratorParser.action(from: "Ctrl+Shift+D")?.display,
            "⌃⇧D"
        )
        XCTAssertEqual(
            ElectronAcceleratorParser.action(from: "CmdOrCtrl+Shift+V")?.display,
            "⇧⌘V"
        )
        XCTAssertEqual(
            ElectronAcceleratorParser.action(from: "Alt+Space")?.display,
            "⌥SPACE"
        )
    }

    func testReadsCodexDesktopKeybindings() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MicTriggerCodexTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let codexURL = directory.appendingPathComponent("keybindings.json")
        try """
        [
          {"command":"globalDictationHold","key":"Ctrl+Shift+D"},
          {"command":"realtimeVoice","key":"Ctrl+Shift+V"},
          {"command":"globalDictationToggle","key":null}
        ]
        """.data(using: .utf8)!.write(to: codexURL)

        let service = AppHotkeyConfigurationService(
            codexKeybindingsURL: codexURL,
            claudeConfigURL: directory.appendingPathComponent("missing-claude.json")
        )
        XCTAssertEqual(service.action(for: .codexHoldToDictate)?.display, "⌃⇧D")
        XCTAssertEqual(service.action(for: .codexVoiceChat)?.display, "⌃⇧V")
        XCTAssertEqual(service.action(for: .codexToggleDictation), .disabled)
    }

    func testReadsClaudeDesktopShortcuts() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MicTriggerClaudeTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let claudeURL = directory.appendingPathComponent("config.json")
        try """
        {
          "preferences": {
            "quickEntryShortcut": {"accelerator":"Alt+Space"},
            "quickEntryDictationShortcut": "capslock"
          }
        }
        """.data(using: .utf8)!.write(to: claudeURL)

        let service = AppHotkeyConfigurationService(
            codexKeybindingsURL: directory.appendingPathComponent("missing-codex.json"),
            claudeConfigURL: claudeURL
        )
        XCTAssertEqual(service.action(for: .claudeQuickEntry)?.display, "⌥SPACE")
        XCTAssertEqual(service.action(for: .claudeVoiceDictation)?.display, "⇪")
    }

    func testTriplePressFinishesImmediately() {
        let queue = DispatchQueue(label: "PressSequenceRecognizerTests")
        let recognizer = PressSequenceRecognizer(interval: 5, queue: queue)
        let expectation = expectation(description: "sequence")
        var received = 0
        recognizer.onSequence = {
            received = $0
            expectation.fulfill()
        }

        queue.async {
            recognizer.registerPress()
            recognizer.registerPress()
            recognizer.registerPress()
        }

        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(received, 3)
    }

    func testLegacyCodexMappingMigratesToToggleHold() throws {
        let legacyJSON = """
        {
          "pressCount": 1,
          "title": "Codex Dictate",
          "action": {
            "keyChord": {
              "_0": {
                "keyCode": 2,
                "modifiers": 10,
                "keyLabel": "D"
              }
            }
          }
        }
        """.data(using: .utf8)!

        let mapping = try JSONDecoder().decode(TriggerMapping.self, from: legacyJSON)
        XCTAssertEqual(mapping.behavior, .toggleHold)
        XCTAssertEqual(mapping.releaseFollowUp, .pressReturn)
    }

    func testToggleHoldPostsDownThenUpAcrossTwoPresses() {
        var events: [(CGKeyCode, CGEventFlags, Bool)] = []
        let emitter = ShortcutEmitter(
            permissionCheck: { true },
            eventPoster: { code, flags, isDown in
                events.append((code, flags, isDown))
                return true
            }
        )

        XCTAssertEqual(emitter.emit(ActionPreset.codexDictate.action, behavior: .toggleHold), .held)
        XCTAssertNotNil(emitter.heldChord)
        XCTAssertEqual(emitter.emit(ActionPreset.codexDictate.action, behavior: .toggleHold), .released)
        XCTAssertNil(emitter.heldChord)
        XCTAssertEqual(events.map(\.2), [true, false])
        XCTAssertEqual(events.map(\.0), [2, 2])
    }

    func testReturnFollowUpRunsAfterHeldShortcutRelease() {
        var events: [(CGKeyCode, Bool)] = []
        let emitter = ShortcutEmitter(
            permissionCheck: { true },
            eventPoster: { code, _, isDown in
                events.append((code, isDown))
                return true
            }
        )

        XCTAssertEqual(
            emitter.emit(
                ActionPreset.codexDictate.action,
                behavior: .toggleHold,
                releaseFollowUp: .pressReturn
            ),
            .held
        )
        XCTAssertEqual(
            emitter.emit(
                ActionPreset.codexDictate.action,
                behavior: .toggleHold,
                releaseFollowUp: .pressReturn
            ),
            .released
        )
        XCTAssertEqual(events.map(\.0), [2, 2, 36, 36])
        XCTAssertEqual(events.map(\.1), [true, false, true, false])
    }

    func testSavedOptionCodexShortcutMigratesToControl() throws {
        let suite = "MicTriggerMigrationTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let oldAction = ShortcutAction.keyChord(KeyChord(
            keyCode: 2,
            modifiers: [.option, .shift],
            keyLabel: "D"
        ))
        let oldPreferences = AppPreferences(mappings: [
            TriggerMapping(
                pressCount: 1,
                title: "Codex Dictate",
                action: oldAction,
                behavior: .toggleHold,
                releaseFollowUp: .pressReturn
            ),
        ])
        oldPreferences.save(to: defaults)

        let migrated = AppPreferences.load(from: defaults)
        XCTAssertEqual(migrated.mappings[0].action, ActionPreset.codexDictate.action)
        XCTAssertEqual(migrated.mappings[0].action.display, "⌃⇧D")
        XCTAssertEqual(migrated.mappings[0].linkedShortcut, .codexHoldToDictate)
    }
}
