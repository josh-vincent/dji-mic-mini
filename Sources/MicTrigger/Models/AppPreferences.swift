import Foundation

struct AppPreferences: Codable, Equatable {
    var selectedDevice: DeviceIdentity = .djiMicMini
    var mappings: [TriggerMapping] = TriggerMapping.defaults
    var isEnabled = true
    var suppressOriginalVolume = true

    static func load(from defaults: UserDefaults = .standard) -> AppPreferences {
        guard let data = defaults.data(forKey: "appPreferences"),
              var preferences = try? JSONDecoder().decode(AppPreferences.self, from: data)
        else { return AppPreferences() }

        // Migrate the original Codex preset to the linked desktop-app shortcut.
        for index in preferences.mappings.indices {
            let mapping = preferences.mappings[index]
            guard mapping.pressCount == 1,
                  mapping.title == "Codex Dictate" || mapping.linkedShortcut == .codexHoldToDictate,
                  mapping.action.isCodexDictationChord
            else { continue }
            preferences.mappings[index].title = LinkedShortcut.codexHoldToDictate.title
            preferences.mappings[index].action = ActionPreset.codexDictate.action
            preferences.mappings[index].behavior = .toggleHold
            preferences.mappings[index].releaseFollowUp = .pressReturn
            preferences.mappings[index].linkedShortcut = .codexHoldToDictate
        }
        preferences.save(to: defaults)
        return preferences
    }

    func save(to defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: "appPreferences")
    }
}
