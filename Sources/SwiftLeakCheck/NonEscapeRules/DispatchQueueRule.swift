//
//  DispatchQueueRule.swift
//  SwiftLeakCheck
//
//  Copyright 2020 Grabtaxi Holdings PTE LTE (GRAB), All rights reserved.
//  Use of this source code is governed by an MIT-style license that can be found in the LICENSE file
//
//  Created by Hoang Le Pham on 28/10/2019.
//

import SwiftSyntax

open class DispatchQueueRule: BaseNonEscapeRule {
  
  private let predicates: [ExprSyntaxPredicate]
  
  public init(basePredicate: ((String) -> Bool)? = nil) {
    self.predicates = {
      let mainQueuePredicate: ExprSyntaxPredicate = .memberAccess("main", base: .name("DispatchQueue"))
      let globalQueuePredicate: ExprSyntaxPredicate = .funcCall(
        signature: FunctionSignature(name: "global", params: [.init(name: "qos", canOmit: true)]),
        base: .name("DispatchQueue")
      )
      
      let asyncSignature = FunctionSignature(name: "async", params: [
        FunctionParam(name: "execute", isClosure: true)
        ])
      let syncSignature = FunctionSignature(name: "sync", params: [
        FunctionParam(name: "execute", isClosure: true)
        ])
      let asyncAfterSignature = FunctionSignature(name: "asyncAfter", params: [
        FunctionParam(name: "deadline"),
        FunctionParam(name: "execute", isClosure: true)
        ])
      
      var predicates = [mainQueuePredicate, globalQueuePredicate].flatMap { base -> [ExprSyntaxPredicate] in
        return [
          .funcCall(signature: asyncSignature, base: base),
          .funcCall(signature: syncSignature, base: base),
          .funcCall(signature: asyncAfterSignature, base: base)
        ]
      }
      
      if let basePredicate = basePredicate {
        predicates.append(contentsOf: [
          .funcCall(signature: asyncSignature, base: .name(basePredicate)),
          .funcCall(signature: syncSignature, base: .name(basePredicate)),
          .funcCall(signature: asyncAfterSignature, base: .name(basePredicate)),
        ])
      }
      
      return predicates
    }()
  }
  
  open override func isNonEscape(arg: FunctionCallArgumentSyntax?,
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

