# NetTool

A Flutter app for network utilities: subnet scanning, port scanning, and internet/LAN speed tests.

## Authorized use

**Only use NetTool on networks and systems you own or have explicit written permission to test.** Unauthorized port scanning or network discovery may violate local laws, contracts, or acceptable-use policies. You are responsible for how you use this app.

## Run

```bash
flutter pub get
flutter run -d windows
```

If you renamed or moved the project directory, run `flutter clean` before building to clear stale platform caches.

## Release builds

- **Android:** Configure a release keystore in `android/app/build.gradle.kts` before distributing (debug signing is used by default).
- **All platforms:** See [RISK_CHECK_REPORT.md](RISK_CHECK_REPORT.md) for remaining platform notes.

## App icon

The launcher icon uses `Icons.wifi_tethering` on the NetTool blue background. To regenerate all platform icons:

```bash
flutter run -t tool/generate_app_icon.dart -d windows
dart run flutter_launcher_icons
```

## Features

- **Network Scan** — discover active devices on a local /24 subnet (desktop platforms)
- **Port Scan** — check open TCP ports on a target host (private targets by default)
- **Speed Test** — internet bandwidth (Cloudflare) and internal LAN read/write throughput

## Privacy

- Internet speed tests send traffic to [Cloudflare](https://www.cloudflare.com/website-terms/) endpoints.
- Global IP lookup is **opt-in** and may contact `api.ipify.org` or `icanhazip.com`.
- Internal LAN speed tests use unencrypted HTTP with token authentication.

## License

Apache License 2.0 — see [LICENSE](LICENSE) and [NOTICE](NOTICE).
