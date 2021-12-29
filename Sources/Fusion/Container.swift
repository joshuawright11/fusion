import Foundation

/// A container from which services should be registered and resolved.
public final class Container: CustomDebugStringConvertible {
    
    /// Create a value of a service.
    public typealias Factory<T> = () -> T

    /// Create a value of a service using the given container.
    public typealias ContainerFactory<T> = (Container) -> T

    /// The caching behavior for a factory.
    public enum ResolveBehavior: String {
        /// A new instance should be created at every `.resolve(...)`.
        case transient
        /// A new instance should be created once per container.
        case singleton
    }
    
    private struct Key: Hashable {
        let type: Any.Type
        let identifier: AnyHashable?
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(identifier)
            hasher.combine("\(type)")
        }
        
        static func == (lhs: Key, rhs: Key) -> Bool {
            lhs.hashValue == rhs.hashValue
        }
    }
    
    private struct Entry {
        let behavior: ResolveBehavior
        let factory: (Container) -> Any
        var cachedValue: Any?
        
        mutating func value<T>(in container: Container) -> T {
            guard let value = valueAny(in: container) as? T else { preconditionFailure("Internal storage type mismatch.") }
            return value
        }
        
        fileprivate mutating func valueAny(in container: Container) -> Any {
            cachedValue ?? create(in: container)
        }
        
        private mutating func create(in container: Container) -> Any {
            let value = factory(container)
            if behavior == .singleton { cachedValue = value }
            return value
        }
    }

    /// The main service container.
    public static var main = Container()
    
    private var parent: Container?
    private let lock = NSRecursiveLock()
    private var _storage: [Key: Entry] = [:]
    private var storage: [Key: Entry] {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _storage
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _storage = newValue
        }
    }
    
    /// Initialize a container with an optional parent `Container`.
    ///
    /// - Parameter parent: The optional parent `Container`. Defaults
    ///   to `nil`.
    public init(parent: Container? = nil) {
        self.parent = parent
    }
    
    // MARK: - Register
    
    /// Register a service to this container.
    ///
    /// - Parameters:
    ///   - behavior: The behavior to resolve the service with. Defaults to
    ///     `transient`.
    ///   - identifier: An optional identifier to register the service with.
    ///   - type: The type to register the service as.
    ///   - factory: The factory, that's passed a container, for creating a
    ///     value when resolving.
    public func register<T>(_ behavior: ResolveBehavior = .transient, identifier: AnyHashable? = nil, as type: T.Type = T.self, factory: @escaping ContainerFactory<T>) {
        storage[Key(type: type, identifier: identifier)] = Entry(behavior: behavior, factory: factory)
    }
    
    /// Register a service to this container.
    ///
    /// - Parameters:
    ///   - behavior: The behavior to resolve the service with. Defaults to
    ///     `transient`.
    ///   - identifier: An optional identifier to register the service with.
    ///   - type: The type to register the service as.
    ///   - factory: The factory for creating a value when resolving.
    public func register<T>(_ behavior: ResolveBehavior = .transient, identifier: AnyHashable? = nil, as type: T.Type = T.self, value: @escaping @autoclosure Factory<T>) {
        register(behavior, identifier: identifier, as: type) { _ in value() }
    }
    
    // MARK: - Resolve
    
    /// Returns an instance of a service, returning nil if the service isn't
    /// registered to this container.
    /// 
    /// - Parameters:
    ///   - type: The service type to resolve.
    ///   - identifier: An optional identifier to resolve with.
    public func resolve<T>(_ type: T.Type = T.self, identifier: AnyHashable? = nil) -> T? {
        storage[Key(type: type, identifier: identifier)]?.value(in: self) ?? parent?.resolve(identifier: identifier)
    }
    
    /// Returns an instance of a service, throwing a `FusionError` if the
    /// service isn't registered to this container.
    ///
    /// - Parameters:
    ///   - type: The service type to resolve.
    ///   - identifier: An optional identifier to resolve with.
    public func resolveThrowing<T>(_ type: T.Type = T.self, identifier: AnyHashable? = nil) throws -> T {
        guard let unwrapped: T = resolve(identifier: identifier) else { throw FusionError.notRegistered(type: T.self, identifier: identifier) }
        return unwrapped
    }
    
    /// Returns an instance of a service, failing an assertion if the service
    /// isn't registered to this container.
    ///
    /// - Parameters:
    ///   - type: The service type to resolve.
    ///   - identifier: An optional identifier to resolve with.
    public func resolveAssert<T>(_ type: T.Type = T.self, identifier: AnyHashable? = nil) -> T {
        guard let unwrapped: T = resolve(identifier: identifier) else { preconditionFailure("Unable to resolve service of type \(T.self)! Perhaps it isn't registered?") }
        return unwrapped
    }
    
    // MARK: - Static Convenience Functions
    
    /// Register a service to the main container.
    ///
    /// - Parameters:
    ///   - behavior: The behavior to resolve the service with. Defaults to
    ///     `transient`.
    ///   - identifier: An optional identifier to register the service with.
    ///   - type: The type to register the service as.
    ///   - factory: The factory, that's passed a container, for creating a
    ///     value when resolving.
    public static func register<T>(_ behavior: ResolveBehavior = .transient, identifier: AnyHashable? = nil, as type: T.Type = T.self, factory: @escaping ContainerFactory<T>) {
        main.register(behavior, identifier: identifier, value: factory)
    }
    
    /// Register a service to the main container.
    ///
    /// - Parameters:
    ///   - behavior: The behavior to resolve the service with. Defaults to
    ///     `transient`.
    ///   - identifier: An optional identifier to register the service with.
    ///   - type: The type to register the service as.
    ///   - factory: The factory for creating a value when resolving.
    public static func register<T>(_ behavior: ResolveBehavior = .transient, identifier: AnyHashable? = nil, as type: T.Type = T.self, value: @escaping @autoclosure Factory<T>) {
        main.register(behavior, identifier: identifier, value: value())
    }
    
    /// Returns an instance of a service from the main container, returning nil
    /// if the service isn't registered.
    ///
    /// - Parameters:
    ///   - type: The service type to resolve.
    ///   - identifier: An optional identifier to resolve with.
    public static func resolve<T>(_ type: T.Type = T.self, identifier: AnyHashable? = nil) -> T? {
        main.resolve(identifier: identifier)
    }
    
    /// Returns an instance of a service from the main container, throwing a
    /// `FusionError` if the service isn't registered.
    ///
    /// - Parameters:
    ///   - type: The service type to resolve.
    ///   - identifier: An optional identifier to resolve with.
    public static func resolveThrowing<T>(_ type: T.Type = T.self, identifier: AnyHashable? = nil) throws -> T {
        try main.resolveThrowing(identifier: identifier)
    }
    
    /// Returns an instance of a service from the main container, failing an
    /// assertion if the service isn't registered to this container.
    ///
    /// - Parameters:
    ///   - type: The service type to resolve.
    ///   - identifier: An optional identifier to resolve with.
    public static func resolveAssert<T>(_ type: T.Type = T.self, identifier: AnyHashable? = nil) -> T {
        main.resolveAssert(identifier: identifier)
    }
    
    // MARK: - CustomDebugStringConvertible
    
    public var debugDescription: String {
        var string = "*Container Entries*\n"
        if storage.isEmpty {
            string.append("<nothing registered>")
        } else {
            let entryStrings: [String] = storage.map { key, entry in
                var entry = entry
                var keyString = "\(key.type)"
                if let identifier = key.identifier { keyString.append(" (\(identifier.base))") }
                let entryString = "\(entry.valueAny(in: self)) (\(entry.behavior.rawValue))"
                return "- \(keyString): \(entryString)"
            }
            
            string.append(contentsOf: entryStrings.sorted().joined(separator: "\n"))
        }
        
        return string
    }
}
