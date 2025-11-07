<p align="center"><a href="https://github.com/alchemy-swift/fusion"><img src="https://github.com/user-attachments/assets/899e4263-d880-457a-8eb4-8f0ae7c7972c" width="406" height="1024" alt="Fusion logo"></a></p>

<p align="center">
<a href="https://swift.org"><img src="https://img.shields.io/badge/Swift-6.2-orange.svg" alt="Swift Version"></a>
<a href="https://github.com/alchemy-swift/fusion/releases"><img src="https://img.shields.io/github/release/alchemy-swift/fusion.svg" alt="Latest Release"></a>
<a href="https://github.com/alchemy-swift/alchemy/blob/main/LICENSE"><img src="https://img.shields.io/github/license/joshuawright11/fusion.svg" alt="License"></a>
</p>

# Fusion

Fusion is a lightweight dependency injection library for Swift. It uses macros to make injection a breeze so you can keep your code testable and modular in modern, Swifty style.

## Installation

Install with the Swift Package Manager.

```swift
.package(url: "https://github.com/joshuawright11/fusion", from: "0.5.0")
```

## Basics

### Declare a Service

Declare services by extending Container and adding properties annotated with `@Service`. Leverage built-in contexts such as `isTest` to return the right implementation for the right context.

```swift
extension Container {
    @Service var apiService: APIService = isTest ? MockAPIService() : LiveAPIService()
}
```

### Resolve a Service

Access your shiny new service with `@Inject`.

```swift
@Inject(\.apiService) var api

let user = try await api.getUser(id: id)
```

### Define Service Scope

Use scopes to control the lifetime of each service. Each service is "transient" by default and will be freshly resolved on each injection.

```swift
// a new `MyService()` will be initialized and returned each time `transientService` is resolved
@Service var transientService = MyService()

// a new `MyService()` will be created the first time `singletonService` is resolved, and that instance will be returned each subsequent resolution
@Service(.singleton) var singletonService = MyService()
```

## Advanced

### Override Service Values

You can globally override the value of a single service (for example, in a test) by just setting the value on `Container`.

```swift
@Test func testFetchUser() {
    let mockUser = User()
    let mockService = UserRepository(currentUser: mockUser)
    Container.userRepository = mockService
}
```

To override the value of services on a _per-task_ basis, use `Container.mock`. The override value will be set via `@TaskLocal` and only accessible inside the `then` block.

```swift
extension Container {
    @Service var logger = LiveLogger()
}

Container.mock {
    $0.logger = MockLogger()
} then: {
    @Inject(\.logger) var logger // MockLogger
}

@Inject(\.testService) var testService // LiveLogger
```

### Custom Scopes

Define custom scopes to control the lifecycle of various service types. Services of a custom scope are treated as `.singleton`s until their scope is reset.

```swift
private extension Container.Scope {
    static let session = id("session")
}

extension Container {
    // the first time this service is resolved, the created instance will be cached until the `.session` scope is reset
    @Service(.session) var userService = UserService()
}

func userDidLogout() {
    Container.main.reset(.session) // the next time `userService` is resolved, it will return a new value
}
```

### Contexts

Control service resolution behavior via contexts on `Container` such as `isPreview`, `isTest`, `isSimulator`, `isDevice`, etc. Add your own contexts by extending `Container`.

```swift
extension Container {
    @Service(.singleton) var apiClient: APIClient {
        switch env {
        case .prod:
            return LiveAPIClient(host: "stage.project.com")
        case .stage:
            return LiveAPIClient(host: "stage.project.com")
        case .dev:
            return LiveAPIClient(host: "localhost:9001")
        }
    }
}

enum Env {
    case prod
    case stage
    case dev
}

extension Container {
    var env: Env {
        let envString = UserDefaults.standard.string(forKey: "env")
        switch envString {
        case "prod":
            return .prod
        case "stage":
            return .stage
        case "dev":
            return .dev
        default:
            return .dev
        }
    }
}
```

### Resolving By Type

You can skip the keypath syntax and resolve a service via direct type.

```swift
let liveDatabase = PostgresDatabase()
Container.main.set(liveDatabase, for: Database.self)

@Inject var database: Database // PostgresDatabase
```

Note that unlike defining services as properties on `Container`, the existence of a service can't be compile-time guaranteed so you'll need to be sure to set the service via `Container.set` before accessing.

### Resolving By Type with alias

Use `Container.setAlias` to define a specific service property as the one that should be resolved when its type is resolved.

```swift
extension Container {
    @Service(.singleton) var datadog = DatadogLogger()
    @Service(.singleton) var splunk = SplunkLogger()
}

Container.setAlias(\.datadog, for: Logger.self)

@Inject var logger: Logger // DatadogLogger
```

## License

Fusion is available under the MIT license. See [LICENSE](LICENSE) for details.
