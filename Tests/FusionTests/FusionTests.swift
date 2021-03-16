import XCTest
@testable import Fusion

final class FusionTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(Fusion().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
