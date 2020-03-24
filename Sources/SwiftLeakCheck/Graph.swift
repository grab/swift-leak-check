//
//  Graph.swift
//  SwiftLeakCheck
//
//  Copyright 2020 Grabtaxi Holdings PTE LTE (GRAB), All rights reserved.
//  Use of this source code is governed by an MIT-style license that can be found in the LICENSE file
//
//  Created by Hoang Le Pham on 11/11/2019.
//

import SwiftSyntax

public protocol Graph {
  var sourceFileScope: SourceFileScope { get }
  
  /// Return the corresponding scope of a node if the node is of scope-type (class, func, closure,...)
  /// or return the enclosing scope if the node is not scope-type
  /// - Parameter node: The node
  func scope(for node: Syntax) -> Scope
  
  /// Get the scope that encloses a given node
  /// Eg, Scopes that enclose a func could be class, enum,...
  /// Or scopes that enclose a statement could be func, closure,...
  /// If the node is not enclosed by a scope (eg, sourcefile node), return the scope of the node itself
  /// - Parameter node: A node
  /// - Returns: The scope that encloses the node
  func enclosingScope(for node: Syntax) -> Scope
  
  /// Return the TypeDecl that encloses a given node
  /// - Parameter node: given node
  func enclosingTypeDecl(for node: Syntax) -> TypeDecl?
  
  /// Find the nearest scope to a symbol, that can resolve the definition of that symbol
  /// Usually it is the enclosing scope of the symbol
  func closetScopeThatCanResolveSymbol(_ symbol: Symbol) -> Scope
  
  func resolveExprType(_ expr: ExprSyntax) -> TypeResolve
  func resolveVariableType(_ variable: Variable) -> TypeResolve
  func resolveType(_ type: TypeSyntax) -> TypeResolve
  func getAllTypeDeclarations(from typeDecl: TypeDecl) -> [TypeDecl]
  func getAllTypeDeclarations(from name: [String]) -> [TypeDecl]
  
  func resolveVariable(_ identifier: IdentifierExprSyntax) -> Variable?
  func getVariableReferences(variable: Variable) -> [IdentifierExprSyntax]
  
  func resolveFunction(_ funcCallExpr: FunctionCallExprSyntax) -> (Function, Function.MatchResult.MappingInfo)?
  
  func isClosureEscape(_ closure: ClosureExprSyntax, nonEscapeRules: [NonEscapeRule]) -> Bool
  func isCollection(_ node: ExprSyntax) -> Bool
}

final class GraphImpl: Graph {
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
  
  let sourceFileScope: SourceFileScope
  init(sourceFileScope: SourceFileScope) {
    self.sourceFileScope = sourceFileScope
  }
}

// MARK: - Scope
extension GraphImpl {
  func scope(for node: Syntax) -> Scope {
    guard let scopeNode = ScopeNode.from(node: node) else {
      return enclosingScope(for: node)
    }
    
    return scope(for: scopeNode)
  }
  
  func enclosingScope(for node: Syntax) -> Scope {
    guard let scopeNode = node.enclosingScopeNode else {
      let result = scope(for: node)
      assert(result == sourceFileScope)
      return result
    }
    
    return scope(for: scopeNode)
  }
  
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
  
  func closetScopeThatCanResolveSymbol(_ symbol: Symbol) -> Scope {
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
  
  private func _getScopeAndAllExtensions(_ scope: Scope) -> Set<Scope> {
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
    if scope.parent == nil { // source file
      return []
    } else if let tokens = scope.typeDecl?.tokens, let parentTokens = _getFullTypePathForScope(scope.parent!) {
      return parentTokens + tokens
    } else {
      return nil
    }
  }
}


// MARK: - Symbol resolve
extension GraphImpl {
  enum ResolveSymbolOption: Equatable, CaseIterable {
    case function
    case variable
    case typeDecl
  }
  
  func _findSymbol(_ symbol: Symbol,
                   options: [ResolveSymbolOption] = ResolveSymbolOption.allCases,
                   onResult: (SymbolResolve) -> Bool) -> SymbolResolve? {
    var scope: Scope! = closetScopeThatCanResolveSymbol(symbol)
    while scope != nil {
      if let result = cachedSymbolResolved[symbol], onResult(result) {
        return result
      }
      
      if let result = _findSymbol(symbol, options: options, in: scope, onResult: onResult) {
        cachedSymbolResolved[symbol] = result
        return result
      }
      
      scope = scope?.parent
    }
    
    return nil
  }
  
  func _findSymbol(_ symbol: Symbol,
                   options: [ResolveSymbolOption] = ResolveSymbolOption.allCases,
                   in scope: Scope,
                   onResult: (SymbolResolve) -> Bool) -> SymbolResolve? {
    let scopeWithAllExtensions = _getScopeAndAllExtensions(scope)
    for scope in scopeWithAllExtensions {
      if options.contains(.variable) {
        if case let .identifier(node) = symbol, let variable = scope.getVariable(node) {
          let result: SymbolResolve = .variable(variable)
          if onResult(result) {
            cachedReferencesToVariable[variable] = (cachedReferencesToVariable[variable] ?? []) + [node]
            return result
          }
        }
      }
      
      if options.contains(.function) {
        for function in scope.getFunctionWithSymbol(symbol) {
          let result: SymbolResolve = .function(function)
          if onResult(result) {
            return result
          }
        }
      }
      
      if options.contains(.typeDecl) {
        let typeDecls = scope.getTypeDecl(name: symbol.name)
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

// MARK: - Variable reference
extension GraphImpl {
  
  @discardableResult
  func resolveVariable(_ identifier: IdentifierExprSyntax) -> Variable? {
    return _findSymbol(.identifier(identifier), options: [.variable]) { resolve -> Bool in
      if resolve.variable != nil {
        return true
      }
      return false
    }?.variable
  }
  
  func getVariableReferences(variable: Variable) -> [IdentifierExprSyntax] {
    return cachedReferencesToVariable[variable] ?? []
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
extension GraphImpl {
  func resolveFunction(_ funcCallExpr: FunctionCallExprSyntax) -> (Function, Function.MatchResult.MappingInfo)? {
    switch funcCallExpr.calledExpression {
    case let identifier as IdentifierExprSyntax: // doSmth(...) or A(...)
      return _findFunction(symbol: .identifier(identifier), funcCallExpr: funcCallExpr)
    case let memberAccessExpr as MemberAccessExprSyntax: // a.doSmth(...)
      guard let base = memberAccessExpr.base else {
        assert(false, "Is it possible that `base` is nil ? \(memberAccessExpr)")
        return nil
      }
      if couldReferenceSelf(base) {
        return _findFunction(symbol: .token(memberAccessExpr.name), funcCallExpr: funcCallExpr)
      }
      if case let .type(typeDecl) = resolveExprType(base) {
        return _findFunction(symbol: .token(memberAccessExpr.name), funcCallExpr: funcCallExpr, in: typeDecl.scope)
      }
      
      return nil
      
    case is ImplicitMemberExprSyntax, // .create { ... }
         is OptionalChainingExprSyntax: // optional closure
      // TODO
      return nil
    default:
      // Unhandled case
      return nil
    }
  }
  
  // TODO: Currently we only resolve to `func`. This could resole to `closure` as well
  private func _findFunction(symbol: Symbol, funcCallExpr: FunctionCallExprSyntax)
    -> (Function, Function.MatchResult.MappingInfo)? {
    
    var result: (Function, Function.MatchResult.MappingInfo)?
    _ = _findSymbol(symbol, options: [.function]) { resolve -> Bool in
      switch resolve {
      case .variable, .typeDecl: // This could be due to cache
        return false
      case .function(let function):
        let mustStop = enclosingScope(for: function).type.isTypeDecl
        
        switch function.match(funcCallExpr) {
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
  
  private func _findFunction(symbol: Symbol, funcCallExpr: FunctionCallExprSyntax,  in scope: Scope)
    -> (Function, Function.MatchResult.MappingInfo)? {
      
      var result: (Function, Function.MatchResult.MappingInfo)?
      
      _ = _findSymbol(symbol, options: [.function], in: scope, onResult: { resolve in
        switch resolve {
        case .variable, .typeDecl:
          assert(false, "Can't happen")
          return false
        case .function(let function):
          switch function.match(funcCallExpr) {
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
extension GraphImpl {
  func resolveVariableType(_ variable: Variable) -> TypeResolve {
    if let type = cachedVariableType[variable] {
      return type
    }
    
    let result = _resolveType(variable.typeInfo)
    cachedVariableType[variable] = result
    return result
  }
  
  func resolveExprType(_ expr: ExprSyntax) -> TypeResolve {
    if let optionalExpr = expr as? OptionalChainingExprSyntax {
      return .optional(base: resolveExprType(optionalExpr.expression))
    }
    
    if let identifierExpr = expr as? IdentifierExprSyntax {
      if let variable = resolveVariable(identifierExpr) {
        return resolveVariableType(variable)
      }
      if identifierExpr.identifier.text == "self" {
        return enclosingTypeDecl(for: expr).flatMap { .type($0) } ?? .unknown
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
    
    if let functionCallExpr = expr as? FunctionCallExprSyntax {
      let result = cachedFunCallExprType[functionCallExpr] ?? _resolveFunctionCallType(functionCallExpr: functionCallExpr)
      cachedFunCallExprType[functionCallExpr] = result
      return result
    }
    
    if let arrayExpr = expr as? ArrayExprSyntax {
      return .sequence(elementType: resolveExprType(arrayExpr.elements[0].expression))
    }
    
    if expr is DictionaryExprSyntax {
      return .dict
    }
    
    if expr is IntegerLiteralExprSyntax {
      return getAllTypeDeclarations(from: ["Int"]).first.flatMap { .type($0) } ?? .name(["Int"])
    }
    if expr is StringLiteralExprSyntax {
      return getAllTypeDeclarations(from: ["String"]).first.flatMap { .type($0) } ?? .name(["String"])
    }
    if expr is FloatLiteralExprSyntax {
      return getAllTypeDeclarations(from: ["Float"]).first.flatMap { .type($0) } ?? .name(["Float"])
    }
    if expr is BooleanLiteralExprSyntax {
      return getAllTypeDeclarations(from: ["Bool"]).first.flatMap { .type($0) } ?? .name(["Bool"])
    }
    
    if let tupleExpr = expr as? TupleExprSyntax {
      if tupleExpr.elementList.count == 1, let range = tupleExpr.elementList[0].expression.rangeInfo {
        if let leftType = range.left.flatMap({ resolveExprType($0) })?.toNilIfUnknown {
          return .sequence(elementType: leftType)
        } else if let rightType = range.right.flatMap({ resolveExprType($0) })?.toNilIfUnknown {
          return .sequence(elementType: rightType)
        } else {
          return .unknown
        }
      }
      
      return .tuple(tupleExpr.elementList.map { resolveExprType($0.expression) })
    }
    
    if let subscriptExpr = expr as? SubscriptExprSyntax {
      let sequenceElementType = resolveExprType(subscriptExpr.calledExpression).sequenceElementType
      if sequenceElementType != .unknown {
        if subscriptExpr.argumentList.count == 1, let argument = subscriptExpr.argumentList.first?.expression {
          if argument.rangeInfo != nil {
            return .sequence(elementType: sequenceElementType)
          }
          if resolveExprType(argument).isInt {
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
      return resolveType(type)
    case .inferedFromExpr(let expr):
      return resolveExprType(expr)
    case .inferedFromClosure(let closureExpr, let paramIndex, let paramCount):
      // let x: (X, Y) -> Z = { a,b in ...}
      if let closureVariable = enclosingScope(for: closureExpr).getVariableBindingTo(expr: closureExpr) {
        switch closureVariable.typeInfo {
        case .exact(let type):
          guard let argumentsType = (type as? FunctionTypeSyntax)?.arguments else {
            // Eg: let onFetchJobs: JobCardsFetcher.OnFetchJobs = { [weak self] jobs in ... }
            return .unknown
          }
          assert(argumentsType.count == paramCount)
          return resolveType(argumentsType[paramIndex].type)
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
      let sequenceType = resolveExprType(sequenceExpr)
      return sequenceType.sequenceElementType
    case .inferedFromTuple(let tupleTypeInfo, let index):
      if case let .tuple(types) = _resolveType(tupleTypeInfo) {
        return types[index]
      }
      return .unknown
    }
  }
  
  func resolveType(_ type: TypeSyntax) -> TypeResolve {
    if type.isOptional {
      return .optional(base: resolveType(type.wrapped))
    }
    
    switch type {
    case let arrayType as ArrayTypeSyntax:
      return .sequence(elementType: resolveType(arrayType.elementType))
    case is DictionaryTypeSyntax:
      return .dict
    case let tupleType as TupleTypeSyntax:
      return .tuple(tupleType.elements.map { resolveType($0.type) })
    default:
      if let tokens = type.tokens {
        if let typeDecl = resolveTypeDecl(tokens: tokens) {
          return .type(typeDecl)
        } else {
          return .name(tokens.map { $0.text })
        }
      }
      return .unknown
    }
  }
  
  private func _resolveFunctionCallType(functionCallExpr: FunctionCallExprSyntax, ignoreOptional: Bool = false) -> TypeResolve {
    
    if let (function, _) = resolveFunction(functionCallExpr) {
      if let type = function.signature.output?.returnType {
        return resolveType(type)
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
        if let typeDecl = resolveTypeDecl(tokens: [typeIdentifier.identifier]) {
          return .sequence(elementType: .type(typeDecl))
        } else {
          return .sequence(elementType: .name([typeIdentifier.identifier.text]))
        }
      } else {
        return .sequence(elementType: resolveExprType(arrayExpr.elements[0].expression))
      }
    }
    
    // [X: Y]()
    if calledExpr is DictionaryExprSyntax {
      return .dict
    }
    
    // doSmth() or A()
    if let identifierExpr = calledExpr as? IdentifierExprSyntax {
      let identifierResolve = _findSymbol(.identifier(identifierExpr)) { resolve in
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
          return returnType.flatMap { resolveType($0) } ?? .unknown
          // A()
        case .typeDecl(let typeDecl):
          return .type(typeDecl)
        case .variable:
          break
        }
      }
    }
    
    // x.y()
    if let memberAccessExpr = calledExpr as? MemberAccessExprSyntax {
      guard let base = memberAccessExpr.base else {
        fatalError("Is it possible that `base` is nil ? \(memberAccessExpr)")
      }
      
      let baseType = resolveExprType(base)
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

// MARK: - TypeDecl resolve
extension GraphImpl {
  
  func resolveTypeDecl(tokens: [TokenSyntax]) -> TypeDecl? {
    guard tokens.count > 0 else {
      return nil
    }
    
    return resolveTypeDecl(token: tokens[0], onResult: { typeDecl in
      var currentScope = typeDecl.scope
      for token in tokens[1...] {
        if let scope = currentScope.getTypeDecl(name: token.text).first?.scope {
          currentScope = scope
        } else {
          return false
        }
      }
      return true
    })
  }
  
  func resolveTypeDecl(token: TokenSyntax, onResult: (TypeDecl) -> Bool) -> TypeDecl? {
    let result =  _findSymbol(.token(token), options: [.typeDecl]) { resolve in
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
  
  func getAllTypeDeclarations(from typeDecl: TypeDecl) -> [TypeDecl] {
    return getAllTypeDeclarations(from: typeDecl.name)
  }
  
  func getAllTypeDeclarations(from name: [String]) -> [TypeDecl] {
    return topLevelTypeDecls.filter { typeDecl in
      return typeDecl.name == name
    }
  }
  
  var topLevelTypeDecls: [TypeDecl] {
    return sourceFileScope.childTypeDecls
  }
}

// MARK: - Classification
extension GraphImpl {
  func isClosureEscape(_ closure: ClosureExprSyntax, nonEscapeRules: [NonEscapeRule]) -> Bool {
    func _isClosureEscape(_ expr: ExprSyntax, isFuncParam: Bool) -> Bool {
      if let closureNode = expr as? ClosureExprSyntax, let cachedResult = cachedClosureEscapeCheck[closureNode] {
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
        if let parentClosure = expr.enclosingtClosureNode {
          if isClosureEscape(parentClosure, nonEscapeRules: nonEscapeRules) {
            return true
          }
        }
      }
      
      // Function call expression: {...}()
      if expr.isCalledExpr() {
        return false // Not escape
      }
      
      // let x = {...}
      // `x` may be used anywhere
      if let variable = enclosingScope(for: expr).getVariableBindingTo(expr: expr) {
        let references = getVariableReferences(variable: variable)
        for reference in references {
          if _isClosureEscape(reference, isFuncParam: isFuncParam) == true {
            return true // Escape
          }
        }
        
        return false
      }
      
      // Used as argument in function call: doSmth(a, b, c: {...}) or doSmth(a, b) {...}
      if let (functionCall, argument) = expr.getEnclosingFunctionCallForArgument() {
        if let (function, matchedInfo) = resolveFunction(functionCall) {
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
          let references = getVariableReferences(variable: variableForParam)
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
      
      // Finally, fallback to rules
      for rule in nonEscapeRules {
        if rule.isNonEscape(closureNode: expr, graph: self) {
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
    let type = resolveExprType(node)
    return _isCollection(type)
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
      return false
    case .type:
      return false
    }
  }
}

private extension Scope {
  func getVariableBindingTo(expr: ExprSyntax) -> Variable? {
    return variables.first(where: { variable -> Bool in
      switch variable.raw {
      case .param, .capture: return false
      case let .binding(_, valueNode):
        return valueNode != nil ? valueNode! == expr : false
      }
    })
  }
}

private extension TypeResolve {
  var toNilIfUnknown: TypeResolve? {
    switch self {
    case .unknown: return nil
    default: return self
    }
  }
}
