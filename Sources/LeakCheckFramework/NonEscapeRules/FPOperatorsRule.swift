//
//  FPOperatorsRule.swift
//  LeakCheckFramework
//
//  Created by Hoang Le Pham on 29/10/2019.
//

import SwiftSyntax

/// Functional programming rules like forEach, map, flatMap,...
public final class FPOperatorsRule: ComposeNonEscapeRule {
  
  public init() {
    super.init(rules: [
      SwiftForEachRule(),
      SwiftCompactMapRule(),
      SwiftMapRule(),
      SwiftFilterRule(),
      SwiftSortRule(),
      SwiftFlatMapRule()
    ])
  }
}

public final class SwiftForEachRule: NonEscapeRule {
  public func isNonEscape(closureNode: ExprSyntax, graph: Graph) -> Bool {
    guard let (funcCallExpr, arg, isTrailing) = closureNode.getArgumentInfoInFunctionCall() else {
      return false
    }
    
    guard let (_, functionName) = funcCallExpr.baseAndSymbol.flatMap({ ($0.0, $0.1.text) }),
      functionName == "forEach",
      funcCallExpr.argumentList.count == 0,
      isTrailing else {
        return false
    }
    
    return true
  }
}

public final class SwiftCompactMapRule: NonEscapeRule {
  public func isNonEscape(closureNode: ExprSyntax, graph: Graph) -> Bool {
    return closureNode.isArgumentInFunctionCall(
      functionNamePredicate: { $0 == "compactMap" },
      argumentNamePredicate: { $0 == "" }, // Swift's Collection compactMap func doesn't have argument name
      calledExprPredicate: { isCollection($0, graph: graph) }
    )
  }
}

public final class SwiftMapRule: NonEscapeRule {
  public func isNonEscape(closureNode: ExprSyntax, graph: Graph) -> Bool {
    return closureNode.isArgumentInFunctionCall(
      functionNamePredicate: { $0 == "map" },
      argumentNamePredicate: { $0 == "" }, // Swift's Collection/Optional map func doesn't have argument name
      calledExprPredicate: { isCollection($0, graph: graph) || isOptional($0, graph: graph) }
    )
  }
}

public final class SwiftFlatMapRule: NonEscapeRule {
  public func isNonEscape(closureNode: ExprSyntax, graph: Graph) -> Bool {
    return closureNode.isArgumentInFunctionCall(
      functionNamePredicate: { $0 == "flatMap" },
      argumentNamePredicate: { $0 == "" }, // Swift's Collection/Optional flatMap func doesn't have argument name
      calledExprPredicate: { isCollection($0, graph: graph) || isOptional($0, graph: graph) }
    )
  }
}

public final class SwiftFilterRule: NonEscapeRule {
  public func isNonEscape(closureNode: ExprSyntax, graph: Graph) -> Bool {
    return closureNode.isArgumentInFunctionCall(
      functionNamePredicate: { $0 == "filter" },
      argumentNamePredicate: { $0 == "" }, // Swift's Collection filter func doesn't have argument name
      calledExprPredicate: { isCollection($0, graph: graph) }
    )
  }
}

public final class SwiftSortRule: NonEscapeRule {
  public func isNonEscape(closureNode: ExprSyntax, graph: Graph) -> Bool {
    return closureNode.isArgumentInFunctionCall(
      functionNamePredicate: { $0 == "sort" },
      argumentNamePredicate: { $0 == "" }, // Swift's Collection sort func doesn't have argument name
      calledExprPredicate: { isCollection($0, graph: graph) }
    )
  }
}

private func isCollection(_ node: ExprSyntax?, graph: Graph) -> Bool {
  guard let node = node else {
    return false
  }
  return graph.isCollection(node)
}

private func isOptional(_ node: ExprSyntax?, graph: Graph) -> Bool {
  guard let node = node else {
    return false
  }
  return graph.isOptional(node)
}
