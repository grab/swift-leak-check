//
//  Scope.swift
//  LeakCheck
//
//  Copyright 2020 Grabtaxi Holdings PTE LTE (GRAB), All rights reserved.
//  Use of this source code is governed by an MIT-style license that can be found in the LICENSE file
//
//  Created by Hoang Le Pham on 27/10/2019.
//

import SwiftSyntax

public enum ScopeNode: Hashable, CustomStringConvertible {
  case sourceFileNode(SourceFileSyntax)
  case classNode(ClassDeclSyntax)
  case structNode(StructDeclSyntax)
  case enumNode(EnumDeclSyntax)
  case enumCaseNode(EnumCaseDeclSyntax)
  case extensionNode(ExtensionDeclSyntax)
  case funcNode(FunctionDeclSyntax)
  case initialiseNode(InitializerDeclSyntax)
  case closureNode(ClosureExprSyntax)
  case ifBlockNode(CodeBlockSyntax, IfStmtSyntax) // If block in a `IfStmtSyntax`
  case elseBlockNode(CodeBlockSyntax, IfStmtSyntax) // Else block in a `IfStmtSyntax`
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
      
    case let codeBlockNode as CodeBlockSyntax where codeBlockNode.parent is IfStmtSyntax:
      let parent = codeBlockNode.parent as! IfStmtSyntax
      if codeBlockNode == parent.body {
        return .ifBlockNode(codeBlockNode, parent)
      } else if codeBlockNode == parent.elseBody as? CodeBlockSyntax {
        return .elseBlockNode(codeBlockNode, parent)
      }
      return nil
      
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
    case .ifBlockNode(let node, _): return node
    case .elseBlockNode(let node, _): return node
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
    case .ifBlockNode, .elseBlockNode: return .ifElseNode
    case .guardNode: return .guardNode
    case .forLoopNode: return .forLoopNode
    case .whileLoopNode: return .whileLoopNode
    case .subscriptNode: return .subscriptNode
    case .accessorNode: return .accessorNode
    case .variableDeclNode: return .variableDeclNode
    case .switchCaseNode: return .switchCaseNode
    }
  }
  
  public var enclosingScopeNode: ScopeNode? {
    return node.enclosingScopeNode
  }
  
  public var description: String {
    return "\(node)"
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
  case ifElseNode
  case guardNode
  case forLoopNode
  case whileLoopNode
  case subscriptNode
  case accessorNode
  case variableDeclNode
  case switchCaseNode
  
  public var isTypeDecl: Bool {
    return self == .classNode
      || self == .structNode
      || self == .enumNode
      || self == .extensionNode
  }
  
  public var isFunction: Bool {
    return self == .funcNode
      || self == .initialiseNode
      || self == .closureNode
      || self == .subscriptNode
  }
  
}

open class Scope: Hashable, CustomStringConvertible {
  public let scopeNode: ScopeNode
  public let parent: Scope?
  public private(set) var variables = Stack<Variable>()
  public private(set) var childScopes = [Scope]()
  public var type: ScopeType {
    return scopeNode.type
  }
  
  public var childFunctions: [Function] {
    return childScopes
      .compactMap { scope in
        if case let .funcNode(funcNode) = scope.scopeNode {
          return funcNode
        }
        return nil
    }
  }
  
  public var childTypeDecls: [TypeDecl] {
    return childScopes
      .compactMap { $0.typeDecl }
  }
  
  public var typeDecl: TypeDecl? {
    switch scopeNode {
    case .classNode(let node):
      return TypeDecl(tokens: [node.identifier], inheritanceTypes: node.inheritanceClause?.inheritedTypeCollection.map { $0 }, scope: self)
    case .structNode(let node):
      return TypeDecl(tokens: [node.identifier], inheritanceTypes: node.inheritanceClause?.inheritedTypeCollection.map { $0 }, scope: self)
    case .enumNode(let node):
      return TypeDecl(tokens: [node.identifier], inheritanceTypes: node.inheritanceClause?.inheritedTypeCollection.map { $0 }, scope: self)
    case .extensionNode(let node):
      return TypeDecl(tokens: node.extendedType.tokens!, inheritanceTypes: node.inheritanceClause?.inheritedTypeCollection.map { $0 }, scope: self)
    default:
      return nil
    }
  }
  
  // Whether a variable can be used before it's declared. This is true for node that defines type, such as class, struct, enum,....
  // Otherwise if a variable is inside func, or closure, or normal block (if, guard,..), it must be declared before being used
  public var canUseVariableOrFuncInAnyOrder: Bool {
    return type == .classNode
      || type == .structNode
      || type == .enumNode
      || type == .extensionNode
      || type == .sourceFileNode
  }
  
  public init(scopeNode: ScopeNode, parent: Scope?) {
    self.parent = parent
    self.scopeNode = scopeNode
    parent?.childScopes.append(self)
    
    if let parent = parent {
      assert(scopeNode.node.isDescendent(of: parent.scopeNode.node))
    }
  }
  
  func addVariable(_ variable: Variable) {
    assert(variable.scope == self)
    variables.push(variable)
  }
  
  func getVariable(_ node: IdentifierExprSyntax) -> Variable? {
    for variable in variables {
      // Special case:
      // guard let `x` = x else { ... }
      // Here x on the right cannot be resolved to x on the left
      if case let .binding(_, valueNode) = variable.raw,
        valueNode != nil && valueNode! == node {
        continue
      }
      
      if variable.raw.token.isBefore(node) || canUseVariableOrFuncInAnyOrder {
        if variable.name == node.identifier.text {
          return variable
        }
      }
    }
    
    return nil
  }
  
  func getFunctionWithSymbol(_ symbol: Symbol) -> [Function] {
    return childFunctions.filter { function in
      if function.identifier.isBefore(symbol.node) || canUseVariableOrFuncInAnyOrder {
        return function.identifier.text == symbol.name
      }
      return false
    }
  }
  
  func getTypeDecl(name: String) -> [TypeDecl] {
    return childTypeDecls
      .filter { typeDecl in
        return typeDecl.name == [name]
      }
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
