//
//  Function.swift
//  SwiftLeakCheck
//
//  Copyright 2020 Grabtaxi Holdings PTE LTE (GRAB), All rights reserved.
//  Use of this source code is governed by an MIT-style license that can be found in the LICENSE file
//
//  Created by Hoang Le Pham on 18/11/2019.
//

import SwiftSyntax

public typealias Function = FunctionDeclSyntax

public extension Function {
  enum MatchResult: Equatable {
    public struct MappingInfo: Equatable {
      let argumentToParamMapping: [FunctionCallArgumentSyntax: FunctionParameterSyntax]
      let trailingClosureArgumentToParam: FunctionParameterSyntax?
    }
    
    case nameMismatch
    case argumentMismatch
    case matched(MappingInfo)
    
    var isMatched: Bool {
      switch self {
      case .nameMismatch,
           .argumentMismatch:
        return false
      case .matched:
        return true
      }
    }
  }
  
  func match(_ functionCallExpr: FunctionCallExprSyntax) -> MatchResult {
    let (signature, mapping) = FunctionSignature.from(functionDeclExpr: self)
    switch signature.match(functionCallExpr) {
    case .nameMismatch:
      return .nameMismatch
    case .argumentMismatch:
      return .argumentMismatch
    case .matched(let matchedInfo):
      return .matched(.init(
        argumentToParamMapping: matchedInfo.argumentToParamMapping.mapValues { mapping[$0]! },
        trailingClosureArgumentToParam: matchedInfo.trailingClosureArgumentToParam.flatMap { mapping[$0] }))
    }
  }
}
