//
//  CollectionRules.swift
//  SwiftLeakCheck
//
//  Copyright 2019 Grabtaxi Holdings PTE LTE (GRAB), All rights reserved.
//  Use of this source code is governed by an MIT-style license that can be found in the LICENSE file
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

open class CollectionForEachRule: BaseNonEscapeRule {
  public let mustBeCollection: Bool
  private let signature = FunctionSignature(name: "forEach", params: [
    FunctionParam(name: nil, isClosure: true)
    ])
  public init(mustBeCollection: Bool = false) {
    self.mustBeCollection = mustBeCollection
  }
  
  open override func isNonEscape(arg: FunctionCallArgumentSyntax?,
                                 funcCallExpr: FunctionCallExprSyntax,
                                 graph: Graph) -> Bool {
    return funcCallExpr.match(.funcCall(signature, base: .init { expr in
      return !self.mustBeCollection || isCollection(expr, graph: graph)
    }))
  }
}

open class CollectionCompactMapRule: BaseNonEscapeRule {
  private let signature = FunctionSignature(name: "compactMap", params: [
    FunctionParam(name: nil, isClosure: true)
    ])
  
  open override func isNonEscape(arg: FunctionCallArgumentSyntax?,
                                 funcCallExpr: FunctionCallExprSyntax,
                                 graph: Graph) -> Bool {
    return funcCallExpr.match(.funcCall(signature, base: .init { expr in
      return isCollection(expr, graph: graph)
    }))
  }
}

open class CollectionMapRule: BaseNonEscapeRule {
  private let signature = FunctionSignature(name: "map", params: [
    FunctionParam(name: nil, isClosure: true)
    ])
  
  open override func isNonEscape(arg: FunctionCallArgumentSyntax?,
                                 funcCallExpr: FunctionCallExprSyntax,
                                 graph: Graph) -> Bool {
    return funcCallExpr.match(.funcCall(signature, base: .init { expr in
      return isCollection(expr, graph: graph) || isOptional(expr, graph: graph)
    }))
  }
}

open class CollectionFlatMapRule: BaseNonEscapeRule {
  private let signature = FunctionSignature(name: "flatMap", params: [
    FunctionParam(name: nil, isClosure: true)
    ])
  
  open override func isNonEscape(arg: FunctionCallArgumentSyntax?,
                                 funcCallExpr: FunctionCallExprSyntax,
                                 graph: Graph) -> Bool {
    return funcCallExpr.match(.funcCall(signature, base: .init { expr in
      return isCollection(expr, graph: graph) || isOptional(expr, graph: graph)
    }))
  }
}

open class CollectionFilterRule: BaseNonEscapeRule {
  private let signature = FunctionSignature(name: "filter", params: [
    FunctionParam(name: nil, isClosure: true)
    ])
  
  open override func isNonEscape(arg: FunctionCallArgumentSyntax?,
                                 funcCallExpr: FunctionCallExprSyntax,
                                 graph: Graph) -> Bool {
    return funcCallExpr.match(.funcCall(signature, base: .init { expr in
      return isCollection(expr, graph: graph)
    }))
  }
}

open class CollectionSortRule: BaseNonEscapeRule {
  private let sortSignature = FunctionSignature(name: "sort", params: [
    FunctionParam(name: "by", isClosure: true)
    ])
  private let sortedSignature = FunctionSignature(name: "sorted", params: [
    FunctionParam(name: "by", isClosure: true)
    ])
  
  open override func isNonEscape(arg: FunctionCallArgumentSyntax?,
                                 funcCallExpr: FunctionCallExprSyntax,
                                 graph: Graph) -> Bool {
    return funcCallExpr.match(.funcCall(sortSignature, base: .init { return isCollection($0, graph: graph) }))
      || funcCallExpr.match(.funcCall(sortedSignature, base: .init { return isCollection($0, graph: graph) }))
  }
}

open class CollectionFirstWhereRule: BaseNonEscapeRule {
  private let firstWhereSignature = FunctionSignature(name: "first", params: [
    FunctionParam(name: "where", isClosure: true)
    ])
  private let firstIndexWhereSignature = FunctionSignature(name: "firstIndex", params: [
    FunctionParam(name: "where", isClosure: true)
    ])
  
  open override func isNonEscape(arg: FunctionCallArgumentSyntax?,
                                 funcCallExpr: FunctionCallExprSyntax,
                                 graph: Graph) -> Bool {
    let base = ExprSyntaxPredicate { expr in
      return isCollection(expr, graph: graph)
    }
    return funcCallExpr.match(.funcCall(firstWhereSignature, base: base))
      || funcCallExpr.match(.funcCall(firstIndexWhereSignature, base: base))
  }
}

open class CollectionContainsRule: BaseNonEscapeRule {
  let signature = FunctionSignature(name: "contains", params: [
    FunctionParam(name: "where", isClosure: true)
    ])
  
  open override func isNonEscape(arg: FunctionCallArgumentSyntax?,
                                 funcCallExpr: FunctionCallExprSyntax,
                                 graph: Graph) -> Bool {
    return funcCallExpr.match(.funcCall(signature, base: .init { expr in
      return isCollection(expr, graph: graph) }))
  }
}

open class CollectionMaxMinRule: BaseNonEscapeRule {
  private let maxSignature = FunctionSignature(name: "max", params: [
    FunctionParam(name: "by", isClosure: true)
    ])
  private let minSignature = FunctionSignature(name: "min", params: [
    FunctionParam(name: "by", isClosure: true)
    ])
  
  open override func isNonEscape(arg: FunctionCallArgumentSyntax?,
                                 funcCallExpr: FunctionCallExprSyntax,
                                 graph: Graph) -> Bool {
    return funcCallExpr.match(.funcCall(maxSignature, base: .init { return isCollection($0, graph: graph) }))
      || funcCallExpr.match(.funcCall(minSignature, base: .init { return isCollection($0, graph: graph) }))
  }
}

private func isCollection(_ expr: ExprSyntax?, graph: Graph) -> Bool {
  guard let expr = expr else {
    return false
  }
  return graph.isCollection(expr)
}

private func isOptional(_ expr: ExprSyntax?, graph: Graph) -> Bool {
  guard let expr = expr else {
    return false
  }
  return graph.resolveExprType(expr).isOptional
}
