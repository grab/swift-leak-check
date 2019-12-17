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
  case optional(base: TypeResolve)
  case sequence(elementType: TypeResolve)
  case dict
  case tuple(TupleTypeSyntax)
  case name([String])
  case unknown
  
  var isOptional: Bool {
    switch self {
    case .optional:
      return true
    case .sequence,
         .dict,
         .tuple,
         .name,
         .unknown:
      return false
    }
  }
  
  fileprivate var toNilIfUnknown: TypeResolve? {
    switch self {
    case .unknown: return nil
    default: return self
    }
  }
  
  var sequenceElementType: TypeResolve {
    switch self {
    case .optional(let base):
      return base.sequenceElementType
    case .sequence(let elementType):
      return elementType
    case .dict,
         .tuple,
         .name,
         .unknown:
      return .unknown
    }
  }
  
  var tupleType: TupleTypeSyntax? {
    switch self {
    case .optional(let base):
      return base.tupleType
    case .tuple(let type):
      return type
    case .dict,
         .sequence,
         .name,
         .unknown:
      return nil
    }
  }
}

public final class Graph {
  enum SymbolResolve {
    case variable(Variable)
    case function(Function)
    case typeDeclOrExtension(Scope)
    
    var variable: Variable? {
      switch self {
      case .variable(let variable): return variable
      default:
        return nil
      }
    }
  }
  
  private var cachedSymbolResolved = [IdentifierExprSyntax: SymbolResolve]()
  private var cachedVariableReferences = [Variable: [IdentifierExprSyntax]]()
  private var cachedVariableType = [Variable: TypeResolve]()
  private var cachedClosureEscapeCheck = [ClosureExprSyntax: Bool]()
  private var cachedScopeWithExtenionsMapping = [String: Set<Scope>]()
  
  private let sourceFileScope: SourceFileScope
  init(sourceFileScope: SourceFileScope) {
    self.sourceFileScope = sourceFileScope
  }
}

// MARK: - Scope
public extension Graph {
  func scopeForNode(_ node: Syntax) -> Scope {
    guard let scope = sourceFileScope.findScope(node) else {
      fatalError(logCantFindScopeForNode(node))
    }
    return scope
  }
  
  func enclosingScopeForNode(_ node: Syntax) -> Scope {
    guard let scope = sourceFileScope.findEnclosingScope(node) else {
      fatalError(logCantFindScopeForNode(node))
    }
    return scope
  }
  
  func getClosetScopeThatCanResolve(_ node: IdentifierExprSyntax) -> Scope {
    var scope = enclosingScopeForNode(node)
    // Special case when node is a closure capture item, ie `{ [weak self] in`
    // We need to examine node wrt closure's parent
    if node.parent is ClosureCaptureItemSyntax {
      if let parentScope = scope.parent {
        scope = parentScope
      } else {
        fatalError("Can't happen")
      }
    }
    
    return scope
  }
  
  // Scopes that are on different branches of the tree could be of same type due to Swift `extension`
  private func _getScopeWithAllExtensions(_ scope: Scope) -> Set<Scope> {
    guard let typePath = _getFullTypePathForScope(scope) else {
      return Set([scope])
    }
    
    let name = typePath.map { $0.text }.joined(separator: ".")
    
    if let result = cachedScopeWithExtenionsMapping[name] {
      return result
    }
    
    sourceFileScope.childScopes.forEach { scope in
      if let typePath = _getFullTypePathForScope(scope) {
        let name = typePath.map { $0.text }.joined(separator: ".")
        var set = cachedScopeWithExtenionsMapping[name] ?? Set()
        set.insert(scope)
        cachedScopeWithExtenionsMapping[name] = set
      }
    }
    
    return cachedScopeWithExtenionsMapping[name] ?? Set([scope])
  }
  
  // For eg, type path for C in be example below is A.B.C
  // class A {
  //   struct B {
  //     enum C {
  private func _getFullTypePathForScope(_ scope: Scope) -> [TokenSyntax]? {
    let parentTypePath: [TokenSyntax]
    if scope.parent == nil {
      parentTypePath = []
    } else if let typePath = _getFullTypePathForScope(scope.parent!) {
      parentTypePath = typePath
    } else {
      return nil
    }
    
    let typePath: [TokenSyntax]? = {
      switch scope.scopeNode {
      case .sourceFileNode:
        return []
      case .classNode(let classNode):
        return parentTypePath + [classNode.identifier]
      case .structNode(let structNode):
        return parentTypePath + [structNode.identifier]
      case .enumNode(let enumNode):
        return parentTypePath + [enumNode.identifier]
      case .extensionNode(let extensionNode):
        assert(parentTypePath.isEmpty)
        return extensionNode.extendedType.tokens
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
    return typePath
  }
}

extension Graph {
  enum ResolveSymbolOption: Equatable, CaseIterable {
    case function
    case variable
    case type
  }
  
  func resolveSymbol(_ node: IdentifierExprSyntax,
                     startingFromScope scope: Scope? = nil,
                     options: [ResolveSymbolOption] = ResolveSymbolOption.allCases,
                     onResult: (SymbolResolve) -> Bool) -> SymbolResolve? {
    var scope: Scope! = scope ?? getClosetScopeThatCanResolve(node)
    while scope != nil {
      if let result = resolveSymbol(node, inScope: scope, options: options, onResult: onResult) {
        return result
      }
      scope = scope?.parent
    }
    
    return nil
  }
  
  func resolveSymbol(_ node: IdentifierExprSyntax,
                     inScope scope: Scope,
                     options: [ResolveSymbolOption] = ResolveSymbolOption.allCases,
                     onResult: (SymbolResolve) -> Bool) -> SymbolResolve? {
    if let result = cachedSymbolResolved[node] {
      _ = onResult(result)
      return result
    }
    
    let group = _getScopeWithAllExtensions(scope)
    for scope in group {
      if options.contains(.variable) {
        if let variable = scope.findVariable(node) {
          let result: SymbolResolve = .variable(variable)
          if onResult(result) {
            cachedSymbolResolved[node] = result
            cachedVariableReferences[variable] = (cachedVariableReferences[variable] ?? []) + [node]
            return result
          }
        }
      }
      
      if options.contains(.function) {
        let functions = scope.findFunction(reference: node)
        for function in functions {
          let result: SymbolResolve = .function(function)
          if onResult(result) {
            cachedSymbolResolved[node] = result
            return result
          }
        }
      }
      
      if options.contains(.type) {
        let typeScopes = scope.findTypeDeclOrExtension(name: node.identifier.text)
        for scope in typeScopes {
          let result: SymbolResolve = .typeDeclOrExtension(scope)
          if onResult(result) {
            cachedSymbolResolved[node] = result
            return result
          }
        }
      }
    }
    
    return nil
  }
}

// MARK: - Variable reference
extension Graph {
  
  @discardableResult
  func resolveVariable(_ node: IdentifierExprSyntax) -> Variable? {
    return resolveSymbol(node, options: [.variable]) { resolve -> Bool in
      if resolve.variable != nil {
        return true
      }
      return false
    }?.variable
  }
  
  func getVariableReferences(variable: Variable) -> [IdentifierExprSyntax] {
    return cachedVariableReferences[variable] ?? []
  }
  
  private func _trace(_ node: IdentifierExprSyntax) -> Variable? {
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
  func resolveFunction(_ node: FunctionCallExprSyntax) -> (Function, Function.MatchResult.MappingInfo)? {
    switch node.calledExpression {
    case let identifier as IdentifierExprSyntax: // doSmth(...) or A(...)
      return _resolveFunction(symbol: identifier.identifier, node: node, scope: enclosingScopeForNode(node))
    case let memberAccessExpr as MemberAccessExprSyntax: // a.doSmth(...)
      guard let base = memberAccessExpr.base else {
        assert(false, "Is it possible that `base` is nil ?")
        return nil
      }
      if couldReferenceSelf(base) {
        return _resolveFunction(symbol: memberAccessExpr.name, node: node, scope: enclosingScopeForNode(node))
      }
      // TODO
//      else if let typeName = _resolveType(base).exactType?.name {
//        sourceFileScope.findTypeDeclOrExtension(name: typeName)
//      }
      return nil
      
    case is ImplicitMemberExprSyntax: // .create { ... }
      // TODO
      return nil
    case is OptionalChainingExprSyntax: // optional closure
      // TODO
      return nil
    default:
      assert(false, "Unhandled case")
      return nil
    }
  }
  
  // TODO: this could resole to `closure` as well
  // Currently we only resolve to `func`
  private func _resolveFunction(symbol: TokenSyntax, node: FunctionCallExprSyntax,  scope: Scope) -> (Function, Function.MatchResult.MappingInfo)? {
    // Wrap funcName into a IdentifierExprSyntax
    let identifier = IdentifierExprSyntax { builder in
      builder.useIdentifier(symbol)
    }
    
    var result: (Function, Function.MatchResult.MappingInfo)?
    _ = resolveSymbol(identifier, startingFromScope: scope, options: [.function]) { resolve -> Bool in
      switch resolve {
      case .variable, .typeDeclOrExtension:
        return false
      case .function(let function):
        switch function.match(node) {
        case .argumentMismatch,
             .nameMismatch:
          return false
        case .matched(let info):
          guard result == nil else {
            // Should not happenn
            assert(false, "ambiguous")
            return true // Exit
          }
          result = (function, info)
          return false // Continue to search to make sure no ambiguity
        }
      }
    }
    
    return result
  }
}

// MARK: Type resolve
extension Graph {
  func resolveType(_ variable: Variable) -> TypeResolve {
    if let type = cachedVariableType[variable] {
      return type
    }
    
    let result = _resolveType(variable.typeInfo)
    cachedVariableType[variable] = result
    return result
  }
  
  private func _resolveType(_ typeInfo: TypeInfo) -> TypeResolve {
    switch typeInfo {
    case .exact(let type):
      return _resolveType(type)
    case .inferedFromExpr(let expr):
      return _resolveType(expr)
    case .inferedFromClosure(let closureExpr, let paramIndex, let paramCount):
      // let x: (X, Y) -> Z = { a,b in ...}
      if let closureVariable = enclosingScopeForNode(closureExpr).getVariable(bindingTo: closureExpr) {
        switch closureVariable.typeInfo {
        case .exact(let type):
          guard let tupleType = (type as? FunctionTypeSyntax)?.arguments else {
            // Eg: let onFetchJobs: JobCardsFetcher.OnFetchJobs = { [weak self] jobs in ... }
            return .unknown
          }
          assert(tupleType.count == paramCount)
          return _resolveType(tupleType[paramIndex].type)
        case .inferedFromClosure,
             .inferedFromExpr,
             .inferedFromSequence,
             .inferedFromTuple:
          assert(false, "Seems wrong")
          return .unknown
        }
      }
      // TODO: there's also this case
      // var b: ((X) -> Y)!
      // b = { x in ... }
      return .unknown
    case .inferedFromSequence(let sequenceExpr):
      let sequenceType = _resolveType(sequenceExpr)
      return sequenceType.sequenceElementType
    case .inferedFromTuple(let tupleTypeInfo, let index):
      if let tupleType = _resolveType(tupleTypeInfo).tupleType {
        return _resolveType(tupleType.elements[index].type)
      }
      return .unknown
    }
  }
  
  // TODO: improve this func to handle more scenarios
  private func _resolveType(_ node: ExprSyntax) -> TypeResolve {
    if let optionalExpr = node as? OptionalChainingExprSyntax {
      return .optional(base: _resolveType(optionalExpr.expression))
    }
    
    if let identifierExpr = node as? IdentifierExprSyntax {
      if let variable = resolveVariable(identifierExpr) {
        return resolveType(variable)
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
      return _resolveFunctionCallType(functionCallExpr: functionCallExpr)
    }
    
    if let arrayExpr = node as? ArrayExprSyntax {
      return .sequence(elementType: _resolveType(arrayExpr.elements[0].expression))
    }
    
    if node is DictionaryExprSyntax {
      return .dict
    }
    
    if let range = node.rangeInfo {
      if let leftType = range.left.flatMap({ _resolveType($0) })?.toNilIfUnknown {
        return .sequence(elementType: leftType)
      } else if let rightType = range.right.flatMap({ _resolveType($0) })?.toNilIfUnknown {
        return .sequence(elementType: rightType)
      } else {
        return .unknown
      }
    }
    
    return .unknown
  }
  
  private func _resolveType(_ type: TypeSyntax) -> TypeResolve {
    if type.isOptional {
      return .optional(base: _resolveType(type.wrapped))
    }
    
    switch type {
    case let arrayType as ArrayTypeSyntax:
      return .sequence(elementType: _resolveType(arrayType.elementType))
    case is DictionaryTypeSyntax:
      return .dict
    case let tupleType as TupleTypeSyntax:
      return .tuple(tupleType)
    default:
      if let tokens = type.tokens {
        return .name(tokens.map { $0.text })
      }
      return .unknown
    }
  }
  
  private func _resolveFunctionCallType(functionCallExpr: FunctionCallExprSyntax, ignoreOptional: Bool = false) -> TypeResolve {
    if let (function, _) = resolveFunction(functionCallExpr) {
      if let type = function.signature.output?.returnType {
        return _resolveType(type)
      } else {
        return .unknown // Void
      }
    }
    
    var calledExpr = functionCallExpr.calledExpression
    
    if let optionalExpr = calledExpr as? OptionalChainingExprSyntax { // Must be optional closure
      if !ignoreOptional {
        return .optional(base: _resolveFunctionCallType(functionCallExpr: functionCallExpr, ignoreOptional: true))
      } else {
        calledExpr = optionalExpr.expression
      }
    }
    
    // [X]()
    if let arrayExpr = calledExpr as? ArrayExprSyntax {
      if let typeIdentifier = arrayExpr.elements[0].expression as? IdentifierPatternSyntax {
        return .sequence(elementType: .name([typeIdentifier.identifier.text]))
      } else {
        return .sequence(elementType: _resolveType(arrayExpr.elements[0].expression))
      }
    }
    
    // [X: Y]()
    if calledExpr is DictionaryExprSyntax {
      return .dict
    }
    
    // doSmth() or A()
    if let identifierExpr = calledExpr as? IdentifierExprSyntax {
      let result = resolveSymbol(identifierExpr) { resolve in
        switch resolve {
        case .function(let function):
          return function.match(functionCallExpr).isMatched
        case .typeDeclOrExtension:
          return true
        case .variable:
          return false
        }
      }
      if let result = result {
        switch result {
          // doSmth()
        case .function(let function):
          let returnType = function.signature.output?.returnType
          return returnType.flatMap { _resolveType($0) } ?? .unknown
          // A()
        case .typeDeclOrExtension(let scope):
          return .name(scope.typeDeclOrExtensionTokens!.map { $0.text })
        case .variable:
          break
        }
      }
    }
    
    // x.y()
    // TODO: here we only resolve a very specific scenario
    if let memberAccessExpr = calledExpr as? MemberAccessExprSyntax {
      guard let base = memberAccessExpr.base else {
        fatalError("Is it possible that `base` is nil ?")
      }
      
      let baseType = _resolveType(base)
      if _isCollection(baseType) {
        let funcName = memberAccessExpr.name.text
        if ["map", "flatMap", "compactMap", "enumerated"].contains(funcName) {
          return .sequence(elementType: .unknown)
        }
        if ["filter", "sort"].contains(funcName) {
          return baseType
        }
      }
      
      return .unknown
    }
    
    return .unknown
  }
}

// MARK: - Classification
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
      if let variable = enclosingScopeForNode(node).getVariable(bindingTo: node) {
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
        if let (function, matchedInfo) = resolveFunction(functionCall) {
          let param: FunctionParameterSyntax!
          if let argument = argument {
            param = matchedInfo.argumentToParamMapping[argument]
          } else {
            guard isTrailing else { fatalError("Something weird") }
            param = matchedInfo.trailingClosureArgumentToParam
          }
          guard param != nil else { fatalError("Something wrong") }
          
          // get the `.function` scope where we define this func
          let scope = scopeForNode(function)
          assert(scope.isFunction)
          let paramToken: TokenSyntax! = param.secondName ?? param.firstName
          guard let variableForParam = scope.getVariable(paramToken) else { fatalError("Something wrong") }
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
        if rule.isNonEscape(closureNode: node, graph: self) {
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
    let type = _resolveType(node)
    return _isCollection(type)
  }
  
  func isOptional(_ node: ExprSyntax) -> Bool {
    return _resolveType(node).isOptional
  }
  
  private func _isCollection(_ type: TypeResolve) -> Bool {
    switch type {
    case .tuple,
         .unknown:
      return false
    case .sequence,
         .dict:
      return true
    case .optional(let base):
      return _isCollection(base)
    case .name:
      // TODO
      return false
    }
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
