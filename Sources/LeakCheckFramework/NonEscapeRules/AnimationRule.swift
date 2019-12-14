//
//  AnimationRule.swift
//  LeakCheckFramework
//
//  Created by Hoang Le Pham on 28/10/2019.
//

import SwiftSyntax

/// Eg, UIView.animate(..., animations: {...}) {
///   .....
/// }
public final class AnimationRule: NonEscapeRule {
  
  public init() {}
  
  public func isNonEscape(closureNode: ExprSyntax) -> Bool {
    guard let (funcCallExpr, arg, isTrailing) = closureNode.getArgumentInfoInFunctionCall() else {
      return false
    }
    
    let (base, functionName) = funcCallExpr.baseAndSymbol
    guard base == "UIView" else {
      return false
    }
    
    guard isTrailing || arg?.label?.text == "animations" || arg?.label?.text == "completion" else {
      return false
    }
    
    if functionName == "animate" {
      let signature1 = FunctionSignature(
        name: functionName,
        params: [
          FunctionParam(name: "withDuration"),
          FunctionParam(name: "animations", isClosure: true)
        ])
      
      let signature2 = FunctionSignature(
        name: functionName,
        params: [
          FunctionParam(name: "withDuration"),
          FunctionParam(name: "animations", isClosure: true),
          FunctionParam(name: "completion", isClosure: true, canOmit: true)
        ])
      
      let signature3 = FunctionSignature(
        name: functionName,
        params: [
          FunctionParam(name: "withDuration"),
          FunctionParam(name: "delay"),
          FunctionParam(name: "options", canOmit: true),
          FunctionParam(name: "animations", isClosure: true),
          FunctionParam(name: "completion", isClosure: true, canOmit: true)
        ])
      let signature4 = FunctionSignature(
        name: functionName,
        params: [
          FunctionParam(name: "withDuration"),
          FunctionParam(name: "delay"),
          FunctionParam(name: "usingSpringWithDamping"),
          FunctionParam(name: "initialSpringVelocity"),
          FunctionParam(name: "options", canOmit: true),
          FunctionParam(name: "animations", isClosure: true),
          FunctionParam(name: "completion", isClosure: true, canOmit: true)
        ])
      
      return
        signature1.match(funcCallExpr).isMatched
        || signature2.match(funcCallExpr).isMatched
        || signature3.match(funcCallExpr).isMatched
        || signature4.match(funcCallExpr).isMatched
    }
    
    if functionName == "transition" {
      let signature1 = FunctionSignature(
        name: functionName,
        params: [
          FunctionParam(name: "from"),
          FunctionParam(name: "to"),
          FunctionParam(name: "duration"),
          FunctionParam(name: "options"),
          FunctionParam(name: "completion", isClosure: true, canOmit: true),
        ])
      
      let signature2 = FunctionSignature(
        name: functionName,
        params: [
          FunctionParam(name: "with"),
          FunctionParam(name: "duration"),
          FunctionParam(name: "options"),
          FunctionParam(name: "animations", isClosure: true, canOmit: true),
          FunctionParam(name: "completion", isClosure: true, canOmit: true),
        ])
      
      return signature1.match(funcCallExpr).isMatched || signature2.match(funcCallExpr).isMatched
    }
    
    if functionName == "animateKeyframes" {
      let signature = FunctionSignature(
        name: functionName,
        params: [
          FunctionParam(name: "withDuration"),
          FunctionParam(name: "delay", canOmit: true),
          FunctionParam(name: "options", canOmit: true),
          FunctionParam(name: "animations", isClosure: true),
          FunctionParam(name: "completion", isClosure: true)
        ])
      
      return signature.match(funcCallExpr).isMatched
    }
    return false
  }
}
