//
//  GraphBuilder.swift
//  SwiftLeakCheck
//
//  Copyright 2020 Grabtaxi Holdings PTE LTE (GRAB), All rights reserved.
//  Use of this source code is governed by an MIT-style license that can be found in the LICENSE file
//
//  Created by Hoang Le Pham on 29/10/2019.
//

import SwiftSyntax

final class GraphBuilder {
  static func buildGraph(node: SourceFileSyntax) -> GraphImpl {
    // First round: build the graph
    let visitor = GraphBuilderVistor()
    visitor.walk(node)
    
    let graph = GraphImpl(sourceFileScope: visitor.sourceFileScope)
    
    // Second round: resolve the references
    ReferenceBuilderVisitor(graph: graph).walk(node)
    
    return graph
  }
}

class BaseGraphVistor: SyntaxAnyVisitor {
  override func visit(_ node: UnknownDeclSyntax) -> SyntaxVisitorContinueKind {
    return .skipChildren
  }
  
  override func visit(_ node: UnknownExprSyntax) -> SyntaxVisitorContinueKind {
    return .skipChildren
  }
  
  override func visit(_ node: UnknownStmtSyntax) -> SyntaxVisitorContinueKind {
    return .skipChildren
  }
  
  override func visit(_ node: UnknownTypeSyntax) -> SyntaxVisitorContinueKind {
    return .skipChildren
  }
  
  override func visit(_ node: UnknownPatternSyntax) -> SyntaxVisitorContinueKind {
    return .skipChildren
  }
}

fileprivate final class GraphBuilderVistor: BaseGraphVistor {
  fileprivate var sourceFileScope: SourceFileScope!
  private var stack = Stack<Scope>()
  
  override func visitAny(_ node: Syntax) -> SyntaxVisitorContinueKind {
    if let scopeNode = ScopeNode.from(node: node) {
      if case let .sourceFileNode(node) = scopeNode {
        assert(stack.peek() == nil)
        sourceFileScope = SourceFileScope(node: node, parent: stack.peek())
        stack.push(sourceFileScope)
      } else {
        let scope = Scope(scopeNode: scopeNode, parent: stack.peek())
        stack.push(scope)
      }
    }
    
    #if DEBUG
    if node.is(ElseBlockSyntax.self) || node.is(ElseIfContinuationSyntax.self) {
      assertionFailure("Unhandled case")
    }
    #endif
    
    
    return super.visitAny(node)
  }
  
  override func visitAnyPost(_ node: Syntax) {
    if let scopeNode = ScopeNode.from(node: node) {
      assert(stack.peek()?.scopeNode == scopeNode)
      stack.pop()
    }
    super.visitAnyPost(node)
  }
  
  // Note: this is not necessarily in a func x(param...)
  // Take this example:
  //  x.block { param in ... }
  // Swift treats `param` as ClosureParamSyntax , but if we put `param` in open and close parathenses,
  // Swift will treat it as FunctionParameterSyntax
  override func visit(_ node: FunctionParameterSyntax) -> SyntaxVisitorContinueKind {
    
    _ = super.visit(node)
    
    guard let scope = stack.peek(), scope.type.isFunction || scope.type == .enumCaseNode else {
      fatalError()
    }
    guard let name = node.secondName ?? node.firstName else {
      assert(scope.type == .enumCaseNode)
      return .visitChildren
    }
    
    guard name.tokenKind != .wildcardKeyword else {
      return .visitChildren
    }
    
    scope.addVariable(Variable.from(node, scope: scope))
    return .visitChildren
  }
  
  override func visit(_ node: ClosureCaptureItemSyntax) -> SyntaxVisitorContinueKind {
    
    _ = super.visit(node)
    
    guard let scope = stack.peek(), scope.isClosure else {
      fatalError()
    }
    
    Variable.from(node, scope: scope).flatMap { scope.addVariable($0) }
    return .visitChildren
  }
  
  override func visit(_ node: ClosureParamSyntax) -> SyntaxVisitorContinueKind {
    
    _ = super.visit(node)
    
    guard let scope = stack.peek(), scope.isClosure else {
      fatalError("A closure should be found for a ClosureParam node. Stack may have been corrupted")
    }
    scope.addVariable(Variable.from(node, scope: scope))
    return .visitChildren
  }
  
  override func visit(_ node: PatternBindingSyntax) -> SyntaxVisitorContinueKind {
    
    _ = super.visit(node)
    
    guard let scope = stack.peek() else {
      fatalError()
    }
    
    Variable.from(node, scope: scope).forEach {
      scope.addVariable($0)
    }
    
    return .visitChildren
  }
  
  override func visit(_ node: OptionalBindingConditionSyntax) -> SyntaxVisitorContinueKind {
    
    _ = super.visit(node)
    
    guard let scope = stack.peek() else {
      fatalError()
    }
    
    let isGuardCondition = node.isGuardCondition()
    assert(!isGuardCondition || scope.type == .guardNode)
    let scopeThatOwnVariable = (isGuardCondition ? scope.parent! : scope)
    if let variable = Variable.from(node, scope: scopeThatOwnVariable) {
      scopeThatOwnVariable.addVariable(variable)
    }
    return .visitChildren
  }
  
  override func visit(_ node: ForInStmtSyntax) -> SyntaxVisitorContinueKind {
    
    _ = super.visit(node)
    
    guard let scope = stack.peek(), scope.type == .forLoopNode else {
      fatalError()
    }
    
    Variable.from(node, scope: scope).forEach { variable in
      scope.addVariable(variable)
    }
    
    return .visitChildren
  }
}

/// Visit the tree and resolve references
private final class ReferenceBuilderVisitor: BaseGraphVistor {
  private let graph: GraphImpl
  init(graph: GraphImpl) {
    self.graph = graph
  }
  
  override func visit(_ node: IdentifierExprSyntax) -> SyntaxVisitorContinueKind {
    graph.resolveVariable(node)
    return .visitChildren
  }
}

private extension Scope {
  var isClosure: Bool {
    return type == .closureNode
  }
}
