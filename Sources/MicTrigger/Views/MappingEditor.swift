import SwiftUI

struct MappingEditor: View {
    private enum CustomKind: String, CaseIterable, Identifiable {
        case chord = "Key combination"
        case modifierTaps = "Modifier taps"

        var id: String { rawValue }
    }

    let mapping: TriggerMapping
    let onChange: (TriggerMapping) -> Void

    @State private var preset: ActionPreset
    @State private var workingMapping: TriggerMapping
    @State private var customKind: CustomKind
    @State private var modifierKey: ModifierKey
    @State private var modifierTapCount: Int

    init(mapping: TriggerMapping, onChange: @escaping (TriggerMapping) -> Void) {
        self.mapping = mapping
        self.onChange = onChange
        _workingMapping = State(initialValue: mapping)
        _preset = State(initialValue: ActionPreset.matching(mapping))
        if case let .modifierTaps(key, count) = mapping.action {
            _customKind = State(initialValue: .modifierTaps)
            _modifierKey = State(initialValue: key)
            _modifierTapCount = State(initialValue: count)
        } else {
            _customKind = State(initialValue: .chord)
            _modifierKey = State(initialValue: .option)
            _modifierTapCount = State(initialValue: 2)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(mapping.pressLabel)
                    .font(.callout.weight(.semibold))
                Spacer()
                Text(workingMapping.action.display)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }

            Picker("Action", selection: $preset) {
                ForEach(ActionPreset.allCases) { preset in
                    Text(preset.title).tag(preset)
                }
            }
            .labelsHidden()
            .onChange(of: preset) { _, newPreset in
                if newPreset == .custom {
                    workingMapping.linkedShortcut = nil
                    onChange(workingMapping)
                    return
                }
                workingMapping.linkedShortcut = newPreset.linkedShortcut
                workingMapping.action = newPreset.action
                workingMapping.title = newPreset.linkedShortcut?.title ?? newPreset.title
                workingMapping.behavior = newPreset.defaultBehavior
                workingMapping.releaseFollowUp = newPreset.defaultReleaseFollowUp
                onChange(workingMapping)
            }

            if let linked = workingMapping.linkedShortcut {
                Label(
                    workingMapping.action == .disabled
                        ? "Not assigned in \(linked.appName) settings"
                        : "Following \(linked.appName) desktop settings",
                    systemImage: "link"
                )
                .font(.caption)
                .foregroundStyle(workingMapping.action == .disabled ? .orange : .secondary)
            }

            if case .keyChord = workingMapping.action {
                Picker("Shortcut behavior", selection: $workingMapping.behavior) {
                    ForEach(TriggerBehavior.allCases) { behavior in
                        Text(behavior.title).tag(behavior)
                    }
                }
                .pickerStyle(.radioGroup)
                .onChange(of: workingMapping.behavior) { _, _ in
                    onChange(workingMapping)
                }

                if workingMapping.behavior == .toggleHold {
                    Picker("After release", selection: $workingMapping.releaseFollowUp) {
                        ForEach(ReleaseFollowUp.allCases) { followUp in
                            Text(followUp.title).tag(followUp)
                        }
                    }
                    .onChange(of: workingMapping.releaseFollowUp) { _, _ in
                        onChange(workingMapping)
                    }
                }
            }

            if preset == .custom {
                Picker("Custom action type", selection: $customKind) {
                    ForEach(CustomKind.allCases) { kind in
                        Text(kind.rawValue).tag(kind)
                    }
                }
                .pickerStyle(.segmented)

                HStack(spacing: 10) {
                    if customKind == .chord {
                        ShortcutRecorder(action: $workingMapping.action)
                    } else {
                        Picker("Modifier", selection: $modifierKey) {
                            ForEach(ModifierKey.allCases, id: \.self) { key in
                                Text(key.symbol).tag(key)
                            }
                        }
                        .frame(width: 78)
                        Stepper("\(modifierTapCount) taps", value: $modifierTapCount, in: 1...3)
                            .fixedSize()
                    }

                    TextField("Action name", text: $workingMapping.title)
                        .textFieldStyle(.roundedBorder)
                }
                .onChange(of: workingMapping) { _, newMapping in
                    onChange(newMapping)
                }
                .onChange(of: customKind) { _, newKind in
                    if newKind == .modifierTaps {
                        setModifierAction()
                    } else if case .modifierTaps = workingMapping.action {
                        workingMapping.action = .keyChord(KeyChord(
                            keyCode: 2,
                            modifiers: [.control, .shift],
                            keyLabel: "D"
                        ))
                    }
                }
                .onChange(of: modifierKey) { _, _ in setModifierAction() }
                .onChange(of: modifierTapCount) { _, _ in setModifierAction() }
            }
        }
        .onChange(of: mapping) { _, newValue in
            workingMapping = newValue
            preset = ActionPreset.matching(newValue)
        }
    }

    private func setModifierAction() {
        workingMapping.action = .modifierTaps(key: modifierKey, count: modifierTapCount)
    }
}
