@testable import Fusion
import Foundation
import Testing

struct ContainerTests {
    let container = Container()

    @Test func transient() {
        #expect(container.transient != container.transient)
    }

    @Test func singleton() {
        #expect(container.singleton1 == container.singleton1)
    }

    @Test func mock() {
        container.transient = "bar"
        container.singleton1 = "foo"
        #expect(container.transient == "bar")
        #expect(container.singleton1 == "foo")
    }

    @Test func mockTaskLocal() {
        let singleton1 = Container.singleton1
        let singleton2 = Container.singleton2
        Container.mock {
            $0.singleton1 = "baz"
        } then: {
            #expect(Container.singleton1 == "baz")
            #expect(Container.singleton2 == singleton2)
        }

        #expect(Container.singleton1 == singleton1)
    }

    @Test func scope() {
        let value = container.customScope
        #expect(container.customScope == container.customScope)
        container.reset()
        #expect(container.customScope == value)
        container.reset(.custom)
        #expect(container.customScope != value)
    }

    @Test func context() {
        #expect(container.arguments.contains(where: { $0.contains("xctest") }))
        #expect(container.isTest == true)
        #expect(container.isPreview == false)
        #expect(container.isDebug == true)
        #expect(container.isSimulator != container.isDevice)
    }

    @Test func inject() {
        @Inject(\.singleton1, container: container) var singleton1
        #expect(singleton1 == container.singleton1)

        @Inject(container: container) var int: Int
        container.set(3)
        #expect(int == 3)
        container.setAlias(\.int, for: Int.self)
        #expect(int == 1)
        container.int = 2
        #expect(int == 2)
    }

    @Test func resolveByType() {
        #expect(container.get(Int.self) == nil)
        container.set(2)
        #expect(container.get(Int.self) == 2)
    }

    @Test func resolveByTypeAlias() {
        container.setAlias(\.int, for: Int.self)
        #expect(container.get(Int.self) == 1)
        container.int = 3
        #expect(container.get(Int.self) == 3)
        #expect(container.require(Int.self) == 3)
    }

    @Test func resolveUnset() {
        container.unset = "foo"
        #expect(container.unset == "foo")
    }
}

private extension Container {
    @Service var transient = UUID().uuidString
    @Service var int = 1
    @Service(.singleton) var singleton1 = UUID().uuidString
    @Service(.singleton) var singleton2 = UUID().uuidString
    @Service(.custom) var customScope = UUID().uuidString
    @Service var unset: String
}

private extension Container.Scope {
    static let custom = id("custom")
}
