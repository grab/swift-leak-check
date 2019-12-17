//
//  DispatchQueueRule.swift
//  LeakCheckFramework
//
//  Created by Hoang Le Pham on 28/10/2019.
//

import SwiftSyntax

public final class DispatchQueueRule: NonEscapeRule {
  
  public var namePredicate: ((String) -> Bool)?
  
  public init(namePredicate: ((String) -> Bool)? = nil) {
    self.namePredicate = namePredicate
  }
  
  public func isNonEscape(closureNode: ExprSyntax, graph: Graph) -> Bool {
    return closureNode.isArgumentInFunctionCall(
      functionNamePredicate: { $0 == "async" || $0 == "sync" || $0 == "asyncAfter" },
      argumentNamePredicate: { $0 == "execution" },
      calledExprPredicate: { expr in
        if let identifierExpr = expr as? IdentifierExprSyntax, let namePredicate = namePredicate {
          return namePredicate(identifierExpr.identifier.text)
        } else if let memberAccessExpr = expr as? MemberAccessExprSyntax {
          return memberAccessExpr.match("DispatchQueue.main")
        } else if let function = expr as? FunctionCallExprSyntax {
          if let subExpr = function.calledExpression as? MemberAccessExprSyntax {
            return subExpr.match("DispatchQueue.global")
          }
        }
        return false
      })
  }
}

