//
//  LeakDetector.swift
//  LeakCheckFramework
//
//  Copyright 2019 Grabtaxi Holdings PTE LTE (GRAB), All rights reserved.
//  Use of this source code is governed by an MIT-style license that can be found in the LICENSE file
//
//  Created by Hoang Le Pham on 27/10/2019.
//

import SwiftSyntax
import SourceKittenFramework
import Foundation

public protocol LeakDetector {
  func detect(content: String) throws -> [Leak]
}

extension LeakDetector {
  public func detect(_ filePath: String) throws -> [Leak] {
    return try detect(content: String(contentsOfFile: filePath))
  }
  
  public func detect(_ url: URL) throws -> [Leak] {
    return try detect(content: String(contentsOf: url))
  }
}
