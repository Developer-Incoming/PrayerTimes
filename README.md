# Prayer Times iOS App

A clean, modern, native iOS Prayer Times app and WidgetKit extension built with **SwiftUI** and **Swift 5.9 / 6**.

Designed to blend natively into the user's iOS environment, adapting seamlessly to **Light and Dark mode**, **Dynamic Type**, system typography, and native controls.

Astronomical prayer time calculations are based on the GitHub repository [PrayerTimes-Swift](https://github.com/ashikahmad/PrayerTimes-Swift) (by Ashik Ahmad, originally ported from praytimes.org), modernized and expanded into an independent, cross-platform Swift package (`PrayerKit`).

---

## Features

### 1. Today View
* **Native iOS Aesthetics**: Adapts cleanly to system colors, accessibility settings, and Dark Mode.
* **Next Prayer Hero Card**: Displays the upcoming prayer, exact time, and a live relative countdown (`in 35m`).
* **Dynamic Elapsed Status**: When a prayer began recently, the view prominently shows the elapsed time (e.g. *"Dhuhr began 12m ago"*).
* **Today's Prayer Schedule**: Clean list of Fajr, Sunrise, Dhuhr, Asr, Maghrib, and Isha with SF Symbols and notification status badges.
* **Contextual Actions**: Long-press any prayer to quickly toggle or change notifications (Sound, Silent, Off).

### 2. Calendar View
* **Graphical Calendar Picker**: Native iOS graphical calendar component to browse prayer times for any past or future date.
* **Dual Calendars**: Displays Gregorian and Hijri dates simultaneously for the selected day.
* **Instant Return**: Quick "Today" action in the toolbar to jump back to current date.

### 3. Settings & Advanced Options
* **Minimal Core Settings**:
  * Location selection: automatic GPS / CoreLocation or search from hundreds of thousands of cities via MapKit.
  * Calculation methods: Muslim World League (MWL), ISNA, Egyptian General Authority, Umm al-Qura (Makkah), Karachi, Tehran, Jafari, Gulf, Kuwait, Qatar, Singapore, France, Turkey, Russia, Dubai, and Custom.
  * Asr calculation: Standard (Shafi'i, Maliki, Hanbali, Ja'fari) vs. Hanafi.
* **Advanced Settings**:
  * **Custom Sun Depression Angles**: Fine-tune Fajr, Maghrib, and Isha angles or minute intervals.
  * **Higher Latitude Adjustments**: Middle of the night, 1/7th of the night, or angle-based formulas for polar / high-latitude regions.
  * **Manual Minute Adjustments (Tune)**: Add or subtract (-30 to +30 min) per prayer to match a local mosque timetable.
  * **Time Format Preferences**: System default, 12-Hour (AM/PM), or 24-Hour.
  * **Hijri Calendar Adjustments**: Select calendar rules (Umm al-Qura, Civil, Tabular, Astronomical), shift by ±2 days for moon sightings, and toggle whether the new Hijri day begins at Maghrib (Islamic sunset) or midnight.
  * **Manual Coordinates**: Direct entry of latitude, longitude, and custom time zone.

### 4. Standard iOS Notifications
* **Native System Notifications**: Uses standard `UNUserNotificationCenter` local notifications.
* **Per-Prayer Notification Styles**:
  * **Sound**: Default system alert sound and banner.
  * **Silent**: Notification banner and lock screen entry without audio interruption.
  * **Off**: Disable notifications for specific times (e.g., Sunrise).
* **Advance Reminders**: Optional early reminder (5, 10, 15, 20, 30, 45, or 60 minutes before prayer).
* **Time Sensitive Alerts**: Configured to break through Focus modes and remain visible on the Lock Screen.
* **Rolling Scheduling Window**: Automatically maintains up to 60 pending notifications, refreshed via foreground app activation and `BGAppRefreshTask`.
* **Test Notification**: Send a test notification in 5 seconds to verify alert permissions.

### 5. Dynamic Widgets (`PrayerTimesWidget`)
* **Widget Sizes Supported**:
  * **Home Screen**: Small (`systemSmall`), Medium (`systemMedium`), Large (`systemLarge`).
  * **Lock Screen Accessories**: Inline (`accessoryInline`), Circular (`accessoryCircular`), Rectangular (`accessoryRectangular`).
* **Dynamic Time Tracking**:
  * Shows next upcoming prayer and live countdown.
  * Dynamically changes to display elapsed time since prayer started (e.g. *"Asr 15m ago"*) during a configurable window after prayer begins.
* **Interactive Widget Configuration (App Intents)**:
  * Toggle **Hijri Date** display (long or short).
  * Toggle **Live Countdown**.
  * Configure **Time Since Prayer Began** window (Off, 10m, 15m, 20m, 30m, 45m, 1 hour).
  * Toggle **Include Sunrise**.
  * Toggle **Show Location Name**.
  * Toggle **Show All Today's Times** on medium and large widgets.
* **Shared App Group Storage**: Seamless synchronization of settings and calculations between app and widget via `group.com.antigravity.PrayerTimes`.

---

## Calculations & Bug Fixes from Reference

Calculations are housed in `Packages/PrayerKit`, based on [ashikahmad/PrayerTimes-Swift](https://github.com/ashikahmad/PrayerTimes-Swift). During the port, several critical upstream bugs were addressed and verified with automated test suites:

1. **Julian Date Bug Fix**:
   * *Upstream*: `julianDate(from:)` calculated components from `Date()` instead of the passed-in date, causing every requested date to produce today's prayer times.
   * *Fixed*: Correctly computes Julian day from the requested target calendar date.
2. **February Date Calculation Bug Fix**:
   * *Upstream*: Used `month < 2` instead of `month <= 2` in the astronomical Julian day reduction, corrupting all dates in February.
   * *Fixed*: Corrected to `month <= 2`, ensuring smooth mathematical continuity across January, February, and March.
3. **Refinement Iteration Bug Fix**:
   * *Upstream*: The iteration loop repeatedly overwrote refined values with the default seed times rather than feeding the refined times into the next iteration.
   * *Fixed*: Now refines iteratively (defaulting to 2 iterations), bringing results to within ≤ 1 minute of standard independent reference astronomical implementations (such as Adhan).
4. **Value Types & Concurrency (`Sendable`)**:
   * *Upstream*: `AKPrayerTime` was a UIKit-dependent class using non-thread-safe state mutation.
   * *Fixed*: Rewritten as an immutable, `Sendable` value-type struct with no UIKit dependencies, allowing it to run safely across background tasks, Swift Concurrency actors, and unit tests on Linux.

---

## Project Structure

```
PrayerTimesApp/
├── Packages/
│   └── PrayerKit/                    # Shared core calculation engine
│       ├── Package.swift             # Swift Package manifest (iOS 17+, macOS 14+)
│       ├── Sources/PrayerKit/
│       │   ├── PrayerTimeCalculator.swift # Astronomical algorithm & bug fixes
│       │   ├── Prayer.swift          # Prayer enum & models
│       │   ├── PrayerSchedule.swift  # Scheduling, transitions, notification plan
│       │   ├── PrayerSettings.swift  # Codable user preferences
│       │   ├── SettingsStore.swift   # App Group UserDefaults bridge
│       │   └── Formatters.swift      # Time & Hijri calendar formatters
│       └── Tests/PrayerKitTests/
│           ├── PrayerTimeCalculatorTests.swift # Reference verification & regression tests
│           ├── PrayerScheduleTests.swift       # Widget & notification tests
│           └── ReferenceData.swift             # 384 astronomical benchmark points
├── PrayerTimes/                      # Main iOS App Target
│   ├── PrayerTimesApp.swift          # @main entry point & UNUserNotificationCenterDelegate
│   ├── Model/
│   │   └── AppModel.swift            # Observable central state
│   ├── Services/
│   │   ├── LocationService.swift     # CoreLocation & reverse geocoding
│   │   ├── NotificationScheduler.swift # Local notification management
│   │   └── BackgroundRefresh.swift   # BGAppRefreshTask handling
│   ├── Views/
│   │   ├── ContentView.swift         # Root TabView (Today, Calendar, Settings)
│   │   ├── TodayView.swift           # Today's times & countdown
│   │   ├── CalendarView.swift        # Calendar date picker & day times
│   │   ├── Components.swift          # Reusable prayer rows & cards
│   │   └── Settings/
│   │       ├── SettingsView.swift    # Minimal settings
│   │       ├── AdvancedSettingsView.swift # Angles, high latitudes, tune, Hijri
│   │       ├── NotificationSettingsView.swift # Notification configurations
│   │       └── LocationSearchView.swift # MapKit search & manual coords
│   ├── Assets.xcassets/              # App icon & asset catalog
│   ├── Info.plist                    # App metadata & background permissions
│   └── PrayerTimes.entitlements      # App Groups & Time Sensitive notifications
├── PrayerTimesWidget/                # WidgetKit Extension Target
│   ├── PrayerTimesWidget.swift       # Small, Medium, Large & Accessory views
│   ├── NextPrayerIntent.swift        # App Intent configuration options
│   ├── NextPrayerProvider.swift      # AppIntentTimelineProvider
│   ├── Info.plist                    # Widget extension metadata
│   └── PrayerTimesWidget.entitlements# App Groups entitlement
├── project.yml                       # XcodeGen project specification
└── PrayerTimes.xcodeproj             # Xcode project bundle
```

---

## Building & Testing

### Running Tests (Linux & macOS)
You can build and run the 29 unit tests in `PrayerKit` directly using SwiftPM:

```bash
cd Packages/PrayerKit
swift test
```

### Opening in Xcode (macOS)
1. Double click `PrayerTimes.xcodeproj` or run:
   ```bash
   open PrayerTimes.xcodeproj
   ```
2. Select the `PrayerTimes` scheme and an iOS Simulator (e.g. iPhone 16 Pro, iOS 17 or 18).
3. Press **Cmd + R** to run.

### Regenerating Project with XcodeGen
If you modify `project.yml`, regenerate the Xcode project:

```bash
xcodegen generate
```

---

## GitHub Actions & TestFlight Deployment

A complete CI/CD workflow is provided in [`.github/workflows/testflight.yml`](.github/workflows/testflight.yml) to build for iOS & iPadOS, run unit tests, and upload `.ipa` releases directly to Apple TestFlight.

### Triggers
* **Push to `main` / `master`** or **tag `v*`**: Automatically builds and uploads to TestFlight.
* **Pull Requests**: Runs test suite and verifies compilation on iOS/iPadOS without requiring signing credentials.
* **Manual trigger (`workflow_dispatch`)**: Trigger on-demand builds from the GitHub Actions tab.

### Required GitHub Repository Secrets

Configure the following secrets in **Repository Settings → Secrets and variables → Actions**:

| Secret Name | Description |
| :--- | :--- |
| `APPLE_CERTIFICATE_BASE64` | Base64-encoded Apple Distribution Certificate (`.p12` file) |
| `APPLE_CERTIFICATE_PASSWORD` | Password used when exporting the `.p12` certificate |
| `APPLE_TEAM_ID` | 10-character Apple Developer Team ID (e.g. `ABC1234567`) |
| `PROVISIONING_PROFILE_APP_BASE64` | Base64-encoded App Store profile for `com.antigravity.PrayerTimes` |
| `PROVISIONING_PROFILE_WIDGET_BASE64` | Base64-encoded App Store profile for `com.antigravity.PrayerTimes.PrayerTimesWidget` |
| `APP_STORE_CONNECT_KEY_ID` | Key ID from App Store Connect (e.g. `2X9R4274KC`) |
| `APP_STORE_CONNECT_ISSUER_ID` | Issuer ID from App Store Connect (UUID format) |
| `APP_STORE_CONNECT_PRIVATE_KEY` | Content of the `.p8` API key file (or base64 encoded) |

#### How to Generate the Secrets:
1. **Certificate (`.p12`)**:
   In macOS **Keychain Access**, export your Apple Distribution Certificate as a `.p12` file with a password, then run:
   ```bash
   base64 -i distribution.p12 | pbcopy
   ```
2. **Provisioning Profiles (`.mobileprovision`)**:
   Download the App Store distribution profiles for both App and Widget from the Apple Developer Portal:
   ```bash
   base64 -i PrayerTimes_AppStore.mobileprovision | pbcopy
   base64 -i PrayerTimesWidget_AppStore.mobileprovision | pbcopy
   ```
3. **App Store Connect API Key (`.p8`)**:
   In [App Store Connect](https://appstoreconnect.apple.com/) → **Users and Access** → **Integrations** → **App Store Connect API**, generate a key with the **Developer** or **App Manager** role.

---

## Sideloading (No Apple Developer Account Required)

If you do not have a paid Apple Developer Account, you can build and download a ready-to-sideload `.ipa` file using [`.github/workflows/build-ipa.yml`](.github/workflows/build-ipa.yml).

### How to Get the `.ipa` from GitHub Actions:
1. Push your code to GitHub (or go to your repository on GitHub).
2. Click the **Actions** tab at the top.
3. Select **Build Sideloadable IPA** from the left sidebar.
4. Click **Run workflow** (or select the latest completed run).
5. Once the job completes, scroll down to the **Artifacts** section at the bottom of the page.
6. Click **`PrayerTimes-Sideloadable-IPA`** to download the zip file.
7. Unzip the file on your computer to obtain `PrayerTimes.ipa`.

### How to Install on iPad or iPhone:
You can sign and install `PrayerTimes.ipa` with a free personal Apple ID using any popular sideloading tool:

* **[Sideloadly](https://sideloadly.io/) (Windows & Mac)**:
  1. Connect your iPhone/iPad to your computer via USB or Wi-Fi.
  2. Open Sideloadly and drag `PrayerTimes.ipa` into the window.
  3. Enter your free personal Apple ID email and password (used only to generate the free 7-day provisioning certificate).
  4. Click **Start** to install the app onto your device.
* **[AltStore](https://altstore.io/) / [SideStore](https://sidestore.io/)**:
  1. Open AltStore or SideStore on your device.
  2. Go to **My Apps**, tap the `+` button in the top corner.
  3. Select `PrayerTimes.ipa` to install.
* **[TrollStore](https://github.com/opa334/TrollStore) (iOS 14.0 – 16.6.1 / 17.0)**:
  1. AirDrop or download `PrayerTimes.ipa` directly to your device.
  2. Share/open with TrollStore for permanent, revoke-free installation without signing.

#### First-Time Sideloading Setup on iOS 16, 17, and 18:
1. **Enable Developer Mode**: On your iOS device, go to **Settings → Privacy & Security → Developer Mode** and toggle it **On** (restart device when prompted).
2. **Trust Your Certificate**: Go to **Settings → General → VPN & Device Management**, tap your personal Apple ID under *Developer App*, and tap **Trust**.


