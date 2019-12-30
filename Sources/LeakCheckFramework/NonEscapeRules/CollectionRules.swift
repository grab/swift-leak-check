//
//  CollectionRules.swift
//  LeakCheckFramework
//
//  Created by Hoang Le Pham on 29/10/2019.
//

import SwiftSyntax

/// Swift Collection functions like forEach, map, flatMap, sorted,....
public enum CollectionRules {
  
  public private(set) static var rules: [NonEscapeRule] = {
    return [
      CollectionForEachRule(),
      CollectionCompactMapRule(),
      CollectionMapRule(),
      CollectionFilterRule(),
      CollectionSortRule(),
      CollectionFlatMapRule(),
      CollectionFirstWhereRule(),
      CollectionContainsRule(),
      CollectionMaxMinRule()
    ]
  }()
}

public final class CollectionForEachRule: BaseNonEscapeRule {
  public let mustBeCollection: Bool
  private let signature = FunctionSignature(name: "forEach", params: [
    FunctionParam(name: nil, isClosure: true)
    ])
  public init(mustBeCollection: Bool = false) {
    self.mustBeCollection = mustBeCollection
  }
  
  public override func isNonEscape(arg: FunctionCallArgumentSyntax?,
                                   funcCallExpr: FunctionCallExprSyntax,
                                   graph: Graph) -> Bool {
    return funcCallExpr.match(.funcCall(signature, base: .init { expr in
      return !self.mustBeCollection || isCollection(expr, graph: graph)
    }))
  }
}

public final class CollectionCompactMapRule: BaseNonEscapeRule {
  private let signature = FunctionSignature(name: "compactMap", params: [
    FunctionParam(name: nil, isClosure: true)
    ])
  
  public override func isNonEscape(arg: FunctionCallArgumentSyntax?,
                                   funcCallExpr: FunctionCallExprSyntax,
                                   graph: Graph) -> Bool {
    return funcCallExpr.match(.funcCall(signature, base: .init { expr in
      return isCollection(expr, graph: graph)
    }))
  }
}

public final class CollectionMapRule: BaseNonEscapeRule {
  private let signature = FunctionSignature(name: "map", params: [
    FunctionParam(name: nil, isClosure: true)
    ])
  
  public override func isNonEscape(arg: FunctionCallArgumentSyntax?,
                                   funcCallExpr: FunctionCallExprSyntax,
                                   graph: Graph) -> Bool {
    return funcCallExpr.match(.funcCall(signature, base: .init { expr in
      return isCollection(expr, graph: graph) || isOptional(expr, graph: graph)
    }))
  }
}

public final class CollectionFlatMapRule: BaseNonEscapeRule {
  private let signature = FunctionSignature(name: "flatMap", params: [
    FunctionParam(name: nil, isClosure: true)
    ])
  
  public override func isNonEscape(arg: FunctionCallArgumentSyntax?,
                                   funcCallExpr: FunctionCallExprSyntax,
                                   graph: Graph) -> Bool {
    return funcCallExpr.match(.funcCall(signature, base: .init { expr in
      return isCollection(expr, graph: graph) || isOptional(expr, graph: graph)
    }))
  }
}

public final class CollectionFilterRule: BaseNonEscapeRule {
  private let signature = FunctionSignature(name: "filter", params: [
    FunctionParam(name: nil, isClosure: true)
    ])
  
  public override func isNonEscape(arg: FunctionCallArgumentSyntax?,
                                   funcCallExpr: FunctionCallExprSyntax,
                                   graph: Graph) -> Bool {
    return funcCallExpr.match(.funcCall(signature, base: .init { expr in
      return isCollection(expr, graph: graph)
    }))
  }
}

public final class CollectionSortRule: BaseNonEscapeRule {
  private let sortSignature = FunctionSignature(name: "sort", params: [
    FunctionParam(name: "by", isClosure: true)
    ])
  private let sortedSignature = FunctionSignature(name: "sorted", params: [
    FunctionParam(name: "by", isClosure: true)
    ])
  
  public override func isNonEscape(arg: FunctionCallArgumentSyntax?,
                                   funcCallExpr: FunctionCallExprSyntax,
                                   graph: Graph) -> Bool {
    return funcCallExpr.match(.funcCall(sortSignature, base: .init { return isCollection($0, graph: graph) }))
      || funcCallExpr.match(.funcCall(sortedSignature, base: .init { return isCollection($0, graph: graph) }))
  }
}

public final class CollectionFirstWhereRule: BaseNonEscapeRule {
  private let firstWhereSignature = FunctionSignature(name: "first", params: [
    FunctionParam(name: "where", isClosure: true)
    ])
  private let firstIndexWhereSignature = FunctionSignature(name: "firstIndex", params: [
    FunctionParam(name: "where", isClosure: true)
    ])
  
  public override func isNonEscape(arg: FunctionCallArgumentSyntax?,
                                   funcCallExpr: FunctionCallExprSyntax,
                                   graph: Graph) -> Bool {
    let base = ExprSyntaxPredicate { expr in
      return isCollection(expr, graph: graph)
    }
    return funcCallExpr.match(.funcCall(firstWhereSignature, base: base))
      || funcCallExpr.match(.funcCall(firstIndexWhereSignature, base: base))
  }
}

public final class CollectionContainsRule: BaseNonEscapeRule {
  let signature = FunctionSignature(name: "contains", params: [
    FunctionParam(name: "where", isClosure: true)
    ])
  
  public override func isNonEscape(arg: FunctionCallArgumentSyntax?,
                                   funcCallExpr: FunctionCallExprSyntax,
                                   graph: Graph) -> Bool {
    return funcCallExpr.match(.funcCall(signature, base: .init { expr in
      return isCollection(expr, graph: graph) }))
  }
}

public final class CollectionMaxMinRule: BaseNonEscapeRule {
  private let maxSignature = FunctionSignature(name: "max", params: [
    FunctionParam(name: "by", isClosure: true)
    ])
  private let minSignature = FunctionSignature(name: "min", params: [
    FunctionParam(name: "by", isClosure: true)
    ])
  
  public override func isNonEscape(arg: FunctionCallArgumentSyntax?,
                                   funcCallExpr: FunctionCallExprSyntax,
                                   graph: Graph) -> Bool {
    return funcCallExpr.match(.funcCall(maxSignature, base: .init { return isCollection($0, graph: graph) }))
      || funcCallExpr.match(.funcCall(minSignature, base: .init { return isCollection($0, graph: graph) }))
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
