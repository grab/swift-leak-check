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
  
  func testNestedClosure() {
    verify(fileName: "NestedClosure")
  }
  
  func testNonEscapingClosure() {
    verify(fileName: "NonEscapingClosure")
  }
  
  func testUIKitAnimation() {
    verify(fileName: "Animation")
  }
  
  func testEscapingAttribute() {
    verify(fileName: "EscapingAttribute")
  }
  
  func testIfElse() {
    verify(fileName: "IfElse")
  }
  
  func testFuncResolve() {
    verify(fileName: "FuncResolve")
  }
  
  func testTypeInfer() {
    verify(fileName: "TypeInfer")
  }
  
  func testTypeResolve() {
    verify(fileName: "TypeResolve")
  }
  
  func testDispatchQueue() {
    verify(fileName: "DispatchQueue")
  }
  
  private func verify(fileName: String, extension: String? = nil) {
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
      let leakDetector = GraphLeakDetector(nonEscapeRules: [
          AnimationRule(),
          DispatchQueueRule()
        ] + CollectionRules.rules
      )
      let leaks = try leakDetector.detect(content: content)
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
