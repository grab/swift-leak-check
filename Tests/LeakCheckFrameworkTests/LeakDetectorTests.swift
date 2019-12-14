//
//  LeakDetectorTests.swift
//  LeakCheckFrameworkTests
//
//  Created by Hoang Le Pham on 27/10/2019.
//

import XCTest
import LeakCheckFramework

final class LeakDetectorTests: XCTestCase {
  func testLeak1() {
    verify(fileName: "Leak1")
  }
  
  func testLeak2() {
    verify(fileName: "Leak2")
  }
  
  func testLeak3() {
    verify(fileName: "Leak3")
  }
  
  func testLeak4() {
    verify(fileName: "Leak4")
  }
  
  func testLeak5() {
    verify(fileName: "Leak5")
  }
  
  func testLeak6() {
    verify(fileName: "Leak6")
  }
  
  func testLeak7() {
    verify(fileName: "Leak7")
  }
  
  func testLeak8() {
    verify(fileName: "Leak8")
  }
  
  func testLeak9() {
    verify(fileName: "Leak9")
  }
  
  func testUIKitAnimation() {
    verify(fileName: "Animation")
  }
  
  func testTupleClosure() {
    let content = """
      func tupleClosure() {
        let (a, b) = (
          closure1: {
            self.doSmth() // No Leak
          },
          closure2: {
            self.doSmth() // Leak
          }
        )

        a()
        doSmthWithCallback(b)
      }
    """
    verify(content: content)
  }
  
  private func verify(fileName: String, extension: String? = "swift") {
    do {
      guard let url = bundle.url(forResource: fileName, withExtension: `extension`) else {
        XCTFail("File \(fileName + (`extension`.flatMap { ".\($0)" } ?? "")) doesn't exist")
        return
      }
      
      let content = try String(contentsOf: url)
      verify(content: content)
    } catch {
      XCTFail(error.localizedDescription)
    }
  }
  
  private func verify(content: String) {
    let lines = content.components(separatedBy: "\n")
    let expectedLeakAtLines = lines.enumerated().compactMap { (lineNumber, line) -> Int? in
      if line.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix("// Leak") {
        return lineNumber + 1
      }
      return nil
    }
    
    do {
      let nonEscapeRules: [NonEscapeRule] = [
        UIViewConfigureRule(),
        AnimationRule(),
        DispatchQueueRule(),
        SnapKitRule()
      ]
      let leaks = try GraphLeakDetector(nonEscapeRules: nonEscapeRules).detect(content: content)
      let leakAtLines = leaks.map { $0.line }
      let leakAtLinesUnique = NSOrderedSet(array: leakAtLines).array as! [Int]
      XCTAssertEqual(leakAtLinesUnique, expectedLeakAtLines)
    } catch {
      XCTFail(error.localizedDescription)
    }
  }
  
  private lazy var bundle: Bundle = {
    return Bundle(for: type(of: self))
  }()
}
