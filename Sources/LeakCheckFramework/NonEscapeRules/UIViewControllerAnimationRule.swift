//
//  UIViewControllerAnimationRule.swift
//  LeakCheckFramework
//
//  Copyright 2019 Grabtaxi Holdings PTE LTE (GRAB), All rights reserved.
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
  
  open func isUIViewControllerType(tokens: [TokenSyntax]) -> Bool {
    
    let typeName = tokens.last?.text ?? ""
    
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
    if isUIViewControllerType(tokens: typeDecl.tokens) {
      return true
    }
    
    let inheritantTypeNames = (typeDecl.inheritanceTypes ?? []).map { $0.typeName }
    for inheritantTypeName in inheritantTypeNames {
      if isUIViewControllerType(tokens: inheritantTypeName.tokens ?? []) {
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
    
    // Eg: x.doSmth()
    // We find the type of `x` and check if it's UIViewController based
    if case let .type(tokens) = graph.resolveType(base) {
      // If we can find the TypeDecl
      if let typeDecl = graph.findTypeDecl(tokens: tokens) {
        return isUIViewControllerType(typeDecl: typeDecl)
      }
      // Else, we will just rely on the type name
      return isUIViewControllerType(tokens: tokens)
    } else {
      return false
    }
  }
}
