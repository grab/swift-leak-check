//
//  NonEscapeRule.swift
//  SwiftLeakCheck
//
//  Copyright 2020 Grabtaxi Holdings PTE LTE (GRAB), All rights reserved.
//  Use of this source code is governed by an MIT-style license that can be found in the LICENSE file
//
//  Created by Hoang Le Pham on 28/10/2019.
//

import SwiftSyntax

public protocol NonEscapeRule {
  func isNonEscape(closureNode: ExprSyntax, graph: Graph) -> Bool
}

open class BaseNonEscapeRule: NonEscapeRule {
  public init() {}
  
  public func isNonEscape(closureNode: ExprSyntax, graph: Graph) -> Bool {
    guard let (funcCallExpr, arg) = closureNode.getEnclosingFunctionCallForArgument() else {
      return false
    }
    
    return isNonEscape(
      arg: arg,
      funcCallExpr: funcCallExpr,
      graph: graph
    )
  }
  
  /// Returns whether a given argument is escaping in a function call
  ///
  /// - Parameters:
  ///   - arg: The closure argument, or nil if it's trailing closure
  ///   - funcCallExpr: the source FunctionCallExprSyntax
  ///   - graph: Source code graph. Use it to retrieve more info
  /// - Returns: true if the closure is non-escaping, false otherwise
  open func isNonEscape(arg: FunctionCallArgumentSyntax?,
                        funcCallExpr: FunctionCallExprSyntax,
                        graph: Graph) -> Bool {
    return false
  }
}

public final class PredicateNonEscapeRule: BaseNonEscapeRule {
  private let predicates: [ExprSyntaxPredicate]
  init(predicates: [ExprSyntaxPredicate]) {
    self.predicates = predicates
  }
  
  public override func isNonEscape(arg: FunctionCallArgumentSyntax?, funcCallExpr: FunctionCallExprSyntax, graph: Graph) -> Bool {
    for predicate in predicates {
      if funcCallExpr.match(predicate) {
        return true
      }
    }
    return false
  }
}
