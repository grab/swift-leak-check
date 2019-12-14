//
//  GraphLeakDetector.swift
//  LeakCheckFramework
//
//  Created by Hoang Le Pham on 12/11/2019.
//

import SwiftSyntax

public final class GraphLeakDetector: BaseSyntaxTreeLeakDetector {
  
  public let nonEscapeRules: ((Graph) -> [NonEscapeRule])?
  
  public init(nonEscapeRules: ((Graph) -> [NonEscapeRule])? = nil) {
    self.nonEscapeRules = nonEscapeRules
  }
  
  override public func detect(_ sourceFileNode: SourceFileSyntax) -> [Leak] {
    var res: [Leak] = []
    let graph = GraphBuilder.buildGraph(node: sourceFileNode)
    let visitor = LeakSyntaxVisitor(graph: graph, nonEscapeRules: nonEscapeRules?(graph) ?? []) { leak in
        res.append(leak)
      }
    sourceFileNode.walk(visitor)
    return res
  }
}

private final class LeakSyntaxVisitor: BaseGraphVistor {
  private let graph: Graph
  private let onLeakDetected: (Leak) -> Void
  private let nonEscapeRules: [NonEscapeRule]
  
  init(graph: Graph, nonEscapeRules: [NonEscapeRule], onLeakDetected: @escaping (Leak) -> Void) {
    self.graph = graph
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
    
    if !graph.couldReferenceSelf(node) {
      return
    }
    
    var currentScope = graph.getClosetScopeThatCanResolve(node)
    var isEscape = false
    while true {
      if let variable = currentScope.resolveVariable(node) {
        if !isEscape {
          // No leak
          return
        }

        switch variable.raw {
        case .param:
          fatalError("Can't happen since a param cannot reference `self`")
        case let .capture(capturedNode):
          if variable.isStrong && isEscape {
            leak = Leak(node: node, capturedNode: capturedNode)
          }
        case let .binding(_, valueNode):
          if let referenceNode = valueNode as? IdentifierExprSyntax {
            if variable.isStrong && isEscape {
              leak = Leak(node: node, capturedNode: referenceNode)
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

      if let parent = currentScope.parent {
        currentScope = parent
      } else {
        break
      }
    }

    if isEscape {
      leak = Leak(node: node, capturedNode: nil)
      return
    }
  }
}
