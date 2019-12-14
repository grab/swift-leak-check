//
//  Graph.swift
//  LeakCheckFramework
//
//  Created by Hoang Le Pham on 11/11/2019.
//

import SwiftSyntax

public indirect enum TypeInfo {
  case exact(TypeSyntax)
  case inferedFromExpr(ExprSyntax)
  case inferedFromSequence(ExprSyntax)
  case inferedFromTuple(tupleType: TypeInfo, index: Int)
  case inferedFromClosure(ClosureExprSyntax, paramIndex: Int, paramCount: Int)
}

indirect enum TypeResolve {
  case unknown
  case sequence(elementType: TypeResolve)
  case dict // TODO (Le): key/value type
  case optional(base: TypeResolve)
  case exact(TypeSyntax)
  
  var isCollection: Bool {
    switch self {
    case .unknown:
      return false
    case .sequence,
         .dict:
      return true
    case .optional(let base):
      return base.isCollection
    case .exact(let type):
      return type.isCollection
    }
  }
  
  var isOptional: Bool {
    switch self {
    case .unknown,
         .sequence,
         .dict:
      return false
    case .optional:
      return true
    case .exact(let type):
      return type is OptionalTypeSyntax
    }
  }
  fileprivate var nilIfUnknown: TypeResolve? {
    switch self {
    case .unknown: return nil
    default: return self
    }
  }
  
  var sequenceElementType: TypeResolve {
    switch self {
    case .sequence(let elementType):
      return elementType
    case .optional(let base):
      return base.sequenceElementType
    case .exact(let type):
      return type.sequenceElementType.flatMap { .exact($0) } ?? .unknown
    case .dict,
         .unknown:
      return .unknown
    }
  }
  
  var tupleType: TupleTypeSyntax? {
    switch self {
    case .dict,
         .sequence,
         .unknown:
      return nil
    case .exact(let type):
      return type.tupleType
    case .optional(let base):
      return base.tupleType
    }
  }
  
  var simpleIdentifierType: SimpleTypeIdentifierSyntax? {
    switch self {
    case .dict, .sequence, .unknown:
      return nil
    case .optional(let base):
      return base.simpleIdentifierType
    case .exact(let type):
      return type as? SimpleTypeIdentifierSyntax
    }
  }
}

public final class Graph {
  enum ReferenceResolve {
    case notFound
    case variable(Variable)
    
    var variable: Variable? {
      switch self {
      case .notFound: return nil
      case .variable(let variable): return variable
      }
    }
  }
  
  private var cachedReferenceResolved = [IdentifierExprSyntax: ReferenceResolve]()
  private var cachedVariableReferences = [Variable: [IdentifierExprSyntax]]()
  private var cachedVariableType = [Variable: TypeResolve]()
  private var cachedClosureEscapeCheck = [ClosureExprSyntax: Bool]()
  private var cachedScopeTypePath = [Scope: String]()
  private var cachedSameTypePathScope = [Scope: Set<Scope>]()
  
  private let sourceFileScope: SourceFileScope
  init(sourceFileScope: SourceFileScope) {
    self.sourceFileScope = sourceFileScope
  }
}

// MARK: - Scope
public extension Graph {
  func getScope(_ node: Syntax) -> Scope {
    guard let scope = sourceFileScope.getScope(node) else {
      fatalError(logCantFindScopeForNode(node))
    }
    return scope
  }
  
  func getEnclosingScope(_ node: Syntax) -> Scope {
    guard let scope = sourceFileScope.getEnclosingScope(node) else {
      fatalError(logCantFindScopeForNode(node))
    }
    return scope
  }
  
  func getClosetScopeThatCanResolve(_ node: IdentifierExprSyntax) -> Scope {
    var scope = getEnclosingScope(node)
    // Special case when node is a closure capture item, ie `{ [weak self] in`
    // We need to examine node wrt closure's parent
    if node.parent is ClosureCaptureItemSyntax {
      if let parentScope = scope.parent {
        scope = parentScope
      } else {
        fatalError("Can't happen")
        // return
      }
    }
    
    return scope
  }
  
  // Scopes that are on different branches of the tree could be of same type due to `extension`
  private func getScopesTogetherWithAllExtensions(_ scope: Scope) -> Set<Scope> {
    if let group = cachedSameTypePathScope[scope] {
      return group
    }
    
    let result: Set<Scope> = {
      guard let typePath = getFullTypePathForScope(scope) else {
        return Set([scope])
      }
      
      // BFS
      var result = Set<Scope>()
      var q: [Scope] = [sourceFileScope]
      while !q.isEmpty {
        let element = q.remove(at: 0)
        if getFullTypePathForScope(element) == typePath {
          result.insert(element)
        }
        element.childScopes.forEach { q.append($0) }
      }
      
      return result
    }()
    
    for scope in result {
      cachedSameTypePathScope[scope] = result
    }
    return result
  }
  
  // For eg, A.B.C, here A,B,C can be class, struct, enum, ...
  private func getFullTypePathForScope(_ scope: Scope) -> String? {
    if let typePath = cachedScopeTypePath[scope] {
      return typePath
    }
    
    let parentTypePath: String
      
    if scope.parent == nil {
      parentTypePath = ""
    } else if let path = getFullTypePathForScope(scope.parent!) {
      parentTypePath = path
    } else {
      return nil
    }
    
    let typePath: String? = {
      switch scope.scopeNode {
      case .sourceFileNode:
        return "sourceFile"
      case .classNode(let classNode):
        return ([parentTypePath, classNode.identifier.text]).joined(separator: ".")
      case .structNode(let structNode):
        return ([parentTypePath, structNode.identifier.text]).joined(separator: ".")
      case .enumNode(let enumNode):
        return ([parentTypePath, enumNode.identifier.text]).joined(separator: ".")
      case .extensionNode(let extensionNode):
        assert(parentTypePath == "sourceFile")
        return ([parentTypePath] + extensionNode.extendedType.typePath.map { $0.text }).joined(separator: ".")
      case .funcNode,
           .enumCaseNode,
           .initialiseNode,
           .closureNode,
           .ifNode,
           .guardNode,
           .forLoopNode,
           .whileLoopNode,
           .subscriptNode,
           .accessorNode,
           .variableDeclNode,
           .switchCaseNode:
        return nil
      }
    }()
    cachedScopeTypePath[scope] = typePath
    return typePath
  }
}

// MARK: - Variable reference
extension Graph {
  
  @discardableResult
  func resolveVariable(_ node: IdentifierExprSyntax) -> Variable? {
    if let result = cachedReferenceResolved[node] {
      return result.variable
    }
    
    var scope: Scope? = getClosetScopeThatCanResolve(node)
    while scope != nil {
      let group = getScopesTogetherWithAllExtensions(scope!)
      for scope in group {
        if let variable = scope.resolveVariable(node) {
          cachedReferenceResolved[node] = .variable(variable)
          cachedVariableReferences[variable] = (cachedVariableReferences[variable] ?? []) + [node]
          return variable
        }
      }
      scope = scope?.parent
    }
    
    return nil
  }
  
  func getVariableReferences(variable: Variable) -> [IdentifierExprSyntax] {
    return cachedVariableReferences[variable] ?? []
  }
  
  private func trace(_ node: IdentifierExprSyntax) -> Variable? {
    guard let variable = resolveVariable(node) else {
      return nil
    }
    
    switch variable.raw {
    case .param:
      return variable
    case let .capture(capturedNode):
      return resolveVariable(capturedNode)
    case let .binding(_, valueNode):
      if let referenceNode = valueNode as? IdentifierExprSyntax {
        return resolveVariable(referenceNode)
      } else {
        return nil
      }
    }
  }
  
  func couldReferenceSelf(_ node: ExprSyntax) -> Bool {
    if let identifierNode = node as? IdentifierExprSyntax {
      guard let variable = resolveVariable(identifierNode) else {
        return identifierNode.identifier.text == "self"
      }
      
      switch variable.raw {
      case .param:
        return false
      case let .capture(capturedNode):
        return couldReferenceSelf(capturedNode)
      case let .binding(_, valueNode):
        if let valueNode = valueNode {
          return couldReferenceSelf(valueNode)
        }
        return false
      }
    }
    
    return false
  }
}

// MARK: - Function resolve
extension Graph {
  func resolveFunctionCall(_ node: FunctionCallExprSyntax) -> (Function, Function.MatchResult.MatchedInfo)? {
    if node.calledExpression is IdentifierExprSyntax { // doSmth(...) or A(...)
      // TODO (Le): identifier could be type, eg A(...), it's better to resolve symbol here instead of resolve func
      return resolveFunctionCall(node, scope: getEnclosingScope(node))
    }
    
    if let memberAccessExpr = node.calledExpression as? MemberAccessExprSyntax { // a.b.doSmth(...)
      guard let base = memberAccessExpr.base else {
        fatalError("Is it possible that `base` is nil ?")
      }
      if couldReferenceSelf(base) {
        return resolveFunctionCall(node, scope: getEnclosingScope(node))
      }
      if let simpleTypeIdentifier = getType(base).simpleIdentifierType {
        // TODO (Le)
      }
      return nil
    }
    
    // .create { ... }
    if node.calledExpression is ImplicitMemberExprSyntax {
      // TODO (Le): we may want to visit later
      return nil
    }
    
    if node.calledExpression is OptionalChainingExprSyntax {
      // Must be optional closure. We only care about function for now
      return nil
    }
    
//    fatalError("Just want to see what it looks like")
    // TODO (Le): there're more, eg SpecializeExprSyntax (X<Y>(...))
    return nil
  }
  
  // TODO (Le): this could resole to `closure` as well
  // Currently we only resolve to `func`
  private func resolveFunctionCall(_ node: FunctionCallExprSyntax, scope: Scope) -> (Function, Function.MatchResult.MatchedInfo)? {
    var scope = scope
    while true {
      let group = getScopesTogetherWithAllExtensions(scope)
      let matchedFunctions = group
        .flatMap { $0.functions }
        .compactMap { function -> (Function, Function.MatchResult.MatchedInfo)? in
          switch function.match(node) {
            case .argumentMismatch,
                 .nameMismatch:
              return nil
          case .matched(let info):
            return (function, info)
          }
        }
      
      if matchedFunctions.count == 1 {
        return matchedFunctions[0]
      }
      else if matchedFunctions.count >= 2 {
        // Should not happenn
        fatalError("ambiguous")
      }
      
      if let parent = scope.parent {
        scope = parent
      } else {
        break
      }
    }
    
    return nil
  }
}

// MARK: Type resolve
extension Graph {
  func getType(_ variable: Variable) -> TypeResolve {
    if let type = cachedVariableType[variable] {
      return type
    }
    
    let result = resolveType(variable.typeInfo)
    cachedVariableType[variable] = result
    return result
  }
  
  private func resolveType(_ typeInfo: TypeInfo) -> TypeResolve {
    switch typeInfo {
    case .exact(let type):
      return .exact(type)
    case .inferedFromExpr(let expr):
      return getType(expr)
    case .inferedFromClosure(let closureExpr, let paramIndex, let paramCount):
      // let x: (X, Y) -> Z = { a,b in ...}
      if let closureVariable = getEnclosingScope(closureExpr).getVariable(bindingTo: closureExpr) {
        switch closureVariable.typeInfo {
        case .exact(let type):
          guard let tupleType = (type as? FunctionTypeSyntax)?.arguments else {
            // Eg: let onFetchJobs: JobCardsFetcher.OnFetchJobs = { [weak self] jobs in ... }
            return .unknown
          }
          assert(tupleType.count == paramCount)
          return .exact(tupleType[paramIndex].type)
        case .inferedFromClosure,
             .inferedFromExpr,
             .inferedFromSequence,
             .inferedFromTuple:
          fatalError("Seems wrong")
        }
      }
      // TODO: there's also this case
      // var b: ((X) -> Y)!
      // b = { x in ... }
      return .unknown
    case .inferedFromSequence(let sequenceExpr):
      let sequenceType = getType(sequenceExpr)
      return sequenceType.sequenceElementType
    case .inferedFromTuple(let tupleTypeInfo, let index):
      if let tupleType = resolveType(tupleTypeInfo).tupleType {
        return .exact(tupleType.elements[index].type)
      }
      return .unknown
    }
  }
  
  // TODO (Le): improve this func to handle more scenarios
  private func getType(_ node: ExprSyntax) -> TypeResolve {
    if let optionalExpr = node as? OptionalChainingExprSyntax {
      return .optional(base: getType(optionalExpr.expression))
    }
    
    if let identifierExpr = node as? IdentifierExprSyntax {
      if let variable = resolveVariable(identifierExpr) {
        return getType(variable)
      }
      // May be global variable, may be type like Int, String,...
      return .unknown
    }
    
//    if let memberAccessExpr = node as? MemberAccessExprSyntax {
//      guard let base = memberAccessExpr.base else {
//        fatalError("Is it possible that `base` is nil ?")
//      }
//
//    }
    
    if let functionCallExpr = node as? FunctionCallExprSyntax {
      return getFunctionReturnType(functionCallExpr: functionCallExpr)
    }
    
    if let arrayExpr = node as? ArrayExprSyntax {
      return .sequence(elementType: getType(arrayExpr.elements[0].expression))
    }
    
    if let dictionaryExpr = node as? DictionaryExprSyntax {
      return .dict
    }
    
    if let range = node.rangeInfo {
      if let leftType = range.left.flatMap({ getType($0) })?.nilIfUnknown {
        return .sequence(elementType: leftType)
      } else if let rightType = range.right.flatMap({ getType($0) })?.nilIfUnknown {
        return .sequence(elementType: rightType)
      } else {
        return .unknown
      }
    }
    
    return .unknown
  }
  
  private func getFunctionReturnType(functionCallExpr: FunctionCallExprSyntax, ignoreOptional: Bool = false) -> TypeResolve {
    var calledExpr = functionCallExpr.calledExpression
    
    if let optionalExpr = calledExpr as? OptionalChainingExprSyntax { // Must be optional closure
      if !ignoreOptional {
        return .optional(base: getFunctionReturnType(functionCallExpr: functionCallExpr, ignoreOptional: true))
      } else {
        calledExpr = optionalExpr.expression
      }
    } else {
      if let (function, _) = resolveFunctionCall(functionCallExpr) {
        if let type = function.node.signature.output?.returnType {
          return .exact(type)
        } else {
          return .unknown // Void
        }
      }
    }
    
    // [X]()
    if let arrayExpr = calledExpr as? ArrayExprSyntax {
      if let typeIdentifier = arrayExpr.elements[0].expression as? IdentifierPatternSyntax {
        let simpleType = SimpleTypeIdentifierSyntax { builder in
          builder.useName(typeIdentifier.identifier)
        }
        return .sequence(elementType: .exact(simpleType))
      } else {
        return .sequence(elementType: getType(arrayExpr.elements[0].expression))
      }
    }
    
    // [X: Y]()
    if let dictExpr = calledExpr as? DictionaryExprSyntax {
      return .dict
    }
    
    // x.y()
    // TODO (Le): here we only resolve a very specific scenario
    if let memberAccessExpr = calledExpr as? MemberAccessExprSyntax {
      guard let base = memberAccessExpr.base else {
        fatalError("Is it possible that `base` is nil ?")
      }
      
      let typeOfBase = getType(base)
      if typeOfBase.isCollection {
        let funcName = memberAccessExpr.name.text
        if ["map", "flatMap", "compactMap", "enumerated"].contains(funcName) {
          return .sequence(elementType: .unknown)
        }
        if ["filter", "sort"].contains(funcName) {
          return typeOfBase
        }
      }
      
      return .unknown
    }
    
    return .unknown
  }
}

// MARK: - Classification
// NOTE: it's not reliable before the graph is fully built
extension Graph {
  func isClosureEscape(_ node: ClosureExprSyntax, nonEscapeRules: [NonEscapeRule]) -> Bool {
    func _isClosureEscape(_ node: ExprSyntax) -> Bool {
      if let closureNode = node as? ClosureExprSyntax, let cachedResult = cachedClosureEscapeCheck[closureNode] {
        return cachedResult
      }
      
      // Function call expression: {...}()
      if node.isFunctionCallExpr() {
        return false // Not escape
      }
      
      // let x = {...}
      // `x` may be used anywhere
      if let variable = getEnclosingScope(node).getVariable(bindingTo: node) {
        let references = getVariableReferences(variable: variable)
        for reference in references {
          if _isClosureEscape(reference) == true {
            return true // Escape
          }
        }
        
        return false
      }
      
      // Used as argument in function call: doSmth(a, b, c: {...}) or doSmth(a, b) {...}
      if let (functionCall, argument, isTrailing) = node.getArgumentInfoInFunctionCall() {
        if let (function, matchedInfo) = resolveFunctionCall(functionCall) {
          let param: FunctionParameterSyntax!
          if let argument = argument {
            param = matchedInfo.argumentToParamMapping[argument]
          } else {
            guard isTrailing else { fatalError("Something weird") }
            param = matchedInfo.trailingClosureParam
          }
          guard param != nil else { fatalError("Something wrong") }
          
          // get the `.function` scope where we define this func
          let scope = getScope(function.node)
          assert(scope.isFunction)
          let paramName: TokenSyntax! = param.secondName ?? param.firstName
          guard let variableForParam = scope.getVariable(paramName) else { fatalError("Something wrong") }
          let references = getVariableReferences(variable: variableForParam)
          for referennce in references {
            if _isClosureEscape(referennce) == true {
              return true
            }
          }
          return false
        } else {
          // Can't resolve the function
        }
      } else {
//        fatalError("We have covered function call expr, closure variable, function param. Are we missing anything else ?")
        // Turns out it can be also inside a tuple, which is function param
      }
      
      // Finally, fallback to rules
      for rule in nonEscapeRules {
        if rule.isNonEscape(closureNode: node) {
          return false // Not escape
        }
      }
      
      return true // Don't know
    }
    
    let result = _isClosureEscape(node)
    cachedClosureEscapeCheck[node] = result
    return result
  }
  
  func isCollection(_ node: ExprSyntax) -> Bool {
    return getType(node).isCollection
  }
  
  func isOptional(_ node: ExprSyntax) -> Bool {
    return getType(node).isOptional
  }
}

private extension Graph {
  func logCantFindScopeForNode(_ node: Syntax) -> String {
    return "Can't find the scope of node at \(node.position.prettyDescription)"
  }
}

class SourceFileScope: Scope {
  let node: SourceFileSyntax
  init(node: SourceFileSyntax, parent: Scope?) {
    self.node = node
    super.init(scopeNode: .sourceFileNode(node), parent: parent)
  }
}

private extension Scope {
  func getVariable(bindingTo node: ExprSyntax) -> Variable? {
    return variables.first(where: { variable -> Bool in
      switch variable.raw {
      case .param, .capture: return false
      case let .binding(_, valueNode):
        return valueNode != nil ? valueNode! == node : false
      }
    })
  }
}
