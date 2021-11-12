/// Conform a class to `Containerized` lets the `@Inject` property
/// wrapper know that there is a custom container from which
/// services should be resolved.
///
/// If the enclosing type of the property wrapper is not
/// `Containerized`, injected services will be resolved
/// from `Container.default`.
///
/// Usage:
/// ```swift
/// final class UsersController: Containerized {
///     let container = Container()
///
///     // Will be resolved from `self.container` instead of
///     // `Container.default`
///     @Inject var database: Database
/// }
/// ```
public protocol Containerized: AnyObject {
    /// The container from which `@Inject`ed services on this type
    /// should be resolved.
    var container: Container { get }
}

/// Provides a convenient `@propertyWrapper` for injecting services to
/// a type. By default, resolves services from the global container
/// (`Container.default`) but if the enclosing type conforms to
/// `Containerized` services are resolved from
/// `EnclosingType.container`.
@propertyWrapper
public class Inject<Service> {
    /// An optional identifier that may be associated with the service
    /// this property wrapper is injecting. Used for storing any
    /// identifiers of a service.
    var identifier: AnyHashable?
    
    /// An instance of the service this property wrapper is injecting.
    public var wrappedValue: Service {
        get { resolve(in: .default) }
    }
    
    /// Create the property wrapper with no identifier.
    public init() {}
    
    /// Create the property wrapper with an identifier.
    ///
    /// - Parameter identifier: The identifier of the service to load.
    public init<H: Hashable>(_ identifier: H) {
        self.identifier = identifier
    }
    
    /// Resolves an instance of `Service` from the given container.
    ///
    /// - Parameter container: The container to resolve a `Service`
    ///   from.
    /// - Returns: An instance of `Service` resolved from `container`.
    private func resolve(in container: Container) -> Service {
        guard let service = container._resolve(Service.self, identifier: identifier) else {
            fatalError("Unable to find service \(Service.self) with identifier \(identifier.map { "\($0)" } ?? "nil")")
        }
        
        return service
    }
    
    /// Leverages an undocumented `Swift` API for accessing the
    /// enclosing type of a property wrapper to detect if the
    /// enclosing type is `Containerized` and then use that
    /// container for resolving when the `wrappedValue` of
    /// the property wrapper is accessed.
    public static subscript<EnclosingSelf>(
        _enclosingInstance object: EnclosingSelf,
        wrapped wrappedKeyPath: KeyPath<EnclosingSelf, Service>,
        storage storageKeyPath: KeyPath<EnclosingSelf, Inject<Service>>
    ) -> Service {
        get {
            let customContainer = (object as? Containerized)?.container
            return object[keyPath: storageKeyPath].resolve(in: customContainer ?? .default)
        }
    }
}
