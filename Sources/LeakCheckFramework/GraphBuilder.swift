//
//  GraphBuilder.swift
//  LeakCheckFramework
//
//  Copyright 2019 Grabtaxi Holdings PTE LTE (GRAB), All rights reserved.
//  Use of this source code is governed by an MIT-style license that can be found in the LICENSE file
//
//  Created by Hoang Le Pham on 29/10/2019.
//

import SwiftSyntax

final class GraphBuilder {
  static func buildGraph(node: SourceFileSyntax) -> Graph {
    // First round: build the graph
    let vistor = GraphBuilderVistor()
    node.walk(vistor)
    let graph = Graph(sourceFileScope: vistor.sourceFileScope)
    
    // Second round: resolve the references
    node.walk(ReferenceBuilderVisitor(graph: graph))
    
    return graph
  }
}

class BaseGraphVistor: SyntaxVisitor {
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

// TODO:
// 1. Add variables in `if case let .someCase(a, b, c) {`
fileprivate final class GraphBuilderVistor: BaseGraphVistor {
  fileprivate var sourceFileScope: SourceFileScope!
  private var stack = Stack<Scope>()
  
  override func visitPre(_ node: Syntax) {
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
    if node is ElseBlockSyntax || node is ElseIfContinuationSyntax {
      assertionFailure("Unhandled case")
    }
    #endif
    
    super.visitPre(node)
  }
  
  override func visitPost(_ node: Syntax) {
    if let scopeNode = ScopeNode.from(node: node) {
      assert(stack.peek()?.scopeNode == scopeNode)
      stack.pop()
    }
    super.visitPost(node)
  }
  
  // Note: this is not necessarily in a func x(param...)
  // Swift will treat `param` as ClosureParamSyntax in the code below
  // x.block { param in
  // }
  // But it will treat `param` as FunctionParameterSyntax if we enclose the param in `(` and `)`
  // x.block { (param) in
  // }
  // Not sure if it's Swift bug
  override func visit(_ node: FunctionParameterSyntax) -> SyntaxVisitorContinueKind {
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
  
  override func visit(_ node: AccessorParameterSyntax) -> SyntaxVisitorContinueKind {
    return .visitChildren
  }
  
  override func visit(_ node: ClosureCaptureItemSyntax) -> SyntaxVisitorContinueKind {
    guard let scope = stack.peek(), scope.isClosure else {
      fatalError()
    }
    
    Variable.from(node, scope: scope).flatMap { scope.addVariable($0) }
    return .visitChildren
  }
  
  override func visit(_ node: ClosureParamSyntax) -> SyntaxVisitorContinueKind {
    guard let scope = stack.peek(), scope.isClosure else {
      fatalError("A closure should be found for a ClosureParam node. Stack may have been corrupted")
    }
    scope.addVariable(Variable.from(node, scope: scope))
    return .visitChildren
  }
  
  override func visit(_ node: PatternBindingSyntax) -> SyntaxVisitorContinueKind {
    guard let scope = stack.peek() else {
      fatalError()
    }
    
    Variable.from(node, scope: scope).forEach {
      scope.addVariable($0)
    }
    
    return .visitChildren
  }
  
  override func visit(_ node: OptionalBindingConditionSyntax) -> SyntaxVisitorContinueKind {
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
    assert(node.caseKeyword == nil, "Unhandled case")
    
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
  private let graph: Graph
  init(graph: Graph) {
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
