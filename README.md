<p align="center"><a href="https://github.com/alchemy-swift/fusion"><img src="https://user-images.githubusercontent.com/6025554/151728294-6185c3ed-ab54-4174-a376-4b2923b647d2.png" width="400"></a></p>

<p align="center">
<a href="https://swift.org"><img src="https://img.shields.io/badge/Swift-5.3-orange.svg" alt="Swift Version"></a>
<a href="https://github.com/alchemy-swift/fusion/releases"><img src="https://img.shields.io/github/release/alchemy-swift/fusion.svg" alt="Latest Release"></a>
<a href="https://github.com/alchemy-swift/alchemy/blob/main/LICENSE"><img src="https://img.shields.io/github/license/alchemy-swift/alchemy.svg" alt="License"></a>
</p>

# Fusion

Fusion is a lightweight dependency injection library for Swift. It uses property wrappers to make injection a breeze so you can keep your code testable and modular in modern, Swifty style.

## Why Use Dependency Injection?

"Dependency Injection" is a fancy phrase that refers to providing concrete implementations of abstract service types.

DI helps keep your code modular, testable and maintainable. It lets you define services in one place so that you may easily swap them for other implementations down the road or during tests.

## Installation

Install with the Swift Package Manager.

```swift
.package(url: "https://github.com/alchemy-swift/fusion", from: "0.4.0")
```

## A Simple Intro: Logging

If you're familiar with dependency injection or would rather just see everything you can do with Fusion, feel free to skip to [Usage](#usage).

Consider an example of using Fusion to make your code modular and testable.

Let's say that you are creating an app and would like to log all logs to a remote log store. You might create an abstract interface for the logger using a protocol.

```swift
protocol Logger {
    func log(_ text: String)
}
```

Next, create a concrete implementation that sends the logs to a remote store.

```swift
struct RemoteLogger: Logger {
    func log(_ text: String) { ... }
}
```

You can now "bind" this type to your app's main container. This just means your telling the container "when I ask for a `Logger`, give me a `RemoteLogger`".

```swift
Container.main.bind(Logger.self, value: RemoteLogger())
```

Note that for your convenience, you can just call `bind` and `resolve` as static functions on `Container` which will use the `main` container.

```swift
Container.bind(Logger.self, value: RemoteLogger())
```

Now, whenever you need to log something, just use the `@Inject` property wrapper to "inject" your service.

```swift
struct CreateAccountView: View {
    @Inject var logger: Logger

    ...

    func createAccount(for email: String) {
        logger.log("Creating an account for \(email).")
    }
}
```

Simple. Your logs will be properly sent to your remote logger. But let's say you want to run unit tests that test creating a user account. You probably don't want to spam up your remote logger with a bunch of dummy logs. Instead it would make more sense just to log everything to the console so you can debug if necessary. 

But this means that you'll need to provide a different instance of `Logger` everywhere you are using it, which could be hundreds of places. Fortunately, since you're using dependency injecion, this is a piece of cake.

First, create a new `Logger` that logs to the console. Then, at the beginning of a test or in the `setup()` function of the test case, bind a `ConsoleLogger` to `Logger` in your app's container.

```swift
struct ConsoleLogger: Logger { ... }

func testCreateAccount() {
    Container.bind(Logger.self, value: ConsoleLogger())

    let view = CreateAccountView()
    // run some test logic
}
```

Now, any calls to an `@Inject`ed `Logger`s during tests will be sent to `ConsoleLogger` instead of `RemoteLogger` and your remote log store will stay nice and tidy. This same pattern can be used to easily swap your production `Logger` out for a different implementation down the road such as a `FileLogger` or `SlackLogger`.

## Usage

Now that you're up to speed on Dependency Injection and the basics of Fusion, here's everything it's API offers.

Services are bound to and resolved from `Container`s. Fusion comes with a main container, `Container.main`, but you can also create your own custom containers.

### Binding

You can register or "bind" an instance to a type using the `bind(value:)` which takes a value or `bind(factory:)` which takes a closure.

```swift
Container.main.bind(Logger.self, value: RemoteLogger()) // A `RemoteLogger()` will be returned when resolving `Logger.self`.

Container.main.bind(Logger.self, factory: { container in
    return RemoteLogger()
}
```

You don't need to specify the type if it's the same as the argument for value.

```swift
Container.main.bind(value: "Hello, world!") // "Hello, world" will be returned when resolving `String.self`.
```

For convenience, there are static functions on `Container` that bind to `Container.main`.

```swift
// Equivalent to the functions above

Container.bind(Logger.self, value: RemoteLogger())

Container.bind(value: "Hello, world!")
```

#### Cross service dependencies

If you need to access a different dependency when resolving a dependency, use `bind(factory:)` and access the provided container parameter.

```swift
Container.bind(Database.self) { container in
    PostgresDatabase(logger: container.resolve(Logger.self))
}
```

#### Singletons

By default, your services are _transient_, meaning they are resolved fresh each time they are injected. If you'd prefer the service to be resolved only once, you may specify so by passing `.singleton` as the first argument to `bind()`.

```swift
// a transient service; factory called each time
Container.bind(value: UUID())
@Inject var uuid: UUID // 15dc5b79-774d-4ec9-a9c5-7cc8b31b7a4a
@Inject var uuid: UUID // 2b43da13-ca2e-4d83-ad19-9fb879afe522
@Inject var uuid: UUID // e4d120a4-58ce-4313-8709-1eba09165c57

// a singleton service; factory called once and the result is returned for all subsequent resolves
Container.bind(.singleton, value: UUID())
@Inject var uuid: UUID // 9b0a42e5-9205-4c98-8650-7010b7eaa401
@Inject var uuid: UUID // 9b0a42e5-9205-4c98-8650-7010b7eaa401
@Inject var uuid: UUID // 9b0a42e5-9205-4c98-8650-7010b7eaa401
```

**Note** the `value` in `bind(value:)` is marked as `@autoclosure` which is why the transient service returned a new value each time it was resolved.

If your service has dependencies, you can bind it as a singleton in the same way.

```swift
Container.bind(.singleton, to: JobQueue.self) { container in
    DatabaseQueue(database: container.resolve(Database.self))
}
```

#### Identifiers

Sometimes, you may have multiple factories of the same service. You can correlate each factory to an identifier by passing anything hashable to the `id:` parameter of `bind()`.

```swift
Container.bind(id: "a", value: "foo")
Container.bind(id: "b", value: "bar")
```

You may then inject a specific instance by passing the identifier to `@Inject`.

```swift
@Inject("a") var first: String  // foo
@Inject("b") var second: String // bar
```

### Resolving

Once you bind a service, you may resolve it directly from the container or with the `@Inject` property wrapper. Note that `@Inject` force unwraps the injected value, and will crash if it isn't bound.

```swift
let log: Logger? = Container.resolve(Logger.self)

@Inject var log: Logger
```

#### Resolving with identifiers

If you bound your service to an identifier, you may inject that specific service by passing the identifier.

```swift
let log = Container.resolve(Logger.self, id: "slack")

@Inject("slack") var log: Logger
```

#### Assert resolving

`Container.resolve()` returns an optional type that will be nil if the service wasn't registered. If you'd prefer not to deal with an optional, you may call `resolveAssert()` which will return a value or end execution if the value isn't registered. Under the hood, this is what `@Inject` uses.

```swift
let log: Logger = Container.resolveAssert(Logger.self)

let slack: Logger = Container.resolveAssert(Logger.self, id: "slack")
```

#### Throwing resolving

Alternatively, you may use `resolveThrowing()` which returns a value or throws a `FusionError.notRegistered` if the service wasn't registered.

```swift
let log: Logger = try Container.resolveThrowing(Logger.self)
```

### Advanced `Container` usage

In many cases, only using `Container.default` will be enough for what you're trying to do. There are some cases however, where you'd like to further modularize your code with custom containers.

#### Custom containers

You easily create and manage your own containers.

```swift
let myContainer = Container()
myContainer.register(value: "Hello from my container!")

let string = myContainer.resolve(String.self) // "Hello from my container!"
```

#### Child containers

You can give a container a "parent" container. This means that if the child container doesn't have a service type bound to it, `resolving` it will attempt to resolve the service from the parent container.

```swift
let parent = Container()
let child = Container(parent: parent)

parent.bind(value: 1)
child.bind(value: "foo")

// "foo"
let string = child.resolve(String.self)

// 1; inherited from `parent`
let int = child.resolve(Int.self)

// nil; parents do not have access to their children's services.
let string = parent.resolve(String.self)
```

#### `@Inject`ing from a custom container

By default, `@Inject` resolves services from the global container. If you'd like to inject from a custom container, you must conform the enclosing type to `Containerized`, which requires a `var container: Container { get }`.

```swift
final class MyEnclosingType: Containerized {
    let container: Container

    @Inject var string: String
    @Inject var int: Int

    init(container: Container) {
        self.container = container
    }
}

let container = Container()
container.register(value: "Howdy")
container.register(value: 42)

let myType = MyEnclosingType(container: container)
myType.string // "Howdy"
myType.int // 42
```
