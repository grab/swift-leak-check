//
//  Stack.swift
//  LeakCheck
//
//  Copyright 2019 Grabtaxi Holdings PTE LTE (GRAB), All rights reserved.
//  Use of this source code is governed by an MIT-style license that can be found in the LICENSE file
//
//  Created by Hoang Le Pham on 27/10/2019.
//

public struct Stack<T> {
  private var items: [T] = []
  
  public init() {}
  
  public init(items: [T]) {
    self.items = items
  }
  
  public mutating func push(_ item: T) {
    items.append(item)
  }
  
  @discardableResult
  public mutating func pop() -> T? {
    if !items.isEmpty {
      return items.removeLast()
    } else {
      return nil
    }
  }
  
  public mutating func reset() {
    items.removeAll()
  }
  
  public func peek() -> T? {
    return items.last
  }
}

extension Stack: Collection {
  public var startIndex: Int {
    return items.startIndex
  }
  
  public var endIndex: Int {
    return items.endIndex
  }
  
  public func index(after i: Int) -> Int {
    return items.index(after: i)
  }
  
  public subscript(_ index: Int) -> T {
    return items[items.count - index - 1]
  }
}
