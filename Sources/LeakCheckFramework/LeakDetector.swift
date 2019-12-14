//
//  LeakDetector.swift
//  LeakCheckFramework
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
