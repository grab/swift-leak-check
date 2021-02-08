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
    if let sourceFileNode = node.as(SourceFileSyntax.self) {
      return .sourceFileNode(sourceFileNode)
    }
    
    if let classNode = node.as(ClassDeclSyntax.self) {
      return .classNode(classNode)
    }
      
    if let structNode = node.as(StructDeclSyntax.self) {
      return .structNode(structNode)
    }
      
    if let enumNode = node.as(EnumDeclSyntax.self) {
      return .enumNode(enumNode)
    }
      
    if let enumCaseNode = node.as(EnumCaseDeclSyntax.self) {
      return .enumCaseNode(enumCaseNode)
    }
      
    if let extensionNode = node.as(ExtensionDeclSyntax.self) {
      return .extensionNode(extensionNode)
    }
    
    if let funcNode = node.as(FunctionDeclSyntax.self) {
      return .funcNode(funcNode)
    }
      
    if let initialiseNode = node.as(InitializerDeclSyntax.self) {
      return .initialiseNode(initialiseNode)
    }
      
    if let closureNode = node.as(ClosureExprSyntax.self) {
      return .closureNode(closureNode)
    }
      
    if let codeBlockNode = node.as(CodeBlockSyntax.self), codeBlockNode.parent?.is(IfStmtSyntax.self) == true {
      let parent = (codeBlockNode.parent?.as(IfStmtSyntax.self))!
      if codeBlockNode == parent.body {
        return .ifBlockNode(codeBlockNode, parent)
      } else if codeBlockNode == parent.elseBody?.as(CodeBlockSyntax.self) {
        return .elseBlockNode(codeBlockNode, parent)
      }
      return nil
    }
      
    if let guardNode = node.as(GuardStmtSyntax.self) {
      return .guardNode(guardNode)
    }
      
    if let forLoopNode = node.as(ForInStmtSyntax.self) {
      return .forLoopNode(forLoopNode)
    }
      
    if let whileLoopNode = node.as(WhileStmtSyntax.self) {
      return .whileLoopNode(whileLoopNode)
    }
      
    if let subscriptNode = node.as(SubscriptDeclSyntax.self) {
      return .subscriptNode(subscriptNode)
    }

    if let accessorNode = node.as(AccessorDeclSyntax.self) {
      return .accessorNode(accessorNode)
    }
      
    if let codeBlockNode = node.as(CodeBlockSyntax.self),
       codeBlockNode.parent?.is(PatternBindingSyntax.self) == true,
       codeBlockNode.parent?.parent?.is(PatternBindingListSyntax.self) == true,
       codeBlockNode.parent?.parent?.parent?.is(VariableDeclSyntax.self) == true {
      return .variableDeclNode(codeBlockNode)
    }
      
    if let switchCaseNode = node.as(SwitchCaseSyntax.self) {
      return .switchCaseNode(switchCaseNode)
    }
    
    return nil
  }
  
  public var node: Syntax {
    switch self {
    case .sourceFileNode(let node): return node._syntaxNode
    case .classNode(let node): return node._syntaxNode
    case .structNode(let node): return node._syntaxNode
    case .enumNode(let node): return node._syntaxNode
    case .enumCaseNode(let node): return node._syntaxNode
    case .extensionNode(let node): return node._syntaxNode
    case .funcNode(let node): return node._syntaxNode
    case .initialiseNode(let node): return node._syntaxNode
    case .closureNode(let node): return node._syntaxNode
    case .ifBlockNode(let node, _): return node._syntaxNode
    case .elseBlockNode(let node, _): return node._syntaxNode
    case .guardNode(let node): return node._syntaxNode
    case .forLoopNode(let node): return node._syntaxNode
    case .whileLoopNode(let node): return node._syntaxNode
    case .subscriptNode(let node): return node._syntaxNode
    case .accessorNode(let node): return node._syntaxNode
    case .variableDeclNode(let node): return node._syntaxNode
    case .switchCaseNode(let node): return node._syntaxNode
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
    let name = node.identifier.text
    for variable in variables.filter({ $0.name == name }) {
      // Special case: guard let `x` = x else { ... }
      // or: let x = x.doSmth()
      // Here x on the right cannot be resolved to x on the left
      if case let .binding(_, valueNode) = variable.raw,
         valueNode != nil && node._syntaxNode.isDescendent(of: valueNode!._syntaxNode) {
        continue
      }
      
      if variable.raw.token.isBefore(node) {
        return variable
      } else if !canUseVariableOrFuncInAnyOrder {
        // Stop
        break
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

extension SyntaxProtocol {
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
