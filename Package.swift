// swift-tools-version:5.10

import PackageDescription

let package = Package(
    name: "DTPhotoViewerController",
    platforms: [
        .iOS(.v12),
    ],
    products: [
        .library(name: "DTPhotoViewerController", targets: ["DTPhotoViewerController"]),
    ],
    targets: [
        .target(
            name: "DTPhotoViewerController",
            path: "DTPhotoViewerController/Classes"),
    ]
)
