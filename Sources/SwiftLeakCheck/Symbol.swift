//
//  Symbol.swift
//  SwiftLeakCheck
//
//  Copyright 2020 Grabtaxi Holdings PTE LTE (GRAB), All rights reserved.
//  Use of this source code is governed by an MIT-style license that can be found in the LICENSE file
//
//  Created by Hoang Le Pham on 03/01/2020.
//

import SwiftSyntax

public enum Symbol: Hashable {
  case token(TokenSyntax)
  case identifier(IdentifierExprSyntax)
  
  var node: Syntax {
    switch self {
    case .token(let node): return node._syntaxNode
    case .identifier(let node): return node._syntaxNode
    }
  }
  
  var name: String {
    switch self {
    case .token(let node): return node.text
    case .identifier(let node): return node.identifier.text
    }
  }
}
