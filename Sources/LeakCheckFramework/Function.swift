//
//  Function.swift
//  LeakCheckFramework
//
//  Created by Hoang Le Pham on 18/11/2019.
//

import SwiftSyntax

// TODO (Le):
// 1. Consider renaming to FunctionMatcher
// 2. How about Closure ?
public final class Function {
  let node: FunctionDeclSyntax
  
  enum MatchResult: Equatable {
    struct MatchedInfo: Equatable {
      let argumentToParamMapping: [FunctionCallArgumentSyntax: FunctionParameterSyntax]
      let trailingClosureParam: FunctionParameterSyntax?
    }
    
    case nameMismatch
    case argumentMismatch
    case matched(MatchedInfo)
    
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
  
  init(node: FunctionDeclSyntax) {
    self.node = node
  }
  
  func match(_ expr: FunctionCallExprSyntax) -> MatchResult {
    let (signature, mapping) = FunctionSignature.from(functionDeclExpr: node)
    switch signature.match(expr) {
    case .nameMismatch:
      return .nameMismatch
    case .argumentMismatch:
      return .argumentMismatch
    case .matched(let matchedInfo):
      return .matched(.init(
        argumentToParamMapping: matchedInfo.argumentToParamMapping.mapValues { mapping[$0]! },
        trailingClosureParam: matchedInfo.trailingClosureParam.flatMap { mapping[$0] }))
    }
  }
}

struct FunctionParam: Hashable {
  let name: String?
  let secondName: String? // This acts as a way to differentiate param when name is omitted. Don't remove this
  let isClosure: Bool
  let canOmit: Bool
  
  init(name: String?,
       secondName: String? = nil,
       isClosure: Bool = false,
       canOmit: Bool = false) {
    self.name = name
    self.secondName = secondName
    self.isClosure = isClosure
    self.canOmit = canOmit
  }
  
  init(param: FunctionParameterSyntax) {
    name = param.firstName?.text
    secondName = param.secondName?.text
    isClosure = param.type is FunctionTypeSyntax
      || (param.type as? AttributedTypeSyntax)?.baseType is FunctionTypeSyntax
    canOmit = param.defaultArgument != nil
  }
}

struct FunctionSignature {
  let name: String
  let params: [FunctionParam]
  
  init(name: String, params: [FunctionParam]) {
    self.name = name
    self.params = params
  }
  
  static func from(functionDeclExpr: FunctionDeclSyntax) -> (FunctionSignature, [FunctionParam: FunctionParameterSyntax]) {
    let functionName = functionDeclExpr.identifier.text
    let params = functionDeclExpr.signature.input.parameterList.map { FunctionParam(param: $0) }
    let mapping = Dictionary(uniqueKeysWithValues: zip(params, functionDeclExpr.signature.input.parameterList))
    return (FunctionSignature(name: functionName, params: params), mapping)
  }
  
  enum MatchResult: Equatable {
    struct MatchedInfo: Equatable {
      let argumentToParamMapping: [FunctionCallArgumentSyntax: FunctionParam]
      let trailingClosureParam: FunctionParam?
    }
    
    case nameMismatch
    case argumentMismatch
    case matched(MatchedInfo)
    
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
    guard name == functionCallExpr.baseAndSymbol.symbol else {
      return .nameMismatch
    }
    return match((ArgumentListWrapper(functionCallExpr.argumentList), functionCallExpr.trailingClosure))
  }
  
  private func match(_ rhs: (ArgumentListWrapper, ClosureExprSyntax?)) -> MatchResult {
    let (arguments, trailingClosure) = rhs
    
    guard params.count > 0 else {
      if arguments.count == 0 && trailingClosure == nil {
        return .matched(.init(argumentToParamMapping: [:], trailingClosureParam: nil))
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
        return .matched(.init(argumentToParamMapping: [:], trailingClosureParam: firstParam))
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
      return .matched(.init(argumentToParamMapping: argumentToParamMapping, trailingClosureParam: matchInfo.trailingClosureParam))
    } else {
      return .argumentMismatch
    }
  }
  
  // TODO (Le): type matching
  private func isMatched(param: FunctionParam, argument: FunctionCallArgumentSyntax) -> Bool {
    return param.name == argument.label?.text
  }
  
  // TODO (Le): may be compare other stuffs like closure param type and return type
  private func isMatched(param: FunctionParam, trailingClosure: ClosureExprSyntax) -> Bool {
    return param.isClosure
  }
  
  private func removingFirstParam() -> FunctionSignature {
    return FunctionSignature(name: name, params: Array(params[1...]))
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
