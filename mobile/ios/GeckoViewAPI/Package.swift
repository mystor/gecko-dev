// swift-tools-version:5.5
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import PackageDescription

let package = Package(
    name: "GeckoViewAPI",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "GeckoViewAPI", targets: ["GeckoViewAPI"]),
    ],
    targets: [
        .target(name: "GeckoViewAPI", dependencies: ["GeckoViewSupport"]),
        .target(name: "GeckoViewSupport"),
    ]
)
