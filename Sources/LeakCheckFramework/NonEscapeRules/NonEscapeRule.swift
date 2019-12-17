//
//  NonEscapeRule.swift
//  LeakCheckFramework
//
//  Created by Hoang Le Pham on 28/10/2019.
//

import SwiftSyntax

public protocol NonEscapeRule {
  func isNonEscape(closureNode: ExprSyntax, graph: Graph) -> Bool
}

open class ComposeNonEscapeRule: NonEscapeRule {
  
  private let rules: [NonEscapeRule]
  
  public init(rules: [NonEscapeRule]) {
    self.rules = rules
  }
  
  public func isNonEscape(closureNode: ExprSyntax, graph: Graph) -> Bool {
    for rule in rules {
      if rule.isNonEscape(closureNode: closureNode, graph: graph) {
        return true
      }
    }
    return false
  }
}

