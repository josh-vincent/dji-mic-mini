# MicTrigger

MicTrigger turns the DJI Mic Mini transmitter’s link/shutter button into configurable macOS shortcuts. It lives only in the menu bar and is designed around one short setup: install, grant two permissions, plug in the receiver, and press the button.

## Download

Download the latest versioned `MicTrigger-*.dmg` from [GitHub Releases](https://github.com/josh-vincent/dji-mic-mini/releases/latest), open it, and drag **MicTrigger** onto **Applications**.

The current preview build is signed with an Apple Development certificate but is not notarized for public distribution. On another Mac, macOS may require you to Control-click MicTrigger in Applications, choose **Open**, and confirm once. A warning-free double-click install requires a Developer ID Application certificate and Apple notarization.

## Install

Requires macOS 14 or later and Apple’s Command Line Tools/Xcode for this source build.

```sh
./install.sh
```

To create the distributable disk image locally:

```sh
./scripts/create-dmg.sh
```

Then click the microphone icon in the menu bar and choose **Enable MicTrigger**. macOS requires you to approve:

1. **Input Monitoring** — to receive consumer-control input from the selected DJI receiver.
2. **Accessibility** — to send the configured shortcut to the currently active app.

If Input Monitoring was previously denied, enable **MicTrigger** in System Settings, then quit and reopen the app. The installer prefers an available Developer ID or Apple Development signing identity so this approval remains attached to the app across rebuilds. An ad-hoc signed build has a changing code-hash identity and may require permission again after every rebuild.

Plug the DJI receiver into the Mac over USB-C. Bluetooth-only mode exposes audio but does not expose the shutter button.

## Defaults

| Transmitter gesture | Action | Output |
| --- | --- | --- |
| Single press, then single press again | Codex Hold to Dictate | Hold, then release the Codex-configured hotkey |
| Double press | Wispr Flow | Double-tap Option |
| Triple press | macOS Dictation | Double-tap Fn |

All three actions can be changed from the menu bar’s **Settings…** panel. Linked presets include Codex Voice Chat, Codex Hold to Dictate, Codex Toggle Dictation, Claude Quick Entry, and Claude Voice Dictation. Other presets include Wispr Flow Hands-free (Fn–Space), Wispr Flow Double Option, and macOS Dictation. A shortcut recorder supports other app-specific combinations.

## Linked Codex and Claude hotkeys

Choose a preset marked **linked** and MicTrigger follows the shortcut saved by that desktop app. It checks for changes while running and also provides a **Refresh Hotkeys** button in Settings.

- Set Codex voice and dictation shortcuts in **Codex → Settings → Voice**. The current Codex desktop build persists these in `~/.codex/keybindings.json`; they are separate from the documented `~/.codex/config.toml` CLI configuration. If Hold to Dictate has not been saved there yet, MicTrigger uses Control–Shift–D as its fallback.
- Set Claude Quick Entry and voice dictation shortcuts in **Claude → Settings → General**. The current Claude desktop build persists these inside `~/Library/Application Support/Claude/config.json`. Claude Quick Entry defaults to double Option; Claude voice dictation remains disabled until it is assigned in Claude.

These persistence formats are implementation details of the currently installed desktop builds, not public configuration APIs. Prefer changing the shortcut in the app’s own Settings UI; MicTrigger only reads the resulting values and never rewrites either app’s configuration.

Key-combination actions can use **Tap shortcut** or **Press once to hold · again to release**. Codex Hold to Dictate defaults to the second mode, so the DJI button starts the held shortcut with one click and releases it with the next click. You never hold the transmitter button itself.

Held actions also have an **After release** option. Codex Hold to Dictate defaults to **Press Return**, so the second Mic Mini press releases the configured Codex shortcut, waits briefly for Codex to commit the transcription, and then taps Return.

The single-press action has a 420 ms recognition delay so MicTrigger can distinguish it from double and triple presses. Press-and-hold is not mapped because DJI reserves a two-second hold for pairing.

## Hardware behavior

The Mic Mini receiver presents the shutter as USB HID consumer volume input. The known receiver identifiers are:

- Vendor: `0x2CA3` (DJI)
- Product: `0x4011`
- Product name: `Wireless Mic Rx`

**Identify Shutter Button** can learn a different compatible receiver. When “Prevent the shutter press from changing volume” is enabled, MicTrigger exclusively opens the selected consumer-control interface; it does not seize the receiver’s audio interface or your keyboard.

## Why macOS, not iOS

iOS can use the Mic Mini button as a camera shutter in compatible foreground apps, but a third-party iOS app cannot globally observe that button and synthesize arbitrary key combinations inside other apps. macOS provides the user-approved Input Monitoring and Accessibility APIs required for this workflow. An iOS companion could manage documentation or Shortcuts automations, but it could not provide the cross-app remapper implemented here.

## Development

```sh
swift test
swift run MicTrigger
./scripts/build-app.sh
./scripts/create-dmg.sh
```

The build script prefers a Developer ID or Apple Development signing identity from your keychain and otherwise falls back to ad-hoc signing. A warning-free public download must be signed with a Developer ID Application certificate and notarized before distribution.
