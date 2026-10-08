// swift-tools-version:5.9
//
// PrayerKit — platform‑independent prayer time engine shared by the
// Prayer Times iOS app and its widget extension.
//
// The astronomical calculation is ported from AKPrayerTime
// (https://github.com/ashikahmad/PrayerTimes-Swift), which itself is a port of
// the praytimes.org algorithm. Only Foundation is used so the package can be
// built and unit‑tested on any platform (`swift test`).

import PackageDescription

let package = Package(
    name: "PrayerKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .watchOS(.v10)
    ],
    products: [
        .library(name: "PrayerKit", targets: ["PrayerKit"])
    ],
    targets: [
        .target(name: "PrayerKit"),
        .testTarget(name: "PrayerKitTests", dependencies: ["PrayerKit"])
    ]
)
