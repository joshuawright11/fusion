@attached(accessor)
@attached(peer, names: prefixed(`$`))
public macro Singleton() = #externalMacro(module: "Plugin", type: "ResolveMacro")

@attached(accessor)
@attached(peer, names: prefixed(`$`))
public macro Factory() = #externalMacro(module: "Plugin", type: "ResolveMacro")
