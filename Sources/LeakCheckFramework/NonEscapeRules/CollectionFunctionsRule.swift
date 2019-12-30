//
//  FPOperatorsRule.swift
//  LeakCheckFramework
//
//  Created by Hoang Le Pham on 29/10/2019.
//

import SwiftSyntax

/// Swift Collection functions like forEach, map, flatMap, sorted,....
public final class CollectionFunctionsRule: ComposeNonEscapeRule {
  
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

public final class SwiftForEachRule: BaseNonEscapeRule {
  public let mustBeCollection: Bool
  public init(mustBeCollection: Bool = false) {
    self.mustBeCollection = mustBeCollection
  }
  
  public override func isNonEscape(arg: FunctionCallArgumentSyntax?,
                                   funcCallExpr: FunctionCallExprSyntax,
                                   graph: Graph) -> Bool {
    
    let signature = FunctionSignature(name: "forEach", params: [
      FunctionParam(name: nil, isClosure: true)
      ])
    let base = ExprSyntaxPredicate { expr in
      return !self.mustBeCollection || isCollection(expr, graph: graph)
    }
    return funcCallExpr.match(.funcCall(signature, base: base))
  }
}

public final class SwiftCompactMapRule: BaseNonEscapeRule {
  public override func isNonEscape(arg: FunctionCallArgumentSyntax?,
                                   funcCallExpr: FunctionCallExprSyntax,
                                   graph: Graph) -> Bool {
    let signature = FunctionSignature(name: "compactMap", params: [
      FunctionParam(name: nil, isClosure: true)
      ])
    let base = ExprSyntaxPredicate { expr in
      return isCollection(expr, graph: graph)
    }
    return funcCallExpr.match(.funcCall(signature, base: base))
  }
}

public final class SwiftMapRule: BaseNonEscapeRule {
  public override func isNonEscape(arg: FunctionCallArgumentSyntax?,
                                   funcCallExpr: FunctionCallExprSyntax,
                                   graph: Graph) -> Bool {
    let signature = FunctionSignature(name: "map", params: [
      FunctionParam(name: nil, isClosure: true)
      ])
    let base = ExprSyntaxPredicate { expr in
      return isCollection(expr, graph: graph) || isOptional(expr, graph: graph)
    }
    return funcCallExpr.match(.funcCall(signature, base: base))
  }
}

public final class SwiftFlatMapRule: BaseNonEscapeRule {
  public override func isNonEscape(arg: FunctionCallArgumentSyntax?,
                                   funcCallExpr: FunctionCallExprSyntax,
                                   graph: Graph) -> Bool {
    let signature = FunctionSignature(name: "flatMap", params: [
      FunctionParam(name: nil, isClosure: true)
      ])
    let base = ExprSyntaxPredicate { expr in
      return isCollection(expr, graph: graph) || isOptional(expr, graph: graph)
    }
    return funcCallExpr.match(.funcCall(signature, base: base))
  }
}

public final class SwiftFilterRule: BaseNonEscapeRule {
  public override func isNonEscape(arg: FunctionCallArgumentSyntax?,
                                   funcCallExpr: FunctionCallExprSyntax,
                                   graph: Graph) -> Bool {
    let signature = FunctionSignature(name: "filter", params: [
      FunctionParam(name: nil, isClosure: true)
      ])
    let base = ExprSyntaxPredicate { expr in
      return isCollection(expr, graph: graph)
    }
    return funcCallExpr.match(.funcCall(signature, base: base))
  }
}

public final class SwiftSortRule: BaseNonEscapeRule {
  public override func isNonEscape(arg: FunctionCallArgumentSyntax?,
                                   funcCallExpr: FunctionCallExprSyntax,
                                   graph: Graph) -> Bool {
    let sortSignature = FunctionSignature(name: "sort", params: [
      FunctionParam(name: "by", isClosure: true)
      ])
    let sortedSignature = FunctionSignature(name: "sorted", params: [
      FunctionParam(name: "by", isClosure: true)
      ])
    let base = ExprSyntaxPredicate { expr in
      return isCollection(expr, graph: graph)
    }
    return funcCallExpr.match(.funcCall(sortSignature, base: base))
      || funcCallExpr.match(.funcCall(sortedSignature, base: base))
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
