//
//  ExprSyntaxPredicate.swift
//  LeakCheckFramework
//
//  Copyright 2019 Grabtaxi Holdings PTE LTE (GRAB), All rights reserved.
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
}

// MARK: - Identifier predicate
extension ExprSyntaxPredicate {
  public static func name(_ namePredicate: @escaping (String) -> Bool) -> ExprSyntaxPredicate {
    return .init({ expr -> Bool in
      guard let identifierExpr = expr as? IdentifierExprSyntax else {
        return false
      }
      return namePredicate(identifierExpr.identifier.text)
    })
  }
  
  public static func name(_ text: String) -> ExprSyntaxPredicate {
    return .name({ $0 == text })
  }
}

// MARK: - Function call predicate
extension ExprSyntaxPredicate {
  public static func funcCall(predicate: @escaping (FunctionCallExprSyntax) -> Bool) -> ExprSyntaxPredicate {
    return .init({ expr -> Bool in
      guard let funcCallExpr = expr as? FunctionCallExprSyntax else {
        return false
      }
      return predicate(funcCallExpr)
    })
  }
  
  public static func funcCall(_ namePredicate: @escaping (String) -> Bool,
                              base basePredicate: ExprSyntaxPredicate) -> ExprSyntaxPredicate {
    return .funcCall(predicate: { funcCallExpr -> Bool in
      guard let symbol = funcCallExpr.symbol else {
        return false
      }
      return namePredicate(symbol.text)
        && basePredicate.match(funcCallExpr.base)
    })
  }
  
  public static func funcCall(_ name: String,
                              base basePredicate: ExprSyntaxPredicate) -> ExprSyntaxPredicate {
    return .funcCall({ $0 == name }, base: basePredicate)
  }
  
  public static func funcCall(_ signature: FunctionSignature,
                              base basePredicate: ExprSyntaxPredicate) -> ExprSyntaxPredicate {
    return .funcCall(predicate: { funcCallExpr -> Bool in
      return signature.match(funcCallExpr).isMatched
        && basePredicate.match(funcCallExpr.base)
    })
  }
}

// MARK: - MemberAccess predicate
extension ExprSyntaxPredicate {
  public static func memberAccess(_ memberPredicate: @escaping (String) -> Bool,
                                  base basePredicate: ExprSyntaxPredicate) -> ExprSyntaxPredicate {
    return .init({ expr -> Bool in
      guard let memberAccessExpr = expr as? MemberAccessExprSyntax else {
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
