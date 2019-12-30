//
//  DispatchQueueRule.swift
//  LeakCheckFramework
//
//  Created by Hoang Le Pham on 28/10/2019.
//

import SwiftSyntax

public final class DispatchQueueRule: BaseNonEscapeRule {
  
  private let predicates: [ExprSyntaxPredicate]
  
  public init(basePredicate: ((String) -> Bool)? = nil) {
    self.predicates = {
      let mainQueuePredicate: ExprSyntaxPredicate = .memberAccess("main", base: .name("DispatchQueue"))
      let globalQueuePredicate: ExprSyntaxPredicate = .funcCall(
        FunctionSignature(name: "global", params: [.init(name: "qos", canOmit: true)]),
        base: .name("DispatchQueue")
      )
      
      let asyncSignature = FunctionSignature(name: "async", params: [
        FunctionParam(name: "execution", isClosure: true)
        ])
      let syncSignature = FunctionSignature(name: "sync", params: [
        FunctionParam(name: "execution", isClosure: true)
        ])
      let asyncAfterSignature = FunctionSignature(name: "asyncAfter", params: [
        FunctionParam(name: "deadline"),
        FunctionParam(name: "execution", isClosure: true)
        ])
      
      var predicates = [mainQueuePredicate, globalQueuePredicate].flatMap { base -> [ExprSyntaxPredicate] in
        return [
          .funcCall(asyncSignature, base: base),
          .funcCall(syncSignature, base: base),
          .funcCall(asyncAfterSignature, base: base)
        ]
      }
      
      if let basePredicate = basePredicate {
        predicates.append(contentsOf: [
          .funcCall(asyncSignature, base: .name(basePredicate)),
          .funcCall(syncSignature, base: .name(basePredicate)),
          .funcCall(asyncAfterSignature, base: .name(basePredicate)),
        ])
      }
      
      return predicates
    }()
  }
  
  public override func isNonEscape(arg: FunctionCallArgumentSyntax?,
                                   funcCallExpr: FunctionCallExprSyntax,
                                   graph: Graph) -> Bool {
    
    for predicate in predicates {
      if funcCallExpr.match(predicate) {
        return true
      }
    }
    
    return false
  }
}

