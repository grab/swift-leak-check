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

public extension SyntaxProtocol {
  func isBefore(_ node: SyntaxProtocol) -> Bool {
    return positionAfterSkippingLeadingTrivia.utf8Offset < node.positionAfterSkippingLeadingTrivia.utf8Offset
  }
  
  func getEnclosingNode<T: SyntaxProtocol>(_ type: T.Type) -> T? {
    var parent = self.parent
    while parent != nil && parent!.is(type) == false {
      parent = parent?.parent
      if parent == nil { return nil }
    }
    return parent?.as(type)
  }
  
  func getEnclosingClosureNode() -> ClosureExprSyntax? {
    return getEnclosingNode(ClosureExprSyntax.self)
  }
}

extension Syntax {
  func isDescendent(of node: Syntax) -> Bool {
    return hasAncestor { $0 == node }
  }
  
  // TODO (Le): should we consider self as ancestor of self like this ?
  func hasAncestor(_ predicate: (Syntax) -> Bool) -> Bool {
    if predicate(self) { return true }
    var parent = self.parent
    while parent != nil {
      if predicate(parent!) {
        return true
      }
      parent = parent?.parent
    }
    return false
  }
}

public extension ExprSyntax {
  /// Returns the enclosing function call to which the current expr is passed as argument. We also return the corresponding
  /// argument of the current expr, or nil if current expr is trailing closure
  func getEnclosingFunctionCallExpression() -> (function: FunctionCallExprSyntax, argument: FunctionCallArgumentSyntax?)? {
    var function: FunctionCallExprSyntax?
    var argument: FunctionCallArgumentSyntax?
    
    if let parent = parent?.as(FunctionCallArgumentSyntax.self) { // Normal function argument
      assert(parent.parent?.is(FunctionCallArgumentListSyntax.self) == true)
      function = parent.parent?.parent?.as(FunctionCallExprSyntax.self)
      argument = parent
    } else if let parent = parent?.as(FunctionCallExprSyntax.self),
              self.is(ClosureExprSyntax.self),
              parent.trailingClosure == self.as(ClosureExprSyntax.self)
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
    if let parentNode = parent?.as(FunctionCallExprSyntax.self) {
      if parentNode.calledExpression == self {
        return true
      }
    }
    
    return false
  }
  
  var rangeInfo: (left: ExprSyntax?, op: TokenSyntax, right: ExprSyntax?)? {
    if let expr = self.as(SequenceExprSyntax.self) {
      let elements = expr.elements
      guard elements.count == 3, let op = elements[1].rangeOperator else {
        return nil
      }
      return (left: elements[elements.startIndex], op: op, right: elements[elements.index(before: elements.endIndex)])
    }
    
    if let expr = self.as(PostfixUnaryExprSyntax.self) {
      if expr.operatorToken.isRangeOperator {
        return (left: nil, op: expr.operatorToken, right: expr.expression)
      } else {
        return nil
      }
    }
    
    if let expr = self.as(PrefixOperatorExprSyntax.self) {
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
    guard let op = self.as(BinaryOperatorExprSyntax.self) else {
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
    return self.is(OptionalTypeSyntax.self) || self.is(ImplicitlyUnwrappedOptionalTypeSyntax.self)
  }
  
  var wrappedType: TypeSyntax {
    if let optionalType = self.as(OptionalTypeSyntax.self) {
      return optionalType.wrappedType
    }
    if let implicitOptionalType = self.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
      return implicitOptionalType.wrappedType
    }
    return self
  }
  
  var tokens: [TokenSyntax]? {
    if self == wrappedType {
      if let type = self.as(MemberTypeIdentifierSyntax.self) {
        if let base = type.baseType.tokens {
          return base + [type.name]
        }
        return nil
      }
      if let type = self.as(SimpleTypeIdentifierSyntax.self) {
        return [type.name]
      }
      return nil
    }
    return wrappedType.tokens
  }
  
  var name: [String]? {
    return tokens?.map { $0.text }
  }
  
  var isClosure: Bool {
    return wrappedType.is(FunctionTypeSyntax.self)
      || (wrappedType.as(AttributedTypeSyntax.self))?.baseType.isClosure == true
      || (wrappedType.as(TupleTypeSyntax.self)).flatMap { $0.elements.count == 1 && $0.elements[$0.elements.startIndex].type.isClosure } == true
  }
}

/// `gurad let a = b, ... `: `let a = b` is a OptionalBindingConditionSyntax
public extension OptionalBindingConditionSyntax {
  func isGuardCondition() -> Bool {
    return parent?.is(ConditionElementSyntax.self) == true
      && parent?.parent?.is(ConditionElementListSyntax.self) == true
      && parent?.parent?.parent?.is(GuardStmtSyntax.self) == true
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
    // base.symbol()
    if let memberAccessExpr = self.as(MemberAccessExprSyntax.self) {
      return (base: memberAccessExpr.base, symbol: memberAccessExpr.name)
    }
    
    // symbol()
    if let identifier = self.as(IdentifierExprSyntax.self) {
      return (base: nil, symbol: identifier.identifier)
    }
    
    // expr?.()
    if let optionalChainingExpr = self.as(OptionalChainingExprSyntax.self) {
      return optionalChainingExpr.expression.baseAndSymbol
    }
    
    // expr<T>()
    if let specializeExpr = self.as(SpecializeExprSyntax.self) {
      return specializeExpr.expression.baseAndSymbol
    }
    
    assert(false, "Unhandled case")
    return nil
  }
}

public extension FunctionParameterSyntax {
  var isEscaping: Bool {
    guard let attributedType = type?.as(AttributedTypeSyntax.self) else {
      return false
    }
    
    return attributedType.attributes?.contains(where: { $0.as(AttributeSyntax.self)?.attributeName.text == "escaping" }) == true
  }
}

/// Convenient
extension ArrayElementListSyntax {
  subscript(_ i: Int) -> ArrayElementSyntax {
    let index = self.index(startIndex, offsetBy: i)
    return self[index]
  }
}

extension FunctionCallArgumentListSyntax {
  subscript(_ i: Int) -> FunctionCallArgumentSyntax {
    let index = self.index(startIndex, offsetBy: i)
    return self[index]
  }
}

extension ExprListSyntax {
  subscript(_ i: Int) -> ExprSyntax {
    let index = self.index(startIndex, offsetBy: i)
    return self[index]
  }
}

extension PatternBindingListSyntax {
  subscript(_ i: Int) -> PatternBindingSyntax {
    let index = self.index(startIndex, offsetBy: i)
    return self[index]
  }
}

extension TupleTypeElementListSyntax {
  subscript(_ i: Int) -> TupleTypeElementSyntax {
    let index = self.index(startIndex, offsetBy: i)
    return self[index]
  }
}
