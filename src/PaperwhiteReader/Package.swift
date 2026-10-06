// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PaperwhiteReader",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "PaperwhiteReader", targets: ["PaperwhiteReader"])],
    targets: [.executableTarget(name: "PaperwhiteReader")]
)
