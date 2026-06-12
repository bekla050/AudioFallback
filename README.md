# AudioFallback

AudioFallback is a small macOS menu bar app for prioritized default audio
devices.

It manages separate priority lists for input devices (microphones) and output
devices (speakers/headphones). When devices appear or disappear, AudioFallback
selects the first available device from the relevant list.

## Download

Download the signed and notarized DMG:
[AudioFallback-0.2.0.dmg](https://github.com/bekla050/AudioFallback/raw/main/dist/AudioFallback-0.2.0.dmg)

## Scope

This is an open-source MVP focused on device priority and fallback behavior.
Per-app audio routing, effects, volume boosting, recording, and virtual audio
drivers are intentionally out of scope.

## Run

```sh
swift run AudioFallback
```

The app appears in the menu bar. Open **Settings...** to sort microphones and
speakers independently, enable or disable automatic switching, and choose
whether AudioFallback should start when you log in.

Preferences are stored at:

```text
~/Library/Application Support/AudioFallback/preferences.json
```

## Build and Test

```sh
swift test
swift build
scripts/build-app.sh
```

The app bundle is written to:

```text
.build/release/AudioFallback.app
```

## Current Behavior

- Input and output priorities are independent.
- Newly discovered devices are appended to the end of the matching priority
  list.
- When switching output devices, the app sets both the default output device and
  the system output device.
- The fallback decision logic is covered by unit tests.
- The UI is localized in English, German, French, Spanish, Italian, Brazilian
  Portuguese, Simplified Chinese, Japanese, Korean, and Dutch.

## Limitations

- AudioFallback is a regular user-space app, not a virtual audio driver.
- Bluetooth "output only" enforcement is not implemented. The app can prefer a
  separate microphone over a headset microphone, but macOS and individual apps
  may still apply their own audio-device behavior.

## License

AudioFallback is released under the MIT License. See [LICENSE](LICENSE).
