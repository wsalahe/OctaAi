# OctaAi

A free, open-source Android browser. Ad-free, no tracking, lightweight, with on-device AI features.

[![Build APK](https://github.com/wsalahe/OctaAi/actions/workflows/build-apk.yml/badge.svg)](https://github.com/wsalahe/OctaAi/actions/workflows/build-apk.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Download APK](https://img.shields.io/badge/download-APK-brightgreen)](https://github.com/wsalahe/OctaAi/releases/latest/download/app-release.apk)

## Why OctaAi

- **No ads, no trackers.** A built-in content blocker cuts the biggest ad and tracking networks before they load.
- **Private by default.** DuckDuckGo search, third-party cookies off, nothing sent anywhere.
- **On-device AI summary.** Long page? Tap the sparkles icon and get a short summary made on your phone. No account, no API key, nothing leaves the device.
- **Handles files and video.** Fullscreen HTML5 video, zoom, and files open in the right external app.
- **Lightweight.** One small APK, no bloat, dark theme.

## Install

1. Download the latest APK: **[app-release.apk](https://github.com/wsalahe/OctaAi/releases/latest/download/app-release.apk)**
2. Open it on your Android phone and allow install from this source.
3. Done.

Every push to `main` builds a fresh APK with GitHub Actions and publishes it as a release, so the link above is always the newest build.

## Roadmap

- v1 (this build): address bar with DuckDuckGo search, back/forward/reload/home, ad and tracker blocking, fullscreen video, external file handling, on-device page summary
- M2: tabs, bookmarks and history, reader mode, text-to-speech
- M3: on-device translation, more blocklists

## Build it yourself

```bash
flutter pub get
flutter create --platforms android --project-name octaai --org dev.octaai .
flutter build apk --release
```

## License

MIT. See [LICENSE](LICENSE).
