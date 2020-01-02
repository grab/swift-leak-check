//
//  StackTests.swift
//  LeakCheckFrameworkTests
//
//  Copyright 2019 Grabtaxi Holdings PTE LTE (GRAB), All rights reserved.
//  Use of this source code is governed by an MIT-style license that can be found in the LICENSE file
//
//  Created by Hoang Le Pham on 27/10/2019.
//

import XCTest
@testable import LeakCheckFramework

final class StackTests: XCTestCase {
  func testEnumerationOrder() {
    var stack = Stack<Int>()
    stack.push(5)
    stack.push(4)
    stack.push(3)
    stack.push(2)
    stack.push(1)
    
    let a = [1, 2, 3, 4, 5]
    
    // Map
    XCTAssertEqual(stack.map { $0 }, a)
    
    // Loop
    var arr1 = [Int]()
    stack.forEach { arr1.append($0) }
    XCTAssertEqual(arr1, a)
    
    var arr2 = [Int]()
    for num in stack {
      arr2.append(num)
    }
    XCTAssertEqual(arr2, a)
  }
  
  func testPushPopPeek() {
    var stack = Stack<Int>()
    stack.push(5)
    XCTAssertEqual(stack.peek(), 5)
    stack.push(4)
    XCTAssertEqual(stack.pop(), 4)
    XCTAssertEqual(stack.peek(), 5)
    stack.push(3)
    stack.push(2)
    XCTAssertEqual(stack.pop(), 2)
    stack.push(1)
    
    XCTAssertEqual(stack.map { $0 }, [1, 3, 5])
  }
  
  func testPopEmpty() {
    var stack = Stack<Int>()
    stack.push(1)
    XCTAssertEqual(stack.pop(), 1)
    XCTAssertEqual(stack.pop(), nil)
  }
  
  func testReset() {
    var stack = Stack<Int>()
    stack.push(5)
    stack.push(4)
    stack.reset()
    
    XCTAssertEqual(stack.map { $0 }, [])
  }
}

