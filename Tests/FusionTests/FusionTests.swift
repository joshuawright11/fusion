@testable import Fusion
import XCTest

final class FusionTest: XCTestCase {
    var container: Container = Container()
    
    override func setUp() {
        super.setUp()
        container = Container()
    }
    
    func testTransient() {
        let exp = expectation(description: "called 3x")
        exp.expectedFulfillmentCount = 3
        container.register(String.self) { _ in
            exp.fulfill()
            return "Testing1"
        }
        
        XCTAssertEqual(container.resolve(String.self), "Testing1")
        XCTAssertEqual(container.resolve(String.self), "Testing1")
        XCTAssertEqual(container.resolve(String.self), "Testing1")
        
        self.waitForExpectations(timeout: 0)
    }
    
    func testSingleton() {
        let exp = expectation(description: "called 1x")
        exp.expectedFulfillmentCount = 1
        container.register(singleton: String.self) { _ in
            exp.fulfill()
            return "Testing2"
        }
        
        XCTAssertEqual(container.resolve(String.self), "Testing2")
        XCTAssertEqual(container.resolve(String.self), "Testing2")
        XCTAssertEqual(container.resolve(String.self), "Testing2")
        
        self.waitForExpectations(timeout: 0)
    }
    
    func testSingletonIdentified() {
        let exp = expectation(description: "called 1x")
        exp.expectedFulfillmentCount = 1
        container.register(singleton: String.self, identifier: "test") { _ in
            exp.fulfill()
            return "Testing3"
        }
        
        XCTAssertEqual(container.resolveOptional(String.self), nil)
        XCTAssertEqual(container.resolveOptional(String.self, identifier: "foo"), nil)
        XCTAssertEqual(container.resolve(String.self, identifier: "test"), "Testing3")
        
        self.waitForExpectations(timeout: 0)
    }
    
    func testOverride() {
        container.register(singleton: "Testing1")
        XCTAssertEqual(container.resolve(String.self), "Testing1")
        container.register(singleton: "Testing2")
        XCTAssertEqual(container.resolve(String.self), "Testing2")
        container.register("Testing3")
        XCTAssertEqual(container.resolve(String.self), "Testing3")
        container.register("Testing4")
        XCTAssertEqual(container.resolve(String.self), "Testing4")
        container.register(singleton: "Testing5")
        XCTAssertEqual(container.resolve(String.self), "Testing5")
        container.register(singleton: "Testing6")
        XCTAssertEqual(container.resolve(String.self), "Testing6")
    }
    
    func testContainer() {
        let childContainer = Container(parent: container)
        
        container.register(singleton: String.self) { _ in "Testing4" }
        childContainer.register(singleton: Int.self) { _ in 4 }
        
        XCTAssertEqual(childContainer.resolve(String.self), "Testing4")
        XCTAssertEqual(childContainer.resolve(Int.self), 4)
        XCTAssertEqual(container.resolveOptional(Int.self), nil)
    }
    
    func testDependency() {
        container.register(String.self) { _ in "5" }
        container.register(Int.self) { container in
            return Int(container.resolve(String.self))!
        }
        
        XCTAssertEqual(container.resolve(String.self), "5")
        XCTAssertEqual(container.resolve(Int.self), 5)
    }
    
    func testDefault() {
        Container.default.register(String.self, factory: { _ in "Testing6" })
        Container.default.register(Int.self, factory: { _ in 6 })
        
        let instance = TestingDefault()
        XCTAssertEqual(instance.string, "Testing6")
        XCTAssertEqual(instance.int, 6)
    }
    
    func testContainerized() {
        let container = Container()
        container.register(String.self, factory: { _ in "Testing7" })
        container.register(Int.self, factory: { _ in 6 })
        container.register(singleton: Bool.self, identifier: true, factory: { _ in true })
        container.register(singleton: Bool.self, identifier: false, factory: { _ in false })
        
        let instance = TestingContainerized(container: container)
        XCTAssertEqual(instance.string, "Testing7")
        XCTAssertEqual(instance.int, 6)
        XCTAssertEqual(instance.boolTrue, true)
        XCTAssertEqual(instance.boolFalse, false)
    }
    
    func testProperlyCastNilToHashable() {
        let container = Container.default
        container.register(singleton: "cat", identifier: nil)
        XCTAssertEqual(container.resolve(String.self), "cat")
        
        XCTAssertEqual(container._resolve(String.self, identifier: nil), "cat")
        
        @Inject var string: String
        XCTAssertEqual(string, "cat")
    }
}

private struct TestingDefault {
    @Inject var string: String
    @Inject var int: Int
}

private final class TestingContainerized: Containerized {
    let container: Container
    
    @Inject        var string: String
    @Inject        var int: Int
    @Inject(true)  var boolTrue: Bool
    @Inject(false) var boolFalse: Bool
    
    init(container: Container) {
        self.container = container
    }
}
