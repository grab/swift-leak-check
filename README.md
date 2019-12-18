# LeakCheckFramework

A proof-of-concept tool that can detect potential memory leak caused by strongly captured `self` in `escaping` closure

<img src=images/leakcheck_sample.png width=800/>


# Example

Some examples of memory leak that are detected by the tool:

```
import RxSwift
class X {
  private let button = UIButton()
  private let anotherButton = UIButton()
  private let disposeBag = DisposeBag()
  
  func setupEventHandlers() {
    button.rx.tap.subscribe(onNext: {
      self.doSmth() // <- Leak
    }).disposed(by: disposeBag)
    
    anotherButton.rx.tap.subscribe(onNext: { // Outer closure
      Observable<Int>
        .interval(1, scheduler: MainScheduler.instance)
        .subscribe { [weak self] _ in // <- Leak
          return self?.doSmth()
        }
    }).disposed(by: disposeBag)
  }
}
```

For first leak, `self` holds a strong reference to `button`, and `button` holds a strong reference to the closure, and the closure holds a strong reference to `self`, which completes a retain cycle.

For second leak, although `self` is captured weakly by the inner closure, but `self` is still implicitly captured strongly by the outer closure, which leaks to the same problem as the first leak


# Usage

Add this repository to the `Package.swift` manifest of your project:

```
// swift-tools-version:4.2
import PackageDescription

let package = Package(
  name: "MyAwesomeLeakDetector",
  dependencies: [
    .package(url: "https://gitlab.myteksi.net/hoang.le/leakcheckframework.git", .exact("1.1.0")),
  ],
  targets: [
    .target(name: "MyAwesomeLeakDetector", dependencies: ["LeakCheckFramework"]),
  ]
)
```

Then, import `LeakCheckFramework` in your Swift code

To create a leak detector and start detecting: 

```
import LeakCheckFramework
let detector = GraphLeakDetector()
let issues = detector.detect(someUrlToSwiftFileOrFolder)
issues.forEach {
    print("\(issue)")
}
```

# Sample project

There is a `Sample` target that you can run directly from XCode or as a command line. 

To run from XCode, edit the `Sample` scheme and change the `/path/to/your/swift/file/or/folder` to an absolute path of a Swift file or directory.

<img src="images/leakcheck_sample_xcode.png" width=800/>


To run from command line:
```
ITSG001658-MAC:Debug hoang.le$ ./Sample ~/Projects/LeakCheckFramework/Source/LeakCheckFramework
```

# How it works

We use [SourceKit](http://jpsim.com/uncovering-sourcekit) to get the [AST](http://clang.llvm.org/docs/IntroductionToTheClangAST.html) representation of the source file, then we travel the AST to detect for potential memory leak. 
Currently we only check if `self` is captured strongly in an escaping closure, which is one specific case that causes memory leak

To do that, 2 things are checked:
**1. Check if a reference actually refers to `self`**

```
block { [weak self] in
    guard let strongSelf = self else { return }
    strongSelf.doSmth { [weak strongSelf] in
        guard let innerSelf = strongSelf else { return }
    }
}
```

In this example, `innerSelf` is originated from `strongSelf`, and `strongSelf` is originated from `self`. So `innerSelf` actually refers to `self`

**2. Check if a closure is non-escaping**

We use the information from the AST to determine if a closure is non-escaping.

In the example below, `block` is non-escaping because it's not marked `@escaping`.
```
func doSmth(block: () -> Void) {
   ... 
}
```

Or if it's anonymous closure, it's non-escaping
```
let value = {
   return self.doSmth()
}()
```

We can check more complicated case like this:

```
func test() {
    let block = {
        self.xxx
    }
    doSmth(block)
}
func doSmth(_ block: () -> Void) {
    ....
}
```

In this case, `block` is passed to a function `doSmth` and is not marked as `@escaping`, hence it's non-escaping

# Non-escaping rules

Sometimes we can't determine if a closure is escaping based on the information we have. For eg, if we call a function from another source file, we won't know
if the closure argument we pass to it is escaping or not. In those cases, we treat the closure as escaping, which could lead to many false-positive alarms. To overcome that, you can define custom rules which classifies a closure as escaping or non-escaping.

To define a rule, extend from `NonEscapeRule` protocol and override `func isNonEscape(closureNode: ExprSyntax, graph: Graph) -> Bool`

```
public final class DispatchQueueRule: NonEscapeRule {
  
  public func isNonEscape(closureNode: ExprSyntax, graph: Graph) -> Bool {
    return closureNode.isArgumentInFunctionCall(
      functionNamePredicate: { $0 == "async" || $0 == "sync" || $0 == "asyncAfter" },
      argumentNamePredicate: { $0 == "execution" },
      calledExprPredicate: { expr in
        if let memberAccessExpr = expr as? MemberAccessExprSyntax {
          return memberAccessExpr.match("DispatchQueue.main")
        } else if let function = expr as? FunctionCallExprSyntax {
          if let subExpr = function.calledExpression as? MemberAccessExprSyntax {
            return subExpr.match("DispatchQueue.global")
          }
        }
        return false
      })
  }
}
```

then pass to the leak detector:

```
let leakDetector = GraphLeakDetector(nonEscapingRules: [DispatchQueueRule()])
```

The above rule will classify all usages of closures in `DispatchQueue.main.async(...)`, `DispatchQueue.global.asyncAfter(...)`, ... as non-escaping

# Predefined non-escaping rules

We have built some non-escaping rules that are ready to be used. 

**1. DispatchQueue**

We know that a closure passed to `DispatchQueue.main.async` or its variations is escaping, but the closure will be executed very soon and destroyed after that. So even if it holds a strong reference to `self`, the reference
will be gone quickly. So it's actually ok to treat it as non-escaping

**2. UIKit animation**

Similar to DispatchQueue, UIView animation closures are escaping but will be executed then destroyed quickly.

**3. Swift Collection map/flatMap/compactMap/sort/filter/forEach/**

All these Swift Collection functions take in a non-escaping closure

# Write your own tool

In case you want to make your own tool instead of using the provided GraphLeakDetector, and you want to use the AST, create a class that extends from `BaseSyntaxTreeLeakDetector` and override the function

```
class MyOwnLeakDetector: BaseSyntaxTreeLeakDetector {
    override func detect(_ sourceFileNode: SourceFileSyntax) -> [Leak] {
        // Your own implementation
    }
}
```


# Graph

Graph is the brain of the tool. It processes the AST and give valuable information, such as where a reference is defined, or if a closure is escaping or not. 
To create a graph:

```
let graph = GraphBuilder.buildGraph(node: sourceFileNode)
```


# Note

1. To check a source file, we use only the AST of that file, and not any other source file. So if you call a function that is defined elsewhere, that information is not available.

2. For non-escaping closure, there's no need to use `self.`. This can help to prevent false-positive


# License

This library is available as open-source under the terms of the [MIT License](https://opensource.org/licenses/MIT).


