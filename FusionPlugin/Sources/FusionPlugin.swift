import SwiftSyntax
import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct FusionPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        ResolveMacro.self,
    ]
}

enum ResolveMacro: PeerMacro, AccessorMacro {

    // MARK: AccessorMacro

    static func expansion(
        of node: AttributeSyntax,
        providingAccessorsOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws (FusionPluginError) -> [AccessorDeclSyntax] {
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
    ) throws (FusionPluginError) -> [DeclSyntax] {
        guard
            let variable = declaration.variable,
            let name = variable.name
        else {
            throw "ResolveMacro can only be applied to properties"
        }

        guard let type = variable.typeName else {
            throw "Unable to infer type of '\(name)', please provide an explicit type"
        }

        guard let scope = node.name?.lowercaseFirstCharacter() else {
            throw "Unable to read attribute name"
        }

        let access = variable.access.map { $0 + " " } ?? ""
        return [
            """
            \(raw: access)var $\(raw: name): \(raw: type) {
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

struct FusionPluginError: Error, CustomDebugStringConvertible, ExpressibleByStringInterpolation {
    private let message: String
    var debugDescription: String { message }
    init(stringLiteral value: String) { self.message = value }
}

extension SyntaxProtocol {
    fileprivate var variable: VariableDeclSyntax? {
        VariableDeclSyntax(self)
    }

    fileprivate var `extension`: ExtensionDeclSyntax? {
        ExtensionDeclSyntax(self)
    }
}

extension ExtensionDeclSyntax {
    fileprivate var typeName: String? {
        IdentifierTypeSyntax(extendedType)?.name.text
    }

    fileprivate var properties: [(name: String, type: String)] {
        memberBlock.members
            .compactMap(\.variable)
            .compactMap {
                guard let name = $0.name, let type = $0.typeName else { return nil}
                return (name, type)
            }
    }
}

extension AttributeSyntax {
    fileprivate var name: String? {
        IdentifierTypeSyntax(attributeName)?.name.text
    }
}

extension VariableDeclSyntax {
    fileprivate var access: String? {
        DeclModifierSyntax(modifiers.first)?.name.text
    }

    fileprivate var typeName: String? {
        guard let type = bindings.first?.typeAnnotation?.type else {
            return inferType()
        }

        return type.trimmedDescription
    }

    private func inferType() -> String? {
        initializerExpression?.inferType()
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

extension ExprSyntax {
    fileprivate func inferType() -> String? {
        if `is`(IntegerLiteralExprSyntax.self) {
            return "Int"
        } else if `is`(StringLiteralExprSyntax.self) {
            return "String"
        } else if `is`(BooleanLiteralExprSyntax.self) {
            return "Bool"
        } else if `is`(FloatLiteralExprSyntax.self) {
            return "Double"
        } else if
            let function = FunctionCallExprSyntax(self),
            let declReference = DeclReferenceExprSyntax(function.calledExpression),
            declReference.isLikelyType
        {
            return declReference.baseName.text
        } else if let ternary = TernaryExprSyntax(self) {
            return ternary.thenExpression.inferType()
        } else if
            let sequence = SequenceExprSyntax(self),
            sequence.elements.count > 1,
            let ternary = sequence.elements.compactMap({ UnresolvedTernaryExprSyntax($0) }).first
        {
            return ternary.thenExpression.inferType()
        } else {
            return nil
        }
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

    fileprivate func uppercaseFirstCharacter() -> String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}
