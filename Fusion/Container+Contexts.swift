import Foundation

extension Container {
    /// All command line arguments of the application.
    public var arguments: [String] { ProcessInfo.processInfo.arguments }
    /// `true` if application is running in an Xcode preview.
    public var isPreview: Bool { ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" }
    /// `true` if application is running in a test.
    public var isTest: Bool { NSClassFromString("XCTest") != nil }
    /// `true` if application is running on a simulator.
    public var isSimulator: Bool { ProcessInfo.processInfo.environment["SIMULATOR_UDID"] != nil }
    /// `true` if application is running on a real device.
    public var isDevice: Bool { !isSimulator }
    /// `true` if application is running in DEBUG.
    public var isDebug: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }
}
