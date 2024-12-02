@testable import Fusion
import Foundation
import Testing

@Suite(.serialized)
struct ContainerTests {
    init() {
        Container.reset()
    }

    @Test func singleton() {
        #expect(Container.singleton1 != Container.singleton1)
        #expect(Container.$singleton1 == Container.$singleton1)
    }

    @Test func factory() {
        #expect(Container.factory != Container.factory)
        #expect(Container.$factory != Container.$factory)
    }

    @Test func mock() {
        Container.$singleton1 = "foo"
        Container.$factory = "bar"
        #expect(Container.$singleton1 == "foo")
        #expect(Container.$factory == "bar")
    }

    @Test func mockClosure() {
        let _ = Container.$singleton1
        let singleton2 = Container.$singleton2
        Container.mock {
            $0.$singleton1 = "baz"
        } then: {
            #expect(Container.$singleton1 == "baz")
            #expect(Container.$singleton2 == singleton2)
        }

        #expect(Container.$singleton1 != "baz")
    }

    @Test func scope() {
        let value = Container.$session
        #expect(Container.$session == Container.$session)
        Container.reset()
        #expect(Container.$session == value)
        Container.reset(.session)
        #expect(Container.$session != value)
    }

    @Test func contexts() {
        #expect(Container.arguments.contains(where: { $0.contains("xctest") }))
        #expect(Container.isTest == true)
        #expect(Container.isPreview == false)
        #expect(Container.isDebug == true)
        #expect(Container.isSimulator == false)
    }

    @Test func dependency() {
        @Dependency(\.$singleton1) var singleton1
        #expect(singleton1 == Container.$singleton1)
    }

    @Test func defaults() {
        #expect(Container.$number == 1)
        Container.$number = 2
        #expect(Container.$number == 2)

        #expect(Container.$string == "foo")
        Container.$string = "bar"
        #expect(Container.$string == "bar")

        #expect(Container.$double == 0.0)
        Container.$double = 2
        #expect(Container.$double == 2)

        #expect(Container.$bool == false)
        Container.$bool = true
        #expect(Container.$bool == true)

        #expect(Container.$type == .value1)
        Container.$type = .value2
        #expect(Container.$type == .value2)

        #expect(Container.$ternary == 1)
        Container.$ternary = 3
        #expect(Container.$ternary == 3)
    }
}

private extension Container {
    @Factory var number = 1
    @Factory var string = "foo"
    @Factory var double = 0.0
    @Factory var bool = false
    @Factory var type = UUID(uuid: UUID.value1.uuid)
    @Factory var ternary = isTest ? 1 : 2

    @Factory var factory: String {
        UUID().uuidString
    }

    @Singleton var singleton1: String {
        UUID().uuidString
    }

    @Singleton var singleton2: String {
        UUID().uuidString
    }

    @Session var session: String {
        UUID().uuidString
    }
}

private extension UUID {
    static let value1 = UUID(uuidString: "6a815d0a-77a2-4170-bfab-8f39cd8c92de")!
    static let value2 = UUID(uuidString: "cdaa4470-a362-4389-ac4a-ac6affc8ed97")!
}

@attached(accessor)
@attached(peer, names: prefixed(`$`))
private macro Session() = #externalMacro(module: "Plugin", type: "ResolveMacro")

private extension Container.Scope {
    static let session = id("auth")
}
