/// Provides a convenient `@propertyWrapper` for injecting services to
/// a type. By default, resolves services from the global container
/// (`Container.default`) but if the enclosing type conforms to
/// `Containerized` services are resolved from
/// `EnclosingType.container`.
@propertyWrapper
public final class Inject<Service> {
    /// An optional identifier that may be associated with the service
    /// this property wrapper is injecting. Used for storing any
    /// identifiers of a service.
    private var identifier: AnyHashable?
    
    /// The service is injected each time this is accessed.
    public var wrappedValue: Service {
        get { resolve(in: .main) }
    }
    
    /// Create the property wrapper with no identifier.
    public init() {}
    
    /// Create the property wrapper with an identifier.
    public init(_ identifier: AnyHashable) {
        self.identifier = identifier
    }
    
    /// Resolves an instance of `Service` from the given container.
    ///
    /// - Parameter container: The container to resolve a `Service`
    ///   from.
    /// - Returns: An instance of `Service` resolved from `container`.
    private func resolve(in container: Container) -> Service {
        container.resolveAssert(identifier: identifier)
    }
    
    /// Resolves the value, resolving from the specified container if
    /// `EnclosingSelf` is `Containerized`.
    public static subscript<EnclosingSelf>(
        _enclosingInstance object: EnclosingSelf,
        wrapped wrappedKeyPath: KeyPath<EnclosingSelf, Service>,
        storage storageKeyPath: KeyPath<EnclosingSelf, Inject<Service>>
    ) -> Service {
        get {
            let customContainer = (object as? Containerized)?.container
            return object[keyPath: storageKeyPath].resolve(in: customContainer ?? .main)
        }
    }
}
