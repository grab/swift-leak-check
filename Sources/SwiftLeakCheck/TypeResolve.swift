//
//  TypeResolve.swift
//  SwiftLeakCheck
//
//  Copyright 2020 Grabtaxi Holdings PTE LTE (GRAB), All rights reserved.
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
    return self != self.wrapped
  }
  
  public var wrapped: TypeResolve {
    switch self {
    case .optional(let base):
      return base.wrapped
    case .sequence,
       .dict,
       .tuple,
       .name,
       .type,
       .unknown:
    return self
    }
  }
  
  public var name: [String]? {
    switch self {
    case .optional(let base):
      return base.name
    case .name(let tokens):
      return tokens
    case .type(let typeDecl):
      return typeDecl.name
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

internal extension TypeResolve {
  var isInt: Bool {
    return name == ["Int"]
  }
}
