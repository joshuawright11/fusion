/// Convenient static accessors for working with the default
/// container.
extension Container {
    /// Register a transient service to the default container.
    /// Transient means that it's factory closure will be
    /// called _each time_ the service type is resolved.
    ///
    /// - Parameters:
    ///   - service: The type of the service to register.
    ///   - factory: The closure for instantiating an instance of the
    ///     service.
    public static func register<T>(_ service: T.Type, factory: @escaping (Container) -> T) {
        Container.default.register(service, factory: factory)
    }
    
    /// Register a singleton service to the default container. This
    /// means that it's factory closure will be called _once_ and
    /// that value will be returned each time the service is
    /// resolved.
    ///
    /// - Parameters:
    ///   - service: The type of the service to register.
    ///   - factory: The closure for instantiating an instance of the
    ///     service.
    public static func register<S>(singleton service: S.Type, factory: @escaping (Container) -> S) {
        Container.default.register(singleton: service, factory: factory)
    }
    
    /// Register a identified singleton service to the default
    /// container. Singleton means that it's factory closure
    /// will be called _once_ per unique identifier and that
    /// value will be returned each time the service is
    /// resolved.
    ///
    /// - Parameters:
    ///   - service: The type of the service to register.
    ///   - factory: The closure for instantiating an instance of the
    ///     service.
    public static func register<S, H: Hashable>(singleton service: S.Type, identifier: H, factory: @escaping (Container) -> S) {
        Container.default.register(singleton: service, identifier: identifier, factory: factory)
    }
    
    /// Register a transient service to the default container.
    public static func register<T>(_ transient: @escaping @autoclosure () -> T) {
        register(T.self, factory: { _ in transient() })
    }
    
    /// Register a singleton service to the default container.
    public static func register<T>(singleton: @escaping @autoclosure () -> T) {
        register(singleton: T.self, factory: { _ in singleton() })
    }
    
    /// Resolves a service from the default container, returning an
    /// instance of it, if one is registered.
    ///
    /// - Parameter service: The type of the service to resolve.
    /// - Returns: An instance of the service.
    public static func resolveOptional<T>(_ service: T.Type) -> T? {
        Container.default.resolveOptional(service)
    }
    
    /// Resolves a service with the given `identifier` from the
    /// default container, returning an instance of it if one
    /// is registered.
    ///
    /// - Parameter service: The type of the service to resolve.
    /// - Parameter identifier: The identifier of the service to
    ///   resolve.
    /// - Returns: An instance of the service.
    public static func resolveOptional<T, H: Hashable>(_ service: T.Type, identifier: H?) -> T? {
        Container.default.resolveOptional(service, identifier: identifier)
    }
    
    /// Resolves a service from the default container, returning an
    /// instance of it.
    ///
    /// This will `fatalError` if the service isn't registered.
    ///
    /// - Parameter service: The type of the service to resolve.
    /// - Returns: An instance of the service.
    public static func resolve<T>(_ service: T.Type) -> T {
        Container.default.resolve(service)
    }
    
    /// Resolves a service with the given `identifier` from the
    /// default container, returning an instance of it.
    ///
    /// This will `fatalError` if the service isn't registered.
    ///
    /// - Parameters:
    ///   - service: The type of the service to resolve.
    ///   - identifier: The identifier of the service to
    ///     resolve.
    /// - Returns: An instance of the service.
    public static func resolve<T, H: Hashable>(_ service: T.Type, identifier: H?) -> T {
        Container.default.resolve(service, identifier: identifier)
    }
}
