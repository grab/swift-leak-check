//
//  TypePath.swift
//  LeakCheckFramework
//
//  Created by Hoang Le Pham on 17/12/2019.
//

import SwiftSyntax

public struct TypePath {
  private let path: [TokenSyntax]
  
  public init(_ path: [TokenSyntax]) {
    self.path = path
  }
  
  public func appending(_ token: TokenSyntax) -> TypePath {
    return TypePath(path + [token])
  }
  
  public func appending(typePath: TypePath) -> TypePath {
    return TypePath(path + typePath.path)
  }
  
  public var name: String {
    return path.map { $0.text }.joined(separator: ".")
  }
}

extension TypePath: Collection {
  public var startIndex: Int {
    return path.startIndex
  }
  
  public var endIndex: Int {
    return path.endIndex
  }
  
  public func index(after i: Int) -> Int {
    return path.index(after: i)
  }
  
  public subscript(_ index: Int) -> TokenSyntax {
    return path[index]
  }
}
