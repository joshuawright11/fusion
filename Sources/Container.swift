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
        let id: AnyHashable?
        
        func hash(into hasher: inout Hasher) {
            if let id = id {
                hasher.combine(AnyHashable(id))
            } else {
                hasher.combine(AnyHashable(nil as AnyHashable?))
            }

            hasher.combine(ObjectIdentifier(type))
        }
        
        static func == (lhs: Key, rhs: Key) -> Bool {
            lhs.hashValue == rhs.hashValue
        }
    }
    
    private final class Entry {
        let behavior: ResolveBehavior
        let factory: (Container) -> Any
        var cachedValue: Any?
        
        init(behavior: Container.ResolveBehavior, factory: @escaping (Container) -> Any) {
            self.behavior = behavior
            self.factory = factory
            self.cachedValue = nil
        }
        
        func value<T>(in container: Container) -> T {
            guard let value = valueAny(in: container) as? T else { preconditionFailure("Internal storage type mismatch.") }
            return value
        }
        
        private func valueAny(in container: Container) -> Any {
            cachedValue ?? create(in: container)
        }
        
        private func create(in container: Container) -> Any {
            let value = factory(container)
            if behavior == .singleton { cachedValue = value }
            return value
        }
    }

    /// The main service container.
    public static var main = Container()
    
    private var parent: Container?
    private let lock = NSRecursiveLock()
    private var storage: [Key: Entry] = [:]
    
    /// Initialize a container with an optional parent `Container`.
    ///
    /// - Parameter parent: The optional parent `Container`. Defaults
    ///   to `nil`.
    public init(parent: Container? = nil) {
        self.parent = parent
    }
    
    // MARK: - Binding
    
    /// Bind a service to this container.
    ///
    /// - Parameters:
    ///   - behavior: The behavior to resolve the service with. Defaults to
    ///     `transient`.
    ///   - type: The type to bind the service as.
    ///   - id: An optional identifier to bind the service with.
    ///   - factory: The factory, that's passed a container, for creating a
    ///     value when resolving.
    public func bind<T>(_ behavior: ResolveBehavior = .transient, to type: T.Type = T.self, id: AnyHashable? = nil, factory: @escaping ContainerFactory<T>) {
        lock.lock()
        storage[Key(type: type, id: id)] = Entry(behavior: behavior, factory: factory)
        lock.unlock()
    }
    
    /// Bind a service to this container.
    ///
    /// - Parameters:
    ///   - behavior: The behavior to resolve the service with. Defaults to
    ///     `transient`.
    ///   - type: The type to bind the service as.
    ///   - id: An optional identifier to bind the service with.
    ///   - factory: The factory for creating a value when resolving.
    public func bind<T>(_ behavior: ResolveBehavior = .transient, to type: T.Type = T.self, id: AnyHashable? = nil, value: @escaping @autoclosure Factory<T>) {
        bind(behavior, to: type, id: id) { _ in value() }
    }
    
    /// Unbind a service from this container.
    ///
    /// - Parameters:
    ///   - type: The type to unbind.
    ///   - id: An optional identifier.
    public func unbind<T>(type: T.Type = T.self, id: AnyHashable? = nil) {
        lock.lock()
        storage[Key(type: type, id: id)] = nil
        lock.unlock()
    }
    
    // MARK: - Resolve
    
    /// Returns an instance of a service, returning nil if the service isn't
    /// registered to this container.
    /// 
    /// - Parameters:
    ///   - type: The service type to resolve.
    ///   - id: An optional identifier to resolve with.
    public func resolve<T>(_ type: T.Type = T.self, id: AnyHashable? = nil) -> T? {
        lock.lock()
        let value: T? = storage[Key(type: type, id: id)]?.value(in: self)
        lock.unlock()
        return value ?? parent?.resolve(id: id)
    }
    
    /// Returns an instance of a service, throwing a `FusionError` if the
    /// service isn't registered to this container.
    ///
    /// - Parameters:
    ///   - type: The service type to resolve.
    ///   - id: An optional identifier to resolve with.
    public func resolveThrowing<T>(_ type: T.Type = T.self, id: AnyHashable? = nil) throws -> T {
        guard let unwrapped: T = resolve(id: id) else { throw FusionError.notRegistered(type: T.self, id: id) }
        return unwrapped
    }
    
    /// Returns an instance of a service, failing an assertion if the service
    /// isn't registered to this container.
    ///
    /// - Parameters:
    ///   - type: The service type to resolve.
    ///   - id: An optional identifier to resolve with.
    public func resolveAssert<T>(_ type: T.Type = T.self, id: AnyHashable? = nil) -> T {
        guard let unwrapped: T = resolve(id: id) else { preconditionFailure("Unable to resolve service of type \(T.self) with identifier \(id.map { "\($0)" } ?? "nil")! Perhaps it isn't registered?") }
        return unwrapped
    }
    
    // MARK: - Static Convenience Functions
    
    /// Register a service to the main container.
    ///
    /// - Parameters:
    ///   - behavior: The behavior to resolve the service with. Defaults to
    ///     `transient`.
    ///   - type: The type to bind the service as.
    ///   - id: An optional identifier to bind the service with.
    ///   - factory: The factory, that's passed a container, for creating a
    ///     value when resolving.
    public static func bind<T>(_ behavior: ResolveBehavior = .transient, to type: T.Type = T.self, id: AnyHashable? = nil, factory: @escaping ContainerFactory<T>) {
        main.bind(behavior, id: id, factory: factory)
    }
    
    /// Register a service to the main container.
    ///
    /// - Parameters:
    ///   - behavior: The behavior to resolve the service with. Defaults to
    ///     `transient`.
    ///   - id: An optional identifier to bind the service with.
    ///   - type: The type to bind the service as.
    ///   - factory: The factory for creating a value when resolving.
    public static func bind<T>(_ behavior: ResolveBehavior = .transient, to type: T.Type = T.self, id: AnyHashable? = nil, value: @escaping @autoclosure Factory<T>) {
        main.bind(behavior, id: id, value: value())
    }
    
    /// Unregister a service from the main container.
    ///
    /// - Parameters:
    ///   - type: The type to unbind.
    ///   - id: An optional identifier.
    public static func unbind<T>(type: T.Type = T.self, id: AnyHashable? = nil) {
        main.unbind(type: type, id: id)
    }
    
    /// Returns an instance of a service from the main container, returning nil
    /// if the service isn't registered.
    ///
    /// - Parameters:
    ///   - type: The service type to resolve.
    ///   - id: An optional identifier to resolve with.
    public static func resolve<T>(_ type: T.Type = T.self, id: AnyHashable? = nil) -> T? {
        main.resolve(id: id)
    }
    
    /// Returns an instance of a service from the main container, throwing a
    /// `FusionError` if the service isn't registered.
    ///
    /// - Parameters:
    ///   - type: The service type to resolve.
    ///   - id: An optional identifier to resolve with.
    public static func resolveThrowing<T>(_ type: T.Type = T.self, id: AnyHashable? = nil) throws -> T {
        try main.resolveThrowing(id: id)
    }
    
    /// Returns an instance of a service from the main container, failing an
    /// assertion if the service isn't registered to this container.
    ///
    /// - Parameters:
    ///   - type: The service type to resolve.
    ///   - id: An optional identifier to resolve with.
    public static func resolveAssert<T>(_ type: T.Type = T.self, id: AnyHashable? = nil) -> T {
        main.resolveAssert(id: id)
    }
    
    // MARK: - CustomDebugStringConvertible
    
    public var debugDescription: String {
        var string = "*Container Entries*\n"
        if storage.isEmpty {
            string.append("<nothing registered>")
        } else {
            let entryStrings: [String] = storage.map { key, entry in
                var keyString = "\(key.type)"
                if let id = key.id { keyString.append(" (\(id.base))") }
                let value: Any = entry.value(in: self)
                let entryString = "\(value) (\(entry.behavior.rawValue))"
                return "- \(keyString): \(entryString)"
            }
            
            string.append(contentsOf: entryStrings.sorted().joined(separator: "\n"))
        }
        
        return string
    }
}
