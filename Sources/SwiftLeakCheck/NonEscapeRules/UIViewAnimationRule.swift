//
//  UIViewAnimationRule.swift
//  SwiftLeakCheck
//
//  Copyright 2019 Grabtaxi Holdings PTE LTE (GRAB), All rights reserved.
//  Use of this source code is governed by an MIT-style license that can be found in the LICENSE file
//
//  Created by Hoang Le Pham on 28/10/2019.
//

import SwiftSyntax

/// Eg, UIView.animate(..., animations: {...}) {
///   .....
/// }
open class UIViewAnimationRule: BaseNonEscapeRule {
  
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
  
  open override func isNonEscape(arg: FunctionCallArgumentSyntax?,
                                 funcCallExpr: FunctionCallExprSyntax,
                                 graph: Graph) -> Bool {
    
    // Check if base is `UIView`, if not we can end early without checking any of the signatures
    guard funcCallExpr.match(.funcCall({ _ in true }, base: .name("UIView"))) else {
      return false
    }
    
    // Now we can check each signature and ignore the base (already checked)
    for signature in signatures {
      if funcCallExpr.match(.funcCall(signature, base: .init { _ in true })) {
        return true
      }
    }
    
    return false
  }
}

