@propertyWrapper
public struct Dependency<T> {
    private let key: KeyPath<Container, T>

    public var wrappedValue: T {
        Container.main[keyPath: key]
    }

    public init(_ key: KeyPath<Container, T>) {
        self.key = key
    }
}
