//
//  GraphLeakDetector.swift
//  SwiftLeakCheck
//
//  Copyright 2020 Grabtaxi Holdings PTE LTE (GRAB), All rights reserved.
//  Use of this source code is governed by an MIT-style license that can be found in the LICENSE file
//
//  Created by Hoang Le Pham on 12/11/2019.
//

import SwiftSyntax

public final class GraphLeakDetector: BaseSyntaxTreeLeakDetector {
  
  public var nonEscapeRules: [NonEscapeRule] = []
  
  override public func detect(_ sourceFileNode: SourceFileSyntax) -> [Leak] {
    var res: [Leak] = []
    let graph = GraphBuilder.buildGraph(node: sourceFileNode)
    let sourceLocationConverter = SourceLocationConverter(file: "", tree: sourceFileNode)
    let visitor = LeakSyntaxVisitor(graph: graph, nonEscapeRules: nonEscapeRules, sourceLocationConverter: sourceLocationConverter) { leak in
        res.append(leak)
      }
    visitor.walk(sourceFileNode)
    return res
  }
}

private final class LeakSyntaxVisitor: BaseGraphVistor {
  private let graph: GraphImpl
  private let sourceLocationConverter: SourceLocationConverter
  private let onLeakDetected: (Leak) -> Void
  private let nonEscapeRules: [NonEscapeRule]
  
  init(graph: GraphImpl,
       nonEscapeRules: [NonEscapeRule],
       sourceLocationConverter: SourceLocationConverter,
       onLeakDetected: @escaping (Leak) -> Void) {
    self.graph = graph
    self.sourceLocationConverter = sourceLocationConverter
    self.nonEscapeRules = nonEscapeRules
    self.onLeakDetected = onLeakDetected
  }
  
  override func visit(_ node: IdentifierExprSyntax) -> SyntaxVisitorContinueKind {
    detectLeak(node)
    return .skipChildren
  }
  
  private func detectLeak(_ node: IdentifierExprSyntax) {
    var leak: Leak?
    defer {
      if let leak = leak {
        onLeakDetected(leak)
      }
    }
    
    if node.getEnclosingClosureNode() == nil {
      // Not inside closure -> ignore
      return
    }
    
    if !graph.couldReferenceSelf(ExprSyntax(node)) {
      return
    }
    
    var currentScope: Scope! = graph.closetScopeThatCanResolveSymbol(.identifier(node))
    var isEscape = false
    while currentScope != nil {
      if let variable = currentScope.getVariable(node) {
        if !isEscape {
          // No leak
          return
        }

        switch variable.raw {
        case .param:
          fatalError("Can't happen since a param cannot reference `self`")
        case let .capture(capturedNode):
          if variable.isStrong && isEscape {
            leak = Leak(node: node, capturedNode: ExprSyntax(capturedNode), sourceLocationConverter: sourceLocationConverter)
          }
        case let .binding(_, valueNode):
          if let referenceNode = valueNode?.as(IdentifierExprSyntax.self) {
            if variable.isStrong && isEscape {
              leak = Leak(node: node, capturedNode: ExprSyntax(referenceNode), sourceLocationConverter: sourceLocationConverter)
            }
          } else {
            fatalError("Can't reference `self`")
          }
        }

        return
      }

      if case let .closureNode(closureNode) = currentScope.scopeNode {
        isEscape = graph.isClosureEscape(closureNode, nonEscapeRules: nonEscapeRules)
      }

      currentScope = currentScope.parent
    }

    if isEscape {
      leak = Leak(node: node, capturedNode: nil, sourceLocationConverter: sourceLocationConverter)
      return
    }
  }
}
