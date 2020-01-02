//
//  FunctionSignature.swift
//  LeakCheckFramework
//
//  Copyright 2019 Grabtaxi Holdings PTE LTE (GRAB), All rights reserved.
//  Use of this source code is governed by an MIT-style license that can be found in the LICENSE file
//
//  Created by Hoang Le Pham on 15/12/2019.
//

import SwiftSyntax

public struct FunctionSignature {
  public let funcName: String
  public let params: [FunctionParam]
  
  public init(name: String, params: [FunctionParam]) {
    self.funcName = name
    self.params = params
  }
  
  public static func from(functionDeclExpr: FunctionDeclSyntax) -> (FunctionSignature, [FunctionParam: FunctionParameterSyntax]) {
    let funcName = functionDeclExpr.identifier.text
    let params = functionDeclExpr.signature.input.parameterList.map { FunctionParam(param: $0) }
    let mapping = Dictionary(uniqueKeysWithValues: zip(params, functionDeclExpr.signature.input.parameterList))
    return (FunctionSignature(name: funcName, params: params), mapping)
  }
  
  public enum MatchResult: Equatable {
    public struct MappingInfo: Equatable {
      let argumentToParamMapping: [FunctionCallArgumentSyntax: FunctionParam]
      let trailingClosureArgumentToParam: FunctionParam?
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
  
  public func match(_ functionCallExpr: FunctionCallExprSyntax) -> MatchResult {
    guard funcName == functionCallExpr.symbol?.text else {
      return .nameMismatch
    }
    return match((ArgumentListWrapper(functionCallExpr.argumentList), functionCallExpr.trailingClosure))
  }
  
  private func match(_ rhs: (ArgumentListWrapper, ClosureExprSyntax?)) -> MatchResult {
    let (arguments, trailingClosure) = rhs
    
    guard params.count > 0 else {
      if arguments.count == 0 && trailingClosure == nil {
        return .matched(.init(argumentToParamMapping: [:], trailingClosureArgumentToParam: nil))
      } else {
        return .argumentMismatch
      }
    }
    
    let firstParam = params[0]
    if firstParam.canOmit {
      let matchResult = removingFirstParam().match(rhs)
      if matchResult.isMatched {
        return matchResult
      }
    }
    
    guard arguments.count > 0 else {
      // In order to match, trailingClosure must be firstParam, there're no more params
      guard let trailingClosure = trailingClosure else {
        return .argumentMismatch
      }
      if params.count > 1 {
        return .argumentMismatch
      }
      if isMatched(param: firstParam, trailingClosure: trailingClosure) {
        return .matched(.init(argumentToParamMapping: [:], trailingClosureArgumentToParam: firstParam))
      } else {
        return .argumentMismatch
      }
    }
    
    let firstArgument = arguments[0]
    guard isMatched(param: firstParam, argument: firstArgument) else {
      return .argumentMismatch
    }
    
    let matchResult = removingFirstParam().match((arguments.removingFirst(), trailingClosure))
    if case let .matched(matchInfo) = matchResult {
      var argumentToParamMapping = matchInfo.argumentToParamMapping
      argumentToParamMapping[firstArgument] = firstParam
      return .matched(.init(argumentToParamMapping: argumentToParamMapping, trailingClosureArgumentToParam: matchInfo.trailingClosureArgumentToParam))
    } else {
      return .argumentMismatch
    }
  }
  
  // TODO: type matching
  private func isMatched(param: FunctionParam, argument: FunctionCallArgumentSyntax) -> Bool {
    return param.name == argument.label?.text
  }
  
  // TODO: may be compare other stuffs like closure param type and return type
  private func isMatched(param: FunctionParam, trailingClosure: ClosureExprSyntax) -> Bool {
    return param.isClosure
  }
  
  private func removingFirstParam() -> FunctionSignature {
    return FunctionSignature(name: funcName, params: Array(params[1...]))
  }
}

public struct FunctionParam: Hashable {
  public let name: String?
  public let secondName: String? // This acts as a way to differentiate param when name is omitted. Don't remove this
  public let canOmit: Bool
  public let isClosure: Bool
  
  public init(name: String?,
              secondName: String? = nil,
              isClosure: Bool = false,
              canOmit: Bool = false) {
    assert(name != "_")
    self.name = name
    self.secondName = secondName
    self.isClosure = isClosure
    self.canOmit = canOmit
  }
  
  public init(param: FunctionParameterSyntax) {
    name = (param.firstName?.text == "_" ? nil : param.firstName?.text)
    secondName = param.secondName?.text
    isClosure = param.type is FunctionTypeSyntax
      || (param.type as? AttributedTypeSyntax)?.baseType is FunctionTypeSyntax
    canOmit = param.defaultArgument != nil
  }
}

private struct ArgumentListWrapper {
  let argumentList: FunctionCallArgumentListSyntax
  private let startIndex: Int
  
  init(_ argumentList: FunctionCallArgumentListSyntax) {
    self.init(argumentList, startIndex: 0)
  }
  
  private init(_ argumentList: FunctionCallArgumentListSyntax, startIndex: Int) {
    self.argumentList = argumentList
    self.startIndex = startIndex
  }
  
  func removingFirst() -> ArgumentListWrapper {
    return ArgumentListWrapper(argumentList, startIndex: startIndex + 1)
  }
  
  subscript(_ i: Int) -> FunctionCallArgumentSyntax {
    return argumentList[startIndex + i]
  }
  
  var count: Int {
    return argumentList.count - startIndex
  }
}
