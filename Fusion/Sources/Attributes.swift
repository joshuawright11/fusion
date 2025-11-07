@attached(accessor)
public macro Service(_ scope: Container.Scope? = nil) = #externalMacro(module: "FusionPlugin", type: "ServiceMacro")

@propertyWrapper
public struct Inject<T> {
    private let keyPath: KeyPath<Container, T>?
    private let container: Container

    public var wrappedValue: T {
        if let keyPath {
            container[keyPath: keyPath]
        } else {
            container.require(T.self)
        }
    }

    public init(_ keyPath: KeyPath<Container, T>? = nil, container: Container = .main) {
        self.keyPath = keyPath
        self.container = container
    }
}
