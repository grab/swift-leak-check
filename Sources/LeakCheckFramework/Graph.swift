//
//  Graph.swift
//  LeakCheckFramework
//
//  Copyright 2019 Grabtaxi Holdings PTE LTE (GRAB), All rights reserved.
//  Use of this source code is governed by an MIT-style license that can be found in the LICENSE file
//
//  Created by Hoang Le Pham on 11/11/2019.
//

import SwiftSyntax

indirect enum TypeInfo {
  case exact(TypeSyntax)
  case inferedFromExpr(ExprSyntax)
  case inferedFromSequence(ExprSyntax)
  case inferedFromTuple(tupleType: TypeInfo, index: Int)
  case inferedFromClosure(ClosureExprSyntax, paramIndex: Int, paramCount: Int)
}

public indirect enum TypeResolve: Equatable {
  case optional(base: TypeResolve)
  case sequence(elementType: TypeResolve)
  case dict
  case tuple([TypeResolve])
  case int
  case string
  case float
  case bool
  case type([TokenSyntax])
  case unknown
  
  var isOptional: Bool {
    switch self {
    case .optional:
      return true
    case .sequence,
         .dict,
         .tuple,
         .int,
         .string,
         .float,
         .bool,
         .type,
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
         .int,
         .string,
         .float,
         .bool,
         .type,
         .unknown:
      return .unknown
    }
  }
}

public enum Symbol: Hashable {
  case token(TokenSyntax)
  case identifier(IdentifierExprSyntax)
  
  var node: Syntax {
    switch self {
    case .token(let node): return node
    case .identifier(let node): return node
    }
  }
  
  var name: String {
    switch self {
    case .token(let node): return node.text
    case .identifier(let node): return node.identifier.text
    }
  }
}

public final class Graph {
  enum SymbolResolve {
    case variable(Variable)
    case function(Function)
    case typeDecl(TypeDecl)
    
    var variable: Variable? {
      switch self {
      case .variable(let variable): return variable
      default:
        return nil
      }
    }
  }
  
  private var cachedSymbolResolved = [Symbol: SymbolResolve]()
  private var cachedReferencesToVariable = [Variable: [IdentifierExprSyntax]]()
  private var cachedVariableType = [Variable: TypeResolve]()
  private var cachedFunCallExprType = [FunctionCallExprSyntax: TypeResolve]()
  private var cachedClosureEscapeCheck = [ClosureExprSyntax: Bool]()
  private var cachedScopeWithExtenionsMapping = [String: Set<Scope>]()
  
  private let sourceFileScope: SourceFileScope
  init(sourceFileScope: SourceFileScope) {
    self.sourceFileScope = sourceFileScope
  }
}

// MARK: - Scope
public extension Graph {
  /// Return the corresponding scope of a node if the node is of scope-type (class, func, closure,...)
  /// or return the enclosing scope if the node is not scope-type
  /// - Parameter node: The node
  func scope(for node: Syntax) -> Scope {
    guard let scopeNode = ScopeNode.from(node: node) else {
      return enclosingScope(for: node)
    }
    
    return scope(for: scopeNode)
  }
  
  /// Get the scope that encloses a given node
  /// Eg, Scopes that enclose a func could be class, enum,...
  /// Or scopes that enclose a statement could be func, closure,...
  /// If the node is not enclosed by a scope (eg, sourcefile node), return the scope of the node itself
  /// - Parameter node: A node
  /// - Returns: The scope that encloses the node
  func enclosingScope(for node: Syntax) -> Scope {
    guard let scopeNode = node.enclosingScopeNode else {
      let result = scope(for: node)
      assert(result == sourceFileScope)
      return result
    }
    
    return scope(for: scopeNode)
  }
  
  /// Return the TypeDecl that encloses a given node
  /// - Parameter node: given node
  func enclosingTypeDecl(for node: Syntax) -> TypeDecl? {
    var scopeNode: ScopeNode! = node.enclosingScopeNode
    while scopeNode != nil  {
      if scopeNode.type.isTypeDecl {
        return scope(for: scopeNode).typeDecl
      }
      scopeNode = scopeNode.enclosingScopeNode
    }
    
    return nil
  }
  
  func scope(for scopeNode: ScopeNode) -> Scope {
    guard let result = _findScope(scopeNode: scopeNode, recursivelyFrom: sourceFileScope) else {
      fatalError("Can't find the scope of node at \(scopeNode.node.position.prettyDescription)")
    }
    return result
  }
  
  private func _findScope(scopeNode: ScopeNode, recursivelyFrom root: Scope) -> Scope? {
    if root.scopeNode == scopeNode {
      return root
    }
    
    return root.childScopes.lazy.compactMap { self._findScope(scopeNode: scopeNode, recursivelyFrom: $0) }.first
  }
  
  func getClosetScopeThatCanResolve(_ symbol: Symbol) -> Scope {
    var scope = enclosingScope(for: symbol.node)
    // Special case when node is a closure capture item, ie `{ [weak self] in`
    // We need to examine node wrt closure's parent
    if symbol.node.parent is ClosureCaptureItemSyntax {
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
           .ifBlockNode,
           .elseBlockNode,
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


// MARK: - Symbol resolve
extension Graph {
  enum ResolveSymbolOption: Equatable, CaseIterable {
    case function
    case variable
    case type
  }
  
  func resolve(_ symbol: Symbol,
               options: [ResolveSymbolOption] = ResolveSymbolOption.allCases,
               startingFrom scope: Scope? = nil,
               onResult: (SymbolResolve) -> Bool) -> SymbolResolve? {
    var scope: Scope! = scope ?? getClosetScopeThatCanResolve(symbol)
    while scope != nil {
      if let result = cachedSymbolResolved[symbol], onResult(result) {
        return result
      }
      
      if let result = resolve(symbol, options: options, in: scope, onResult: onResult) {
        cachedSymbolResolved[symbol] = result
        return result
      }
      
      scope = scope?.parent
    }
    
    return nil
  }
  
  func resolve(_ symbol: Symbol,
               options: [ResolveSymbolOption] = ResolveSymbolOption.allCases,
               in scope: Scope,
               onResult: (SymbolResolve) -> Bool) -> SymbolResolve? {
    let group = _getScopeWithAllExtensions(scope)
    for scope in group {
      if options.contains(.variable) {
        if case let .identifier(node) = symbol, let variable = scope.findVariable(node) {
          let result: SymbolResolve = .variable(variable)
          if onResult(result) {
            cachedReferencesToVariable[variable] = (cachedReferencesToVariable[variable] ?? []) + [node]
            return result
          }
        }
      }
      
      if options.contains(.function) {
        for function in scope.findFunction(symbol) {
          let result: SymbolResolve = .function(function)
          if onResult(result) {
            return result
          }
        }
      }
      
      if options.contains(.type) {
        let typeDecls = scope.findTypeDecl(name: symbol.name)
        for typeDecl in typeDecls {
          let result: SymbolResolve = .typeDecl(typeDecl)
          if onResult(result) {
            return result
          }
        }
      }
    }
    
    return nil
  }
}

// MARK: - TypeDecl resolve
extension Graph {
  
  func findTypeDecl(symbol: Symbol,
                    startingFrom scope: Scope? = nil,
                    onResult: (TypeDecl) -> Bool) -> TypeDecl? {
    let result =  resolve(symbol, options: [.type], startingFrom: scope) { resolve in
      if case let .typeDecl(typeDecl) = resolve {
        return onResult(typeDecl)
      }
      return false
    }
    
    if let result = result, case let .typeDecl(scope) = result {
      return scope
    }
    
    return nil
  }
  
  func findTypeDecl(symbol: Symbol, in scope: Scope) -> TypeDecl? {
    if let result =  resolve(symbol, options: [.type], in: scope, onResult: { _ in true }) {
      if case let .typeDecl(typeDecl) = result {
        return typeDecl
      }
    }
    
    return nil
  }
  
  func findTypeDecl(tokens: [TokenSyntax], startingFrom scope: Scope? = nil) -> TypeDecl? {
    guard tokens.count > 0 else {
      return nil
    }
    
    return findTypeDecl(symbol: .token(tokens[0]), startingFrom: scope, onResult: { typeDecl in
      var currentScope = typeDecl.scope
      for token in tokens[1...] {
        if let scope = findTypeDecl(symbol: .token(token), in: currentScope)?.scope {
          currentScope = scope
        } else {
          return false
        }
      }
      return true
    })
  }
}

// MARK: - Variable reference
extension Graph {
  
  @discardableResult
  func resolveVariable(_ node: IdentifierExprSyntax) -> Variable? {
    return resolve(.identifier(node), options: [.variable]) { resolve -> Bool in
      if resolve.variable != nil {
        return true
      }
      return false
    }?.variable
  }
  
  func getReferencesToVariable(variable: Variable) -> [IdentifierExprSyntax] {
    return cachedReferencesToVariable[variable] ?? []
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
    if node.isCalledExpr() {
      return false
    }
    
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
public extension Graph {
  func findFunction(_ node: FunctionCallExprSyntax) -> (Function, Function.MatchResult.MappingInfo)? {
    switch node.calledExpression {
    case let identifier as IdentifierExprSyntax: // doSmth(...) or A(...)
      return _findFunction(symbol: .identifier(identifier), node: node)
    case let memberAccessExpr as MemberAccessExprSyntax: // a.doSmth(...)
      guard let base = memberAccessExpr.base else {
        assert(false, "Is it possible that `base` is nil ?")
        return nil
      }
      if couldReferenceSelf(base) {
        return _findFunction(symbol: .token(memberAccessExpr.name), node: node)
      }
      if case let .type(tokens) = resolveType(base) {
        guard let typeDecl = findTypeDecl(tokens: tokens, startingFrom: enclosingScope(for: node)) else {
          return nil
        }
        return _findFunction(symbol: .token(memberAccessExpr.name), node: node, in: typeDecl.scope)
      }
      
      return nil
      
    case is ImplicitMemberExprSyntax: // .create { ... }
      // TODO
      return nil
    case is OptionalChainingExprSyntax: // optional closure
      // TODO
      return nil
    default:
      // Unhandled case
      return nil
    }
  }
  
  // TODO: this could resole to `closure` as well
  // Currently we only resolve to `func`
  private func _findFunction(symbol: Symbol, node: FunctionCallExprSyntax)
    -> (Function, Function.MatchResult.MappingInfo)? {
    
    var result: (Function, Function.MatchResult.MappingInfo)?
    _ = resolve(symbol, options: [.function], startingFrom: enclosingScope(for: node)) { resolve -> Bool in
      switch resolve {
      case .variable, .typeDecl:
        assert(false, "Can't happen")
        return false
      case .function(let function):
        let mustStop = enclosingScope(for: function).type.isTypeDecl
        
        switch function.match(node) {
        case .argumentMismatch,
             .nameMismatch:
          return mustStop
        case .matched(let info):
          guard result == nil else {
            // Should not happenn
            assert(false, "ambiguous")
            return true // Exit
          }
          result = (function, info)
          #if DEBUG
          return mustStop // Continue to search to make sure no ambiguity
          #else
          return true
          #endif
        }
      }
    }
    
    return result
  }
  
  private func _findFunction(symbol: Symbol, node: FunctionCallExprSyntax,  in scope: Scope)
    -> (Function, Function.MatchResult.MappingInfo)? {
      
      var result: (Function, Function.MatchResult.MappingInfo)?
      
      _ = resolve(symbol, options: [.function], in: scope, onResult: { resolve in
        switch resolve {
        case .variable, .typeDecl:
          assert(false, "Can't happen")
          return false
        case .function(let function):
          switch function.match(node) {
          case .argumentMismatch,
               .nameMismatch:
            return false
          case .matched(let info):
            result = (function, info)
            return true
          }
        }
      })
      
      return result
  }
}

// MARK: Type resolve
public extension Graph {
  func resolveType(_ variable: Variable) -> TypeResolve {
    if let type = cachedVariableType[variable] {
      return type
    }
    
    let result = _resolveType(variable.typeInfo)
    cachedVariableType[variable] = result
    return result
  }
  
  func resolveType(_ node: ExprSyntax) -> TypeResolve {
    if let optionalExpr = node as? OptionalChainingExprSyntax {
      return .optional(base: resolveType(optionalExpr.expression))
    }
    
    if let identifierExpr = node as? IdentifierExprSyntax {
      if let variable = resolveVariable(identifierExpr) {
        return resolveType(variable)
      }
      if identifierExpr.identifier.text == "self" {
        return enclosingTypeDecl(for: node).flatMap { .type($0.tokens) } ?? .unknown
      }
      // May be global variable, or type like Int, String,...
      return .unknown
    }
    
//    if let memberAccessExpr = node as? MemberAccessExprSyntax {
//      guard let base = memberAccessExpr.base else {
//        fatalError("Is it possible that `base` is nil ?")
//      }
//
//    }
    
    if let functionCallExpr = node as? FunctionCallExprSyntax {
      let result = cachedFunCallExprType[functionCallExpr] ?? _resolveFunctionCallType(functionCallExpr: functionCallExpr)
      cachedFunCallExprType[functionCallExpr] = result
      return result
    }
    
    if let arrayExpr = node as? ArrayExprSyntax {
      return .sequence(elementType: resolveType(arrayExpr.elements[0].expression))
    }
    
    if node is DictionaryExprSyntax {
      return .dict
    }
    
    if node is IntegerLiteralExprSyntax {
      return .int
    }
    if node is StringLiteralExprSyntax {
      return .string
    }
    if node is FloatLiteralExprSyntax {
      return .float
    }
    if node is BooleanLiteralExprSyntax {
      return .bool
    }
    
    if let tupleExpr = node as? TupleExprSyntax {
      if tupleExpr.elementList.count == 1, let range = tupleExpr.elementList[0].expression.rangeInfo {
        if let leftType = range.left.flatMap({ resolveType($0) })?.toNilIfUnknown {
          return .sequence(elementType: leftType)
        } else if let rightType = range.right.flatMap({ resolveType($0) })?.toNilIfUnknown {
          return .sequence(elementType: rightType)
        } else {
          return .unknown
        }
      }
      
      return .tuple(tupleExpr.elementList.map { resolveType($0.expression) })
    }
    
    if let subscriptExpr = node as? SubscriptExprSyntax {
      let sequenceElementType = resolveType(subscriptExpr.calledExpression).sequenceElementType
      if sequenceElementType != .unknown {
        if subscriptExpr.argumentList.count == 1, let argument = subscriptExpr.argumentList.first?.expression {
          if argument.rangeInfo != nil {
            return .sequence(elementType: sequenceElementType)
          }
          if resolveType(argument) == .int {
            return sequenceElementType
          }
        }
      }
      
      return .unknown
    }
    
    return .unknown
  }
  
  private func _resolveType(_ typeInfo: TypeInfo) -> TypeResolve {
    switch typeInfo {
    case .exact(let type):
      return _resolveType(type)
    case .inferedFromExpr(let expr):
      return resolveType(expr)
    case .inferedFromClosure(let closureExpr, let paramIndex, let paramCount):
      // let x: (X, Y) -> Z = { a,b in ...}
      if let closureVariable = enclosingScope(for: closureExpr)._findVariable(bindingTo: closureExpr) {
        switch closureVariable.typeInfo {
        case .exact(let type):
          guard let argumentsType = (type as? FunctionTypeSyntax)?.arguments else {
            // Eg: let onFetchJobs: JobCardsFetcher.OnFetchJobs = { [weak self] jobs in ... }
            return .unknown
          }
          assert(argumentsType.count == paramCount)
          return _resolveType(argumentsType[paramIndex].type)
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
      let sequenceType = resolveType(sequenceExpr)
      return sequenceType.sequenceElementType
    case .inferedFromTuple(let tupleTypeInfo, let index):
      if case let .tuple(types) = _resolveType(tupleTypeInfo) {
        return types[index]
      }
      return .unknown
    }
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
      return .tuple(tupleType.elements.map { _resolveType($0.type) })
    default:
      if let tokens = type.tokens {
        return .type(tokens)
      }
      return .unknown
    }
  }
  
  private func _resolveFunctionCallType(functionCallExpr: FunctionCallExprSyntax, ignoreOptional: Bool = false) -> TypeResolve {
    
    if let (function, _) = findFunction(functionCallExpr) {
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
        return .sequence(elementType: .type([typeIdentifier.identifier]))
      } else {
        return .sequence(elementType: resolveType(arrayExpr.elements[0].expression))
      }
    }
    
    // [X: Y]()
    if calledExpr is DictionaryExprSyntax {
      return .dict
    }
    
    // doSmth() or A()
    if let identifierExpr = calledExpr as? IdentifierExprSyntax {
      let identifierResolve = resolve(.identifier(identifierExpr)) { resolve in
        switch resolve {
        case .function(let function):
          return function.match(functionCallExpr).isMatched
        case .typeDecl:
          return true
        case .variable:
          return false
        }
      }
      if let identifierResolve = identifierResolve {
        switch identifierResolve {
          // doSmth()
        case .function(let function):
          let returnType = function.signature.output?.returnType
          return returnType.flatMap { _resolveType($0) } ?? .unknown
          // A()
        case .typeDecl(let typeDecl):
          return .type(typeDecl.tokens)
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
      
      let baseType = resolveType(base)
      if _isCollection(baseType) {
        let funcName = memberAccessExpr.name.text
        if ["map", "flatMap", "compactMap", "enumerated"].contains(funcName) {
          return .sequence(elementType: .unknown)
        }
        if ["filter", "sorted"].contains(funcName) {
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
  func isClosureEscape(_ closure: ClosureExprSyntax, nonEscapeRules: [NonEscapeRule]) -> Bool {
    func _isClosureEscape(_ node: ExprSyntax, isFuncParam: Bool) -> Bool {
      if let closureNode = node as? ClosureExprSyntax, let cachedResult = cachedClosureEscapeCheck[closureNode] {
        return cachedResult
      }
      
      // If it's a param, and it's inside an escaping closure, then it's also escaping
      // For eg:
      // func doSmth(block: @escaping () -> Void) {
      //   someObject.callBlock {
      //     block()
      //   }
      // }
      // Here block is a param and it's used inside an escaping closure
      if isFuncParam {
        if let parentClosure = node.enclosingtClosureNode {
          if isClosureEscape(parentClosure, nonEscapeRules: nonEscapeRules) {
            return true
          }
        }
      }
      
      // Function call expression: {...}()
      if node.isCalledExpr() {
        return false // Not escape
      }
      
      // let x = {...}
      // `x` may be used anywhere
      if let variable = enclosingScope(for: node)._findVariable(bindingTo: node) {
        let references = getReferencesToVariable(variable: variable)
        for reference in references {
          if _isClosureEscape(reference, isFuncParam: isFuncParam) == true {
            return true // Escape
          }
        }
        
        return false
      }
      
      // Used as argument in function call: doSmth(a, b, c: {...}) or doSmth(a, b) {...}
      if let (functionCall, argument) = node.getEnclosingFunctionCallForArgument() {
        if let (function, matchedInfo) = findFunction(functionCall) {
          let param: FunctionParameterSyntax!
          if let argument = argument {
            param = matchedInfo.argumentToParamMapping[argument]
          } else {
            param = matchedInfo.trailingClosureArgumentToParam
          }
          guard param != nil else { fatalError("Something wrong") }
          
          // If the param is marked as `@escaping`, we still need to check with the non-escaping rules
          // If the param is not marked as `@escaping`, and it's optional, we don't know anything about it
          // If the param is not marked as `@escaping`, and it's not optional, we know it's non-escaping for sure
          if !param.isEscaping && param.type?.isOptional != true {
            return false
          }
          
          // get the `.function` scope where we define this func
          let scope = self.scope(for: function)
          assert(scope.type.isFunction)
          
          guard let variableForParam = scope.variables.first(where: { $0.raw.token == (param.secondName ?? param.firstName) }) else {
            fatalError("Can't find the Variable that wrap the param")
          }
          let references = getReferencesToVariable(variable: variableForParam)
          for referennce in references {
            if _isClosureEscape(referennce, isFuncParam: true) == true {
              return true
            }
          }
          return false
        } else {
          // Can't resolve the function
        }
      }
      
      // TODO
      // There're other scenarios, such as the closure can be inside a tuple which is a function param
      
      // Finally, fallback to rules
      for rule in nonEscapeRules {
        if rule.isNonEscape(closureNode: node, graph: self) {
          return false // Not escape
        }
      }
      
      return true // Don't know
    }
    
    let result = _isClosureEscape(closure, isFuncParam: false)
    cachedClosureEscapeCheck[closure] = result
    return result
  }
  
  func isCollection(_ node: ExprSyntax) -> Bool {
    let type = resolveType(node)
    return _isCollection(type)
  }
  
  func isOptional(_ node: ExprSyntax) -> Bool {
    return resolveType(node).isOptional
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
    case .int,
         .string,
         .float,
         .bool:
      return false
    case .type:
      // TODO
      return false
    }
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
  func _findVariable(bindingTo node: ExprSyntax) -> Variable? {
    return variables.first(where: { variable -> Bool in
      switch variable.raw {
      case .param, .capture: return false
      case let .binding(_, valueNode):
        return valueNode != nil ? valueNode! == node : false
      }
    })
  }
}
