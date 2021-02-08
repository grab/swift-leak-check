//
//  SyntaxRetrieval.swift
//  SwiftLeakCheck
//
//  Copyright 2020 Grabtaxi Holdings PTE LTE (GRAB), All rights reserved.
//  Use of this source code is governed by an MIT-style license that can be found in the LICENSE file
//
//  Created by Hoang Le Pham on 09/12/2019.
//

import SwiftSyntax

public enum SyntaxRetrieval {
  public static func request(content: String) throws -> SourceFileSyntax {
    return try SyntaxParser.parse(
      source: content
    )
  }
}
