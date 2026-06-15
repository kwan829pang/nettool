# NetTool — Risk Check Report

**Project:** NetTool (`net_tool`)  
**Report date:** 2026-06-11  
**Scope:** Static review of source, platform configs, dependencies, and operational behavior  
**Method:** Code inspection (`flutter analyze` passes; no runtime penetration testing)

---

## Executive Summary

NetTool provides subnet scanning, port scanning, and internet/LAN speed tests. The desktop (Windows) path is the most complete. **Mobile and macOS release builds have platform configuration gaps** that will block or weaken core features. **Security and legal exposure** comes mainly from unrestricted network probing and an unauthenticated LAN speed-test server.

| Severity | Count |
|----------|------:|
| Critical | 1 |
| High     | 7 |
| Medium   | 18 |
| Low      | 12 |

---

## Risk Register

### 1. Security

| ID | Severity | Risk | Location | Mitigation |
|----|----------|------|----------|------------|
| SEC-01 | **High** | Internal speed-test server binds to all IPv4 interfaces (`InternetAddress.anyIPv4`) with no authentication. Any reachable client can call `/ping`, `/download` (up to 100 MB), and `/upload`. | `lib/services/internal_speed_test_server.dart` (L13–17, L25–55) | Bind to loopback or a chosen interface; add token auth; rate-limit; show firewall/LAN exposure warning in UI. |
| SEC-02 | **High** | Port scan accepts any user-supplied IP/hostname with no scope restriction or blocklist. Supports up to 65,535 ports at concurrency 64. | `lib/screens/port_scan_panel.dart`, `lib/services/port_scan_service.dart` | Default to RFC1918/link-local; require explicit opt-in for external targets; cap range/concurrency; legal warning before scan. |
| SEC-03 | Medium | Internal LAN speed tests use cleartext HTTP. Traffic can be observed or modified on the LAN. | `lib/services/internal_speed_test_service.dart` | Use TLS where possible, or label clearly as unencrypted LAN-only test. |
| SEC-04 | Medium | Public IP is fetched from third-party endpoints (`api.ipify.org`, `icanhazip.com`) on panel load, disclosing egress IP to those services. | `lib/services/network_info_service.dart`, `lib/screens/speed_test_panel.dart` | Disclose in UI; make opt-in; allow disable or provider choice. |
| SEC-05 | Medium | `_isValidPublicIp` validates octet format only (0–255), not private/reserved ranges. A misbehaving endpoint could return RFC1918 addresses shown as “Global IP”. | `lib/services/network_info_service.dart` | Reject private, loopback, link-local, and CGNAT ranges before display. |
| SEC-06 | Medium | Subnet scan pings up to 254 hosts (concurrency 32) with no restriction to networks the user owns. | `lib/services/network_scan_service.dart`, `lib/services/network_info_service.dart` | Default to auto-detected local /24; warn before scanning; optional allowlist. |
| SEC-07 | Low | Raw exception messages are shown in the UI (`Scan failed: $e`, etc.), which may expose internal error detail. | `lib/screens/*_panel.dart` | Map to user-safe messages; log details only in debug builds. |

---

### 2. Platform & Build

| ID | Severity | Risk | Location | Mitigation |
|----|----------|------|----------|------------|
| PLT-01 | **Critical** | Android **release** manifest has no `INTERNET` permission. It exists only in debug/profile overlays. Release builds cannot use networking (scans, speed tests, public IP). | `android/app/src/main/AndroidManifest.xml` vs `android/app/src/debug/AndroidManifest.xml` | Add `<uses-permission android:name="android.permission.INTERNET"/>` to the main manifest. |
| PLT-02 | **High** | Android 9+ blocks cleartext HTTP by default. No `usesCleartextTraffic` or `networkSecurityConfig` is defined. LAN internal speed tests may fail on Android release. | `android/app/src/main/AndroidManifest.xml`, `lib/services/internal_speed_test_service.dart` | Add cleartext exception scoped to private IP ranges only, or use HTTPS for internal tests. |
| PLT-03 | **High** | macOS **Release** entitlements enable App Sandbox only—no `network.client` or `network.server`. Debug/Profile has `network.server` only. Release macOS builds are likely blocked from outbound scans and hosting the internal server. | `macos/Runner/Release.entitlements`, `macos/Runner/DebugProfile.entitlements` | Add `com.apple.security.network.client` (and `network.server` if hosting) to Release entitlements. |
| PLT-04 | **High** | iOS `Info.plist` has no `NSLocalNetworkUsageDescription`, Bonjour keys, or location keys. Local network discovery, ping scans, and LAN speed tests may be blocked or rejected by App Store review (iOS 14+). | `ios/Runner/Info.plist` | Add required usage descriptions and Bonjour entries per Apple local-network policy. |
| PLT-05 | Medium | App uses `network_info_plus` (`getWifiIP`, etc.) but does not declare Android location permissions or request them at runtime. WiFi IP/gateway may return null on Android API 29+. | `lib/services/network_info_service.dart`, `android/app/src/main/AndroidManifest.xml` | Add manifest permissions and runtime permission flow. |
| PLT-06 | Medium | Network scan shells out to `ping` via `Process.run`. Often unavailable or restricted in Android/iOS sandboxes; Windows uses `runInShell: true`. | `lib/services/network_scan_service.dart` | Use platform-appropriate reachability APIs; document desktop-only support or implement mobile alternatives. |
| PLT-07 | Medium | Release Android builds use debug signing keys. | `android/app/build.gradle.kts` (L34–38) | Configure a release keystore before distribution. |
| PLT-08 | Low | `MainActivity` is `android:exported="true"`. Acceptable for a launcher app; review if deep links are added. | `android/app/src/main/AndroidManifest.xml` | Keep exported surface minimal. |
| PLT-09 | Low | Stale CMake/build cache after project path rename (`self-network-tools` → `nettool`) causes build failures until `flutter clean` is run. | `build/` directory | Document rename procedure; add clean step to CI. |

---

### 3. Dependencies & Supply Chain

| ID | Severity | Risk | Location | Mitigation |
|----|----------|------|----------|------------|
| DEP-01 | Medium | No `pubspec.lock` committed. `.gitignore` excludes `*.lock`, so dependency versions are not pinned across environments. | `.gitignore` (L3), `pubspec.yaml` | Remove `pubspec.lock` from ignore rules; commit lockfile; run `flutter pub audit` in CI. |
| DEP-02 | Low | Loose semver constraints (`^5.0.2`, `^6.0.2`) allow drift between environments without a lockfile. | `pubspec.yaml` | Pin with lockfile; review updates deliberately. |
| DEP-03 | Low | No automated dependency audit configured in-repo. Resolved versions may lag behind security patches. | `pubspec.yaml` | Periodically run `flutter pub outdated` and `flutter pub audit`. |

---

### 4. Legal & Compliance

| ID | Severity | Risk | Location | Mitigation |
|----|----------|------|----------|------------|
| LEG-01 | **High** | No in-app or README disclaimer that port scanning and network discovery may be illegal without authorization on networks the user does not own or manage. | `README.md`, `lib/screens/*_panel.dart` | Add first-run consent and persistent “authorized use only” notice; link to applicable laws/terms. |
| LEG-02 | Medium | README describes business network use but does not state authorized-use requirements or liability limits. | `README.md` | Add explicit authorized-use and liability disclaimer. |
| LEG-03 | Medium | Apache 2.0 `LICENSE` has unfilled template placeholders (`Copyright [yyyy] [name of copyright owner]`). Redistribution compliance is incomplete. | `LICENSE` (L189–191) | Complete copyright notice; add `NOTICE` for third-party deps if distributing binaries. |
| LEG-04 | Low | Internet speed tests send traffic to Cloudflare endpoints without explicit third-party processing disclosure beyond UI copy. | `lib/services/internet_speed_test_service.dart`, `lib/screens/speed_test_panel.dart` | Expand disclosure; link to Cloudflare terms where applicable. |

---

### 5. Operational

| ID | Severity | Risk | Location | Mitigation |
|----|----------|------|----------|------------|
| OPS-01 | Medium | Cancellation is checked only between batches. In-flight `Socket.connect`, `ping`, and `Future.wait` work continues until the batch finishes. | `lib/services/port_scan_service.dart`, `lib/services/network_scan_service.dart` | Use per-task timeouts; abort sockets on cancel. |
| OPS-02 | Medium | Internet `measureLatency()` has no cancellation support; stop is ineffective during that phase. | `lib/services/internet_speed_test_service.dart` | Add cancellation/timeouts to latency measurement. |
| OPS-03 | Medium | Internal server allows up to 100 MB per `/download` request with no rate limiting—LAN DoS/resource exhaustion risk while server is running. | `lib/services/internal_speed_test_server.dart` (L34–38, L58–73) | Lower defaults; throttle concurrent requests; cap bytes per client/IP. |
| OPS-04 | Medium | `_internalServer.stop()` is called in `dispose()` without `await`; shutdown may be incomplete on app exit. | `lib/screens/speed_test_panel.dart` | Ensure graceful shutdown; await stop where possible. |
| OPS-05 | Low | On cancel during `testBoth`, return value duplicates read result as write, producing misleading results. | `lib/services/internal_speed_test_service.dart` | Return partial/null write result on cancel. |
| OPS-06 | Low | Server `listen` uses `onError: (_) {}`, swallowing bind/runtime errors silently. | `lib/services/internal_speed_test_server.dart` (L17) | Log/report errors to UI. |
| OPS-07 | Low | Internet speed test downloads 25 MB and uploads 10 MB per run with no user-configurable limits—bandwidth/cost impact on metered connections. | `lib/services/internet_speed_test_service.dart` | Check metered connectivity; offer smaller sizes. |
| OPS-08 | Low | `IndexedStack` keeps all panels alive; internal server can keep running when user switches tabs. | `lib/screens/home_screen.dart`, `lib/screens/speed_test_panel.dart` | Stop server on tab change or show persistent server indicator. |

---

### 6. Code Quality & Maintainability

| ID | Severity | Risk | Location | Mitigation |
|----|----------|------|----------|------------|
| QA-01 | Medium | `hostsInSubnet` regex accepts any `/\d+$` suffix but always generates a /24 host list (254 hosts). Non-/24 subnets are misleading. | `lib/services/network_info_service.dart` | Validate CIDR; support prefix lengths correctly or reject non-/24 input. |
| QA-02 | Medium | Subnet regex does not validate octet ranges (e.g. `999.999.999.0/24` is accepted). | `lib/services/network_info_service.dart` | Reuse octet validation from `subnetFromIp`. |
| QA-03 | Medium | `hasNetworkConnection()` is implemented but never called; internet tests start without a connectivity check. | `lib/services/network_info_service.dart` | Call before speed tests/scans or remove dead code. |
| QA-04 | Medium | Only a smoke widget test exists; no tests for port scan, network scan, speed services, or input validation. | `test/widget_test.dart` | Add unit tests for services and validation edge cases. |
| QA-05 | Low | Home screen status bar is hardcoded to `'Ready'` and does not reflect scan/test state. | `lib/screens/home_screen.dart` | Wire status to active panel state or remove misleading indicator. |
| QA-06 | Low | Port/host inputs lack format validation in UI (only empty checks); invalid ports fall back to `8765` silently. | `lib/screens/speed_test_panel.dart`, `lib/screens/port_scan_panel.dart` | Validate IP/hostname and port range 1–65535 before operations. |

---

## Positive Observations

- `.gitignore` excludes build artifacts, `.dart_tool/`, `key.properties`, and `*.jks`.
- `HttpClient` instances are closed in `finally` blocks in speed-test and network-info services.
- Open port sockets are closed after probe in `PortScanService`.
- Port range is validated server-side (1–65535) in `PortScanService`.
- Internal speed-test server avoids disk I/O (in-memory buffers only).
- No secrets or credentials found in reviewed source files.
- `flutter analyze` reports no static analysis issues.

---

## Priority Actions

| Priority | Action | Risk IDs |
|----------|--------|----------|
| P0 | Add `INTERNET` to `android/app/src/main/AndroidManifest.xml` | PLT-01 |
| P0 | Add authorized-use / legal disclaimers before port and network scanning | LEG-01, LEG-02 |
| P1 | Harden internal speed-test server (bind address, auth, rate limits) | SEC-01, OPS-03 |
| P1 | Fix macOS Release network entitlements | PLT-03 |
| P1 | Add iOS local-network privacy keys before mobile distribution | PLT-04 |
| P2 | Commit `pubspec.lock` (update `.gitignore`) and complete `LICENSE` copyright | DEP-01, LEG-03 |
| P2 | Add Android cleartext exception for LAN tests or switch to HTTPS | PLT-02 |
| P3 | Add service unit tests and input validation | QA-04, QA-06 |

---

## Out of Scope / Follow-Up

- Runtime penetration testing or fuzzing of network endpoints.
- External CVE verification (`flutter pub audit` against current advisories).
- App Store / Play Store review simulation.
- Performance benchmarking under load.

---

*This report reflects the codebase as of the report date. Re-run this review after major feature or platform changes.*
