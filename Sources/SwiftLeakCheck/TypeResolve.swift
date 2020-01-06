//
//  TypeResolve.swift
//  SwiftLeakCheck
//
//  Copyright 2019 Grabtaxi Holdings PTE LTE (GRAB), All rights reserved.
//  Use of this source code is governed by an MIT-style license that can be found in the LICENSE file
//
//  Created by Hoang Le Pham on 03/01/2020.
//

import SwiftSyntax

public indirect enum TypeResolve: Equatable {
  case optional(base: TypeResolve)
  case sequence(elementType: TypeResolve)
  case dict
  case tuple([TypeResolve])
  case name([String])
  case type(TypeDecl)
  case unknown
  
  public var isOptional: Bool {
    switch self {
    case .optional:
      return true
    case .sequence,
         .dict,
         .tuple,
         .name,
         .type,
         .unknown:
      return false
    }
  }
  
  public var isInt: Bool {
    return name == "Int"
  }
  
  public var name: String? {
    switch self {
    case .optional(let base):
      return base.name
    case .name(let tokens):
      return tokens.joined(separator: ".")
    case .type(let typeDecl):
      return typeDecl.tokens.map { $0.text }.joined(separator: ".")
    case .sequence,
         .dict,
         .tuple,
         .unknown:
      return nil
    }
  }
  
  public var sequenceElementType: TypeResolve {
    switch self {
    case .optional(let base):
      return base.sequenceElementType
    case .sequence(let elementType):
      return elementType
    case .dict,
         .tuple,
         .name,
         .type,
         .unknown:
      return .unknown
    }
  }
}
