//
//  UIViewControllerAnimationRule.swift
//  SwiftLeakCheck
//
//  Copyright 2020 Grabtaxi Holdings PTE LTE (GRAB), All rights reserved.
//  Use of this source code is governed by an MIT-style license that can be found in the LICENSE file
//
//  Created by Hoang Le Pham on 30/12/2019.
//

import SwiftSyntax

/// Eg, someViewController.present(vc, animated: true, completion: { ... })
/// or someViewController.dismiss(animated: true) { ... }
open class UIViewControllerAnimationRule: BaseNonEscapeRule {
  
  private let signatures: [FunctionSignature] = [
    FunctionSignature(name: "present", params: [
      FunctionParam(name: nil), // "viewControllerToPresent"
      FunctionParam(name: "animated"),
      FunctionParam(name: "completion", isClosure: true, canOmit: true)
      ]),
    FunctionSignature(name: "dismiss", params: [
      FunctionParam(name: "animated"),
      FunctionParam(name: "completion", isClosure: true, canOmit: true)
      ]),
    FunctionSignature(name: "transition", params: [
      FunctionParam(name: "from"),
      FunctionParam(name: "to"),
      FunctionParam(name: "duration"),
      FunctionParam(name: "options", canOmit: true),
      FunctionParam(name: "animations", isClosure: true),
      FunctionParam(name: "completion", isClosure: true, canOmit: true)
      ])
  ]
  
  open override func isNonEscape(arg: FunctionCallArgumentSyntax?,
                                 funcCallExpr: FunctionCallExprSyntax,
                                 graph: Graph) -> Bool {
    
    // Make sure the func is called from UIViewController
    guard isCalledFromUIViewController(funcCallExpr: funcCallExpr, graph: graph) else {
      return false
    }
    
    // Now we can check each signature and ignore the base that is already checked
    for signature in signatures {
      if funcCallExpr.match(.funcCall(signature, base: .init { _ in true })) {
        return true
      }
    }
    
    return false
  }
  
  open func isUIViewControllerType(name: [String]) -> Bool {
    
    let typeName = name.last ?? ""
    
    let candidates = [
      "UIViewController",
      "UITableViewController",
      "UICollectionViewController",
      "UIAlertController",
      "UIActivityViewController",
      "UINavigationController",
      "UITabBarController",
      "UIMenuController",
      "UISearchController"
    ]
    
    return candidates.contains(typeName) || typeName.hasSuffix("ViewController")
  }
  
  private func isUIViewControllerType(typeDecl: TypeDecl) -> Bool {
    if isUIViewControllerType(name: typeDecl.tokens.map { $0.text }) {
      return true
    }
    
    let inheritantTypes = (typeDecl.inheritanceTypes ?? []).map { $0.typeName }
    for inheritantType in inheritantTypes {
      if isUIViewControllerType(name: (inheritantType.tokens ?? []).map { $0.text }) {
        return true
      }
    }
    
    return false
  }
  
  private func isCalledFromUIViewController(funcCallExpr: FunctionCallExprSyntax, graph: Graph) -> Bool {
    guard let base = funcCallExpr.base else {
      // No base, eg: doSmth()
      // class SomeClass {
      //   func main() {
      //      doSmth()
      //   }
      // }
      // In this case, we find the TypeDecl where this func is called from (Eg, SomeClass)
      if let typeDecl = graph.enclosingTypeDecl(for: funcCallExpr) {
        return isUIViewControllerType(typeDecl: typeDecl)
      } else {
        return false
      }
    }
    
    // Eg: base.doSmth()
    // We check if base is UIViewController
    switch graph.resolveExprType(base) {
    case .type(let typeDecl):
      return isUIViewControllerType(typeDecl: typeDecl)
    case .name(let name):
      return isUIViewControllerType(name: name)
    default:
      return false
    }
  }
}
