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
public final class AnimationRule: BaseNonEscapeRule {
  
  private let signatures: [FunctionSignature] = [
    FunctionSignature(name: "animate", params: [
      FunctionParam(name: "withDuration"),
      FunctionParam(name: "animations", isClosure: true)
      ]),
    FunctionSignature(name: "animate", params: [
      FunctionParam(name: "withDuration"),
      FunctionParam(name: "animations", isClosure: true),
      FunctionParam(name: "completion", isClosure: true, canOmit: true)
      ]),
    FunctionSignature(name: "animate", params: [
      FunctionParam(name: "withDuration"),
      FunctionParam(name: "delay"),
      FunctionParam(name: "options", canOmit: true),
      FunctionParam(name: "animations", isClosure: true),
      FunctionParam(name: "completion", isClosure: true, canOmit: true)
      ]),
    FunctionSignature(name: "animate", params: [
      FunctionParam(name: "withDuration"),
      FunctionParam(name: "delay"),
      FunctionParam(name: "usingSpringWithDamping"),
      FunctionParam(name: "initialSpringVelocity"),
      FunctionParam(name: "options", canOmit: true),
      FunctionParam(name: "animations", isClosure: true),
      FunctionParam(name: "completion", isClosure: true, canOmit: true)
      ]),
    FunctionSignature(name: "transition", params: [
      FunctionParam(name: "from"),
      FunctionParam(name: "to"),
      FunctionParam(name: "duration"),
      FunctionParam(name: "options"),
      FunctionParam(name: "completion", isClosure: true, canOmit: true),
      ]),
    FunctionSignature( name: "transition", params: [
      FunctionParam(name: "with"),
      FunctionParam(name: "duration"),
      FunctionParam(name: "options"),
      FunctionParam(name: "animations", isClosure: true, canOmit: true),
      FunctionParam(name: "completion", isClosure: true, canOmit: true),
      ]),
    FunctionSignature(name: "animateKeyframes", params: [
      FunctionParam(name: "withDuration"),
      FunctionParam(name: "delay", canOmit: true),
      FunctionParam(name: "options", canOmit: true),
      FunctionParam(name: "animations", isClosure: true),
      FunctionParam(name: "completion", isClosure: true)
      ])
  ]
  
  public override func isNonEscape(arg: FunctionCallArgumentSyntax?,
                                   funcCallExpr: FunctionCallExprSyntax,
                                   graph: Graph) -> Bool {
    
    let base: ExprSyntaxPredicate = .name("UIView")
    for signature in signatures {
      if funcCallExpr.match(.funcCall(signature, base: base)) {
        return true
      }
    }
    
    return false
  }
}

