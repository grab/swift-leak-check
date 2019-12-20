//
//  EscapingAttribute.swift
//  LeakCheckFrameworkTests
//
//  Created by Hoang Le Pham on 19/12/2019.
//

class X {
  var x: Int!
  
  func test() {
    doSmth1 {
      self.x // Leak
    }
    doSmth2 {
      self.x // Leak
    }
    doSmth3 {
      self.x // Not leak
    }
  }
  
  func doSmth1(block: @escaping () -> Void) {
    a.callBlock(block)
  }

  func doSmth2(block: (() -> Void)?) {
    b.callBlock(block)
  }

  func doSmth3(block: () -> Void) {
    c.callBlock(block)
  }
}
