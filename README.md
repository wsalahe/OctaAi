# OctaAi

<img width="1280" height="640" alt="OctaAi" src="https://github.com/user-attachments/assets/f0ae2e95-7663-4166-a6be-27ed76791ae2" />

A free, open-source Android browser. Ad-free, no tracking, lightweight, with on-device AI features.

[![Build APK](https://github.com/wsalahe/OctaAi/actions/workflows/build-apk.yml/badge.svg)](https://github.com/wsalahe/OctaAi/actions/workflows/build-apk.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Download APK](https://img.shields.io/badge/download-APK-brightgreen)](https://github.com/wsalahe/OctaAi/releases/latest/download/app-release.apk)

## Why OctaAi

- **No ads, no trackers.** A built-in content blocker cuts the biggest ad and tracking networks before they load, with a live block counter.
- **Private by default.** DuckDuckGo search, third-party cookies off, nothing sent anywhere.
- **Tabs, bookmarks, history.** A real browser, not a demo.
- **On-device AI summary.** Long page? Get a short summary made on your phone. No account, no API key, nothing leaves the device.
- **Handles files and video.** Fullscreen HTML5 video, zoom, and files open in the right external app.
- **Lightweight.** One small APK, dark and light themes.

## Install

1. Download the latest APK: **[app-release.apk](https://github.com/wsalahe/OctaAi/releases/latest/download/app-release.apk)**
2. Open it on your Android phone and allow install from this source.
3. Done.

Every push to `main` builds a fresh APK with GitHub Actions and publishes it as a release, so the link above is always the newest build.

## Privacy

- No ads and no trackers: a built-in content blocker cuts the biggest ad and tracking networks before they load
- No accounts, no sign-in, no analytics in the app
- DuckDuckGo is the default search, third-party cookies are off
- The AI summary runs fully on your phone; page text never leaves the device

## Roadmap

- v0.2 (current): tabs, bookmarks, history, block counter, dark/light mode, launcher icon
- M2: reader mode, text-to-speech, in-app download manager
- M3: on-device translation, more blocklists

## Build it yourself

```bash
flutter pub get
flutter create --platforms android --project-name octaai --org dev.octaai .
flutter build apk --release
```

## License

MIT. See [LICENSE](LICENSE).
