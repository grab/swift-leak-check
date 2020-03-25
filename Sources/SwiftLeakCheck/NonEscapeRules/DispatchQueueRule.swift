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
  
  private let signatures: [FunctionSignature] = [
    FunctionSignature(name: "async", params: [
      FunctionParam(name: "group", canOmit: true),
      FunctionParam(name: "qos", canOmit: true),
      FunctionParam(name: "flags", canOmit: true),
      FunctionParam(name: "execute", isClosure: true)
    ]),
    FunctionSignature(name: "async", params: [
      FunctionParam(name: "group", canOmit: true),
      FunctionParam(name: "execute")
    ]),
    FunctionSignature(name: "sync", params: [
      FunctionParam(name: "flags", canOmit: true),
      FunctionParam(name: "execute", isClosure: true)
    ]),
    FunctionSignature(name: "sync", params: [
      FunctionParam(name: "execute")
    ]),
    FunctionSignature(name: "asyncAfter", params: [
      FunctionParam(name: "deadline"),
      FunctionParam(name: "qos", canOmit: true),
      FunctionParam(name: "flags", canOmit: true),
      FunctionParam(name: "execute", isClosure: true)
    ]),
    FunctionSignature(name: "asyncAfter", params: [
      FunctionParam(name: "wallDeadline"),
      FunctionParam(name: "qos", canOmit: true),
      FunctionParam(name: "flags", canOmit: true),
      FunctionParam(name: "execute", isClosure: true)
    ])
  ]
  
  private let mainQueuePredicate: ExprSyntaxPredicate = .memberAccess("main", base: .name("DispatchQueue"))
  private let globalQueuePredicate: ExprSyntaxPredicate = .funcCall(
    signature: FunctionSignature(name: "global", params: [.init(name: "qos", canOmit: true)]),
    base: .name("DispatchQueue")
  )
  
  
  open override func isNonEscape(arg: FunctionCallArgumentSyntax?,
                                 funcCallExpr: FunctionCallExprSyntax,
                                 graph: Graph) -> Bool {
    
    for signature in signatures {
      for queue in [mainQueuePredicate, globalQueuePredicate] {
        let predicate: ExprSyntaxPredicate = .funcCall(signature: signature, base: queue)
        if funcCallExpr.match(predicate) {
          return true
        }
      }
    }
    
    let isDispatchQueuePredicate: ExprSyntaxPredicate = .init { expr -> Bool in
      guard let expr = expr else { return false }
      let typeResolve = graph.resolveExprType(expr)
      switch typeResolve.wrappedType {
      case .name(let name):
        return self.isDispatchQueueType(name: name)
      case .type(let typeDecl):
        let allTypeDecls = graph.getAllTypeDeclarations(from: typeDecl)
        for typeDecl in allTypeDecls {
          if self.isDispatchQueueType(typeDecl: typeDecl) {
            return true
          }
        }
        
        return false
        
      case .dict,
           .sequence,
           .tuple,
           .optional, // Can't happen
           .unknown:
        return false
      }
    }
    
    for signature in signatures {
      let predicate: ExprSyntaxPredicate = .funcCall(signature: signature, base: isDispatchQueuePredicate)
      if funcCallExpr.match(predicate) {
        return true
      }
    }
    
    return false
  }
  
  private func isDispatchQueueType(name: [String]) -> Bool {
    return name.last == "DispatchQueue"
  }
  
  private func isDispatchQueueType(typeDecl: TypeDecl) -> Bool {
    if self.isDispatchQueueType(name: typeDecl.name) {
      return true
    }
    for inheritedType in (typeDecl.inheritanceTypes ?? []) {
      if self.isDispatchQueueType(name: inheritedType.typeName.name) {
        return true
      }
    }
    return false
  }
}

