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
            if let identifier = identifier {
                hasher.combine(AnyHashable(identifier))
            } else {
                hasher.combine(AnyHashable(nil as AnyHashable?))
            }
            
            hasher.combine("\(type)")
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
    ///   - identifier: An optional identifier to bind the service with.
    ///   - factory: The factory, that's passed a container, for creating a
    ///     value when resolving.
    public func bind<T>(_ behavior: ResolveBehavior = .transient, to type: T.Type = T.self, identifier: AnyHashable? = nil, factory: @escaping ContainerFactory<T>) {
        lock.lock()
        storage[Key(type: type, identifier: identifier)] = Entry(behavior: behavior, factory: factory)
        lock.unlock()
    }
    
    /// Bind a service to this container.
    ///
    /// - Parameters:
    ///   - behavior: The behavior to resolve the service with. Defaults to
    ///     `transient`.
    ///   - type: The type to bind the service as.
    ///   - identifier: An optional identifier to bind the service with.
    ///   - factory: The factory for creating a value when resolving.
    public func bind<T>(_ behavior: ResolveBehavior = .transient, to type: T.Type = T.self, identifier: AnyHashable? = nil, value: @escaping @autoclosure Factory<T>) {
        bind(behavior, to: type, identifier: identifier) { _ in value() }
    }
    
    // MARK: - Resolve
    
    /// Returns an instance of a service, returning nil if the service isn't
    /// registered to this container.
    /// 
    /// - Parameters:
    ///   - type: The service type to resolve.
    ///   - identifier: An optional identifier to resolve with.
    public func resolve<T>(_ type: T.Type = T.self, identifier: AnyHashable? = nil) -> T? {
        lock.lock()
        let value: T? = storage[Key(type: type, identifier: identifier)]?.value(in: self)
        lock.unlock()
        return value ?? parent?.resolve(identifier: identifier)
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
        guard let unwrapped: T = resolve(identifier: identifier) else { preconditionFailure("Unable to resolve service of type \(T.self) with identifier \(identifier.map { "\($0)" } ?? "nil")! Perhaps it isn't registered?") }
        return unwrapped
    }
    
    // MARK: - Static Convenience Functions
    
    /// Register a service to the main container.
    ///
    /// - Parameters:
    ///   - behavior: The behavior to resolve the service with. Defaults to
    ///     `transient`.
    ///   - identifier: An optional identifier to bind the service with.
    ///   - type: The type to bind the service as.
    ///   - factory: The factory, that's passed a container, for creating a
    ///     value when resolving.
    public static func bind<T>(_ behavior: ResolveBehavior = .transient, to type: T.Type = T.self, identifier: AnyHashable? = nil, factory: @escaping ContainerFactory<T>) {
        main.bind(behavior, identifier: identifier, factory: factory)
    }
    
    /// Register a service to the main container.
    ///
    /// - Parameters:
    ///   - behavior: The behavior to resolve the service with. Defaults to
    ///     `transient`.
    ///   - identifier: An optional identifier to bind the service with.
    ///   - type: The type to bind the service as.
    ///   - factory: The factory for creating a value when resolving.
    public static func bind<T>(_ behavior: ResolveBehavior = .transient, to type: T.Type = T.self, identifier: AnyHashable? = nil, value: @escaping @autoclosure Factory<T>) {
        main.bind(behavior, identifier: identifier, value: value())
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
                var keyString = "\(key.type)"
                if let identifier = key.identifier { keyString.append(" (\(identifier.base))") }
                let value: Any = entry.value(in: self)
                let entryString = "\(value) (\(entry.behavior.rawValue))"
                return "- \(keyString): \(entryString)"
            }
            
            string.append(contentsOf: entryStrings.sorted().joined(separator: "\n"))
        }
        
        return string
    }
}
