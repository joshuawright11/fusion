@attached(accessor)
@attached(peer, names: prefixed(`$`))
public macro Singleton() = #externalMacro(module: "FusionPlugin", type: "ResolveMacro")

@attached(accessor)
@attached(peer, names: prefixed(`$`))
public macro Factory() = #externalMacro(module: "FusionPlugin", type: "ResolveMacro")

@propertyWrapper
public struct Injected<T> {
    private let keyPath: KeyPath<Container, T>?

    public var wrappedValue: T {
        if let keyPath {
            Container.main[keyPath: keyPath]
        } else {
            Container.main.require(T.self)
        }
    }

    public init(_ keyPath: KeyPath<Container, T>) {
        self.keyPath = keyPath
    }

    public init(_ type: T.Type = T.self) {
        self.keyPath = nil
    }
}
