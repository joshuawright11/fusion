@testable import Fusion
import Foundation
import Testing

@Suite(.serialized)
struct ContainerTests {
    init() {
        Container.main.reset()
    }

    @Test func singleton() {
        #expect(Container.main.singleton1 != Container.main.singleton1)
        #expect(Container.$singleton1 == Container.$singleton1)
    }

    @Test func factory() {
        #expect(Container.main.factory != Container.main.factory)
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
        Container.main.mock {
            $0.$singleton1 = "baz"
        } then: {
            #expect(Container.$singleton1 == "baz")
            #expect(Container.$singleton2 == singleton2)
        }

        #expect(Container.$singleton1 != "baz")
    }

    @Test func scope() {
        let value = Container.$auth
        #expect(Container.$auth == Container.$auth)
        Container.main.reset()
        #expect(Container.$auth == value)
        Container.main.reset(.auth)
        #expect(Container.$auth != value)
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

        #expect(Container.$type == Foo(bar: 1))
        Container.$type = Foo(bar: 2)
        #expect(Container.$type == Foo(bar: 2))

        #expect(Container.$ternary == 1)
        Container.$ternary = 3
        #expect(Container.$ternary == 3)
    }
}

struct Foo: Equatable {
    let bar: Int
}

extension Container {
    @Factory var number = 1
    @Factory var string = "foo"
    @Factory var double = 0.0
    @Factory var bool = false
    @Factory var type = Foo(bar: 1)
    @Factory var ternary: Int = isTest ? 1 : 2

    @Factory var factory: String {
        UUID().uuidString
    }

    @Singleton var singleton1: String {
        UUID().uuidString
    }

    @Singleton var singleton2: String {
        UUID().uuidString
    }

    @Auth var auth: String {
        UUID().uuidString
    }
}

@attached(accessor)
@attached(peer, names: prefixed(`$`))
public macro Auth() = #externalMacro(module: "Plugin", type: "ResolveMacro")

extension Container.Scope {
    static let auth = id("auth")
}
