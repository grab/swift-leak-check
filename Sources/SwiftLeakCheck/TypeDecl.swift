//
//  TypeDecl.swift
//  SwiftLeakCheck
//
//  Copyright 2019 Grabtaxi Holdings PTE LTE (GRAB), All rights reserved.
//  Use of this source code is governed by an MIT-style license that can be found in the LICENSE file
//
//  Created by Hoang Le Pham on 04/01/2020.
//

import SwiftSyntax

// Class, struct, enum or extension
public struct TypeDecl: Equatable {
  /// The name of the class/struct/enum/extension.
  /// For class/struct/enum, it's 1 element
  /// For extension, it could be multiple. Eg, extension X.Y.Z {...}
  public let tokens: [TokenSyntax]
  
  public let inheritanceTypes: [InheritedTypeSyntax]?
  
  // Must be class/struct/enum/extension
  public let scope: Scope
}
