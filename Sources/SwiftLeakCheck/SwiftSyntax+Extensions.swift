//
//  SwiftSyntax+Extensions.swift
//  LeakCheck
//
//  Copyright 2020 Grabtaxi Holdings PTE LTE (GRAB), All rights reserved.
//  Use of this source code is governed by an MIT-style license that can be found in the LICENSE file
//
//  Created by Hoang Le Pham on 27/10/2019.
//

import SwiftSyntax

public extension Syntax {
  func isBefore(_ node: Syntax) -> Bool {
    return positionAfterSkippingLeadingTrivia.utf8Offset < node.positionAfterSkippingLeadingTrivia.utf8Offset
  }
  
  func isDescendent(of node: Syntax) -> Bool {
    if self == node { return true }
    var parent = self.parent
    while parent != nil {
      if parent! == node {
        return true
      }
      parent = parent?.parent
    }
    return false
  }
  
  func getEnclosingNodeByType<T>(_ type: T.Type) -> T? {
    var parent = self.parent
    while !(parent is T) {
      parent = parent?.parent
      if parent == nil { return nil }
    }
    return parent as? T
  }
  
  var enclosingtClosureNode: ClosureExprSyntax? {
    return getEnclosingNodeByType(ClosureExprSyntax.self)
  }
}

public extension ExprSyntax {
  /// Returns the enclosing function call to which the current expr is passed as argument. We also return the corresponding
  /// argument of the current expr, or nil if current expr is trailing closure
  func getEnclosingFunctionCallForArgument() -> (function: FunctionCallExprSyntax, argument: FunctionCallArgumentSyntax?)? {
    var function: FunctionCallExprSyntax?
    var argument: FunctionCallArgumentSyntax?
    
    if let parent = parent as? FunctionCallArgumentSyntax { // Normal function argument
      assert(parent.parent is FunctionCallArgumentListSyntax)
      function = parent.parent?.parent as? FunctionCallExprSyntax
      argument = parent
    } else if let parent = parent as? FunctionCallExprSyntax,
      self is ClosureExprSyntax,
      parent.trailingClosure == self as? ClosureExprSyntax
    { // Trailing closure
      function = parent
    }
    
    guard function != nil else {
      // Not function call
      return nil
    }
    
    return (function: function!, argument: argument)
  }
  
  func isCalledExpr() -> Bool {
    if let parentNode = parent as? FunctionCallExprSyntax {
      if parentNode.calledExpression == self {
        return true
      }
    }
    
    return false
  }
  
  var rangeInfo: (left: ExprSyntax?, op: TokenSyntax, right: ExprSyntax?)? {
    if let expr = self as? SequenceExprSyntax {
      guard expr.elements.count == 3, let op = expr.elements[1].rangeOperator else {
        return nil
      }
      return (left: expr.elements[0], op: op, right: expr.elements[2])
    }
    
    if let expr = self as? PostfixUnaryExprSyntax {
      if expr.operatorToken.isRangeOperator {
        return (left: nil, op: expr.operatorToken, right: expr.expression)
      } else {
        return nil
      }
    }
    
    if let expr = self as? PrefixOperatorExprSyntax {
      assert(expr.operatorToken != nil)
      if expr.operatorToken!.isRangeOperator {
        return (left: expr.postfixExpression, op: expr.operatorToken!, right: nil)
      } else {
        return nil
      }
    }
    
    return nil
  }
  
  private var rangeOperator: TokenSyntax? {
    guard let op = self as? BinaryOperatorExprSyntax else {
      return nil
    }
    return op.operatorToken.isRangeOperator ? op.operatorToken : nil
  }
}

public extension TokenSyntax {
  var isRangeOperator: Bool {
    return text == "..." || text == "..<"
  }
}

public extension TypeSyntax {
  var isOptional: Bool {
    return self is OptionalTypeSyntax || self is ImplicitlyUnwrappedOptionalTypeSyntax
  }
  
  var wrapped: TypeSyntax {
    if let optionalType = self as? OptionalTypeSyntax {
      return optionalType.wrappedType
    }
    if let implicitOptionalType = self as? ImplicitlyUnwrappedOptionalTypeSyntax {
      return implicitOptionalType.wrappedType
    }
    return self
  }
  
  var tokens: [TokenSyntax]? {
    if self == wrapped {
      if let type = self as? MemberTypeIdentifierSyntax {
        if let base = type.baseType.tokens {
          return base + [type.name]
        }
        return nil
      }
      if let type = self as? SimpleTypeIdentifierSyntax {
        return [type.name]
      }
      return nil
    }
    return wrapped.tokens
  }
}

public extension OptionalBindingConditionSyntax {
  func isGuardCondition() -> Bool {
    return parent is ConditionElementSyntax
      && parent?.parent is ConditionElementListSyntax
      && parent?.parent?.parent is GuardStmtSyntax
  }
}

public extension FunctionCallExprSyntax {
  var base: ExprSyntax? {
    return calledExpression.baseAndSymbol?.base
  }
  
  var symbol: TokenSyntax? {
    return calledExpression.baseAndSymbol?.symbol
  }
}

// Only used for the FunctionCallExprSyntax extension above
private extension ExprSyntax {
  var baseAndSymbol: (base: ExprSyntax?, symbol: TokenSyntax)? {
    if let identifier = self as? IdentifierExprSyntax {
      return (base: nil, symbol: identifier.identifier)
    }
    if let memberAccessExpr = self as? MemberAccessExprSyntax {
      return (base: memberAccessExpr.base, symbol: memberAccessExpr.name)
    }
    if let implicitMemberExpr = self as? ImplicitMemberExprSyntax {
      return (base: nil, symbol: implicitMemberExpr.name)
    }
    if let optionalChainingExpr = self as? OptionalChainingExprSyntax {
      return optionalChainingExpr.expression.baseAndSymbol
    }
    if self is SpecializeExprSyntax {
      return nil
    }
    assert(false, "Unhandled case")
    return nil
  }
}

public extension FunctionParameterSyntax {
  var isEscaping: Bool {
    guard let attributedType = type as? AttributedTypeSyntax else {
      return false
    }
    
    return attributedType.attributes?.contains(where: { $0.attributeName.text == "escaping" }) == true
  }
}

public extension AbsolutePosition {
  var prettyDescription: String {
    return "(line: \(line), column: \(column))"
  }
}
