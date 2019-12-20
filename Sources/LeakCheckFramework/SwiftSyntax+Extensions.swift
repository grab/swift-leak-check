//
//  SwiftSyntax+Extensions.swift
//  LeakCheck
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
  func isArgumentInFunctionCall(functionNamePredicate: (String) -> Bool,
                                argumentNamePredicate: (String?) -> Bool,
                                calledExprPredicate: (ExprSyntax?) -> Bool) -> Bool {
    guard let (functionCall, argument, isTrailing) = getArgumentInfoInFunctionCall() else {
      // Not argument in function call
      return false
    }
    
    if !isTrailing {
      if !argumentNamePredicate(argument?.label?.text) {
        return false
      }
    }
    
    if let identifier = functionCall.calledExpression as? IdentifierExprSyntax {
      return functionNamePredicate(identifier.identifier.text)
        && calledExprPredicate(nil)
    } else if let memberAccessExpr = functionCall.calledExpression as? MemberAccessExprSyntax {
      return functionNamePredicate(memberAccessExpr.name.text)
        && calledExprPredicate(memberAccessExpr.base)
    }
    
    return false
  }
  
  func getArgumentInfoInFunctionCall() -> (function: FunctionCallExprSyntax, argument: FunctionCallArgumentSyntax?, isTrailing: Bool)? {
    var function: FunctionCallExprSyntax?
    var argument: FunctionCallArgumentSyntax?
    var isTrailing = false
    
    if let parent = parent as? FunctionCallArgumentSyntax { // Normal function argument
      assert(parent.parent is FunctionCallArgumentListSyntax)
      function = parent.parent?.parent as? FunctionCallExprSyntax
      argument = parent
    } else if let parent = parent as? FunctionCallExprSyntax { // Trailing closure
      function = parent
      isTrailing = true
      assert(self is ClosureExprSyntax)
      assert(function?.trailingClosure == self as? ClosureExprSyntax)
    }
    
    guard function != nil else {
      // Not function call
      return nil
    }
    
    return (function: function!, argument: argument, isTrailing: isTrailing)
  }
  
  // Eg: the closure below is in FunctionCallExpr
  // let x = {
  // ...
  // }()
  func isFunctionCallExpr() -> Bool {
    if let parentNode = parent as? FunctionCallExprSyntax {
      if parentNode.calledExpression == self {
        return true
      }
    }
    
    return false
  }
  
  var rangeInfo: (left: ExprSyntax?, op: TokenSyntax, right: ExprSyntax?)? {
    if let tuple = self as? TupleExprSyntax {
      guard tuple.elementList.count == 1 else {
        return nil
      }
      return tuple.elementList[0].expression.rangeInfo
    }
    
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
  
  var isRange: Bool {
    return rangeInfo != nil
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

public extension MemberAccessExprSyntax {

  /// Eg: match("DispatchQueue.main.async")
  func match(_ pattern: String) -> Bool {
    let components = pattern.components(separatedBy: ".")
    return match(components)
  }
  
  private func match(_ components: [String]) -> Bool {
    assert(components.count > 0)
    if name.text != components.last {
      return false
    }
    
    if components.count == 1 {
      return base == nil
    } else if components.count == 2 {
      return (base as? IdentifierExprSyntax)?.identifier.text == components[0]
    } else {
      return (base as? MemberAccessExprSyntax)?.match(Array(components.dropLast())) == true
    }
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
  var baseAndSymbol: (base: ExprSyntax?, symbol: TokenSyntax)? {
    return calledExpression.baseAndSymbol
  }
}
// Only used for the FunctionCallExprSyntax extension above
private extension ExprSyntax {
  var baseAndSymbol: (base: ExprSyntax?, symbol: TokenSyntax)? {
    if let identifier = self as? IdentifierExprSyntax {
      return (base: nil, symbol: identifier.identifier)
    }
    if let memberAccessExpr = self as? MemberAccessExprSyntax {
      return (base: (memberAccessExpr.base as? IdentifierExprSyntax),
              symbol: memberAccessExpr.name)
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
    assert(false, "Not sure how it looks like")
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
