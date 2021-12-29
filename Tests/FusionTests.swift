@testable import Fusion
import XCTest

final class FusionTest: XCTestCase {
    var container = Container()
    
    override func setUp() {
        super.setUp()
        Container.main = Container()
        container = .main
    }
    
    func testTransient() {
        let exp = expectation(description: "called 3x")
        exp.expectedFulfillmentCount = 3
        container.register(as: String.self) { _ in
            exp.fulfill()
            return "Testing1"
        }
        
        XCTAssertEqual(container.resolve(String.self), "Testing1")
        XCTAssertEqual(container.resolve(String.self), "Testing1")
        XCTAssertEqual(container.resolve(String.self), "Testing1")
        waitForExpectations(timeout: 0)
    }
    
    func testSingleton() {
        let exp = expectation(description: "called 1x")
        exp.expectedFulfillmentCount = 1
        container.register(.singleton, as: String.self) { _ in
            exp.fulfill()
            return "Testing2"
        }
        
        XCTAssertEqual(container.resolve(String.self), "Testing2")
        XCTAssertEqual(container.resolve(String.self), "Testing2")
        XCTAssertEqual(container.resolve(String.self), "Testing2")
        waitForExpectations(timeout: 0)
    }
    
    func testSingletonIdentified() {
        let exp = expectation(description: "called 1x")
        exp.expectedFulfillmentCount = 1
        container.register(.singleton, identifier: "test", as: String.self) { _ in
            exp.fulfill()
            return "Testing3"
        }
        
        XCTAssertEqual(container.resolve(String.self), nil)
        XCTAssertEqual(container.resolve(String.self, identifier: "foo"), nil)
        XCTAssertEqual(container.resolve(String.self, identifier: "test"), "Testing3")
        waitForExpectations(timeout: 0)
    }
    
    func testOverride() {
        container.register(.singleton, value: "Testing1")
        XCTAssertEqual(container.resolve(String.self), "Testing1")
        container.register(.singleton, value: "Testing2")
        XCTAssertEqual(container.resolve(String.self), "Testing2")
        container.register(value: "Testing3")
        XCTAssertEqual(container.resolve(String.self), "Testing3")
        container.register(value: "Testing4")
        XCTAssertEqual(container.resolve(String.self), "Testing4")
        container.register(.singleton, value: "Testing5")
        XCTAssertEqual(container.resolve(String.self), "Testing5")
        container.register(.singleton, value: "Testing6")
        XCTAssertEqual(container.resolve(String.self), "Testing6")
    }
    
    func testContainer() {
        let childContainer = Container(parent: container)
        container.register(.singleton, as: String.self) { _ in "Testing4" }
        childContainer.register(.singleton, as: Int.self) { _ in 4 }
        XCTAssertEqual(childContainer.resolve(String.self), "Testing4")
        XCTAssertEqual(childContainer.resolve(Int.self), 4)
        XCTAssertEqual(container.resolve(Int.self), nil)
    }
    
    func testDependency() {
        container.register(value: "5")
        container.register { container in
            return Int(container.resolve(String.self)!)!
        }
        
        XCTAssertEqual(container.resolve(String.self), "5")
        XCTAssertEqual(container.resolve(Int.self), 5)
    }
    
    func testDefault() {
        Container.main.register(as: String.self, factory: { _ in "Testing6" })
        Container.main.register(as: Int.self, factory: { _ in 6 })
        let instance = TestingDefault()
        XCTAssertEqual(instance.string, "Testing6")
        XCTAssertEqual(instance.int, 6)
    }
    
    func testContainerized() {
        let container = Container()
        container.register(as: String.self, factory: { _ in "Testing7" })
        container.register(as: Int.self, factory: { _ in 6 })
        container.register(.singleton, identifier: true, as: Bool.self, factory: { _ in true })
        container.register(.singleton, identifier: false, as: Bool.self, factory: { _ in false })
        
        let instance = TestingContainerized(container: container)
        XCTAssertEqual(instance.string, "Testing7")
        XCTAssertEqual(instance.int, 6)
        XCTAssertEqual(instance.boolTrue, true)
        XCTAssertEqual(instance.boolFalse, false)
    }
    
    func testProperlyCastNilToHashable() {
        container.register(.singleton, identifier: nil, value: "cat")
        XCTAssertEqual(container.resolve(String.self), "cat")
    }
    
    func testInject() {
        container.register(value: "foo")
        container.register(identifier: 1, value: "bar")
        container.register(identifier: 2, value: "baz")
        
        @Inject    var string1: String
        @Inject(1) var string2: String
        @Inject(2) var string3: String
        
        XCTAssertEqual(string1, "foo")
        XCTAssertEqual(string2, "bar")
        XCTAssertEqual(string3, "baz")
    }
    
    func testThrowing() throws {
        container.register(value: 1)
        XCTAssertEqual(try container.resolveThrowing(Int.self), 1)
        XCTAssertThrowsError(try container.resolveThrowing(String.self))
        XCTAssertThrowsError(try Container.resolveThrowing(String.self))
    }
    
    func testStatic() throws {
        Container.register(value: 1)
        Container.register { "\($0.resolveAssert(Int.self))" }
        XCTAssertNil(Container.resolve(Bool.self))
        XCTAssertEqual(Container.resolve(String.self), "1")
        XCTAssertEqual(try Container.resolveThrowing(Int.self), 1)
        XCTAssertEqual(Container.resolveAssert(String.self), "1")
    }
    
    func testDebug() {
        container.register(.singleton, value: "foo")
        container.register(identifier: 1, value: 0)
        container.register(identifier: 2, value: false)
        XCTAssertEqual(container.debugDescription, """
        *Container Entries*
        - Bool (2): false (transient)
        - Int (1): 0 (transient)
        - String: foo (singleton)
        """)
    }
    
    func testDebugEmpty() {
        XCTAssertEqual(container.debugDescription, """
        *Container Entries*
        <nothing registered>
        """)
    }
}

private final class TestingDefault {
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
