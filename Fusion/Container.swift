import Foundation

/// A container from which services are resolved.
@dynamicMemberLookup
public final class Container: @unchecked Sendable {
    public enum Scope: Equatable, Sendable {
        case id(String)

        public static let singleton = id("singleton")
        public static let factory = id("factory")
    }

    private struct Entry {
        let scope: Scope
        let value: Any
    }

    @TaskLocal public static var main = Container()

    private let lock = NSRecursiveLock()
    private var cache: [PartialKeyPath<Container>: Entry] = [:]

    public func resolve<T>(_ key: KeyPath<Container, T>, _ scope: Scope, create: () -> T) -> T {
        lock.withLock {
            if let entry = cache[key] {
                return entry.value as! T
            } else {
                guard scope != .factory else {
                    return create()
                }

                let value = create()
                cache[key] = Entry(scope: scope, value: value)
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
        lock.withLock {
            cache[key] = Entry(scope: .singleton, value: value)
        }
    }

    public static func mock(_ mocker: (Container) -> Void, then perform: () -> Void) {
        let copy = Container()
        copy.cache = lock.withLock { cache }
        mocker(copy)
        Container.$main.withValue(copy, operation: perform)
    }

    // MARK: @dynamicMemberLookup

    public static subscript<T>(dynamicMember member: ReferenceWritableKeyPath<Container, T>) -> T {
        get { main[keyPath: member] }
        set { main[keyPath: member] = newValue }
    }

    public static subscript<T>(dynamicMember member: KeyPath<Container, T>) -> T {
        get { main[keyPath: member] }
    }
}
