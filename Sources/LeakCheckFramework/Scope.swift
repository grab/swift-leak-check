//
//  Scope.swift
//  LeakCheck
//
//  Created by Hoang Le Pham on 27/10/2019.
//

import SwiftSyntax

public enum ScopeNode: Hashable {
  case sourceFileNode(SourceFileSyntax)
  case classNode(ClassDeclSyntax)
  case structNode(StructDeclSyntax)
  case enumNode(EnumDeclSyntax)
  case enumCaseNode(EnumCaseDeclSyntax)
  case extensionNode(ExtensionDeclSyntax)
  case funcNode(FunctionDeclSyntax)
  case initialiseNode(InitializerDeclSyntax)
  case closureNode(ClosureExprSyntax)
  case ifNode(IfStmtSyntax)
  case guardNode(GuardStmtSyntax)
  case forLoopNode(ForInStmtSyntax)
  case whileLoopNode(WhileStmtSyntax)
  case subscriptNode(SubscriptDeclSyntax)
  case accessorNode(AccessorDeclSyntax)
  case variableDeclNode(CodeBlockSyntax) // var x: Int { ... }
  case switchCaseNode(SwitchCaseSyntax)
  
  public static func from(node: Syntax) -> ScopeNode? {
    switch node {
    case let sourceFileNode as SourceFileSyntax:
      return .sourceFileNode(sourceFileNode)
      
    case let classNode as ClassDeclSyntax:
      return .classNode(classNode)
      
    case let structNode as StructDeclSyntax:
      return .structNode(structNode)
      
    case let enumNode as EnumDeclSyntax:
      return .enumNode(enumNode)
      
    case let enumCaseNode as EnumCaseDeclSyntax:
      return .enumCaseNode(enumCaseNode)
      
    case let extensionNode as ExtensionDeclSyntax:
      assert(node.enclosingScopeNode?.type == .sourceFileNode)
      return .extensionNode(extensionNode)
      
    case let funcNode as FunctionDeclSyntax:
      return .funcNode(funcNode)
      
    case let initialiseNode as InitializerDeclSyntax:
      return.initialiseNode(initialiseNode)
      
    case let closureNode as ClosureExprSyntax:
      return .closureNode(closureNode)
      
    case let ifNode as IfStmtSyntax:
      return .ifNode(ifNode)
      
    case let guardNode as GuardStmtSyntax:
      return .guardNode(guardNode)
      
    case let forLoopNode as ForInStmtSyntax:
      return .forLoopNode(forLoopNode)
      
    case let whileLoopNode as WhileStmtSyntax:
      return .whileLoopNode(whileLoopNode)
      
    case let subscriptNode as SubscriptDeclSyntax:
      return .subscriptNode(subscriptNode)

    case let accessorNode as AccessorDeclSyntax:
      return .accessorNode(accessorNode)
      
    case let codeBlockNode as CodeBlockSyntax where codeBlockNode.parent is PatternBindingSyntax
        && codeBlockNode.parent?.parent is PatternBindingListSyntax
        && codeBlockNode.parent?.parent?.parent is VariableDeclSyntax:
      return .variableDeclNode(codeBlockNode)
      
    case let switchCaseNode as SwitchCaseSyntax:
      return .switchCaseNode(switchCaseNode)
      
    default:
      return nil
    }
  }
  
  public var node: Syntax {
    switch self {
    case .sourceFileNode(let node): return node
    case .classNode(let node): return node
    case .structNode(let node): return node
    case .enumNode(let node): return node
    case .enumCaseNode(let node): return node
    case .extensionNode(let node): return node
    case .funcNode(let node): return node
    case .initialiseNode(let node): return node
    case .closureNode(let node): return node
    case .ifNode(let node): return node
    case .guardNode(let node): return node
    case .forLoopNode(let node): return node
    case .whileLoopNode(let node): return node
    case .subscriptNode(let node): return node
    case .accessorNode(let node): return node
    case .variableDeclNode(let node): return node
    case .switchCaseNode(let node): return node
    }
  }
  
  public var type: ScopeType {
    switch self {
    case .sourceFileNode: return .sourceFileNode
    case .classNode: return .classNode
    case .structNode: return .structNode
    case .enumNode: return .enumNode
    case .enumCaseNode: return .enumCaseNode
    case .extensionNode: return .extensionNode
    case .funcNode: return .funcNode
    case .initialiseNode: return .initialiseNode
    case .closureNode: return .closureNode
    case .ifNode: return .ifNode
    case .guardNode: return .guardNode
    case .forLoopNode: return .forLoopNode
    case .whileLoopNode: return .whileLoopNode
    case .subscriptNode: return .subscriptNode
    case .accessorNode: return .accessorNode
    case .variableDeclNode: return .variableDeclNode
    case .switchCaseNode: return .switchCaseNode
    }
  }
  
  public var isDataTypeScope: Bool {
    switch self {
    case .classNode,
         .structNode,
         .enumNode,
         .extensionNode:
      return true
    case .sourceFileNode,
         .funcNode,
         .enumCaseNode,
         .initialiseNode,
         .closureNode,
         .ifNode,
         .guardNode,
         .forLoopNode,
         .whileLoopNode,
         .subscriptNode,
         .accessorNode,
         .variableDeclNode,
         .switchCaseNode:
      return false
    }
  }
  
  public var isFunction: Bool {
    return type == .funcNode
      || type == .initialiseNode
      || type == .closureNode
      || type == .subscriptNode
  }
  
  // Whether a variable can be used before it's declared. This is true for node that defines type, such as class, struct, enum,....
  // Otherwise if a variable is inside func, or closure, or normal block (if, guard,..), it must be declared before being used
  public var canUseVariableInAnyOrder: Bool {
    return isDataTypeScope
  }
}

public enum ScopeType: Equatable {
  case sourceFileNode
  case classNode
  case structNode
  case enumNode
  case enumCaseNode
  case extensionNode
  case funcNode
  case initialiseNode
  case closureNode
  case ifNode
  case guardNode
  case forLoopNode
  case whileLoopNode
  case subscriptNode
  case accessorNode
  case variableDeclNode
  case switchCaseNode
}

open class Scope: Hashable, CustomStringConvertible {
  public let scopeNode: ScopeNode
  public let parent: Scope?
  public private(set) var variables = Stack<Variable>()
  public private(set) var childScopes = [Scope]()
  
  var functions: [Function] {
    return childScopes
      .compactMap { scope in
        if case let .funcNode(funcNode) = scope.scopeNode {
          return Function(node: funcNode)
        }
        return nil
      }
  }
  
  open var isFunction: Bool {
    return scopeNode.isFunction
  }
  
  public init(scopeNode: ScopeNode, parent: Scope?) {
    self.parent = parent
    self.scopeNode = scopeNode
    parent?.childScopes.append(self)
    
    if let parent = parent {
      assert(scopeNode.node.isDescendent(of: parent.scopeNode.node))
    }
  }
  
  open func addVariable(_ variable: Variable) {
    assert(variable.scope == self)
    variables.push(variable)
  }
  
  open func getVariable(_ token: TokenSyntax) -> Variable? {
    return variables.first(where: { $0.raw.token == token })
  }
  
  open func resolveVariable(_ node: IdentifierExprSyntax) -> Variable? {
    // We travel bottom up, so the first few variables might be irrelevant
    for variable in variables {
      // Special case: guard let `x` = x
      // Here x on the right cannot be resolved to x on the left
      if case let .binding(_, valueNode) = variable.raw, valueNode != nil && valueNode! == node {
        continue
      }
      
      if scopeNode.canUseVariableInAnyOrder || variable.raw.token.isBefore(node) {
        if variable.name == node.identifier.text {
          return variable
        }
      }
    }
    
    return nil
  }
  
  open func getEnclosingScope(_ node: Syntax) -> Scope? {
    guard let scopeNode = node.enclosingScopeNode else {
      return nil
    }
    return getScope(scopeNode)
  }
  
  open func getScope(_ node: Syntax) -> Scope? {
    guard let scopeNode = ScopeNode.from(node: node) else {
      return nil
    }
    return getScope(scopeNode)
  }
  
  open func getScope(_ scopeNode: ScopeNode) -> Scope? {
    if self.scopeNode == scopeNode {
      return self
    }
    return childScopes.lazy.compactMap { return $0.getScope(scopeNode) }.first
  }
  
  open var description: String {
    return "\(scopeNode)"
  }
}

// MARK: - Hashable
extension Scope {
  open func hash(into hasher: inout Hasher) {
    scopeNode.hash(into: &hasher)
  }
  
  public static func == (_ lhs: Scope, _ rhs: Scope) -> Bool {
    return lhs.scopeNode == rhs.scopeNode
  }
}

extension Syntax {
  public var enclosingScopeNode: ScopeNode? {
    var parent = self.parent
    while parent != nil {
      if let scopeNode = ScopeNode.from(node: parent!) {
        return scopeNode
      }
      parent = parent?.parent
    }
    return nil
  }
}
