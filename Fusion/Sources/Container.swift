import Foundation

/// A container from which services are resolved.
@dynamicMemberLookup
public final class Container: @unchecked Sendable {
    public enum Scope: Equatable, Sendable {
        case id(String)
        public static let singleton = id("singleton")
    }

    private enum Key: Hashable {
        case id(ObjectIdentifier)
        case keyPath(PartialKeyPath<Container>)

        static func type(_ type: Any.Type) -> Key {
            .id(ObjectIdentifier(type))
        }
    }

    private struct Entry {
        let scope: Scope
        let get: () -> Any
    }

    @TaskLocal public static var main = Container()

    private let lock = NSRecursiveLock()
    private var cache: [Key: Entry] = [:]

    public init() {}

    public func resolve<T>(scope: Scope? = nil, _ key: KeyPath<Container, T>, create: () -> T) -> T {
        lock.withLock {
            let key: Key = .keyPath(key)
            if let entry = cache[key] {
                return entry.get() as! T
            } else {
                guard let scope else {
                    return create()
                }

                let value = create()
                cache[key] = Entry(scope: scope, get: { value })
                return value
            }
        }
    }

    public func reset(_ scope: Scope = .singleton) {
        lock.withLock {
            for (key, entry) in cache where entry.scope == scope {
                cache[key] = nil
            }
        }
    }

    public static func reset(_ scope: Scope = .singleton) {
        Container.main.reset(scope)
    }

    // MARK: Mocking

    public func mock<T>(_ key: KeyPath<Container, T>, value: T) {
        let key: Key = .keyPath(key)
        lock.withLock {
            cache[key] = Entry(scope: .singleton, get: { value })
        }
    }

    public static func mock<T>(_ key: KeyPath<Container, T>, value: T) {
        main.mock(key, value: value)
    }

    public static func mock(mocker: (Container) -> Void, then perform: () -> Void) {
        let copy = Container()
        copy.cache = lock.withLock { cache }
        mocker(copy)
        Container.$main.withValue(copy, operation: perform)
    }

    // MARK: Types

    public func get<T>(_ type: T.Type = T.self) -> T? {
        let entry = lock.withLock { cache[.type(type)] }
        guard let entry else { return nil }
        return entry.get() as! T?
    }

    public func require<T>(_ type: T.Type = T.self) -> T {
        guard let value = get(type) else {
            preconditionFailure("No default set for \(type). Try registering one with `set()` or `Container.set()`")
        }

        return value
    }

    public func set<T>(_ value: T, as type: T.Type = T.self) {
        lock.withLock {
            cache[.type(type)] = .init(scope: .singleton, get: { value })
        }
    }

    /// Sets a specific key to be returned when the given type is accessed via `get()`.
    public func setAlias<T>(_ key: KeyPath<Container, T>, for type: T.Type = T.self) {
        lock.withLock {
            cache[.type(type)] = .init(scope: .singleton, get: { self[keyPath: key] })
        }
    }

    // MARK: Contexts

    /// All command line arguments of the application.
    public var arguments: [String] { CommandLine.arguments }
    /// `true` if application is running in an Xcode preview.
    public var isPreview: Bool { ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" }
    /// `true` if application is running in a test.
    public var isTest: Bool { arguments.contains { $0.contains("xctest") } }
    /// `true` if application is running on a simulator.
    public var isSimulator: Bool { ProcessInfo.processInfo.environment["SIMULATOR_UDID"] != nil }
    /// `true` if application is running on a real device.
    public var isDevice: Bool { !isSimulator }
    /// `true` if the application is run from Xcode
    public var isXcode: Bool {
        arguments.contains {
            $0.contains("/Xcode/DerivedData") ||
            $0.contains("/Xcode/Agents")
        }
    }
    /// `true` if application is running in DEBUG.
    public var isDebug: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }

    // MARK: @dynamicMemberLookup

    public static subscript<T>(dynamicMember member: ReferenceWritableKeyPath<Container, T>) -> T {
        get { main[keyPath: member] }
        set {
            // don't call `main[keyPath: member] = newValue` since this will
            // trigger an unnecessary getter.
            //
            // https://forums.swift.org/t/keypaths-subscript-setter-accesses-the-properties-getter/22212
            mock(member, value: newValue)
        }
    }

    public static subscript<T>(dynamicMember member: KeyPath<Container, T>) -> T {
        get { main[keyPath: member] }
    }
}
