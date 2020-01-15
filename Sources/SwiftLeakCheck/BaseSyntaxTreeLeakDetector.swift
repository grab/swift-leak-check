//
//  BaseSyntaxTreeLeakDetector.swift
//  SwiftLeakCheck
//
//  Copyright 2020 Grabtaxi Holdings PTE LTE (GRAB), All rights reserved.
//  Use of this source code is governed by an MIT-style license that can be found in the LICENSE file
//
//  Created by Hoang Le Pham on 09/12/2019.
//

import SwiftSyntax

open class BaseSyntaxTreeLeakDetector: LeakDetector {
  public init() {}
  
  public func detect(content: String) throws -> [Leak] {
    let node = try SyntaxRetrieval.request(content: content)
    return detect(node)
  }
  
  open func detect(_ sourceFileNode: SourceFileSyntax) -> [Leak] {
    fatalError("Implemented by subclass")
  }
}
