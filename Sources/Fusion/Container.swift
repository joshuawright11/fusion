import Foundation

/// The caching behavior, per container, for a factory.
public enum ResolveBehavior: String {
    /// A new instance should be created once per container.
    case singleton
    /// A new instance should be created at every `.resolve(...)`.
    case transient
}

/// A container from which services should be registered and resolved.
public final class Container {
    struct StorageKey: Hashable {
        let type: Any.Type
        let identifier: AnyHashable
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(identifier)
            hasher.combine("\(type)")
        }
        
        static func == (lhs: Container.StorageKey, rhs: Container.StorageKey) -> Bool {
            lhs.hashValue == rhs.hashValue
        }
    }
    
    struct StorageEntry {
        let factory: (Container) -> Any
        let resolveBehavior: ResolveBehavior
        let cachedValue: Any?
    }
    
    /// Generic factory closure. A container and an optional
    /// identifier are passed in and a service is generated.
    private typealias FactoryClosure = (Container, Any?) -> Any
    
    /// The main service container.
    public static var `default` = Container()
    
    /// The parent container of this container. Resolves that don't
    /// have a value in this container will be deferred to the
    /// parent container.
    private var parent: Container?
    
    /// Lock for keeping access of the storage dict threadsafe.
    private let lock = NSRecursiveLock()
    
    /// Any cached instances of services held in this container (used
    /// for singletons and multitons). Access to this is threadsafe.
    private var instances: [String: Any] {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _instances
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _instances = newValue
        }
    }
    
    /// Backing property for `instances` to keep access threadsafe.
    private var _instances: [String: Any] = [:]
    
    /// The resolvers registered to this container. Each resolver has
    /// a factory closure and behavior by which the values are
    /// cached or not.
    private var resolvers: [String: (behavior: ResolveBehavior, factory: FactoryClosure)] = [:]
    
    /// Initialize a container with an optional parent `Container`.
    ///
    /// - Parameter parent: The optional parent `Container`. Defaults
    ///   to `nil`.
    public init(parent: Container? = nil) {
        self.parent = parent
    }
    
    // MARK: Registration
    
    /// Register a transient service to this container. Transient
    /// means that it's factory closure will be called
    /// _each time_ the service type is resolved.
    ///
    /// - Parameters:
    ///   - service: The type of the service to register.
    ///   - factory: The closure for instantiating an instance of the
    ///     service.
    public func register<T>(_ service: T.Type, factory: @escaping (Container) -> T) {
        let key = storageKey(for: service, identifier: nil)
        instances.removeValue(forKey: key)
        resolvers[key] = (.transient, { container, _ in
            factory(container)
        })
    }
    
    /// Register a singleton service to this container. This means
    /// that it's factory closure will be called _once_ and that
    /// value will be returned each time the service is resolved.
    ///
    /// - Parameters:
    ///   - service: The type of the service to register.
    ///   - factory: The closure for instantiating an instance of the
    ///     service.
    public func register<S>(singleton service: S.Type, factory: @escaping (Container) -> S) {
        let key = storageKey(for: service, identifier: nil)
        instances.removeValue(forKey: key)
        resolvers[key] = (.singleton, { container, _ in
            factory(container)
        })
    }
    
    /// Register a transient service to the container.
    public func register<T>(_ transient: @escaping (Container) -> T) {
        register(T.self, factory: transient)
    }
    
    /// Register a singleton service to the container.
    public func register<T>(singleton: @escaping (Container) -> T) {
        register(singleton: T.self, factory: singleton)
    }
    
    /// Register a transient service to the container.
    public func register<T>(_ transient: @escaping @autoclosure () -> T) {
        register(T.self, factory: { _ in transient() })
    }
    
    /// Register a singleton service to the container.
    public func register<T>(singleton: @escaping @autoclosure () -> T, identifier: AnyHashable? = nil) {
        register(singleton: T.self, identifier: identifier, factory: { _ in singleton() })
    }
    
    /// Register a identified singleton service to this container.
    /// Singleton means that it's factory closure will be called
    /// _once_ per unique identifier and that value will be
    /// returned each time the service is resolved.
    ///
    /// - Parameters:
    ///   - service: The type of the service to register.
    ///   - factory: The closure for instantiating an instance of the
    ///     service.
    public func register<S, H: Hashable>(singleton service: S.Type, identifier: H?, factory: @escaping (Container) -> S) {
        let key = storageKey(for: service, identifier: identifier)
        instances.removeValue(forKey: key)
        resolvers[key] = (.singleton, { container, _ in
            factory(container)
        })
    }
    
    // MARK: Resolving
    
    /// Resolves a service, returning an instance of it, if one is
    /// registered.
    ///
    /// - Parameter service: The type of the service to resolve.
    /// - Returns: An instance of the service.
    public func resolveOptional<T>(_ service: T.Type) -> T? {
        _resolve(service, identifier: nil)
    }
    
    /// Resolves a service with the given `identifier`, returning an
    /// instance of it if one is registered.
    ///
    /// - Parameter service: The type of the service to resolve.
    /// - Parameter identifier: The identifier of the service to
    ///   resolve.
    /// - Returns: An instance of the service.
    public func resolveOptional<T, H: Hashable>(_ service: T.Type, identifier: H?) -> T? {
        _resolve(service, identifier: identifier)
    }
    
    /// Resolves a service, returning an instance of it.
    ///
    /// This will `fatalError` if the service isn't registered.
    ///
    /// - Parameter service: The type of the service to resolve.
    /// - Returns: An instance of the service.
    public func resolve<T>(_ service: T.Type) -> T {
        assertNotNil(_resolve(service, identifier: nil))
    }
    
    /// Resolves a service with the given `identifier`, returning an
    /// instance of it.
    ///
    /// This will `fatalError` if the service isn't registered.
    ///
    /// - Parameters:
    ///   - service: The type of the service to resolve.
    ///   - identifier: The identifier of the service to
    ///     resolve.
    /// - Returns: An instance of the service.
    public func resolve<T, H: Hashable>(_ service: T.Type, identifier: H?) -> T {
        assertNotNil(_resolve(service, identifier: identifier))
    }
    
    /// Resolves a generic service with an optional identifier.
    ///
    /// Internal for usage in the `Inject` property wrapper.
    ///
    /// - Parameters:
    ///   - service: The type of the service to resolve.
    ///   - identifier: An optional identifier that may be associated
    ///     with this service.
    /// - Returns: An instance of the service, if it is able to be
    ///   resolved by this `Container` or it's parents.
    func _resolve<T>(_ service: T.Type, identifier: AnyHashable?) -> T? {
        let key = storageKey(for: service, identifier: identifier)
        if let instance = instances[key] {
            return assertType(of: instance)
        } else if let resolver = resolvers[key] {
            let instance: T = assertType(of: resolver.factory(self, identifier))
            if resolver.behavior == .singleton {
                instances[key] = instance
            }
            return instance
        } else if let instance = parent?._resolve(service, identifier: identifier) {
            return instance
        }
        return nil
    }
    
    /// A key for local storage of instances and factories of
    /// services. It's the type name & the hash value of the
    /// identifier (if it exists), joined by an underscore.
    ///
    /// - Parameters:
    ///   - service: The service type to generate a key for.
    ///   - identifier: An optional identifier to include in the key.
    /// - Returns: A string for keying the dictionaries that may hold
    ///   instances or factories associated with the service type.
    private func storageKey<T>(for service: T.Type, identifier: AnyHashable?) -> String {
        let any = AnyHashable(identifier)
        return "\(service)_\(any.hashValue)"
    }
    
    /// Asserts that an optional value is not nil. If it is nil, a
    /// fatal error occurs.
    ///
    /// - Parameter value: The value to check for nil.
    /// - Returns: The unwrapped value `T`.
    private func assertNotNil<T>(_ value: T?) -> T {
        guard let unwrapped = value else {
            preconditionFailure("Unable to resolve service of type \(T.self)! Perhaps it isn't registered?")
        }
        
        return unwrapped
    }
    
    /// Asserts that an instance matches another type. If it does not,
    /// a fatal error occurs.
    ///
    /// - Parameters:
    ///   - instance: The instance to check the type of.
    ///   - equals: The type to ensure `instance` conforms to.
    /// - Returns: The instance cast to `U` if the conversion was
    ///   successful.
    private func assertType<T, U>(of instance: T, equals: U.Type = U.self) -> U {
        guard let instance = instance as? U else {
            preconditionFailure("Internal storage type mismatch.")
        }
        
        return instance
    }
}

extension Container: CustomDebugStringConvertible {
    public var debugDescription: String {
        var string = """
            *Resolvers*:\n
            """
        string.append(
            resolvers
                .map { "- \($1.behavior.rawValue): \($0)" }
                .joined(separator: "\n")
        )
        string.append("\n*Cached Instances*:\n")
        string.append(instances.map { "- \($0): \($1)" }.joined(separator: "\n"))
        return string
    }
}

/*
 Register
 - identifier
 - singleton / transient
 - value / with container
 Resolve
 - identifier
 - throwing / optional / fatal
 */

extension Container {
    typealias ContainerFactory<T> = (Container) -> T
    typealias Factory<T> = () -> T
    
    // Register
    
    func register<T>(identifier: AnyHashable = .default, behavior: ResolveBehavior = .transient, as type: T.Type = T.self, factory: @escaping ContainerFactory<T>) {
        
    }
    
    func register<T>(identifier: AnyHashable = .default, behavior: ResolveBehavior = .transient, as type: T.Type = T.self, factory: @escaping @autoclosure Factory<T>) {
        
    }
    
    // Resolve
    
    func resolve<T>(_ type: T.Type = T.self, identifier: AnyHashable = .default) -> T? {
        return nil
    }
    
    func resolveThrowing<T>(_ type: T.Type = T.self, identifier: AnyHashable = .default) throws -> T {
        try unwrap(resolve(identifier: identifier))
    }
    
    func resolveAssert<T>(_ type: T.Type = T.self, identifier: AnyHashable = .default) -> T {
        assert(resolve(identifier: identifier))
    }
    
    private func unwrap<T>(_ value: T?) throws -> T {
        guard let unwrapped = value else { throw FusionError.notRegistered(T.self) }
        return unwrapped
    }
    
    private func assert<T>(_ value: T?) -> T {
        guard let unwrapped = value else { preconditionFailure("Unable to resolve service of type \(T.self)! Perhaps it isn't registered?") }
        return unwrapped
    }
}

public enum FusionError: Error {
    case notRegistered(Any.Type)
}

extension AnyHashable {
    /// The default identifier for services.
    static var `default` = AnyHashable(nil as AnyHashable?)
}
