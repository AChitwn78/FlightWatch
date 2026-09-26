// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "FlightWatch", platforms: [.macOS(.v13), .iOS(.v16)], products: [.executable(name: "FlightWatch", targets: ["FlightWatch"])], targets: [.target(name: "FlightCore"), .executableTarget(name: "FlightWatch", dependencies: ["FlightCore"]), .testTarget(name: "FlightCoreTests", dependencies: ["FlightCore"])])
