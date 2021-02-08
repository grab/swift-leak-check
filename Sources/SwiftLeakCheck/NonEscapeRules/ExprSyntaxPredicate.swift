//
//  ExprSyntaxPredicate.swift
//  SwiftLeakCheck
//
//  Copyright 2020 Grabtaxi Holdings PTE LTE (GRAB), All rights reserved.
//  Use of this source code is governed by an MIT-style license that can be found in the LICENSE file
//
//  Created by Hoang Le Pham on 26/12/2019.
//

import SwiftSyntax

open class ExprSyntaxPredicate {
  public let match: (ExprSyntax?) -> Bool
  public init(_ match: @escaping (ExprSyntax?) -> Bool) {
    self.match = match
  }
  
  public static let any: ExprSyntaxPredicate = .init { _ in true }
}

// MARK: - Identifier predicate
extension ExprSyntaxPredicate {
  public static func name(_ text: String) -> ExprSyntaxPredicate {
    return .name({ $0 == text })
  }
  
  public static func name(_ namePredicate: @escaping (String) -> Bool) -> ExprSyntaxPredicate {
    return .init({ expr -> Bool in
      guard let identifierExpr = expr?.as(IdentifierExprSyntax.self) else {
        return false
      }
      return namePredicate(identifierExpr.identifier.text)
    })
  }
}

// MARK: - Function call predicate
extension ExprSyntaxPredicate {
  public static func funcCall(name: String,
                              base basePredicate: ExprSyntaxPredicate) -> ExprSyntaxPredicate {
    return .funcCall(namePredicate: { $0 == name }, base: basePredicate)
  }
  
  public static func funcCall(namePredicate: @escaping (String) -> Bool,
                              base basePredicate: ExprSyntaxPredicate) -> ExprSyntaxPredicate {
    return .funcCall(predicate: { funcCallExpr -> Bool in
      guard let symbol = funcCallExpr.symbol else {
        return false
      }
      return namePredicate(symbol.text)
        && basePredicate.match(funcCallExpr.base)
    })
  }
  
  public static func funcCall(signature: FunctionSignature,
                              base basePredicate: ExprSyntaxPredicate) -> ExprSyntaxPredicate {
    return .funcCall(predicate: { funcCallExpr -> Bool in
      return signature.match(funcCallExpr).isMatched
        && basePredicate.match(funcCallExpr.base)
    })
  }
  
  public static func funcCall(predicate: @escaping (FunctionCallExprSyntax) -> Bool) -> ExprSyntaxPredicate {
    return .init({ expr -> Bool in
      guard let funcCallExpr = expr?.as(FunctionCallExprSyntax.self) else {
        return false
      }
      return predicate(funcCallExpr)
    })
  }
}

// MARK: - MemberAccess predicate
extension ExprSyntaxPredicate {
  public static func memberAccess(_ memberPredicate: @escaping (String) -> Bool,
                                  base basePredicate: ExprSyntaxPredicate) -> ExprSyntaxPredicate {
    return .init({ expr -> Bool in
      guard let memberAccessExpr = expr?.as(MemberAccessExprSyntax.self) else {
        return false
      }
      return memberPredicate(memberAccessExpr.name.text)
        && basePredicate.match(memberAccessExpr.base)
    })
  }
  
  public static func memberAccess(_ member: String, base basePredicate: ExprSyntaxPredicate) -> ExprSyntaxPredicate {
    return .memberAccess({ $0 == member }, base: basePredicate)
  }
}

public extension ExprSyntax {
  
  func match(_ predicate: ExprSyntaxPredicate) -> Bool {
    return predicate.match(self)
  }
}

// Convenient
public extension FunctionCallExprSyntax {
  func match(_ predicate: ExprSyntaxPredicate) -> Bool {
    return predicate.match(ExprSyntax(self))
  }
}
