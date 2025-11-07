import SwiftSyntax
import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct FusionPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        ServiceMacro.self,
    ]
}

enum ServiceMacro: AccessorMacro {
    static func expansion(
        of node: AttributeSyntax,
        providingAccessorsOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws (FusionPluginError) -> [AccessorDeclSyntax] {
        guard let property = VariableDeclSyntax(declaration) else {
            throw "@Service can only be applied to properties."
        }

        guard !property.isComputed else {
            throw "@Service doesn't support computed properties - use a lazy property with a closure initializer instead."
        }

        let initializer: String = if let initializerExpression = property.initializerExpression {
            "\(initializerExpression)"
        } else {
            """
            preconditionFailure("@Service '\(property.name)' has no default value and needs to be set manually before use.")
            """
        }

        let scope = node.arguments.map { "scope: \($0.trimmedDescription)" }
        let keyPath = "\\.\(property.name)"
        let arguments = [scope, keyPath].compactMap { $0 }.joined(separator: ", ")
        return [
            """
            get { 
                resolve(\(raw: arguments)) { \(raw: initializer) } 
            }
            set {
                mock(\(raw: keyPath), value: newValue)
            }
            """
        ]
    }
}

extension VariableDeclSyntax {
    fileprivate var name: String {
        IdentifierPatternSyntax(bindings.first?.pattern)?.identifier.text ?? ""
    }

    fileprivate var initializerExpression: ExprSyntax? {
        bindings.first?.initializer?.value
    }

    fileprivate var isComputed: Bool {
        bindings.first?.accessorBlock != nil
    }
}

struct FusionPluginError: Error, CustomDebugStringConvertible, ExpressibleByStringInterpolation {
    let debugDescription: String

    init(stringLiteral value: String) {
        self.debugDescription = value
    }
}
