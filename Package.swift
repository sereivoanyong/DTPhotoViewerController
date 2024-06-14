// swift-tools-version:5.10

import PackageDescription

let package = Package(
    name: "DTPhotoViewerController",
    platforms: [
        .iOS(.v15),
    ],
    products: [
        .library(name: "DTPhotoViewerController", targets: ["DTPhotoViewerController"])
    ],
    dependencies: [
        .package(url: "https://github.com/sereivoanyong/GSPlayer", branch: "sy/main"),
        .package(url: "https://github.com/onevcat/Kingfisher", from: "7.12.0")
    ],
    targets: [
        .target(name: "DTPhotoViewerController", dependencies: ["GSPlayer", "Kingfisher"]),
    ]
)
