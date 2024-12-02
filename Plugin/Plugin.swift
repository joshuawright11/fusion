import SwiftSyntax
import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct Plugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        ResolveMacro.self,
    ]
}

enum ResolveMacro: PeerMacro, AccessorMacro {
    struct Error: Swift.Error, CustomDebugStringConvertible, ExpressibleByStringLiteral {
        private let message: String
        var debugDescription: String { message }
        init(stringLiteral value: String) { self.message = value }
    }

    // MARK: AccessorMacro

    static func expansion(
        of node: AttributeSyntax,
        providingAccessorsOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws (Error) -> [AccessorDeclSyntax] {
        guard let variable = declaration.variable else {
            throw "ResolveMacro can only be applied to properties"
        }

        guard !variable.isComputed else {
            return []
        }

        guard let initializer = variable.initializerExpression else {
            throw "Property must be optional or have an initial value"
        }

        return [
            """
            get { \(initializer) }
            """
        ]
    }

    // MARK: PeerMacro

    static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws (Error) -> [DeclSyntax] {
        guard
            let variable = declaration.variable,
            let name = variable.name
        else {
            throw "ResolveMacro can only be applied to properties"
        }

        guard let type = variable.typeName else {
            throw .init(stringLiteral: "Unable to infer type of '\(name)', please provide an explicit type")
        }

        guard let scope = node.name?.lowercaseFirstCharacter() else {
            throw "Unable to read attribute name"
        }

        return [
            """
            var $\(raw: name): \(raw: type) {
                get {
                    resolve(\\.$\(raw: name), .\(raw: scope)) { \(raw: name) }
                }
                set {
                    mock(\\.$\(raw: name), value: newValue)
                }
            }
            """
        ]
    }
}

extension DeclSyntaxProtocol {
    fileprivate var variable: VariableDeclSyntax? {
        `as`(VariableDeclSyntax.self)
    }
}

extension AttributeSyntax {
    fileprivate var name: String? {
        IdentifierTypeSyntax(attributeName)?.name.text
    }
}

extension VariableDeclSyntax {
    fileprivate var typeName: String? {
        IdentifierTypeSyntax(bindings.first?.typeAnnotation?.type)?.name.text ?? inferType()
    }

    private func inferType() -> String? {
        guard let initializerExpression else { return nil }
        if initializerExpression.is(IntegerLiteralExprSyntax.self) {
            return "Int"
        } else if initializerExpression.is(StringLiteralExprSyntax.self) {
            return "String"
        } else if initializerExpression.is(BooleanLiteralExprSyntax.self) {
            return "Bool"
        } else if initializerExpression.is(FloatLiteralExprSyntax.self) {
            return "Double"
        } else if
            let function = initializerExpression.as(FunctionCallExprSyntax.self),
            let declReference = function.calledExpression.as(DeclReferenceExprSyntax.self),
            declReference.isLikelyType
        {
            return declReference.baseName.text
        } else {
            return nil
        }
    }

    fileprivate var name: String? {
        IdentifierPatternSyntax(bindings.first?.pattern)?.identifier.text
    }

    fileprivate var initializerExpression: ExprSyntax? {
        bindings.first?.initializer?.value
    }

    fileprivate var isComputed: Bool {
        bindings.first?.accessorBlock != nil
    }
}

extension DeclReferenceExprSyntax {
    fileprivate var isLikelyType: Bool {
        guard let first = baseName.text.first else { return false }
        return first == "_" || first.isUppercase
    }
}

extension String {
    fileprivate func lowercaseFirstCharacter() -> String {
        guard let first else { return self }
        return first.lowercased() + dropFirst()
    }
}
